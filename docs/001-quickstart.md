# Quickstart

This guide runs the template on your machine for local development. The commands
run from the root of the repository, unless a step says otherwise.

## Before you start

Install these tools:

- [Rust and Cargo](https://rustup.rs)
- [Elm](https://guide.elm-lang.org/install/elm.html)
- [elm-format](https://github.com/avh4/elm-format)
- [Tailwind CSS](https://tailwindcss.com)
- [terser](https://github.com/terser/terser)
- [Node and npm](https://nodejs.org)
- [Zig](https://ziglang.org)
- [cargo-zigbuild](https://github.com/rust-cross/cargo-zigbuild)
- [cargo-watch](https://github.com/watchexec/cargo-watch)
- [cargo-llvm-cov](https://crates.io/crates/cargo-llvm-cov)
- [PostgreSQL](https://www.postgresql.org)
- [sqlx-cli](https://crates.io/crates/sqlx-cli)
- [dekit](https://github.com/pvolok/dekit)
- [make](https://www.gnu.org/software/make/)

You also need a running Postgres server.

## Steps

1. Install the client dependencies:

   ```sh
   make install
   ```

2. Create the database:

   ```sh
   createdb axum_elm_template
   ```

3. Copy the example environment file:

   ```sh
   cp server/.env.example server/.env
   ```

4. Open `server/.env` and set `DATABASE_URL` and `JWT_SECRET`. For the full list of
   variables, see [Configuration](004-configuration.md).

5. Apply the database migrations. The server tests its queries against the database
   when it compiles, so the schema must exist before the first build:

   ```sh
   cd server && sqlx migrate run && cd ..
   ```

6. Start the development servers. This starts the server, the Elm build, and the
   Tailwind build, with reload on change:

   ```sh
   make dev
   ```

7. Open `http://localhost:8000` in the browser.

After the first build, the server applies any pending migrations at startup. You run
`sqlx migrate run` by hand only to prepare the schema before you build.

## Create the first administrator

The sign-up page creates a normal user, never an administrator. Create the first
administrator from the terminal instead.

1. Run the register command:

   ```sh
   cd server && cargo run -- register
   ```

2. Answer the prompts for the email, the name, and the password.
3. Answer yes to the administrator prompt.

Sign in at `http://localhost:8000` with the account you created.
