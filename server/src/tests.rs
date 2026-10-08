use crate::api::{
    AuthError, ChangePassword, CreateRole, CreateUser, LoginRequest, LoginResponse, MeResponse,
    PasswordError, PermissionInfo, PermissionsBody, PublicConfig, RegisterRequest,
    RegistrationError, RoleBody, RolePage, RoleResponse, SettingInfo, SettingUpdate, SettingsBody,
    TotpCode, TotpConfirm, TotpDisable, TotpSetup, UserResponse,
};
use crate::pagination::ListParams;
use crate::router::{self, AppState};
use axum::Router;
use axum::body::Body;
use axum::http::{Request, StatusCode, header};
use serde::Serialize;
use serde::de::DeserializeOwned;
use sqlx::PgPool;
use sqlx::postgres::PgPoolOptions;
use std::collections::HashMap;
use std::sync::{Arc, Mutex};
use tokio::sync::broadcast;
use tower::ServiceExt;
use uuid::Uuid;

const SECRET: &str = "test-secret";

async fn harness() -> (Router, PgPool) {
    let url = std::env::var("DATABASE_URL").expect("error reading DATABASE_URL for the tests");
    let pool = PgPoolOptions::new()
        .connect(&url)
        .await
        .expect("error connecting to the test database");

    let (events, _) = broadcast::channel(16);
    let state = AppState {
        pool: pool.clone(),
        jwt_secret: Arc::from(SECRET),
        secure_cookies: false,
        presence: Arc::new(Mutex::new(HashMap::new())),
        events,
    };

    (router::build(state), pool)
}

async fn send(
    app: &Router,
    method: &str,
    uri: &str,
    cookie: Option<&str>,
    body: Option<Vec<u8>>,
) -> (StatusCode, Option<String>, Vec<u8>) {
    let mut builder = Request::builder().method(method).uri(uri);
    if let Some(cookie) = cookie {
        builder = builder.header(header::COOKIE, cookie);
    }

    let request = match body {
        Some(body) => builder
            .header(header::CONTENT_TYPE, "application/json")
            .body(Body::from(body))
            .expect("error building the request"),
        None => builder
            .body(Body::empty())
            .expect("error building the request"),
    };

    let response = app
        .clone()
        .oneshot(request)
        .await
        .expect("error dispatching the request");

    let status = response.status();
    let set_cookie = response
        .headers()
        .get(header::SET_COOKIE)
        .and_then(|value| value.to_str().ok())
        .map(str::to_string);
    let bytes = axum::body::to_bytes(response.into_body(), usize::MAX)
        .await
        .expect("error reading the response body");

    (status, set_cookie, bytes.to_vec())
}

fn body<T: Serialize>(value: &T) -> Vec<u8> {
    serde_json::to_vec(value).expect("error serializing the request body")
}

fn decode<T: DeserializeOwned>(bytes: &[u8]) -> T {
    serde_json::from_slice(bytes).expect("error decoding the response body")
}

fn hash_password(password: &str) -> String {
    use argon2::{Argon2, PasswordHasher};

    Argon2::default()
        .hash_password(password.as_bytes())
        .expect("error hashing a test password")
        .to_string()
}

