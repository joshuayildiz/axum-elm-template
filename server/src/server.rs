use crate::api;
use std::io;

pub(crate) async fn serve() -> io::Result<()> {
    use tokio::net::TcpListener;

    let router = router();

    let listener = TcpListener::bind("0.0.0.0:3000").await?;
    println!("Listening on http://0.0.0.0:3000");

    axum::serve(listener, router).await?;
    Ok(())
}

fn router() -> axum::Router<()> {
    use axum::Router;
    use axum::routing::get;
    use tower_http::services::{ServeDir, ServeFile};

    let client = ServeDir::new("client").not_found_service(ServeFile::new("client/index.html"));

    Router::new()
        .route("/api/v1/hello", get(hello))
        .fallback_service(client)
}

async fn hello() -> axum::Json<api::HelloResponse> {
    axum::Json(api::HelloResponse {
        message: "hello".to_string(),
    })
}
