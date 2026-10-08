# Development

This page gives the minimum you need to work on the template day to day. For the
first-time setup, follow the [Quickstart](../001-quickstart.md). For the environment
variables, see [Configuration](001-configuration.md). For how each part fits
together, see [How it works](002-how-it-works.md).

## Run

Start the development servers with `make dev`, then open `http://localhost:8000` in
the browser. The app runs on port 8000 during development.

## The loop

`make dev` runs everything with hot reload. Edit Rust, Elm, or CSS, and the matching
part rebuilds and the browser updates on its own. elm-watch serves the client on
port 8000 and forwards every `/api/` request to the server on port 3000.

## Create a user

The sign-up page creates a normal user, never an administrator. To create an
administrator, run the register command and answer yes to the administrator prompt:

```sh
cd server && cargo run -- register
```

## Git hooks

Point Git at the repository hooks once, so a commit runs the formatting checks:

```sh
git config core.hooksPath .githooks
```

See [How it works](002-how-it-works.md) for what the pre-commit hook runs.
