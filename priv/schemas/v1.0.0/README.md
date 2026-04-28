# JSON Schema — opentelemetry-configuration v1.0.0

`opentelemetry_configuration.json` is a verbatim copy of the schema
shipped at
[`open-telemetry/opentelemetry-configuration` v1.0.0](https://github.com/open-telemetry/opentelemetry-configuration/blob/v1.0.0/opentelemetry_configuration.json)
(also available locally under
`references/opentelemetry-configuration/opentelemetry_configuration.json`
when the submodule is initialized).

Bundled here in `priv/` because it is needed at **runtime** —
`Otel.Config.Schema.validate!/1` loads it via
`:code.priv_dir(:otel_config)`. Vendoring (rather than reading from
the submodule) keeps the schema available without requiring CI or
production deploys to fetch git submodules.

## Sync process

When the `references/opentelemetry-configuration` submodule pin
advances (e.g. to v1.1.0), re-copy:

```bash
cp references/opentelemetry-configuration/opentelemetry_configuration.json \
   apps/otel_config/priv/schemas/v1.0.0/opentelemetry_configuration.json
```

…and rename the directory if the major version changes.

The schema's own [versioning policy](https://github.com/open-telemetry/opentelemetry-configuration/blob/v1.0.0/VERSIONING.md)
guarantees that minor versions add only backwards-compatible
properties, so existing `validate!` consumers will not break across
minor schema bumps.
