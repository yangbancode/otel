# OTLP HTTP Exporter

## Question

How to implement the OTLP HTTP exporter on BEAM? HTTP client choice, binary protobuf encoding, gzip compression, endpoint configuration, partial success handling?

## Decision

TBD

## Compliance

- [OTLP Protocol](../compliance.md)
  * OTLP/HTTP — L390, L392
  * Binary Protobuf Encoding — L400
  * JSON Protobuf Encoding — L409, L418, L426, L443
  * OTLP/HTTP Request — L454, L459, L462, L469
  * OTLP/HTTP Response — L478, L482, L484, L485
  * Full Success (HTTP) — L498, L500, L507
  * Partial Success (HTTP) — L513, L518, L525, L533, L536
  * Failures (HTTP) — L541, L545, L554, L560, L562, L566, L568
  * Bad Data (HTTP) — L580, L581, L586
  * OTLP/HTTP Throttling — L592, L597, L600
  * All Other Responses — L608
  * OTLP/HTTP Connection — L614, L618, L620
  * OTLP/HTTP Concurrent Requests — L632
  * OTLP/HTTP Default Port — L636
  * Implementation Recommendations — L648, L650, L669
  * Future Versions and Interoperability — L695, L723
- [OTLP Exporter Configuration](../compliance.md)
  * Configuration Options — L13, L14, L17, L26, L71, L77, L83
  * Endpoint URLs for OTLP/HTTP — L101, L105, L115
  * Specify Protocol — L169, L170, L173
  * User Agent — L205, L211
