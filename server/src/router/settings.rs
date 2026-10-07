use crate::api::{SettingInfo, SettingKind, SettingsBody};
use crate::rbac::check::Permissions;
use crate::router::AppState;
use crate::router::auth::extractors::require_auth;
use axum::Json;
use axum::Router;
use axum::extract::State;
use axum::http::StatusCode;
use axum::routing::get;

pub(crate) fn routes(state: AppState) -> Router<AppState> {
    Router::new()
        .route("/api/v1/settings", get(list_settings).put(update_settings))
        .route_layer(axum::middleware::from_fn_with_state(state, require_auth))
}

async fn list_settings(
    State(state): State<AppState>,
    perms: Permissions,
) -> Result<Json<Vec<SettingInfo>>, StatusCode> {
    perms.require(crate::rbac::settings::read::NAME)?;

    Ok(Json(crate::settings::all(&state.pool).await))
}

async fn update_settings(
    State(state): State<AppState>,
    perms: Permissions,
    Json(body): Json<SettingsBody>,
) -> Result<StatusCode, StatusCode> {
    perms.require(crate::rbac::settings::update::NAME)?;

    for update in &body.settings {
        let Some(definition) = crate::settings::definition(&update.name) else {
            return Err(StatusCode::UNPROCESSABLE_ENTITY);
        };

        let value = match definition.kind {
            SettingKind::Bool => {
                if update.value != "true" && update.value != "false" {
                    return Err(StatusCode::UNPROCESSABLE_ENTITY);
                }
                update.value.clone()
            }
            SettingKind::Text => {
                let trimmed = update.value.trim();
                if trimmed.is_empty() {
                    return Err(StatusCode::UNPROCESSABLE_ENTITY);
                }
                trimmed.to_string()
            }
        };

        crate::settings::set(&state.pool, &update.name, &value).await;
    }

    Ok(StatusCode::NO_CONTENT)
}
