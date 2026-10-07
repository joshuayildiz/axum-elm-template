use crate::api::{CreateRole, PermissionInfo, PermissionsBody, RoleBody, RoleResponse};
use crate::rbac::check::Permissions;
use crate::router::AppState;
use crate::router::auth::extractors::require_auth;
use axum::Json;
use axum::Router;
use axum::extract::{Path, State};
use axum::http::StatusCode;
use axum::routing::{delete, get};
use sqlx::error::ErrorKind;
use uuid::Uuid;

pub(crate) fn routes(state: AppState) -> Router<AppState> {
    Router::new()
        .route("/api/v1/rbac/permissions", get(list_permissions))
        .route("/api/v1/rbac/roles", get(list_roles).post(create_role))
        .route(
            "/api/v1/rbac/roles/{id}",
            delete(delete_role).put(update_role),
        )
        .route(
            "/api/v1/rbac/roles/{id}/permissions",
            get(list_role_permissions).put(set_role_permissions),
        )
        .route(
            "/api/v1/users/{id}/roles",
            get(list_user_roles).post(assign_role).delete(remove_role),
        )
        .route(
            "/api/v1/users/{id}/roles/permissions",
            get(list_user_role_permissions),
        )
        .route(
            "/api/v1/users/{id}/permissions",
            get(list_user_permissions).put(set_user_permissions),
        )
        .route_layer(axum::middleware::from_fn_with_state(state, require_auth))
}

async fn list_permissions(perms: Permissions) -> Result<Json<Vec<PermissionInfo>>, StatusCode> {
    // The catalog backs both the user and the role permission trees.
    if !perms.has(crate::rbac::users::permissions::read::NAME)
        && !perms.has(crate::rbac::roles::permissions::read::NAME)
    {
        return Err(StatusCode::FORBIDDEN);
    }

    let list = crate::rbac::permission::all()
        .into_iter()
        .map(|perm| PermissionInfo {
            name: perm.name.to_string(),
            parent: perm
                .name
                .strip_suffix(perm.segment)
                .and_then(|prefix| prefix.strip_suffix('.'))
                .map(str::to_string),
        })
        .collect();

    Ok(Json(list))
}

