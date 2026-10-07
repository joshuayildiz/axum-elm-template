//! Resolving and checking a user's permissions.

use crate::api::AuthError;
use crate::router::AppState;
use crate::router::auth::extractors::CurrentUser;
use axum::extract::FromRequestParts;
use axum::http::StatusCode;
use axum::http::request::Parts;
use sqlx::PgPool;
use std::collections::HashSet;
use uuid::Uuid;

/// A user's resolved rights for one request. `admin` short-circuits every check.
pub(crate) struct Permissions {
    admin: bool,
    granted: HashSet<String>,
}

impl Permissions {
    pub(crate) fn has(&self, name: &str) -> bool {
        self.admin || self.granted.contains(name)
    }

    pub(crate) fn require(&self, name: &str) -> Result<(), StatusCode> {
        if self.has(name) {
            Ok(())
        } else {
            Err(StatusCode::FORBIDDEN)
        }
    }

    /// The effective permission names, sorted. An admin gets every name in the
    /// tree, so a caller can rely on this list without checking `admin`.
    pub(crate) fn names(&self) -> Vec<String> {
        let mut names: Vec<String> = if self.admin {
            crate::rbac::permission::all()
                .into_iter()
                .map(|perm| perm.name.to_string())
                .collect()
        } else {
            self.granted.iter().cloned().collect()
        };
        names.sort();
        names
    }
}

/// Read a user's rights: their direct grants plus the grants of every active
/// role they hold. An admin needs no query.
pub(crate) async fn resolve(pool: &PgPool, user_id: Uuid, is_admin: bool) -> Permissions {
    if is_admin {
        return Permissions {
            admin: true,
            granted: HashSet::new(),
        };
    }

    let rows = sqlx::query!(
        r#"
        select permission as "permission!"
        from user_permissions
        where user_id = $1
        union
        select rp.permission
        from role_permissions rp
        join user_roles ur on ur.role_id = rp.role_id
        where ur.user_id = $1
        "#,
        user_id
    )
    .fetch_all(pool)
    .await
    .expect("error resolving permissions");

    Permissions {
        admin: false,
        granted: rows.into_iter().map(|row| row.permission).collect(),
    }
}

/// Builds from the `CurrentUser` that `require_auth` put in the request, so this
/// extractor works only behind that gate.
impl FromRequestParts<AppState> for Permissions {
    type Rejection = AuthError;

    async fn from_request_parts(
        parts: &mut Parts,
        state: &AppState,
    ) -> Result<Self, Self::Rejection> {
        let user = parts
            .extensions
            .get::<CurrentUser>()
            .cloned()
            .ok_or(AuthError::NotSignedIn)?;

        let id = Uuid::parse_str(&user.id).map_err(|_| AuthError::NotSignedIn)?;

        Ok(resolve(&state.pool, id, user.is_admin).await)
    }
}
