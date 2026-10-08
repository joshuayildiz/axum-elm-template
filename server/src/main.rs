mod api;
mod cmd;
mod config;
mod jwt;
mod pagination;
mod rbac;
mod router;
mod settings;
mod telemetry;

use sqlx::PgPool;
use sqlx::postgres::PgPoolOptions;
use std::io;

#[tokio::main(flavor = "current_thread")]
async fn main() -> io::Result<()> {
    dotenvy::dotenv().ok();
    let config = config::Config::from_env();
    let provider = telemetry::init(&config);
    let pool = connect(&config.database_url).await;
    let result = cmd::cmd(config, pool).await;
    telemetry::shutdown(provider);
    result
}

async fn connect(database_url: &str) -> PgPool {
    let pool = PgPoolOptions::new()
        .connect(database_url)
        .await
        .expect("error connecting to database");

    sqlx::migrate!()
        .run(&pool)
        .await
        .expect("error applying migrations");

    pool
}
