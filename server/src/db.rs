use sqlx::PgPool;
use sqlx::postgres::PgPoolOptions;

pub(crate) async fn connect(database_url: &str) -> PgPool {
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
