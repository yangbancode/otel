# Resource Creation & Merge

## Question

How to represent and merge Resources? What data structure and merge semantics to use?

## Decision

### Module: `Otel.SDK.Resource`

Location: `apps/otel_sdk/lib/otel/sdk/resource.ex`

### Data Structure

```elixir
%Otel.SDK.Resource{
  attributes: %{"service.name" => "my-service", ...},
  schema_url: ""
}
```

### Create

`create(attributes, schema_url \\ "")` — accepts map or `[{key, value}]` list.

### Merge

`merge(old, updating)` — updating resource's attributes take precedence.

Schema URL rules:
- If old has empty schema_url → use updating's
- If updating has empty schema_url → use old's
- If both match → use that URL
- If both differ → empty (merge conflict)

### SDK Default Resource

`default/0` returns a Resource with:
- `telemetry.sdk.name` → `"otel"`
- `telemetry.sdk.language` → `"elixir"`
- `telemetry.sdk.version` → from mix.exs
- `service.name` → `"unknown_service"`

### Integration

`Configuration.default_config()` builds the Resource by merging SDK defaults with env var overrides:

```
Resource.merge(Resource.default(), Resource.from_env())
```

TracerProvider stores the Resource and makes it available to exporters.

## Compliance

- [Compliance](../compliance.md)
  * Resource SDK — L22, L29
  * SDK-provided Resource Attributes — L39, L41
  * Create — L58
  * Merge — L71, L78, L79
