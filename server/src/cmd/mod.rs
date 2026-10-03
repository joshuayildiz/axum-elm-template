mod genelm;
mod register;
mod serve;

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
    Register,
}

pub(crate) async fn cmd() -> io::Result<()> {
    let args = Args::parse();
    match args.cmd {
        Cmd::Serve => serve::cmd().await,
        Cmd::Genelm => genelm::cmd(),
        Cmd::Register => register::cmd().await,
    }
}
