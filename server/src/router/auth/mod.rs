pub(crate) mod extractors;

use super::AppState;
use crate::api::{AuthError, LoginRequest, MeResponse, UserResponse};
use axum::Json;
use axum::Router;
use axum::extract::State;
use axum::http::StatusCode;
use axum::routing::{get, post};
use axum_extra::extract::cookie::{Cookie, CookieJar, SameSite};
use extractors::{CurrentUser, require_auth};
use std::sync::LazyLock;

pub(crate) fn routes(state: AppState) -> Router<AppState> {
    let protected = Router::new()
        .route("/api/v1/auth/me", get(me))
        .route_layer(axum::middleware::from_fn_with_state(state, require_auth));

    Router::new()
        .route("/api/v1/auth/login", post(login))
        .route("/api/v1/auth/logout", post(logout))
        .merge(protected)
}

async fn login(
    State(state): State<AppState>,
    jar: CookieJar,
    Json(body): Json<LoginRequest>,
) -> (CookieJar, Json<Result<UserResponse, AuthError>>) {
    let row = sqlx::query!(
        r#"
        select id::text as "id!", email, password_hash, name, is_admin,
               (deleted_at is not null) as "deactivated!"
        from users
        where email = $1
        "#,
        body.email
    )
    .fetch_optional(&state.pool)
    .await
    .expect("error querying user");

    let Some(row) = row else {
        // run the hash anyway, so a missing account answers in the same time
        let _ = verify_password(&body.password, &DUMMY_HASH);
        return (jar, Json(Err(AuthError::InvalidCredentials)));
    };

    if !verify_password(&body.password, &row.password_hash) {
        return (jar, Json(Err(AuthError::InvalidCredentials)));
    }

    if row.deactivated {
        return (jar, Json(Err(AuthError::AccountDeactivated)));
    }

    let token = crate::jwt::sign_token(&row.id, &state.jwt_secret);

    sqlx::query!(
        "update users set last_login_at = now() where email = $1",
        row.email.as_str()
    )
    .execute(&state.pool)
    .await
    .expect("error updating last login time");

    (
        jar.add(token_cookie(token)),
        Json(Ok(UserResponse {
            id: row.id,
            email: row.email,
            name: row.name,
            is_admin: row.is_admin,
        })),
    )
}

async fn me(
    user: CurrentUser,
    perms: crate::rbac::check::Permissions,
) -> Json<Result<MeResponse, AuthError>> {
    Json(Ok(MeResponse {
        id: user.id,
        email: user.email,
        name: user.name,
        is_admin: user.is_admin,
        permissions: perms.names(),
    }))
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
