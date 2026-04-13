# OTLP gRPC Exporter

## Question

How to implement the OTLP gRPC exporter on BEAM? gRPC client library choice, unary calls, concurrent request support, status code handling?

## Decision

Deferred. HTTP protobuf is the most widely used OTLP transport and is already implemented. gRPC adds significant dependencies (grpcbox or grpc-elixir) for marginal benefit in most deployments.

Candidate libraries when needed:
- `grpcbox` — Erlang, 5 dependencies, same as opentelemetry-erlang
- `grpc` — Elixir, 10 dependencies, native Elixir API

Will revisit when high-throughput gRPC use cases arise.

## Compliance

- [OTLP Protocol](../compliance.md)
  * OTLP/gRPC Concurrent Requests — L129, L130, L137, L151, L155
  * OTLP/gRPC Response — L160
  * Full Success (gRPC) — L170, L172, L178
  * Partial Success (gRPC) — L185, L189, L197, L205, L208
  * Failures (gRPC) — L217, L222, L226, L228, L269, L291, L295
  * OTLP/gRPC Throttling — L309, L310, L312, L344, L365
  * OTLP/gRPC Default Port — L381
- [OTLP Exporter Configuration](../compliance.md)
  * Configuration Options — L13, L14, L17, L26, L71, L77, L83
  * Specify Protocol — L169, L170, L173
  * User Agent — L205, L211
