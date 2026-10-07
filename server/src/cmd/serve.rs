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

    let listener = TcpListener::bind("0.0.0.0:3000").await?;
    println!("Listening on http://0.0.0.0:3000");

    axum::serve(listener, app).await?;
    Ok(())
}
