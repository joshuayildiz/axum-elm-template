# Telemetry

The server produces distributed traces with OpenTelemetry and exports them over
OTLP. OTLP is the OpenTelemetry wire protocol. A trace is the tree of timed steps
for one request. Each step is a span. Export stays off until you set a collector
endpoint, so local work needs no collector.

- Backends: any OTLP backend, for example a local SigNoz or Honeycomb.
- Transport: OTLP over HTTP with protobuf, over the rustls TLS stack.
- Request spans: one span per request with the method, the path, the status, and
  the latency. A 5xx response marks the span as an error.
- Database spans: one child span per query, named by operation.
- Identity: an authenticated request records the user id and email on its span.
- Events: the server records sign-in, two-factor, and registration outcomes as
  events.
- Resource: each trace carries the service name, the service version, the instance
  id, the host name, and the deployment environment.
- Console logs: logs go to standard error, so they never corrupt generated output
  on standard output.

The collector endpoint and its headers come from the environment. See
[Configuration](004-configuration.md).

## Tail sampling

Tail sampling means the keep-or-drop decision happens after the trace finishes. The
server makes this decision inside the process, so it needs no separate collector.

- Keep rule: the server always keeps a trace that contains an error, with all of
  its child spans.
- Sample rule: for a trace with no error, the server keeps it at a ratio. The
  server decides on the trace id, so it keeps or drops the whole trace together.
- Ratio: the `OTEL_TRACES_SAMPLER_ARG` value, from 0 to 1. A value of 1 keeps every
  trace.
- Bounds: the server flushes a trace whose root never ends after 20 seconds. A
  clean shutdown flushes the pending traces.
