# AGENTS.md

Guidance for AI agents and new contributors in this repository. Read this first.
Then read the documentation under `docs/`. It starts at `docs/000-index.md`.

## What this is

A template for a web application with a Rust Axum server in `server/` and an Elm
client in `client/`. The server owns the data and the rules. The client calls it
over HTTP. The two share their API types through code generated from the Rust types.

## Layout

- `server/`: the Rust server.
- `client/`: the Elm client, with `app.css` and `index.html`.
- `client/src/Api/Types.elm`: generated from the Rust types. Never edit it by hand.
- `docs/`: the documentation. Start at `docs/000-index.md`.
- `Makefile` and `dekit.yaml`: the build steps and the dev-runner tasks.

## Run and build

- Develop: run `make dev`, then open `http://localhost:8000`. The server listens on
  3000, and elm-watch serves the client on 8000 and proxies `/api/` to 3000.
- Apply migrations before building: `cd server && sqlx migrate run`. The
  `sqlx::query!` macros test queries against the live database when the server
  compiles, and there is no offline cache, so the schema must exist before the build.
- Regenerate the shared types: `make genelm`. The dev runner also does this on each
  Rust change.
- Format before committing: `make format`. The pre-commit hook rejects unformatted
  code.
- Build a release: `make release`. See `docs/003-deployment/000-index.md`.

## Conventions

- Rust visibility: prefer `pub(crate)` over `pub`.
- Rust dependencies: add them with `cargo add`, never by editing `Cargo.toml` by
  hand.
- Rust `.expect()` messages read as "error <verb>ing ...", for example
  `.expect("error reading system clock")`.
- Do not add new code comments.
- Shared API types: define each type once in `server/src/api.rs`, add its name to
  both lists in `genelm`, and regenerate. Every generated enum constructor name must
  be unique across all types, because they share one Elm module.
- Client colors: use the theme tokens such as `primary`, `muted`, and `border`, not
  raw Tailwind palette classes. See `docs/008-frontend.md`.
- Documentation: write it in plain English in the spirit of ASD-STE100. Use short
  sentences and active voice. Do not use em-dashes or marketing words.

## Facts worth knowing

- Logs go to standard error, never standard output, because `genelm` writes the
  generated Elm to standard output.
- Tracing is off until you set `OTEL_EXPORTER_OTLP_ENDPOINT`. The server does
  in-process tail sampling. See `docs/009-telemetry.md`.
- An administrator is created only by the CLI `register` command. The API and the
  sign-up page never create one.
- A panic in a handler becomes a 500 response, and the server stays up.
- `DEPLOY_ENV` is required. It must be one of `local`, `development`, `staging`, or
  `production`. The value `local` serves the session cookie over plain HTTP. Every
  other value marks the cookie `Secure`.
- The health endpoint is `GET /api/v1/health`. It returns 200 with no body and needs
  no auth, so a reverse proxy can poll it. The repository root holds
  `Caddyfile.example`.

## Before you finish

- `cd server && cargo build` succeeds.
- `cd client && elm make src/Main.elm --output /dev/null` succeeds.
- `make format` leaves the tree clean.
