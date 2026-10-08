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
migrations at startup. Put a reverse proxy in front for a public address and for
HTTPS. HTTPS is HTTP over an encrypted connection.
