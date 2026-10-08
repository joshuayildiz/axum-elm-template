# axum-elm-template

A full-stack web template with a Rust server and an Elm client that share one set of
types.

Build your product on a Rust (Axum) API and an Elm single-page client. The types are
checked across the whole stack, from the database to the client. sqlx checks every
query against the real database schema when the server compiles, and the Rust API
types are generated into Elm, so the client stops compiling the moment it drifts from
the server. A change to a database column can surface as an Elm type error. Sign-in,
access control, settings, theming, and tracing are already built, so you start on
your own features.

## Features

- Types checked from the database schema to the Elm client, all at compile time.
- Email and password sign-in, with optional two-factor codes.
- Role-based access control, edited from the admin screens.
- Self-service sign-up that an admin turns on or off at runtime.
- A settings screen backed by the database.
- Light and dark themes from one set of color tokens.
- English and Turkish, enforced at compile time.
- Live presence and a broadcast feed over a websocket.
- Request tracing to Honeycomb, SigNoz, or any OpenTelemetry backend.

## Get started

Follow the [quickstart](docs/001-quickstart.md). The full documentation lives in
[docs/](docs/000-index.md).

## Built with

- Rust and Axum
- Elm
- Tailwind CSS
- PostgreSQL with sqlx
- OpenTelemetry
