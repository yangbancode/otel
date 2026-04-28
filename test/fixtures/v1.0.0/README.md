# YAML fixtures — opentelemetry-configuration v1.0.0

These files are verbatim copies of the canonical examples shipped at
[`open-telemetry/opentelemetry-configuration` v1.0.0](https://github.com/open-telemetry/opentelemetry-configuration/tree/v1.0.0/examples)
(also available locally under `references/opentelemetry-configuration/examples/`
when the submodule is initialized).

**Why copies and not direct references?** CI does not initialize git
submodules — pulling them all (especially `otp`) would significantly slow
the build. The `opentelemetry-configuration` schema is now Stable per
its [v1.0.0 versioning policy](https://github.com/open-telemetry/opentelemetry-configuration/blob/v1.0.0/VERSIONING.md),
so these fixtures should not drift in behavior; minor schema versions
will only add backwards-compatible properties.

## Sync process

When the `references/opentelemetry-configuration` submodule pin advances
(e.g. to v1.1.0), re-copy the example files:

```bash
cp references/opentelemetry-configuration/examples/*.yaml \
   apps/otel_config/test/fixtures/v1.0.0/
```

…and rename the directory if the major version changes.
