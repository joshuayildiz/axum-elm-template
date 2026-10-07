mod genelm;
mod register;
mod serve;

use crate::config::Config;
use clap::{Parser, Subcommand};
use sqlx::PgPool;
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

pub(crate) async fn cmd(config: Config, pool: PgPool) -> io::Result<()> {
    let args = Args::parse();
    match args.cmd {
        Cmd::Serve => serve::cmd(config, pool).await,
        Cmd::Genelm => genelm::cmd(),
        Cmd::Register => register::cmd(pool).await,
    }
}