async fn list_roles(
    State(state): State<AppState>,
    perms: Permissions,
) -> Result<Json<Vec<RoleResponse>>, StatusCode> {
    perms.require(crate::rbac::roles::read::NAME)?;

    let rows =
        sqlx::query!(r#"select id::text as "id!", name, description from roles order by name"#)
            .fetch_all(&state.pool)
            .await
            .expect("error listing roles");

    Ok(Json(
        rows.into_iter()
            .map(|row| RoleResponse {
                id: row.id,
                name: row.name,
                description: row.description,
            })
            .collect(),
    ))
}

async fn create_role(
    State(state): State<AppState>,
    perms: Permissions,
    Json(body): Json<CreateRole>,
) -> Result<(StatusCode, Json<RoleResponse>), StatusCode> {
    perms.require(crate::rbac::roles::create::NAME)?;

    let name = body.name.trim();
    if name.is_empty() {
        return Err(StatusCode::UNPROCESSABLE_ENTITY);
    }

    let description = clean(&body.description);

    let result = sqlx::query!(
        r#"insert into roles (name, description) values ($1, $2) returning id::text as "id!", name, description"#,
        name,
        description
    )
    .fetch_one(&state.pool)
    .await;

    let row = match result {
        Ok(row) => row,
        Err(sqlx::Error::Database(e)) if e.kind() == ErrorKind::UniqueViolation => {
            return Err(StatusCode::CONFLICT);
        }
        Err(e) => panic!("error creating role: {e}"),
    };

    Ok((
        StatusCode::CREATED,
        Json(RoleResponse {
            id: row.id,
            name: row.name,
            description: row.description,
        }),
    ))
}

/// Trim an optional string and treat an empty result as absent.
fn clean(value: &Option<String>) -> Option<String> {
    value
        .as_deref()
        .map(str::trim)
        .filter(|v| !v.is_empty())
        .map(str::to_string)
}

async fn update_role(
    State(state): State<AppState>,
    perms: Permissions,
    Path(id): Path<Uuid>,
    Json(body): Json<CreateRole>,
) -> Result<Json<RoleResponse>, StatusCode> {
    perms.require(crate::rbac::roles::update::NAME)?;

    let name = body.name.trim();
    if name.is_empty() {
        return Err(StatusCode::UNPROCESSABLE_ENTITY);
    }

    let description = clean(&body.description);

    let result = sqlx::query!(
        r#"update roles set name = $1, description = $2 where id = $3 returning id::text as "id!", name, description"#,
        name,
        description,
        id
    )
    .fetch_optional(&state.pool)
    .await;

    match result {
        Ok(Some(row)) => Ok(Json(RoleResponse {
            id: row.id,
            name: row.name,
            description: row.description,
        })),
        Ok(None) => Err(StatusCode::NOT_FOUND),
        Err(sqlx::Error::Database(e)) if e.kind() == ErrorKind::UniqueViolation => {
            Err(StatusCode::CONFLICT)
        }
        Err(e) => panic!("error updating role: {e}"),
    }
}

async fn delete_role(
    State(state): State<AppState>,
    perms: Permissions,
    Path(id): Path<Uuid>,
) -> Result<StatusCode, StatusCode> {
    perms.require(crate::rbac::roles::delete::NAME)?;

    let result = sqlx::query!("delete from roles where id = $1", id)
        .execute(&state.pool)
        .await
        .expect("error deleting role");

    if result.rows_affected() == 0 {
        return Err(StatusCode::NOT_FOUND);
    }

    Ok(StatusCode::NO_CONTENT)
}

async fn list_role_permissions(
    State(state): State<AppState>,
    perms: Permissions,
    Path(id): Path<Uuid>,
) -> Result<Json<Vec<String>>, StatusCode> {
    perms.require(crate::rbac::roles::permissions::read::NAME)?;

    if !role_exists(&state, id).await {
        return Err(StatusCode::NOT_FOUND);
    }

    let rows = sqlx::query!(
        r#"select permission from role_permissions where role_id = $1 order by permission"#,
        id
    )
    .fetch_all(&state.pool)
    .await
    .expect("error listing role permissions");

    Ok(Json(rows.into_iter().map(|row| row.permission).collect()))
}

async fn set_role_permissions(
    State(state): State<AppState>,
    perms: Permissions,
    Path(id): Path<Uuid>,
    Json(body): Json<PermissionsBody>,
) -> Result<StatusCode, StatusCode> {
    perms.require(crate::rbac::roles::permissions::grant::NAME)?;

    if body
        .permissions
        .iter()
        .any(|name| crate::rbac::permission::find(name).is_none())
    {
        return Err(StatusCode::UNPROCESSABLE_ENTITY);
    }
    if !role_exists(&state, id).await {
        return Err(StatusCode::NOT_FOUND);
    }

    let mut tx = state
        .pool
        .begin()
        .await
        .expect("error starting transaction");

    sqlx::query!("delete from role_permissions where role_id = $1", id)
        .execute(&mut *tx)
        .await
        .expect("error clearing role permissions");

    for name in &body.permissions {
        sqlx::query!(
            "insert into role_permissions (role_id, permission) values ($1, $2) \
             on conflict do nothing",
            id,
            name
        )
        .execute(&mut *tx)
        .await
        .expect("error setting role permission");
    }

    tx.commit().await.expect("error committing transaction");

    Ok(StatusCode::NO_CONTENT)
}

async fn list_user_roles(
    State(state): State<AppState>,
    perms: Permissions,
    Path(id): Path<Uuid>,
) -> Result<Json<Vec<RoleResponse>>, StatusCode> {
    perms.require(crate::rbac::users::roles::read::NAME)?;

    if !user_exists(&state, id).await {
        return Err(StatusCode::NOT_FOUND);
    }

    let rows = sqlx::query!(
        r#"
        select r.id::text as "id!", r.name, r.description
        from roles r
        join user_roles ur on ur.role_id = r.id
        where ur.user_id = $1
        order by r.name
        "#,
        id
    )
    .fetch_all(&state.pool)
    .await
    .expect("error listing user roles");

    Ok(Json(
        rows.into_iter()
            .map(|row| RoleResponse {
                id: row.id,
                name: row.name,
                description: row.description,
            })
            .collect(),
    ))
}

async fn list_user_role_permissions(
    State(state): State<AppState>,
    perms: Permissions,
    Path(id): Path<Uuid>,
) -> Result<Json<Vec<String>>, StatusCode> {
    perms.require(crate::rbac::users::permissions::read::NAME)?;

    if !user_exists(&state, id).await {
        return Err(StatusCode::NOT_FOUND);
    }

    let rows = sqlx::query!(
        r#"
        select distinct rp.permission
        from role_permissions rp
        join user_roles ur on ur.role_id = rp.role_id
        where ur.user_id = $1
        order by rp.permission
        "#,
        id
    )
    .fetch_all(&state.pool)
    .await
    .expect("error listing user role permissions");

    Ok(Json(rows.into_iter().map(|row| row.permission).collect()))
}

async fn list_user_permissions(
    State(state): State<AppState>,
    perms: Permissions,
    Path(id): Path<Uuid>,
) -> Result<Json<Vec<String>>, StatusCode> {
    perms.require(crate::rbac::users::permissions::read::NAME)?;

    if !user_exists(&state, id).await {
        return Err(StatusCode::NOT_FOUND);
    }

    let rows = sqlx::query!(
        "select permission from user_permissions where user_id = $1 order by permission",
        id
    )
    .fetch_all(&state.pool)
    .await
    .expect("error listing user permissions");

    Ok(Json(rows.into_iter().map(|row| row.permission).collect()))
}

async fn assign_role(
    State(state): State<AppState>,
    perms: Permissions,
    Path(user_id): Path<Uuid>,
    Json(body): Json<RoleBody>,
) -> Result<StatusCode, StatusCode> {
    perms.require(crate::rbac::users::roles::assign::NAME)?;

    let Ok(role_id) = Uuid::parse_str(&body.role_id) else {
        return Err(StatusCode::UNPROCESSABLE_ENTITY);
    };

    if !user_exists(&state, user_id).await || !role_exists(&state, role_id).await {
        return Err(StatusCode::NOT_FOUND);
    }

    sqlx::query!(
        "insert into user_roles (user_id, role_id) values ($1, $2) on conflict do nothing",
        user_id,
        role_id
    )
    .execute(&state.pool)
    .await
    .expect("error assigning role to user");

    Ok(StatusCode::NO_CONTENT)
}

async fn remove_role(
    State(state): State<AppState>,
    perms: Permissions,
    Path(user_id): Path<Uuid>,
    Json(body): Json<RoleBody>,
) -> Result<StatusCode, StatusCode> {
    perms.require(crate::rbac::users::roles::assign::NAME)?;

    let Ok(role_id) = Uuid::parse_str(&body.role_id) else {
        return Err(StatusCode::UNPROCESSABLE_ENTITY);
    };

    sqlx::query!(
        "delete from user_roles where user_id = $1 and role_id = $2",
        user_id,
        role_id
    )
    .execute(&state.pool)
    .await
    .expect("error removing role from user");

    Ok(StatusCode::NO_CONTENT)
}

async fn set_user_permissions(
    State(state): State<AppState>,
    perms: Permissions,
    Path(user_id): Path<Uuid>,
    Json(body): Json<PermissionsBody>,
) -> Result<StatusCode, StatusCode> {
    perms.require(crate::rbac::users::permissions::grant::NAME)?;

    if body
        .permissions
        .iter()
        .any(|name| crate::rbac::permission::find(name).is_none())
    {
        return Err(StatusCode::UNPROCESSABLE_ENTITY);
    }
    if !user_exists(&state, user_id).await {
        return Err(StatusCode::NOT_FOUND);
    }

    let mut tx = state
        .pool
        .begin()
        .await
        .expect("error starting transaction");

    sqlx::query!("delete from user_permissions where user_id = $1", user_id)
        .execute(&mut *tx)
        .await
        .expect("error clearing user permissions");

    for name in &body.permissions {
        sqlx::query!(
            "insert into user_permissions (user_id, permission) values ($1, $2) \
             on conflict do nothing",
            user_id,
            name
        )
        .execute(&mut *tx)
        .await
        .expect("error setting user permission");
    }

    tx.commit().await.expect("error committing transaction");

    Ok(StatusCode::NO_CONTENT)
}

async fn role_exists(state: &AppState, id: Uuid) -> bool {
    sqlx::query_scalar!(
        r#"select exists(select 1 from roles where id = $1) as "exists!""#,
        id
    )
    .fetch_one(&state.pool)
    .await
    .expect("error checking role")
}

async fn user_exists(state: &AppState, id: Uuid) -> bool {
    sqlx::query_scalar!(
        r#"select exists(select 1 from users where id = $1) as "exists!""#,
        id
    )
    .fetch_one(&state.pool)
    .await
    .expect("error checking user")
}
