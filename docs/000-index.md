# Documentation

Start with the quickstart to get the template running. The pages below cover each
area in more depth.

The server owns the data and the rules. The client renders the screens and calls
the server over HTTP. The two share their data types through generated code, so a
change on the server becomes a type error on the client until you update the
client.

- [Quickstart](001-quickstart.md): install the tools, set up the database, and run
  the app.
- [Development](002-development/000-index.md): the local development flow and how the pieces
  fit together.
- [Deployment](003-deployment/000-index.md): how to build the release output and run it on a
  server.
- [Configuration](004-configuration.md): the environment variables and why the
  server needs them.
- [Architecture](005-architecture.md): how the server and client fit together, the
  shared types, and error handling.
- [Authentication](006-authentication.md): sign-in, sessions, two-factor, and
  self-service registration.
- [Administration](007-administration.md): access control, user management, role
  management, and settings.
- [Frontend](008-frontend.md): theming, languages, pagination, and real-time
  presence.
- [Telemetry](009-telemetry.md): request tracing, the exported data, and tail
  sampling.
