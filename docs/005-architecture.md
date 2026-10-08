# Architecture

The server owns the data and the rules. The client renders the screens and calls
the server over HTTP. The two share their data types through generated code, as
the next section describes.

## Shared types

The server defines each request and response type once in Rust. A build step
generates the matching Elm types, encoders, and decoders.

- Generation: `make genelm` runs the server `genelm` command and writes
  `client/src/Api/Types.elm`.
- Naming: Rust `snake_case` fields become Elm `camelCase` fields. The JSON keys
  stay `snake_case`.
- Safety: all generated types share one Elm module, so every enum constructor name
  must be unique across all types.

## Error handling

A panic is an unexpected abort in Rust code. The server catches a panic in a
request handler and turns it into a 500 response. One failed request does not drop
the connection or stop the server.
