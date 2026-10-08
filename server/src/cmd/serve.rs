use crate::config::Config;
use crate::router::{self, AppState};
use sqlx::PgPool;
use std::io;

pub(crate) async fn cmd(config: Config, pool: PgPool) -> io::Result<()> {
    use std::collections::HashMap;
    use std::sync::{Arc, Mutex};
    use tokio::net::TcpListener;
    use tokio::sync::broadcast;

    let (events, _) = broadcast::channel(100);
    let state = AppState {
        pool,
        jwt_secret: config.jwt_secret.into(),
        presence: Arc::new(Mutex::new(HashMap::new())),
        events,
    };
    let app = router::build(state);

    let port = std::env::var("PORT").unwrap_or_else(|_| "3000".to_string());
    let listener = TcpListener::bind(format!("0.0.0.0:{port}")).await?;
    tracing::info!("listening on http://0.0.0.0:{port}");

    axum::serve(listener, app)
        .with_graceful_shutdown(shutdown_signal())
        .await?;
    Ok(())
}

async fn shutdown_signal() {
    tokio::signal::ctrl_c()
        .await
        .expect("error installing ctrl-c handler");
}
