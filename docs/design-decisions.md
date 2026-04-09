# Design Decisions (BEAM/OTP)

Decisions specific to implementing the OpenTelemetry SDK on the BEAM VM. These are not part of the OTel specification but are required to map spec concepts to Erlang/OTP primitives.

<!-- TODO: Each decision should be documented with the following structure:
  - Decision: what was decided
  - Choice: the selected option
  - Alternatives considered: other options evaluated
  - Rationale: why this choice was made (BEAM/OTP constraints, performance, etc.)
  - Status: decided / open / revisit

  Topics to cover:
  - Context storage mechanism (pdict vs ETS vs other)
  - Cross-process Context passing strategy
  - Span storage (ETS table design, ownership, access patterns)
  - Context attach/detach and token restore pattern
  - BatchSpanProcessor concurrency model (mailbox vs ETS queue vs other)
  - Supervision tree structure for SDK components
  - Exporter packaging strategy (monorepo vs separate packages)
  - NIF vs pure Erlang boundary for IdGenerator, hashing
  - Application boot order (ensuring providers are ready before instrumented code)
  - :logger integration approach (Handler vs Backend)
  - API/SDK package split timing (single package vs separate from the start)
-->
