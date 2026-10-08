use crate::telemetry::Traced;
pub(crate) mod extractors;

use super::AppState;
use crate::api::{
    AuthError, ChangePassword, LoginRequest, LoginResponse, MeResponse, PasswordError,
    RegisterRequest, RegistrationError, TotpCode, TotpConfirm, TotpDisable, TotpSetup,
    UserResponse,
};
use axum::Json;
use axum::Router;
use axum::extract::State;
use axum::http::StatusCode;
use axum::routing::{get, post};
use axum_extra::extract::cookie::{Cookie, CookieJar, SameSite};
use extractors::{CurrentUser, require_auth};
use std::sync::LazyLock;
use totp_rs::{Algorithm, Builder, Secret, Totp};
use uuid::Uuid;

pub(crate) fn routes(state: AppState) -> Router<AppState> {
    let protected = Router::new()
        .route("/api/v1/auth/me", get(me))
        .route("/api/v1/auth/password", post(change_password))
        .route("/api/v1/auth/totp/setup", post(totp_setup))
        .route("/api/v1/auth/totp/enable", post(totp_enable))
        .route("/api/v1/auth/totp/disable", post(totp_disable))
        .route_layer(axum::middleware::from_fn_with_state(state, require_auth));

    Router::new()
        .route("/api/v1/auth/register", post(register))
        .route("/api/v1/auth/login", post(login))
        .route("/api/v1/auth/login/totp", post(login_totp))
        .route("/api/v1/auth/logout", post(logout))
        .merge(protected)
}

async fn register(
    State(state): State<AppState>,
    jar: CookieJar,
    Json(body): Json<RegisterRequest>,
) -> (CookieJar, Json<Result<UserResponse, RegistrationError>>) {
    use sqlx::error::ErrorKind;

    if !crate::settings::get_bool(&state.pool, crate::settings::REGISTRATION_ENABLED).await {
        tracing::info!(auth.outcome = "registration_disabled");
        return (jar, Json(Err(RegistrationError::RegistrationDisabled)));
    }

    let email = body.email.trim();
    if !email.contains('@') {
        tracing::info!(auth.outcome = "invalid_email");
        return (jar, Json(Err(RegistrationError::InvalidEmail)));
    }

    if body.password.len() < 8 {
        tracing::info!(auth.outcome = "weak_password", email = %email);
        return (jar, Json(Err(RegistrationError::WeakPassword)));
    }

    let password_hash = hash_password(&body.password);

    let name = body
        .name
        .as_deref()
        .map(str::trim)
        .filter(|value| !value.is_empty());

    let result = sqlx::query!(
        r#"
        insert into users (email, password_hash, name, is_admin)
        values ($1, $2, $3, false)
        returning id::text as "id!", email, name, is_admin
        "#,
        email,
        password_hash,
        name,
    )
    .fetch_one(&state.pool)
    .traced("auth.register")
    .await;

    let row = match result {
        Ok(row) => row,
        Err(sqlx::Error::Database(e)) if e.kind() == ErrorKind::UniqueViolation => {
            tracing::info!(auth.outcome = "email_taken", email = %email);
            return (jar, Json(Err(RegistrationError::EmailTaken)));
        }
        Err(e) => panic!("error registering user: {e}"),
    };

    tracing::info!(auth.outcome = "registered", email = %row.email);

    sqlx::query!(
        "update users set last_login_at = now() where id = $1",
        parse_id(&row.id)
    )
    .execute(&state.pool)
    .traced("auth.register.touch")
    .await
    .expect("error updating last login time");

    (
        jar.add(token_cookie_for(&state, &row.id)),
        Json(Ok(UserResponse {
            id: row.id,
            email: row.email,
            name: row.name,
            is_admin: row.is_admin,
        })),
    )
}

