use crate::api::{CreateUser, UserResponse};
use crate::rbac::check::Permissions;
use crate::router::AppState;
use crate::router::auth::extractors::require_auth;
use axum::Json;
use axum::Router;
use axum::extract::{Path, State};
use axum::http::StatusCode;
use axum::routing::get;
use sqlx::error::ErrorKind;
use uuid::Uuid;

pub(crate) fn routes(state: AppState) -> Router<AppState> {
    Router::new()
        .route("/api/v1/users", get(list_users).post(create_user))
        .route("/api/v1/users/{id}", get(get_user).delete(delete_user))
        .route_layer(axum::middleware::from_fn_with_state(state, require_auth))
}

async fn list_users(
    State(state): State<AppState>,
    perms: Permissions,
) -> Result<Json<Vec<UserResponse>>, StatusCode> {
    perms.require(crate::rbac::users::read::NAME)?;

    let rows = sqlx::query!(
        r#"
        select id::text as "id!", email, name, is_admin
        from users
        where deleted_at is null
        order by is_admin desc, email
        "#
    )
    .fetch_all(&state.pool)
    .await
    .expect("error listing users");

    Ok(Json(
        rows.into_iter()
            .map(|row| UserResponse {
                id: row.id,
                email: row.email,
                name: row.name,
                is_admin: row.is_admin,
            })
            .collect(),
    ))
}

async fn create_user(
    State(state): State<AppState>,
    perms: Permissions,
    Json(body): Json<CreateUser>,
) -> Result<(StatusCode, Json<UserResponse>), StatusCode> {
    use argon2::{Argon2, PasswordHasher};

    perms.require(crate::rbac::users::create::NAME)?;

    let email = body.email.trim();
    if !email.contains('@') || body.password.len() < 8 {
        return Err(StatusCode::UNPROCESSABLE_ENTITY);
    }

    let password_hash = Argon2::default()
        .hash_password(body.password.as_bytes())
        .expect("error hashing password")
        .to_string();

    let name = body
        .name
        .as_deref()
        .map(str::trim)
        .filter(|value| !value.is_empty());

    let result = sqlx::query!(
        r#"
        insert into users (email, password_hash, name, is_admin)
        values ($1, $2, $3, $4)
        returning id::text as "id!", email, name, is_admin
        "#,
        email,
        password_hash,
        name,
        body.is_admin
    )
    .fetch_one(&state.pool)
    .await;

    let row = match result {
        Ok(row) => row,
        Err(sqlx::Error::Database(e)) if e.kind() == ErrorKind::UniqueViolation => {
            return Err(StatusCode::CONFLICT);
        }
        Err(e) => panic!("error creating user: {e}"),
    };

    Ok((
        StatusCode::CREATED,
        Json(UserResponse {
            id: row.id,
            email: row.email,
            name: row.name,
            is_admin: row.is_admin,
        }),
    ))
}

async fn delete_user(
    State(state): State<AppState>,
    perms: Permissions,
    Path(id): Path<Uuid>,
) -> Result<StatusCode, StatusCode> {
    perms.require(crate::rbac::users::delete::NAME)?;

    // Soft delete: the account row stays, other objects keep their links.
    let result = sqlx::query!(
        "update users set deleted_at = now() where id = $1 and deleted_at is null",
        id
    )
    .execute(&state.pool)
    .await
    .expect("error deleting user");

    if result.rows_affected() == 0 {
        return Err(StatusCode::NOT_FOUND);
    }

    Ok(StatusCode::NO_CONTENT)
}

async fn get_user(
    State(state): State<AppState>,
    perms: Permissions,
    Path(id): Path<Uuid>,
) -> Result<Json<UserResponse>, StatusCode> {
    perms.require(crate::rbac::users::read::NAME)?;

    let row = sqlx::query!(
        r#"
        select id::text as "id!", email, name, is_admin
        from users
        where id = $1 and deleted_at is null
        "#,
        id
    )
    .fetch_optional(&state.pool)
    .await
    .expect("error querying user");

    let Some(row) = row else {
        return Err(StatusCode::NOT_FOUND);
    };

    Ok(Json(UserResponse {
        id: row.id,
        email: row.email,
        name: row.name,
        is_admin: row.is_admin,
    }))
}
