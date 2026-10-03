mod api;
mod cmd;
mod config;
mod db;
mod jwt;
mod router;

use std::io;

#[tokio::main(flavor = "current_thread")]
async fn main() -> io::Result<()> {
    dotenvy::dotenv().ok();
    cmd::cmd().await
}
