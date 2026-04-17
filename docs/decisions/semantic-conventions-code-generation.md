# Semantic Conventions Code Generation

## Question

How to generate Elixir modules for OpenTelemetry Semantic Conventions? What is the generation pipeline, input source, and output structure?

## Decision

### Code Generation Tool: OTel Weaver v0.22.1

OTel Weaver is the official OpenTelemetry code generation CLI. Pinned via `.mise.toml` as `github:open-telemetry/weaver` = `0.22.1`. Source is checked in as a submodule at `references/weaver` for offline reference.

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

### Domain Inclusion

All stable domains in the spec are generated, including runtime/framework-specific ones (`aspnetcore`, `dotnet`, `jvm`, `kestrel`, `signalr`) that an Elixir application would not natively emit. The reasoning:

- The package is a constants library, not a runtime — exposing extra modules has zero cost beyond compile time.
- An OTel Collector or polyglot pipeline running inside an Elixir app may legitimately forward foreign-runtime telemetry and benefit from the constants.
- Filtering by domain duplicates judgment that the upstream spec already encodes via stability — anything truly irrelevant is unlikely to be marked stable.
- Maintenance simplicity: one less list to update when the spec adds a new domain.

For modules whose lowercase domain ID needs CamelCase normalization (e.g. `aspnetcore` → `AspNetCore`), the `acronyms` list in `weaver.yaml` carries the canonical capitalization alongside true acronyms like `HTTP` and `JVM`.

Other language/platform domains (`go`, `ios`, `nodejs`, `v8js`) currently have no stable items in v1.40.0 and produce nothing under the `stability=stable` filter. They will appear automatically when the spec promotes any of their items to stable.

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

Enum attributes additionally get a `_values()` helper returning a member-to-value map. Member ids (left-hand side) are atoms for type precision; member values (right-hand side) are strings because those are what callers emit as the attribute value:

```elixir
@type http_request_method_values :: %{
        :connect => String.t(),
        :delete => String.t(),
        ...
      }

@spec http_request_method_values :: http_request_method_values()
def http_request_method_values do
  %{:connect => "CONNECT", :delete => "DELETE", ...}
end
```

Dotted member ids use quoted-atom form, e.g. `:"microsoft.sql_server" => "microsoft.sql_server"`.

### Key Type: String.t() on the Wire

The OTel spec (v1.55.0, [common/README.md L185](../../references/opentelemetry-specification/specification/common/README.md#L185)) requires:

> The attribute key MUST be a non-`null` and non-empty string.

Everything the caller emits as an OTel attribute — the key returned by `http_request_method()`, and the value returned by `http_request_method_values()[:connect]` — is a `String.t()`, matching the spec verbatim.

The helper-map member ids (`:connect`, `:delete`, ...) are **not** OTel attribute keys. They are Elixir-side navigation handles for the caller to look up an allowed value in a finite enum; they never appear on the wire. Keeping them as atoms lets the typespec enumerate the exact valid keys (`%{:connect => String.t(), ...}`) so Dialyzer can catch typos like `values()[:conect]`, which a `%{optional(String.t()) => String.t()}` type cannot.

This differs from opentelemetry-erlang, which emits atoms for attribute keys themselves. The trade-off for that approach: atoms give O(1) pointer equality and singleton literal types, but introduce a footgun where `:"http.method"` and `"http.method"` are distinct map keys. For a spec-strict project, strings on the wire remove that ambiguity and align with the OTLP format without conversion.

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

- [OpenTelemetry Semantic Conventions](https://github.com/open-telemetry/semantic-conventions) — source YAML model, also vendored at [`references/semantic-conventions/`](../../references/semantic-conventions/)
- [OTel Weaver](https://github.com/open-telemetry/weaver) — generation CLI, also vendored at [`references/weaver/`](../../references/weaver/) (v0.22.1)
- [opentelemetry-erlang semconv templates](../../references/opentelemetry-erlang/apps/opentelemetry_semantic_conventions/templates/registry/elixir/)
