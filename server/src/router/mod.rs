pub(crate) mod auth;
pub(crate) mod rbac;
pub(crate) mod settings;
pub(crate) mod users;
pub(crate) mod ws;

use crate::api::{HelloResponse, PublicConfig, ServerMessage};
use axum::Json;
use axum::extract::State;
use std::collections::HashMap;
use std::sync::{Arc, Mutex};
use tokio::sync::broadcast;

#[derive(Clone)]
pub(crate) struct AppState {
    pub(crate) pool: sqlx::PgPool,
    pub(crate) jwt_secret: Arc<str>,
    // Open websocket connections per user id. A count, not a flag, so many tabs
    // for one user read as one online user.
    pub(crate) presence: Arc<Mutex<HashMap<String, usize>>>,
    // Fans one message out to every connected socket.
    pub(crate) events: broadcast::Sender<ServerMessage>,
}

pub(crate) fn build(state: AppState) -> axum::Router {
    use axum::Router;
    use axum::routing::get;
    use tower_http::services::{ServeDir, ServeFile};

    let client = ServeDir::new("client").not_found_service(ServeFile::new("client/index.html"));

    Router::new()
        .route("/api/v1/hello", get(hello))
        .route("/api/v1/config", get(public_config))
        .merge(auth::routes(state.clone()))
        .merge(rbac::routes(state.clone()))
        .merge(settings::routes(state.clone()))
        .merge(users::routes(state.clone()))
        .merge(ws::routes(state.clone()))
        .fallback_service(client)
        .with_state(state)
}

async fn hello() -> Json<HelloResponse> {
    Json(HelloResponse {
        message: "hello".to_string(),
    })
}

async fn public_config(State(state): State<AppState>) -> Json<PublicConfig> {
    Json(PublicConfig {
        company_name: crate::settings::get(&state.pool, crate::settings::COMPANY_NAME).await,
        registration_enabled: crate::settings::get_bool(
            &state.pool,
            crate::settings::REGISTRATION_ENABLED,
        )
        .await,
    })
}
