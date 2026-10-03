use crate::router::{self, AppState};
use std::io;

pub(crate) async fn cmd() -> io::Result<()> {
    use tokio::net::TcpListener;

    let config = crate::config::Config::from_env();
    let pool = crate::db::connect(&config.database_url).await;
    let state = AppState {
        pool,
        jwt_secret: config.jwt_secret.into(),
    };
    let app = router::build(state);

    let listener = TcpListener::bind("0.0.0.0:3000").await?;
    println!("Listening on http://0.0.0.0:3000");

    axum::serve(listener, app).await?;
    Ok(())
}
