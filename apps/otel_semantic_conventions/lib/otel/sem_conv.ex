defmodule Otel.SemConv do
  @moduledoc """
  OpenTelemetry Semantic Conventions for Elixir.

  Auto-generated attribute and metric key constants from the OpenTelemetry
  Semantic Conventions specification (v1.40.0).

  Generated modules live under two namespaces:

  * `Otel.SemConv.Attributes.*` — attribute key constants (e.g., `Otel.SemConv.Attributes.HTTP`)
  * `Otel.SemConv.Metrics.*` — metric name constants (e.g., `Otel.SemConv.Metrics.HTTP`)

  Module names preserve canonical acronym casing — `HTTP`, `DB`, `URL`,
  `K8S`, `JVM`, `AspNetCore`, `DotNet`, `SignalR`, etc. — rather than
  Pascal-cased variants (`Http`, `Db`, `Jvm`, `Aspnetcore`).

  Only stable items are generated. See the
  [generation decision](https://github.com/yangbancode/otel/blob/main/docs/decisions/semantic-conventions-code-generation.md)
  for the pipeline.
  """
end
