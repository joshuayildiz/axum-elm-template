# Configuration

The server reads its configuration from environment variables. It reads them from
the real environment, or from `server/.env` during development. Copy the example
file and edit the values:

```sh
cp server/.env.example server/.env
```

This page explains each variable and why the server needs it.

## Required

The server does not start without these three.

- `DATABASE_URL`: the Postgres connection string. The server keeps every user,
  role, and setting in Postgres, so it has no data without a database.
- `JWT_SECRET`: the secret that signs session tokens. The server signs each session
  token with this value and later accepts a token only because its signature
  matches. Use a long random value, because anyone who learns it can forge a valid
  session.
- `DEPLOY_ENV`: the deployment environment. It must be one of `local`,
  `development`, `staging`, or `production`. It does two things. It tags every
  trace, so you can tell production traffic from staging in the backend. It also
  controls the `Secure` flag on the session cookie. The value `local` serves the
  cookie over plain HTTP, so local development works. Every other value marks the
  cookie `Secure`, so the browser sends it over HTTPS only. Use `local` on your
  machine and `production` on a live server behind TLS.

## Optional

These have a default, or they only add detail to traces.

- `HOST`: the address the server binds to. The default is `127.0.0.1`, so the server
  accepts connections only from the same machine. This is what you want behind a
  reverse proxy on the same host. Set it to `0.0.0.0` only when the server must
  accept connections from other machines directly.
- `PORT`: the port the server listens on. The default is 3000. Set it when another
  program already uses that port.
- `HOSTNAME`: the host name on traces. It tells you which machine produced a trace
  when you run more than one.

## Tracing

The server exports no traces until you set an endpoint. When you set the endpoint,
two more variables become required, so every trace has a service name and a sample
ratio.

- `OTEL_EXPORTER_OTLP_ENDPOINT`: the trace collector address. Setting it turns
  export on. Leaving it empty keeps export off, so local work needs no collector.
- `OTEL_EXPORTER_OTLP_HEADERS`: the headers the collector needs, for example the
  Honeycomb API key. A local collector often needs none.
- `OTEL_SERVICE_NAME`: the name of this service on its traces. The backend groups
  traces by it. It is required when the endpoint is set.
- `OTEL_TRACES_SAMPLER_ARG`: the keep ratio from 0 to 1, for traces with no error.
  It controls how much normal traffic you store and pay for. A value of 1 keeps
  every trace. It is required when the endpoint is set.

See [Telemetry](009-telemetry.md) for how the server uses these.
