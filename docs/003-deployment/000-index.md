# Deployment

This directory holds the deployment guide and the configuration a deployed server
needs. The server serves both the API and the client, so one process runs the whole
app.

## Files in this directory

- `001-configuration.md`: the environment variables to set on a deployed server.

## Build the release

Run `make release` from the repository root. It builds the client and the server
into the `target` directory:

- `target/server`: the server binary.
- `target/client`: the built client, with `index.html`, `app.js`, and `app.css`.

The binary includes the migrations, so it applies them at startup and ships nothing
else. You deploy only the `target` directory.

`make release` cross-compiles the binary for the deploy host. The build target comes
from the `OS` and `ARCH` variables, which default to the current machine. Build a
Linux x86_64 binary for a typical server:

```sh
make release OS=linux ARCH=amd64
```

The binary is a static musl build, so it runs on the host without extra libraries.

## Run it

1. Copy the `target` directory to the host.
2. Set the environment variables. See [Configuration](001-configuration.md).
3. Make sure that a Postgres database is reachable at `DATABASE_URL`.
4. Run the binary from inside `target`, so it finds the `client` directory:
   `cd target && ./server serve`.

The server listens on the port from `PORT`, which defaults to 3000. It runs its
migrations at startup.

## Put a reverse proxy in front

The server speaks plain HTTP and does not rate limit. Run it behind a reverse proxy
that terminates TLS, rate limits the sign-in routes, and forwards traffic to the
server. HTTPS is HTTP over an encrypted connection.

The repository root holds `Caddyfile.example`, a ready Caddy configuration. Copy it
to `Caddyfile`, set your domain, and point it at the host and port of the server. It
does four things:

1. It terminates TLS and adds security headers such as HSTS.
2. It rate limits the `/api/v1/auth/` routes, so password guessing is harder. This
   step needs the `caddy-ratelimit` plugin.
3. It polls the health endpoint at `/api/v1/health`, so it stops routing when the
   server is down.
4. It serves a maintenance page when the server is down. See below.

Set `DEPLOY_ENV=production`, so the session cookie carries the `Secure` flag and the
browser sends it over HTTPS only. See [Configuration](001-configuration.md).

## Maintenance page

When the server stops answering the health endpoint, the proxy returns a 502 or 503.
The example configuration serves a maintenance page for those codes, so a crash or a
deploy shows a friendly page instead of a raw error. Put your page at
`/srv/maintenance/maintenance.html` on the proxy host. The page returns a 503 status
and a `Retry-After` header, so search engines and uptime checks know the outage is
temporary.
