use std::io;

#[tokio::main(flavor = "current_thread")]
async fn main() -> io::Result<()> {
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

    Router::new().route("/api/v1/hello", get(hello))
}

async fn hello() -> &'static str {
    "hello"
}
