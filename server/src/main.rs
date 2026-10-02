mod api;
mod server;

use clap::{Parser, Subcommand};
use std::io;

#[derive(Parser, Debug)]
#[clap(version, about, long_about = None)]
struct Args {
    #[command(subcommand)]
    cmd: Cmd,
}

#[derive(Subcommand, Debug)]
enum Cmd {
    Serve,
    Genelm,
}

#[tokio::main(flavor = "current_thread")]
async fn main() -> io::Result<()> {
    let args = Args::parse();
    match args.cmd {
        Cmd::Serve => server::serve().await,
        Cmd::Genelm => api::genelm(),
    }
}
