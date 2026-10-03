# axum-elm-template

Batteries included Rust/Elm template/framework

## Prerequisites

- [rust & cargo](https://rustup.rs)
- [elm](https://guide.elm-lang.org/install/elm.html)
- [elm-format](https://github.com/avh4/elm-format)
- [tailwindcss](https://tailwindcss.com)
- [terser](https://github.com/terser/terser)
- [node & npm](https://nodejs.org)
- [zig](https://ziglang.org)
- [cargo-zigbuild](https://github.com/rust-cross/cargo-zigbuild)
- [cargo-watch](https://github.com/watchexec/cargo-watch)
- [postgres](https://www.postgresql.org)
- [dekit](https://github.com/pvolok/dekit)
- [make](https://www.gnu.org/software/make/)

## Configuration

The server reads its settings from environment variables. Copy the example file
and edit the values.

```sh
cp server/.env.example server/.env
```

Set these keys in `server/.env`:

- `DATABASE_URL`: the Postgres connection string, for example
  `postgres://user@localhost/axum_elm_template`.
- `JWT_SECRET`: the secret that signs the session tokens. Use a long random value.
- `ENABLE_REGISTRATION`: set to `true` to open sign-ups, or leave it out to keep
  them closed.

Create the database before you start the server. The server runs the migrations
on start-up.

```sh
createdb axum_elm_template
```

## Development

```sh
make install
make dev
```

## Git Hooks

```sh
git config core.hooksPath .githooks
```
