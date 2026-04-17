# Semantic Conventions Code Generation

## Question

How to generate Elixir modules for OpenTelemetry Semantic Conventions? What is the generation pipeline, input source, and output structure?

## Decision

### Code Generation Tool: OTel Weaver v0.22.1

OTel Weaver is the official OpenTelemetry code generation CLI. Managed via `.mise.toml` as `github:open-telemetry/weaver`.

Chosen over a custom Mix task because Weaver handles YAML model resolution (`ref:`, `extends:`, multi-file group aggregation) internally. The same tool is used by opentelemetry-erlang.

### Source Data

YAML model files from the `references/semantic-conventions` submodule (pinned at v1.40.0).

Registry YAML files under `model/<domain>/registry.yaml` define attribute groups. Metrics YAML files define metrics.

### Generated Modules

Location: `apps/otel_semantic_conventions/lib/otel/sem_conv/`

| Group | Generated Module |
|---|---|
| attribute groups (stable) | `Otel.SemConv.Attributes.*` |
| metric groups (stable) | `Otel.SemConv.Metrics.*` |

Acronyms (`HTTP`, `DB`, `URL`, `K8S`, etc.) are preserved in module names per the `acronyms` list in `weaver.yaml`.

Example modules:
- `Otel.SemConv.Attributes.HTTP` — `http.*` attributes
- `Otel.SemConv.Attributes.DB` — `db.*` attributes
- `Otel.SemConv.Metrics.HTTP` — `http.*` metrics

### Scope: Stable Only

Per tech-spec, experimental/incubating attributes are out of scope. One generation pass with `--param stability=stable`.

Excluded platform-specific groups (no relevance outside their runtime):
`aspnetcore`, `dotnet`, `go`, `ios`, `jvm`, `kestrel`, `nodejs`, `signalr`, `v8js`, `veightjs`, `webengine`.

### Templates

Location: `apps/otel_semantic_conventions/templates/registry/elixir/`

| File | Purpose |
|---|---|
| `weaver.yaml` | JQ filter config, text_maps, acronyms |
| `common.j2` | Shared Jinja2 macros |
| `semantic_attributes.ex.j2` | Attribute module template |
| `semantic_metrics.ex.j2` | Metrics module template |

Adapted from the opentelemetry-erlang templates. Differences:
- Namespace: `Otel.SemConv.Attributes.*` / `Otel.SemConv.Metrics.*`
- Stable-only: no incubating, no `defdelegate`, no `@deprecated` handling
- No Erlang `.hrl` generation
- Simplified `@doc`: brief + iex doctest only (no Notes/Examples/Value type sections)

### Generated Code Pattern

Each attribute becomes a zero-arity function returning the key as a string:

```elixir
@spec http_request_method :: String.t()
def http_request_method do
  "http.request.method"
end
```

Enum attributes additionally get a `_values()` function returning a member-to-value map:

```elixir
@type http_request_method_values :: %{
        "connect" => String.t(),
        ...
      }

@spec http_request_method_values :: http_request_method_values()
def http_request_method_values do
  %{"connect" => "CONNECT", ...}
end
```

### Key Type: String.t()

The OTel spec (v1.55.0, [common/README.md L185](../../references/opentelemetry-specification/specification/common/README.md#L185)) requires:

> The attribute key MUST be a non-`null` and non-empty string.

All generated attribute and metric constants return `String.t()` to match the spec verbatim. Enum map keys and values are also strings for consistency.

This differs from opentelemetry-erlang, which emits atoms. The trade-off: atoms give O(1) pointer equality and singleton literal types for Dialyzer, but introduce a footgun where `:"http.method"` and `"http.method"` are distinct map keys. For a spec-strict project, strings remove ambiguity and align with the wire format without conversion.

API signatures (`Otel.API.Trace.Span.set_attribute/3`, `set_attributes/2`, `add_event/3`) accept `String.t()` only — atoms were removed from the union.

### Generation Command

```bash
weaver registry generate \
  --registry=references/semantic-conventions/model \
  --templates=apps/otel_semantic_conventions/templates \
  --param output=apps/otel_semantic_conventions/lib \
  --param stability=stable \
  elixir .

mix format apps/otel_semantic_conventions/lib/otel/sem_conv/attributes/*.ex \
           apps/otel_semantic_conventions/lib/otel/sem_conv/metrics/*.ex
```

### Testing

`test/otel/sem_conv/registry_test.exs` dynamically runs `doctest` on every generated module (filtered by namespace prefix). Each generated function includes an `iex>` doctest that exercises the return value, providing both documentation and test coverage.

### Design Notes

- Generated files are committed to the repository (same pattern as protobuf)
- Regeneration needed only when the semantic-conventions submodule is updated
- erlang uses Weaver with Jinja2 templates (same approach)

## References

- [OpenTelemetry Semantic Conventions](https://github.com/open-telemetry/semantic-conventions)
- [OTel Weaver](https://github.com/open-telemetry/weaver)
- [opentelemetry-erlang semconv templates](../../references/opentelemetry-erlang/apps/opentelemetry_semantic_conventions/templates/registry/elixir/)