async fn unique(pool: &PgPool) -> String {
    sqlx::query_scalar!(r#"select gen_random_uuid()::text as "id!""#)
        .fetch_one(pool)
        .await
        .expect("error generating a unique test value")
}

async fn unique_email(pool: &PgPool) -> String {
    format!("test-{}@example.test", unique(pool).await)
}

async fn admin_session(pool: &PgPool) -> String {
    let (id, _) = insert_user(pool, "password123", true).await;
    session_cookie(id)
}

async fn insert_role(pool: &PgPool) -> Uuid {
    let name = format!("role-{}", unique(pool).await);
    sqlx::query_scalar!("insert into roles (name) values ($1) returning id", name)
        .fetch_one(pool)
        .await
        .expect("error inserting a test role")
}

fn totp_code(secret: &str) -> String {
    use totp_rs::{Algorithm, Builder, Secret};

    Builder::new()
        .with_algorithm(Algorithm::SHA1)
        .with_digits(6)
        .with_skew(1)
        .with_step_duration(30)
        .with_secret(Secret::try_from_base32(secret).expect("error parsing the totp secret"))
        .with_issuer(Some("test"))
        .with_account_name("test@example.test")
        .build()
        .expect("error building a totp")
        .generate_current()
        .to_string()
}

async fn insert_user(pool: &PgPool, password: &str, is_admin: bool) -> (Uuid, String) {
    let email = unique_email(pool).await;
    let hash = hash_password(password);

    let id = sqlx::query_scalar!(
        "insert into users (email, password_hash, is_admin) values ($1, $2, $3) returning id",
        email,
        hash,
        is_admin,
    )
    .fetch_one(pool)
    .await
    .expect("error inserting a test user");

    (id, email)
}

fn session_cookie(id: Uuid) -> String {
    format!("token={}", crate::jwt::sign_token(&id.to_string(), SECRET))
}

#[tokio::test]
async fn login_succeeds_and_sets_a_session_cookie() {
    let (app, pool) = harness().await;
    let (_, email) = insert_user(&pool, "password123", false).await;

    let (status, cookie, bytes) = send(
        &app,
        "POST",
        "/api/v1/auth/login",
        None,
        Some(body(&LoginRequest {
            email: email.clone(),
            password: "password123".to_string(),
        })),
    )
    .await;

    assert_eq!(status, StatusCode::OK);
    let result: Result<LoginResponse, AuthError> = decode(&bytes);
    match result {
        Ok(LoginResponse::Authenticated { user }) => {
            assert_eq!(user.email, email);
            assert!(!user.is_admin);
        }
        other => panic!("expected an authenticated response, got {other:?}"),
    }

    let cookie = cookie.expect("expected a Set-Cookie header");
    assert!(cookie.contains("token="));
    assert!(cookie.contains("HttpOnly"));
    assert!(!cookie.contains("Secure"));
}

#[tokio::test]
async fn login_rejects_a_wrong_password() {
    let (app, pool) = harness().await;
    let (_, email) = insert_user(&pool, "password123", false).await;

    let (status, cookie, bytes) = send(
        &app,
        "POST",
        "/api/v1/auth/login",
        None,
        Some(body(&LoginRequest {
            email,
            password: "not-the-password".to_string(),
        })),
    )
    .await;

    assert_eq!(status, StatusCode::OK);
    let result: Result<LoginResponse, AuthError> = decode(&bytes);
    assert!(matches!(result, Err(AuthError::InvalidCredentials)));
    assert!(
        cookie.is_none(),
        "a failed login must not set a session cookie"
    );
}

#[tokio::test]
async fn login_rejects_a_deactivated_account() {
    let (app, pool) = harness().await;
    let (id, email) = insert_user(&pool, "password123", false).await;

    sqlx::query!("update users set deleted_at = now() where id = $1", id)
        .execute(&pool)
        .await
        .expect("error deactivating the test user");

    let (_, _, bytes) = send(
        &app,
        "POST",
        "/api/v1/auth/login",
        None,
        Some(body(&LoginRequest {
            email,
            password: "password123".to_string(),
        })),
    )
    .await;

    let result: Result<LoginResponse, AuthError> = decode(&bytes);
    assert!(matches!(result, Err(AuthError::AccountDeactivated)));
}

#[tokio::test]
async fn me_is_closed_without_a_session() {
    let (app, _) = harness().await;

    let (status, _, bytes) = send(&app, "GET", "/api/v1/auth/me", None, None).await;

    assert_eq!(status, StatusCode::OK);
    let result: Result<MeResponse, AuthError> = decode(&bytes);
    assert!(matches!(result, Err(AuthError::NotSignedIn)));
}

#[tokio::test]
async fn me_returns_the_user_with_a_valid_session() {
    let (app, pool) = harness().await;
    let (id, email) = insert_user(&pool, "password123", true).await;

    let (status, _, bytes) = send(
        &app,
        "GET",
        "/api/v1/auth/me",
        Some(&session_cookie(id)),
        None,
    )
    .await;

    assert_eq!(status, StatusCode::OK);
    let result: Result<MeResponse, AuthError> = decode(&bytes);
    let me = result.expect("expected a user response");
    assert_eq!(me.email, email);
    assert!(me.is_admin);
    assert!(
        me.permissions
            .contains(&crate::rbac::users::read::NAME.to_string())
    );
}

#[tokio::test]
async fn listing_users_needs_permission() {
    let (app, pool) = harness().await;

    let (plain, _) = insert_user(&pool, "password123", false).await;
    let (forbidden, _, _) = send(
        &app,
        "GET",
        "/api/v1/users",
        Some(&session_cookie(plain)),
        None,
    )
    .await;
    assert_eq!(forbidden, StatusCode::FORBIDDEN);

    let (admin, _) = insert_user(&pool, "password123", true).await;
    let (allowed, _, _) = send(
        &app,
        "GET",
        "/api/v1/users",
        Some(&session_cookie(admin)),
        None,
    )
    .await;
    assert_eq!(allowed, StatusCode::OK);
}

#[tokio::test]
async fn register_respects_the_setting() {
    let (app, pool) = harness().await;

    crate::settings::set(&pool, crate::settings::REGISTRATION_ENABLED, "false").await;
    let (_, _, bytes) = send(
        &app,
        "POST",
        "/api/v1/auth/register",
        None,
        Some(body(&RegisterRequest {
            email: unique_email(&pool).await,
            password: "password123".to_string(),
            name: None,
        })),
    )
    .await;
    let result: Result<UserResponse, RegistrationError> = decode(&bytes);
    assert!(matches!(
        result,
        Err(RegistrationError::RegistrationDisabled)
    ));

    crate::settings::set(&pool, crate::settings::REGISTRATION_ENABLED, "true").await;
    let email = unique_email(&pool).await;
    let (status, cookie, bytes) = send(
        &app,
        "POST",
        "/api/v1/auth/register",
        None,
        Some(body(&RegisterRequest {
            email: email.clone(),
            password: "password123".to_string(),
            name: None,
        })),
    )
    .await;
    assert_eq!(status, StatusCode::OK);
    let result: Result<UserResponse, RegistrationError> = decode(&bytes);
    let user = result.expect("expected a created user");
    assert_eq!(user.email, email);
    assert!(!user.is_admin);
    assert!(
        cookie
            .expect("expected a session cookie")
            .contains("token=")
    );

    let (_, _, bytes) = send(
        &app,
        "POST",
        "/api/v1/auth/register",
        None,
        Some(body(&RegisterRequest {
            email: "no-at-sign".to_string(),
            password: "password123".to_string(),
            name: None,
        })),
    )
    .await;
    let result: Result<UserResponse, RegistrationError> = decode(&bytes);
    assert!(matches!(result, Err(RegistrationError::InvalidEmail)));

    let (_, _, bytes) = send(
        &app,
        "POST",
        "/api/v1/auth/register",
        None,
        Some(body(&RegisterRequest {
            email: unique_email(&pool).await,
            password: "short".to_string(),
            name: None,
        })),
    )
    .await;
    let result: Result<UserResponse, RegistrationError> = decode(&bytes);
    assert!(matches!(result, Err(RegistrationError::WeakPassword)));

    let (_, taken) = insert_user(&pool, "password123", false).await;
    let (_, _, bytes) = send(
        &app,
        "POST",
        "/api/v1/auth/register",
        None,
        Some(body(&RegisterRequest {
            email: taken,
            password: "password123".to_string(),
            name: None,
        })),
    )
    .await;
    let result: Result<UserResponse, RegistrationError> = decode(&bytes);
    assert!(matches!(result, Err(RegistrationError::EmailTaken)));

    crate::settings::set(&pool, crate::settings::REGISTRATION_ENABLED, "false").await;
}

const MISSING: &str = "00000000-0000-0000-0000-000000000000";

#[tokio::test]
async fn login_rejects_an_unknown_email() {
    let (app, pool) = harness().await;
    let email = unique_email(&pool).await;

    let (status, cookie, bytes) = send(
        &app,
        "POST",
        "/api/v1/auth/login",
        None,
        Some(body(&LoginRequest {
            email,
            password: "password123".to_string(),
        })),
    )
    .await;

    assert_eq!(status, StatusCode::OK);
    let result: Result<LoginResponse, AuthError> = decode(&bytes);
    assert!(matches!(result, Err(AuthError::InvalidCredentials)));
    assert!(cookie.is_none());
}

#[tokio::test]
async fn me_rejects_a_garbage_token() {
    let (app, _) = harness().await;

    let (status, _, bytes) = send(
        &app,
        "GET",
        "/api/v1/auth/me",
        Some("token=not-a-jwt"),
        None,
    )
    .await;

    assert_eq!(status, StatusCode::OK);
    let result: Result<MeResponse, AuthError> = decode(&bytes);
    assert!(matches!(result, Err(AuthError::NotSignedIn)));
}

#[tokio::test]
async fn health_and_public_config_are_open() {
    let (app, _) = harness().await;

    let (health, _, _) = send(&app, "GET", "/api/v1/health", None, None).await;
    assert_eq!(health, StatusCode::OK);

    let (config, _, bytes) = send(&app, "GET", "/api/v1/config", None, None).await;
    assert_eq!(config, StatusCode::OK);
    let _: PublicConfig = decode(&bytes);
}

#[tokio::test]
async fn password_change_checks_the_current_password() {
    let (app, pool) = harness().await;
    let (id, _) = insert_user(&pool, "password123", false).await;
    let cookie = session_cookie(id);

    let (_, _, bytes) = send(
        &app,
        "POST",
        "/api/v1/auth/password",
        Some(&cookie),
        Some(body(&ChangePassword {
            current_password: "wrong".to_string(),
            new_password: "newpassword1".to_string(),
        })),
    )
    .await;
    let result: Result<(), PasswordError> = decode(&bytes);
    assert!(matches!(result, Err(PasswordError::IncorrectPassword)));

    let (_, _, bytes) = send(
        &app,
        "POST",
        "/api/v1/auth/password",
        Some(&cookie),
        Some(body(&ChangePassword {
            current_password: "password123".to_string(),
            new_password: "short".to_string(),
        })),
    )
    .await;
    let result: Result<(), PasswordError> = decode(&bytes);
    assert!(matches!(result, Err(PasswordError::PasswordTooShort)));

    let (_, _, bytes) = send(
        &app,
        "POST",
        "/api/v1/auth/password",
        Some(&cookie),
        Some(body(&ChangePassword {
            current_password: "password123".to_string(),
            new_password: "newpassword1".to_string(),
        })),
    )
    .await;
    let result: Result<(), PasswordError> = decode(&bytes);
    assert!(result.is_ok());
}

#[tokio::test]
async fn logout_clears_the_cookie() {
    let (app, pool) = harness().await;
    let (id, _) = insert_user(&pool, "password123", false).await;

    let (status, cookie, _) = send(
        &app,
        "POST",
        "/api/v1/auth/logout",
        Some(&session_cookie(id)),
        None,
    )
    .await;

    assert_eq!(status, StatusCode::NO_CONTENT);
    assert!(
        cookie
            .expect("expected a Set-Cookie header")
            .contains("token=")
    );
}

#[tokio::test]
async fn totp_can_be_set_up_used_and_disabled() {
    let (app, pool) = harness().await;
    let (id, email) = insert_user(&pool, "password123", false).await;
    let cookie = session_cookie(id);

    let (status, _, bytes) =
        send(&app, "POST", "/api/v1/auth/totp/setup", Some(&cookie), None).await;
    assert_eq!(status, StatusCode::OK);
    let setup: TotpSetup = decode(&bytes);
    let secret = setup.secret;

    let (_, _, bytes) = send(
        &app,
        "POST",
        "/api/v1/auth/totp/enable",
        Some(&cookie),
        Some(body(&TotpConfirm {
            secret: secret.clone(),
            code: "000000".to_string(),
        })),
    )
    .await;
    let result: Result<(), AuthError> = decode(&bytes);
    assert!(matches!(result, Err(AuthError::InvalidCode)));

    let (_, _, bytes) = send(
        &app,
        "POST",
        "/api/v1/auth/totp/enable",
        Some(&cookie),
        Some(body(&TotpConfirm {
            secret: secret.clone(),
            code: totp_code(&secret),
        })),
    )
    .await;
    let result: Result<(), AuthError> = decode(&bytes);
    assert!(result.is_ok());

    let (_, pending_cookie, bytes) = send(
        &app,
        "POST",
        "/api/v1/auth/login",
        None,
        Some(body(&LoginRequest {
            email: email.clone(),
            password: "password123".to_string(),
        })),
    )
    .await;
    let result: Result<LoginResponse, AuthError> = decode(&bytes);
    assert!(matches!(result, Ok(LoginResponse::TotpRequired)));
    let pending = pending_cookie.expect("expected a pending cookie");
    let pending = pending
        .split(';')
        .next()
        .expect("expected a cookie value")
        .to_string();

    let (status, _, bytes) = send(
        &app,
        "POST",
        "/api/v1/auth/login/totp",
        Some(&pending),
        Some(body(&TotpCode {
            code: totp_code(&secret),
        })),
    )
    .await;
    assert_eq!(status, StatusCode::OK);
    let result: Result<LoginResponse, AuthError> = decode(&bytes);
    assert!(matches!(result, Ok(LoginResponse::Authenticated { .. })));

    let (_, _, bytes) = send(
        &app,
        "POST",
        "/api/v1/auth/totp/disable",
        Some(&cookie),
        Some(body(&TotpDisable {
            password: "wrong".to_string(),
        })),
    )
    .await;
    let result: Result<(), PasswordError> = decode(&bytes);
    assert!(matches!(result, Err(PasswordError::IncorrectPassword)));

    let (_, _, bytes) = send(
        &app,
        "POST",
        "/api/v1/auth/totp/disable",
        Some(&cookie),
        Some(body(&TotpDisable {
            password: "password123".to_string(),
        })),
    )
    .await;
    let result: Result<(), PasswordError> = decode(&bytes);
    assert!(result.is_ok());
}

#[tokio::test]
async fn users_can_be_created_read_and_deleted() {
    let (app, pool) = harness().await;
    let cookie = admin_session(&pool).await;
    let email = unique_email(&pool).await;

    let (created, _, bytes) = send(
        &app,
        "POST",
        "/api/v1/users",
        Some(&cookie),
        Some(body(&CreateUser {
            email: email.clone(),
            password: "password123".to_string(),
            name: Some("Tester".to_string()),
        })),
    )
    .await;
    assert_eq!(created, StatusCode::CREATED);
    let user: UserResponse = decode(&bytes);
    assert_eq!(user.email, email);
    assert!(!user.is_admin);
    let id = user.id;

    let (dup, _, _) = send(
        &app,
        "POST",
        "/api/v1/users",
        Some(&cookie),
        Some(body(&CreateUser {
            email,
            password: "password123".to_string(),
            name: None,
        })),
    )
    .await;
    assert_eq!(dup, StatusCode::CONFLICT);

    let (invalid, _, _) = send(
        &app,
        "POST",
        "/api/v1/users",
        Some(&cookie),
        Some(body(&CreateUser {
            email: "no-at-sign".to_string(),
            password: "password123".to_string(),
            name: None,
        })),
    )
    .await;
    assert_eq!(invalid, StatusCode::UNPROCESSABLE_ENTITY);

    let (got, _, _) = send(
        &app,
        "GET",
        &format!("/api/v1/users/{id}"),
        Some(&cookie),
        None,
    )
    .await;
    assert_eq!(got, StatusCode::OK);

    let (missing, _, _) = send(
        &app,
        "GET",
        &format!("/api/v1/users/{MISSING}"),
        Some(&cookie),
        None,
    )
    .await;
    assert_eq!(missing, StatusCode::NOT_FOUND);

    let (listed, _, _) = send(
        &app,
        "GET",
        "/api/v1/users?search=Tester&page=1&per_page=10",
        Some(&cookie),
        None,
    )
    .await;
    assert_eq!(listed, StatusCode::OK);

    let (deleted, _, _) = send(
        &app,
        "DELETE",
        &format!("/api/v1/users/{id}"),
        Some(&cookie),
        None,
    )
    .await;
    assert_eq!(deleted, StatusCode::NO_CONTENT);

    let (again, _, _) = send(
        &app,
        "DELETE",
        &format!("/api/v1/users/{id}"),
        Some(&cookie),
        None,
    )
    .await;
    assert_eq!(again, StatusCode::NOT_FOUND);
}

#[tokio::test]
async fn rbac_role_lifecycle() {
    let (app, pool) = harness().await;
    let cookie = admin_session(&pool).await;

    let name = format!("role-{}", unique(&pool).await);
    let (status, _, bytes) = send(
        &app,
        "POST",
        "/api/v1/rbac/roles",
        Some(&cookie),
        Some(body(&CreateRole {
            name: name.clone(),
            description: Some("a role".to_string()),
        })),
    )
    .await;
    assert_eq!(status, StatusCode::CREATED);
    let role: RoleResponse = decode(&bytes);
    assert_eq!(role.name, name);
    let id = role.id;

    let (dup, _, _) = send(
        &app,
        "POST",
        "/api/v1/rbac/roles",
        Some(&cookie),
        Some(body(&CreateRole {
            name,
            description: None,
        })),
    )
    .await;
    assert_eq!(dup, StatusCode::CONFLICT);

    let (empty, _, _) = send(
        &app,
        "POST",
        "/api/v1/rbac/roles",
        Some(&cookie),
        Some(body(&CreateRole {
            name: "   ".to_string(),
            description: None,
        })),
    )
    .await;
    assert_eq!(empty, StatusCode::UNPROCESSABLE_ENTITY);

    let (listed, _, bytes) = send(
        &app,
        "GET",
        &format!("/api/v1/rbac/roles?search=role-&page=1&per_page=5"),
        Some(&cookie),
        None,
    )
    .await;
    assert_eq!(listed, StatusCode::OK);
    let _: RolePage = decode(&bytes);

    let (all, _, _) = send(&app, "GET", "/api/v1/rbac/roles/all", Some(&cookie), None).await;
    assert_eq!(all, StatusCode::OK);

    let new_name = format!("role-{}", unique(&pool).await);
    let (updated, _, bytes) = send(
        &app,
        "PUT",
        &format!("/api/v1/rbac/roles/{id}"),
        Some(&cookie),
        Some(body(&CreateRole {
            name: new_name.clone(),
            description: None,
        })),
    )
    .await;
    assert_eq!(updated, StatusCode::OK);
    let role: RoleResponse = decode(&bytes);
    assert_eq!(role.name, new_name);

    let (update_empty, _, _) = send(
        &app,
        "PUT",
        &format!("/api/v1/rbac/roles/{id}"),
        Some(&cookie),
        Some(body(&CreateRole {
            name: "  ".to_string(),
            description: None,
        })),
    )
    .await;
    assert_eq!(update_empty, StatusCode::UNPROCESSABLE_ENTITY);

    let (update_missing, _, _) = send(
        &app,
        "PUT",
        &format!("/api/v1/rbac/roles/{MISSING}"),
        Some(&cookie),
        Some(body(&CreateRole {
            name: "whatever".to_string(),
            description: None,
        })),
    )
    .await;
    assert_eq!(update_missing, StatusCode::NOT_FOUND);

    let (set, _, _) = send(
        &app,
        "PUT",
        &format!("/api/v1/rbac/roles/{id}/permissions"),
        Some(&cookie),
        Some(body(&PermissionsBody {
            permissions: vec!["users.read".to_string(), "users.create".to_string()],
        })),
    )
    .await;
    assert_eq!(set, StatusCode::NO_CONTENT);

    let (set_invalid, _, _) = send(
        &app,
        "PUT",
        &format!("/api/v1/rbac/roles/{id}/permissions"),
        Some(&cookie),
        Some(body(&PermissionsBody {
            permissions: vec!["nope.nope".to_string()],
        })),
    )
    .await;
    assert_eq!(set_invalid, StatusCode::UNPROCESSABLE_ENTITY);

    let (set_missing, _, _) = send(
        &app,
        "PUT",
        &format!("/api/v1/rbac/roles/{MISSING}/permissions"),
        Some(&cookie),
        Some(body(&PermissionsBody {
            permissions: vec!["users.read".to_string()],
        })),
    )
    .await;
    assert_eq!(set_missing, StatusCode::NOT_FOUND);

    let (perms_status, _, bytes) = send(
        &app,
        "GET",
        &format!("/api/v1/rbac/roles/{id}/permissions"),
        Some(&cookie),
        None,
    )
    .await;
    assert_eq!(perms_status, StatusCode::OK);
    let perms: Vec<String> = decode(&bytes);
    assert_eq!(perms.len(), 2);

    let (list_missing, _, _) = send(
        &app,
        "GET",
        &format!("/api/v1/rbac/roles/{MISSING}/permissions"),
        Some(&cookie),
        None,
    )
    .await;
    assert_eq!(list_missing, StatusCode::NOT_FOUND);

    let (deleted, _, _) = send(
        &app,
        "DELETE",
        &format!("/api/v1/rbac/roles/{id}"),
        Some(&cookie),
        None,
    )
    .await;
    assert_eq!(deleted, StatusCode::NO_CONTENT);

    let (again, _, _) = send(
        &app,
        "DELETE",
        &format!("/api/v1/rbac/roles/{id}"),
        Some(&cookie),
        None,
    )
    .await;
    assert_eq!(again, StatusCode::NOT_FOUND);
}

#[tokio::test]
async fn rbac_user_roles_and_permissions() {
    let (app, pool) = harness().await;
    let cookie = admin_session(&pool).await;
    let (user, _) = insert_user(&pool, "password123", false).await;
    let role = insert_role(&pool).await;

    let (assigned, _, _) = send(
        &app,
        "POST",
        &format!("/api/v1/users/{user}/roles"),
        Some(&cookie),
        Some(body(&RoleBody {
            role_id: role.to_string(),
        })),
    )
    .await;
    assert_eq!(assigned, StatusCode::NO_CONTENT);

    let (bad, _, _) = send(
        &app,
        "POST",
        &format!("/api/v1/users/{user}/roles"),
        Some(&cookie),
        Some(body(&RoleBody {
            role_id: "not-a-uuid".to_string(),
        })),
    )
    .await;
    assert_eq!(bad, StatusCode::UNPROCESSABLE_ENTITY);

    let (missing, _, _) = send(
        &app,
        "POST",
        &format!("/api/v1/users/{MISSING}/roles"),
        Some(&cookie),
        Some(body(&RoleBody {
            role_id: role.to_string(),
        })),
    )
    .await;
    assert_eq!(missing, StatusCode::NOT_FOUND);

    let (roles_status, _, bytes) = send(
        &app,
        "GET",
        &format!("/api/v1/users/{user}/roles"),
        Some(&cookie),
        None,
    )
    .await;
    assert_eq!(roles_status, StatusCode::OK);
    let roles: Vec<RoleResponse> = decode(&bytes);
    assert!(roles.iter().any(|r| r.id == role.to_string()));

    let (role_perms, _, _) = send(
        &app,
        "GET",
        &format!("/api/v1/users/{user}/roles/permissions"),
        Some(&cookie),
        None,
    )
    .await;
    assert_eq!(role_perms, StatusCode::OK);

    let (set, _, _) = send(
        &app,
        "PUT",
        &format!("/api/v1/users/{user}/permissions"),
        Some(&cookie),
        Some(body(&PermissionsBody {
            permissions: vec!["users.read".to_string()],
        })),
    )
    .await;
    assert_eq!(set, StatusCode::NO_CONTENT);

    let (set_invalid, _, _) = send(
        &app,
        "PUT",
        &format!("/api/v1/users/{user}/permissions"),
        Some(&cookie),
        Some(body(&PermissionsBody {
            permissions: vec!["nope".to_string()],
        })),
    )
    .await;
    assert_eq!(set_invalid, StatusCode::UNPROCESSABLE_ENTITY);

    let (set_missing, _, _) = send(
        &app,
        "PUT",
        &format!("/api/v1/users/{MISSING}/permissions"),
        Some(&cookie),
        Some(body(&PermissionsBody {
            permissions: vec!["users.read".to_string()],
        })),
    )
    .await;
    assert_eq!(set_missing, StatusCode::NOT_FOUND);

    let (list_perms, _, bytes) = send(
        &app,
        "GET",
        &format!("/api/v1/users/{user}/permissions"),
        Some(&cookie),
        None,
    )
    .await;
    assert_eq!(list_perms, StatusCode::OK);
    let perms: Vec<String> = decode(&bytes);
    assert!(perms.contains(&"users.read".to_string()));

    let granted = session_cookie(user);
    let (self_list, _, _) = send(&app, "GET", "/api/v1/users", Some(&granted), None).await;
    assert_eq!(self_list, StatusCode::OK);

    let (removed, _, _) = send(
        &app,
        "DELETE",
        &format!("/api/v1/users/{user}/roles"),
        Some(&cookie),
        Some(body(&RoleBody {
            role_id: role.to_string(),
        })),
    )
    .await;
    assert_eq!(removed, StatusCode::NO_CONTENT);

    let (remove_bad, _, _) = send(
        &app,
        "DELETE",
        &format!("/api/v1/users/{user}/roles"),
        Some(&cookie),
        Some(body(&RoleBody {
            role_id: "nope".to_string(),
        })),
    )
    .await;
    assert_eq!(remove_bad, StatusCode::UNPROCESSABLE_ENTITY);
}

#[tokio::test]
async fn rbac_lists_the_permission_catalog() {
    let (app, pool) = harness().await;
    let cookie = admin_session(&pool).await;

    let (status, _, bytes) =
        send(&app, "GET", "/api/v1/rbac/permissions", Some(&cookie), None).await;
    assert_eq!(status, StatusCode::OK);
    let list: Vec<PermissionInfo> = decode(&bytes);
    let read = list
        .iter()
        .find(|p| p.name == "users.read")
        .expect("expected users.read in the catalog");
    assert_eq!(read.parent.as_deref(), Some("users"));
}

#[tokio::test]
async fn settings_can_be_read_and_updated() {
    let (app, pool) = harness().await;
    let cookie = admin_session(&pool).await;

    let (status, _, bytes) = send(&app, "GET", "/api/v1/settings", Some(&cookie), None).await;
    assert_eq!(status, StatusCode::OK);
    let settings: Vec<SettingInfo> = decode(&bytes);
    assert!(settings.iter().any(|s| s.name == "company.name"));

    let (updated, _, _) = send(
        &app,
        "PUT",
        "/api/v1/settings",
        Some(&cookie),
        Some(body(&SettingsBody {
            settings: vec![SettingUpdate {
                name: "company.name".to_string(),
                value: "Acme".to_string(),
            }],
        })),
    )
    .await;
    assert_eq!(updated, StatusCode::NO_CONTENT);

    let (unknown, _, _) = send(
        &app,
        "PUT",
        "/api/v1/settings",
        Some(&cookie),
        Some(body(&SettingsBody {
            settings: vec![SettingUpdate {
                name: "nope".to_string(),
                value: "x".to_string(),
            }],
        })),
    )
    .await;
    assert_eq!(unknown, StatusCode::UNPROCESSABLE_ENTITY);

    let (bad_bool, _, _) = send(
        &app,
        "PUT",
        "/api/v1/settings",
        Some(&cookie),
        Some(body(&SettingsBody {
            settings: vec![SettingUpdate {
                name: "registration.enabled".to_string(),
                value: "maybe".to_string(),
            }],
        })),
    )
    .await;
    assert_eq!(bad_bool, StatusCode::UNPROCESSABLE_ENTITY);

    let (empty_text, _, _) = send(
        &app,
        "PUT",
        "/api/v1/settings",
        Some(&cookie),
        Some(body(&SettingsBody {
            settings: vec![SettingUpdate {
                name: "company.name".to_string(),
                value: "   ".to_string(),
            }],
        })),
    )
    .await;
    assert_eq!(empty_text, StatusCode::UNPROCESSABLE_ENTITY);

    crate::settings::set(&pool, crate::settings::COMPANY_NAME, "Axum Elm Template").await;
}

#[test]
fn window_clamps_and_computes_offsets() {
    let window = ListParams {
        page: None,
        per_page: None,
        search: None,
    }
    .window();
    assert_eq!(window.page, 1);
    assert_eq!(window.per_page, 25);
    assert_eq!(window.offset, 0);

    let window = ListParams {
        page: Some(0),
        per_page: Some(0),
        search: Some("   ".to_string()),
    }
    .window();
    assert_eq!(window.page, 1);
    assert_eq!(window.per_page, 1);
    assert!(window.search.is_none());

    let window = ListParams {
        page: Some(3),
        per_page: Some(500),
        search: Some("  hi ".to_string()),
    }
    .window();
    assert_eq!(window.per_page, 100);
    assert_eq!(window.limit, 100);
    assert_eq!(window.offset, 200);
    assert_eq!(window.search.as_deref(), Some("hi"));
}

#[test]
fn permission_catalog_is_searchable() {
    let all = crate::rbac::permission::all();
    assert!(all.iter().any(|p| p.name == "users.read"));

    let found = crate::rbac::permission::find("users.roles.assign")
        .expect("expected users.roles.assign in the catalog");
    assert_eq!(found.name, "users.roles.assign");

    assert!(crate::rbac::permission::find("does.not.exist").is_none());
}

#[test]
fn genelm_renders_the_bindings() {
    crate::api::genelm().expect("error generating the Elm bindings");
}