async fn login(
    State(state): State<AppState>,
    jar: CookieJar,
    Json(body): Json<LoginRequest>,
) -> (CookieJar, Json<Result<LoginResponse, AuthError>>) {
    let row = sqlx::query!(
        r#"
        select id::text as "id!", email, password_hash, name, is_admin, totp_secret,
               (deleted_at is not null) as "deactivated!"
        from users
        where email = $1
        "#,
        body.email
    )
    .fetch_optional(&state.pool)
    .traced("auth.login.lookup")
    .await
    .expect("error querying user");

    let Some(row) = row else {
        // run the hash anyway, so a missing account answers in the same time
        let _ = verify_password(&body.password, &DUMMY_HASH);
        tracing::warn!(auth.outcome = "invalid_credentials", email = %body.email);
        return (jar, Json(Err(AuthError::InvalidCredentials)));
    };

    if !verify_password(&body.password, &row.password_hash) {
        tracing::warn!(auth.outcome = "invalid_credentials", email = %body.email);
        return (jar, Json(Err(AuthError::InvalidCredentials)));
    }

    if row.deactivated {
        tracing::warn!(auth.outcome = "account_deactivated", email = %body.email);
        return (jar, Json(Err(AuthError::AccountDeactivated)));
    }

    if row.totp_secret.is_some() {
        tracing::info!(auth.outcome = "totp_required", email = %body.email);
        let pending = crate::jwt::sign_pending_token(&row.id, &state.jwt_secret);
        return (
            jar.add(token_cookie(pending)),
            Json(Ok(LoginResponse::TotpRequired)),
        );
    }

    tracing::info!(auth.outcome = "authenticated", email = %body.email);
    let user = finish_login(&state, &row.id, row.email, row.name, row.is_admin).await;
    (jar.add(token_cookie_for(&state, &row.id)), Json(Ok(user)))
}

async fn login_totp(
    State(state): State<AppState>,
    jar: CookieJar,
    Json(body): Json<TotpCode>,
) -> (CookieJar, Json<Result<LoginResponse, AuthError>>) {
    let Some(claims) = jar
        .get("token")
        .and_then(|cookie| crate::jwt::read_token(cookie.value(), &state.jwt_secret).ok())
        .filter(|claims| claims.totp_pending)
    else {
        return (jar, Json(Err(AuthError::NotSignedIn)));
    };

    let Ok(id) = Uuid::parse_str(&claims.sub) else {
        return (jar, Json(Err(AuthError::NotSignedIn)));
    };

    let row = sqlx::query!(
        r#"
        select id::text as "id!", email, name, is_admin, totp_secret,
               (deleted_at is not null) as "deactivated!"
        from users
        where id = $1 and totp_secret is not null
        "#,
        id
    )
    .fetch_optional(&state.pool)
    .traced("auth.totp.lookup")
    .await
    .expect("error querying user");

    let Some(row) = row else {
        return (jar, Json(Err(AuthError::NotSignedIn)));
    };

    if row.deactivated {
        return (jar, Json(Err(AuthError::AccountDeactivated)));
    }

    let issuer = crate::settings::get(&state.pool, crate::settings::COMPANY_NAME).await;
    let valid = row
        .totp_secret
        .as_deref()
        .and_then(|secret| build_totp(&issuer, secret, &row.email))
        .and_then(|totp| totp.check_current(&body.code))
        .is_some();

    if !valid {
        tracing::warn!(auth.outcome = "invalid_totp", email = %row.email);
        return (jar, Json(Err(AuthError::InvalidCode)));
    }

    tracing::info!(auth.outcome = "authenticated", email = %row.email);
    let user = finish_login(&state, &row.id, row.email, row.name, row.is_admin).await;
    (jar.add(token_cookie_for(&state, &row.id)), Json(Ok(user)))
}

async fn me(
    user: CurrentUser,
    State(state): State<AppState>,
    perms: crate::rbac::check::Permissions,
) -> Json<Result<MeResponse, AuthError>> {
    let company_name = crate::settings::get(&state.pool, crate::settings::COMPANY_NAME).await;

    Json(Ok(MeResponse {
        id: user.id,
        email: user.email,
        name: user.name,
        is_admin: user.is_admin,
        permissions: perms.names(),
        totp_enabled: user.totp_enabled,
        company_name,
    }))
}

async fn change_password(
    user: CurrentUser,
    State(state): State<AppState>,
    Json(body): Json<ChangePassword>,
) -> Json<Result<(), PasswordError>> {
    let id = parse_id(&user.id);

    let row = sqlx::query!("select password_hash from users where id = $1", id)
        .fetch_one(&state.pool)
        .traced("auth.password.lookup")
        .await
        .expect("error querying user");

    if !verify_password(&body.current_password, &row.password_hash) {
        return Json(Err(PasswordError::IncorrectPassword));
    }

    if body.new_password.len() < 8 {
        return Json(Err(PasswordError::PasswordTooShort));
    }

    let hash = hash_password(&body.new_password);
    sqlx::query!(
        "update users set password_hash = $1 where id = $2",
        hash,
        id
    )
    .execute(&state.pool)
    .traced("auth.password.update")
    .await
    .expect("error updating password");

    Json(Ok(()))
}

