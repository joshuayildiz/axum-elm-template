pub(crate) mod auth;
pub(crate) mod rbac;
pub(crate) mod users;

use crate::api::HelloResponse;
use axum::Json;
use std::sync::Arc;

#[derive(Clone)]
pub(crate) struct AppState {
    pub(crate) pool: sqlx::PgPool,
    pub(crate) jwt_secret: Arc<str>,
}

pub(crate) fn build(state: AppState) -> axum::Router {
    use axum::Router;
    use axum::routing::get;
    use tower_http::services::{ServeDir, ServeFile};

    let client = ServeDir::new("client").not_found_service(ServeFile::new("client/index.html"));

    Router::new()
        .route("/api/v1/hello", get(hello))
        .merge(auth::routes(state.clone()))
        .merge(rbac::routes(state.clone()))
        .merge(users::routes(state.clone()))
        .fallback_service(client)
        .with_state(state)
}

async fn hello() -> Json<HelloResponse> {
    Json(HelloResponse {
        message: "hello".to_string(),
    })
}
