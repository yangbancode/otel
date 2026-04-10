# Built-in Samplers

## Question

How to implement AlwaysOn, AlwaysOff, TraceIdRatioBased, and ParentBased samplers on BEAM?

## Decision

### Four built-in samplers

| Sampler | Decision | Description |
|---|---|---|
| AlwaysOn | `:record_and_sample` | Always record and propagate |
| AlwaysOff | `:drop` | Never record |
| TraceIdRatioBased | deterministic by trace_id | Sample a percentage of traces |
| ParentBased | delegates by parent state | Decorator that routes to sub-samplers |

### TraceIdRatioBased algorithm

Uses lower 64 bits of trace_id compared against a threshold derived from the ratio. Deterministic: same trace_id always produces the same decision. A higher ratio always samples traces that a lower ratio would sample (L467).

### ParentBased routing

| Parent | Remote? | Sampled? | Delegate |
|---|---|---|---|
| absent | — | — | `root` (default: AlwaysOn) |
| present | true | true | `remote_parent_sampled` (default: AlwaysOn) |
| present | true | false | `remote_parent_not_sampled` (default: AlwaysOff) |
| present | false | true | `local_parent_sampled` (default: AlwaysOn) |
| present | false | false | `local_parent_not_sampled` (default: AlwaysOff) |

### Default sampler

`ParentBased(root=AlwaysOn)` per spec (L421).

### Modules

| Module | Location |
|---|---|
| `Otel.SDK.Trace.Sampler.AlwaysOn` | `apps/otel_sdk/lib/otel/sdk/trace/sampler/always_on.ex` |
| `Otel.SDK.Trace.Sampler.AlwaysOff` | `apps/otel_sdk/lib/otel/sdk/trace/sampler/always_off.ex` |
| `Otel.SDK.Trace.Sampler.TraceIdRatioBased` | `apps/otel_sdk/lib/otel/sdk/trace/sampler/trace_id_ratio_based.ex` |
| `Otel.SDK.Trace.Sampler.ParentBased` | `apps/otel_sdk/lib/otel/sdk/trace/sampler/parent_based.ex` |

## Compliance

- [Trace SDK](../compliance/trace-sdk.md)
  * Built-in Samplers — AlwaysOn — L426
  * Built-in Samplers — AlwaysOff — L431
  * Built-in Samplers — TraceIdRatioBased — L447, L450, L453, L462, L467
  * Built-in Samplers — ParentBased — L563, L575, L579, L580, L581, L582
