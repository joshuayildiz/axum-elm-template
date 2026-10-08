use crate::api::{CreateUser, UserPage, UserResponse};
use crate::pagination::ListParams;
use crate::rbac::check::Permissions;
use crate::router::AppState;
use crate::router::auth::extractors::require_auth;
use crate::telemetry::Traced;
use axum::Json;
use axum::Router;
use axum::extract::{Path, Query, State};
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
    Query(params): Query<ListParams>,
) -> Result<Json<UserPage>, StatusCode> {
    perms.require(crate::rbac::users::read::NAME)?;

    let window = params.window();
    let search = window.search.as_deref();

    let total = sqlx::query_scalar!(
        r#"
        select count(*) as "count!"
        from users
        where deleted_at is null
          and ($1::text is null
               or email ilike '%' || $1 || '%'
               or coalesce(name, '') ilike '%' || $1 || '%')
        "#,
        search
    )
    .fetch_one(&state.pool)
    .traced("users.count")
    .await
    .expect("error counting users");

    let rows = sqlx::query!(
        r#"
        select id::text as "id!", email, name, is_admin
        from users
        where deleted_at is null
          and ($1::text is null
               or email ilike '%' || $1 || '%'
               or coalesce(name, '') ilike '%' || $1 || '%')
        order by is_admin desc, email
        limit $2 offset $3
        "#,
        search,
        window.limit,
        window.offset,
    )
    .fetch_all(&state.pool)
    .traced("users.list")
    .await
    .expect("error listing users");

    tracing::info!(
        page = window.page,
        per_page = window.per_page,
        total,
        returned = rows.len() as i64,
        searching = search.is_some(),
    );

    Ok(Json(UserPage {
        items: rows
            .into_iter()
            .map(|row| UserResponse {
                id: row.id,
                email: row.email,
                name: row.name,
                is_admin: row.is_admin,
            })
            .collect(),
        total,
        page: window.page,
        per_page: window.per_page,
    }))
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
    .traced("users.create")
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

    tracing::info!(target.user_id = %id);

    // Soft delete: the account row stays, other objects keep their links.
    let result = sqlx::query!(
        "update users set deleted_at = now() where id = $1 and deleted_at is null",
        id
    )
    .execute(&state.pool)
    .traced("users.delete")
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
    .traced("users.get")
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
