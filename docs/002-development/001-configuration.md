# Configuration

This page lists the environment variables for local development. The server reads
them from `server/.env`. Copy the example file:

```sh
cp server/.env.example server/.env
```

For every variable and its full meaning, see the main
[Configuration](../004-configuration.md) page.

## What to set

Set `DATABASE_URL` to the connection string for your local Postgres database, for
example `postgres://you@localhost/axum_elm_template`. Set `JWT_SECRET` to any
non-empty value for local development, and do not reuse that value in production.

## What to leave alone

Leave `PORT` unset. The server listens on 3000, and elm-watch serves the app on 8000
and forwards the API calls to 3000. Leave the `OTEL_` variables unset too, so the
server exports no traces. Local development needs no collector.
