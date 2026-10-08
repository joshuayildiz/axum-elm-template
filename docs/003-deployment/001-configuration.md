# Configuration

This page lists the environment variables to set on a deployed server. The server
reads them from the real environment at startup. For every variable and its full
meaning, see the main [Configuration](../004-configuration.md) page.

## What to set

- `DATABASE_URL`: the connection string for the production Postgres database.
- `JWT_SECRET`: a long random secret that signs session tokens. Generate a fresh
  value for production, and do not reuse the development secret.
- `HOST`: the address the server binds to. The default is `127.0.0.1`, so only the
  reverse proxy on the same host reaches it. Leave it at the default unless the proxy
  runs on another machine.
- `PORT`: the port the server listens on. The default is 3000. Set it to match the
  reverse proxy in front of the server.
- `DEPLOY_ENV`: the deployment environment. Set it to `production`. It marks the
  session cookie `Secure`, so the browser sends it over HTTPS only. It also tags
  every trace with the environment. The server does not start without it.

## Tracing

Set these only when you export traces to a collector. When you set the endpoint,
the service name and the sample ratio become required.

- `OTEL_EXPORTER_OTLP_ENDPOINT`: the trace collector address.
- `OTEL_EXPORTER_OTLP_HEADERS`: the headers the collector needs, for example an API
  key.
- `OTEL_SERVICE_NAME`: the name of this service on its traces.
- `OTEL_TRACES_SAMPLER_ARG`: the keep ratio from 0 to 1. A value of 1 keeps every
  trace.