async fn totp_setup(user: CurrentUser, State(state): State<AppState>) -> Json<TotpSetup> {
    let secret = Secret::generate().to_base32();

    let issuer = crate::settings::get(&state.pool, crate::settings::COMPANY_NAME).await;
    let totp =
        build_totp(&issuer, &secret, &user.email).expect("error building totp for a fresh secret");
    let otpauth_url = totp.to_url().expect("error building totp url");
    let qr = totp.to_qr_base64().expect("error building totp qr code");

    Json(TotpSetup {
        secret,
        otpauth_url,
        qr_png: format!("data:image/png;base64,{qr}"),
    })
}

async fn totp_enable(
    user: CurrentUser,
    State(state): State<AppState>,
    Json(body): Json<TotpConfirm>,
) -> Json<Result<(), AuthError>> {
    let issuer = crate::settings::get(&state.pool, crate::settings::COMPANY_NAME).await;
    let valid = build_totp(&issuer, &body.secret, &user.email)
        .and_then(|totp| totp.check_current(&body.code))
        .is_some();

    if !valid {
        return Json(Err(AuthError::InvalidCode));
    }

    let id = parse_id(&user.id);
    sqlx::query!(
        "update users set totp_secret = $1 where id = $2",
        body.secret,
        id
    )
    .execute(&state.pool)
    .traced("auth.totp.enable")
    .await
    .expect("error enabling totp");

    Json(Ok(()))
}

async fn totp_disable(
    user: CurrentUser,
    State(state): State<AppState>,
    Json(body): Json<TotpDisable>,
) -> Json<Result<(), PasswordError>> {
    let id = parse_id(&user.id);

    let row = sqlx::query!("select password_hash from users where id = $1", id)
        .fetch_one(&state.pool)
        .traced("auth.totp.disable.lookup")
        .await
        .expect("error querying user");

    if !verify_password(&body.password, &row.password_hash) {
        return Json(Err(PasswordError::IncorrectPassword));
    }

    sqlx::query!("update users set totp_secret = null where id = $1", id)
        .execute(&state.pool)
        .traced("auth.totp.disable")
        .await
        .expect("error disabling totp");

    Json(Ok(()))
}

// Logout clears the cookie. It needs no auth, because a stale token holder must
// still be able to drop the cookie.
async fn logout(jar: CookieJar) -> (CookieJar, StatusCode) {
    let removal = Cookie::build(("token", "")).path("/").build();
    (jar.remove(removal), StatusCode::NO_CONTENT)
}

fn token_cookie(token: String) -> Cookie<'static> {
    Cookie::build(("token", token))
        .http_only(true)
        .same_site(SameSite::Lax)
        .path("/")
        .build()
}

async fn finish_login(
    state: &AppState,
    id: &str,
    email: String,
    name: Option<String>,
    is_admin: bool,
) -> LoginResponse {
    sqlx::query!(
        "update users set last_login_at = now() where id = $1",
        parse_id(id)
    )
    .execute(&state.pool)
    .traced("auth.login.touch")
    .await
    .expect("error updating last login time");

    LoginResponse::Authenticated {
        user: UserResponse {
            id: id.to_string(),
            email,
            name,
            is_admin,
        },
    }
}

fn token_cookie_for(state: &AppState, id: &str) -> Cookie<'static> {
    token_cookie(crate::jwt::sign_token(id, &state.jwt_secret))
}

fn parse_id(id: &str) -> Uuid {
    Uuid::parse_str(id).expect("error parsing user id")
}

fn build_totp(issuer: &str, secret: &str, email: &str) -> Option<Totp> {
    let secret = Secret::try_from_base32(secret).ok()?;
    Builder::new()
        .with_algorithm(Algorithm::SHA1)
        .with_digits(6)
        .with_skew(1)
        .with_step_duration(30)
        .with_secret(secret)
        .with_issuer(Some(issuer))
        .with_account_name(email)
        .build()
        .ok()
}

fn hash_password(password: &str) -> String {
    use argon2::{Argon2, PasswordHasher};

    Argon2::default()
        .hash_password(password.as_bytes())
        .expect("error hashing password")
        .to_string()
}

fn verify_password(password: &str, hash: &str) -> bool {
    use argon2::{Argon2, PasswordHash, PasswordVerifier};

    let Ok(parsed) = PasswordHash::new(hash) else {
        return false;
    };
    Argon2::default()
        .verify_password(password.as_bytes(), &parsed)
        .is_ok()
}

static DUMMY_HASH: LazyLock<String> = LazyLock::new(|| {
    use argon2::{Argon2, PasswordHasher};

    Argon2::default()
        .hash_password(b"dummy-password")
        .expect("error hashing dummy password")
        .to_string()
});
