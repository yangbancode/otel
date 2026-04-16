# E2E Environment Strategy

## Question

How to structure E2E testing and continuous improvement for the OTel SDK? Where should the E2E environment live, and how can AI Agents be used to automate testing and code improvement?

## Decision

### Two Separate Repositories

The E2E testing strategy is split across two repositories with distinct purposes:

**1. SDK Repository (`otel`) — In-process E2E**

Located at `test/e2e/`. Verifies that the SDK produces correct OTLP protobuf output using OTel Collector + File Exporter. Lightweight, runs in CI-compatible environments.

- Docker: OTel Collector only (~100MB)
- Verification: `jq` assertions on exported JSON files
- Purpose: "Does our SDK send correct OTLP?"

**2. Separate Repository (TBD) — Full E2E with Grafana Stack**

A standalone Elixir application (e.g., Phoenix) that depends on the `otel` SDK as a hex package. Tests the SDK from an actual user's perspective.

- Docker: `grafana/otel-lgtm` (Loki + Grafana + Tempo + Mimir + OTel Collector, single container)
- Verification: Grafana REST APIs (Tempo for traces, Loki for logs, Mimir/Prometheus for metrics)
- Purpose: "Does the SDK work correctly in a real application?"

### Why Separate Repositories

- SDK repository stays free of heavy dependencies (Phoenix, Ecto, etc.)
- E2E scenario changes don't trigger SDK CI
- Tests the SDK as a user would consume it (hex dependency)
- Scenarios can be freely expanded without affecting SDK development

### Grafana Stack for Parallel Scenarios

When running multiple scenarios in parallel, Grafana Stack is preferred over File Exporter:

| Concern | File Exporter | Grafana Stack |
|---|---|---|
| Parallel scenario isolation | Data mixes in one file, complex `jq` filters needed | Query by `service.name` or custom attributes via REST API |
| Data volume scaling | File parsing slows down | Database indexing stays fast |
| AI Agent verification | `cat` + `jq` | `curl` + JSON response |
| Resource overhead | ~100MB (Collector only) | ~600MB (all-in-one) |

### SDK Internal Debug Mode (Future)

The SDK can optionally instrument its own internals for debugging purposes. This requires **two separate pipelines** to avoid infinite recursion:

```
Pipeline A (user data):
  User code → SDK TracerProvider A → Processor A → Collector (port 4318)

Pipeline B (SDK internals):
  SDK internal code → TracerProvider B → Processor B → Collector (port 4319)
```

Key rules:
- Pipeline B instruments Pipeline A's code (Processor, Exporter, etc.)
- Pipeline B does NOT instrument itself
- Controlled by environment variable: `OTEL_SDK_INTERNAL_DEBUG=true`
- Zero overhead when disabled

This enables analysis like: "User span export took 150ms; inside that, BatchProcessor spent 120ms" — visible side-by-side in Grafana.

### AI Agent Automation Loop

The separate E2E repository can be used with AI Agents in an Observe → Diagnose → Fix → Verify loop:

```
1. Execute  → run scenario against Grafana Stack
2. Observe  → query Grafana APIs for results
3. Diagnose → compare against expected behavior + OTel spec
4. Fix      → modify SDK code
5. Verify   → re-run unit tests + E2E scenario
6. Repeat   → pass → commit, fail → back to step 2
```

Practical constraints:
- Scenarios should be leveled (basic → complex → chaos)
- One issue per loop iteration
- Maximum retry limit (e.g., 5 attempts)
- Grafana Stack kept running continuously (only scenarios restart)

### Implementation Order

1. **Now**: SDK repository `test/e2e/` with OTel Collector + File Exporter (done)
2. **Next**: Separate repository with Grafana Stack + realistic app scenarios
3. **Later**: SDK internal debug mode with dual pipelines
4. **Future**: AI Agent automation loop

## Compliance

No spec compliance items — this is an engineering strategy decision.
