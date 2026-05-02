defmodule Otel.Configuration.ComposerTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureLog

  @fixtures_dir Path.expand("../../fixtures/v1.0.0", __DIR__)

  defp compose!(model), do: Otel.Configuration.Composer.compose!(model)

  defp processors(specs) do
    compose!(%{"tracer_provider" => %{"processors" => specs}}).trace.processors
  end

  defp log_processors(specs) do
    compose!(%{"logger_provider" => %{"processors" => specs}}).logs.processors
  end

  defp readers(specs) do
    compose!(%{"meter_provider" => %{"readers" => specs}}).metrics.readers
  end

  defp exemplar(value) do
    compose!(%{"meter_provider" => %{"exemplar_filter" => value}}).metrics.exemplar_filter
  end

  defp e2e(filename) do
    @fixtures_dir
    |> Path.join(filename)
    |> File.read!()
    |> Otel.Configuration.Substitution.substitute!()
    |> Otel.Configuration.Parser.parse_string!()
    |> tap(&Otel.Configuration.Schema.validate!/1)
    |> compose!()
  end

  describe "compose!/1 top-level" do
    test "minimal model returns three pillars with sensible defaults" do
      %{trace: trace, metrics: metrics, logs: logs} = compose!(%{"file_format" => "1.0"})

      assert trace.processors == []
      assert %Otel.SDK.Trace.SpanLimits{} = trace.span_limits

      assert metrics.readers == []
      assert metrics.exemplar_filter == :trace_based

      assert logs.processors == []
      assert %Otel.SDK.Logs.LogRecordLimits{} = logs.log_record_limits
    end
  end

  describe "compose span processors" do
    test "batch processor with its exporter" do
      [{Otel.SDK.Trace.SpanProcessor, batch}] =
        processors([
          %{
            "batch" => %{
              "schedule_delay" => 100,
              "max_queue_size" => 50,
              "exporter" => %{"otlp_http" => %{"endpoint" => "http://x:4318/v1/traces"}}
            }
          }
        ])

      assert batch.exporter ==
               {Otel.OTLP.Trace.SpanExporter.HTTP, %{endpoint: "http://x:4318/v1/traces"}}

      assert batch.scheduled_delay_ms == 100
      assert batch.max_queue_size == 50
      assert batch.export_timeout_ms == 30_000
      assert batch.max_export_batch_size == 512
    end

    test "concrete key alongside */development sibling — picks the concrete one" do
      [{module, _}] =
        processors([
          %{
            "batch" => %{"exporter" => %{"otlp_http" => %{}}},
            "experimental_xyz/development" => %{"some" => "data"}
          }
        ])

      assert module == Otel.SDK.Trace.SpanProcessor
    end

    test "rejection cases: missing exporter / unknown exporter / unknown processor / all-development" do
      assert_raise ArgumentError, ~r/exporter is required/, fn ->
        processors([%{"batch" => %{"schedule_delay" => 100}}])
      end

      assert_raise ArgumentError, ~r/unsupported trace exporter/, fn ->
        processors([%{"batch" => %{"exporter" => %{"otlp_grpc" => %{}}}}])
      end

      assert_raise ArgumentError, ~r/unsupported span processor/, fn ->
        processors([%{"simple" => %{}}])
      end

      assert_raise ArgumentError, ~r/unsupported span processor/, fn ->
        processors([%{"my_custom_processor" => %{}}])
      end

      assert_raise ArgumentError, ~r/no concrete \(non-development\) key/, fn ->
        processors([
          %{"experimental_a/development" => nil, "experimental_b/development" => nil}
        ])
      end
    end
  end

  describe "compose metric readers" do
    test "periodic reader with otlp_http exporter" do
      [{Otel.SDK.Metrics.MetricReader.PeriodicExporting, http}] =
        readers([
          %{
            "periodic" => %{
              "interval" => 5_000,
              "timeout" => 1_000,
              "exporter" => %{"otlp_http" => %{"endpoint" => "http://x:4318/v1/metrics"}}
            }
          }
        ])

      assert http.export_interval_ms == 5_000
      assert http.export_timeout_ms == 1_000

      assert http.exporter ==
               {Otel.OTLP.Metrics.MetricExporter.HTTP, %{endpoint: "http://x:4318/v1/metrics"}}
    end

    test "rejection cases: pull / unknown reader / missing exporter / unknown exporter" do
      assert_raise ArgumentError, ~r/pull MetricReader.*not implemented/, fn ->
        readers([%{"pull" => %{}}])
      end

      assert_raise ArgumentError, ~r/unsupported metric reader/, fn ->
        readers([%{"my_custom_reader" => %{}}])
      end

      assert_raise ArgumentError, ~r/reader.exporter is required/, fn ->
        readers([%{"periodic" => %{"interval" => 1000}}])
      end

      assert_raise ArgumentError, ~r/unsupported metrics exporter/, fn ->
        readers([%{"periodic" => %{"exporter" => %{"prometheus" => %{}}}}])
      end
    end
  end

  describe "compose exemplar_filter" do
    test "hardcoded :trace_based; YAML exemplar_filter ignored" do
      assert compose!(%{}).metrics.exemplar_filter == :trace_based

      # YAML `meter_provider.exemplar_filter` block silently
      # ignored — mirrors sampler / limits / propagator policy.
      assert exemplar("always_on") == :trace_based
      assert exemplar("custom") == :trace_based
    end
  end

  describe "compose log processors" do
    test "batch processor with its exporter; spec default schedule_delay 1000" do
      [{Otel.SDK.Logs.LogRecordProcessor, batch}] =
        log_processors([
          %{
            "batch" => %{
              "schedule_delay" => 200,
              "exporter" => %{"otlp_http" => %{"endpoint" => "http://x:4318/v1/logs"}}
            }
          }
        ])

      assert batch.scheduled_delay_ms == 200

      assert batch.exporter ==
               {Otel.OTLP.Logs.LogRecordExporter.HTTP, %{endpoint: "http://x:4318/v1/logs"}}

      [{_, default}] = log_processors([%{"batch" => %{"exporter" => %{"otlp_http" => %{}}}}])
      assert default.scheduled_delay_ms == 1_000
    end

    test "rejection cases: unknown processor / missing exporter / unknown exporter" do
      assert_raise ArgumentError, ~r/unsupported log processor/, fn ->
        log_processors([%{"my_custom" => %{}}])
      end

      assert_raise ArgumentError, ~r/unsupported log processor/, fn ->
        log_processors([%{"simple" => %{}}])
      end

      assert_raise ArgumentError, ~r/processor.exporter is required/, fn ->
        log_processors([%{"batch" => %{}}])
      end

      assert_raise ArgumentError, ~r/unsupported logs exporter/, fn ->
        log_processors([%{"batch" => %{"exporter" => %{"otlp_grpc" => %{}}}}])
      end
    end
  end

  describe "compose resource" do
    test "no resource section → SDK baseline + schema_url default" do
      resource = compose!(%{}).trace.resource
      assert resource.attributes["telemetry.sdk.name"] == "otel"
      assert resource.attributes["telemetry.sdk.language"] == "elixir"
      assert is_binary(resource.attributes["telemetry.sdk.version"])

      assert compose!(%{"resource" => %{"schema_url" => "https://example.com/schema/v1"}}).trace.resource.schema_url ==
               "https://example.com/schema/v1"
    end

    test "attributes from list / typed / structured override list" do
      list_only =
        compose!(%{"resource" => %{"attributes_list" => "service.name=foo,deployment.env=prod"}}).trace.resource

      assert list_only.attributes["service.name"] == "foo"
      assert list_only.attributes["deployment.env"] == "prod"

      typed_only =
        compose!(%{
          "resource" => %{
            "attributes" => [
              %{"name" => "service.name", "value" => "bar"},
              %{"name" => "service.version", "value" => "1.2.3"}
            ]
          }
        }).trace.resource

      assert typed_only.attributes["service.name"] == "bar"
      assert typed_only.attributes["service.version"] == "1.2.3"

      override =
        compose!(%{
          "resource" => %{
            "attributes_list" => "service.name=from_list",
            "attributes" => [%{"name" => "service.name", "value" => "from_structured"}]
          }
        }).trace.resource

      assert override.attributes["service.name"] == "from_structured"
    end

    test "empty attributes_list yields only SDK baseline" do
      attrs = compose!(%{"resource" => %{"attributes_list" => ""}}).trace.resource.attributes

      assert attrs |> Map.keys() |> Enum.sort() ==
               ["telemetry.sdk.language", "telemetry.sdk.name", "telemetry.sdk.version"]
    end

    test "warns + skips */development resource detection" do
      log =
        capture_log(fn ->
          compose!(%{
            "resource" => %{
              "attributes_list" => "service.name=foo",
              "detection/development" => %{"detectors" => []}
            }
          })
        end)

      assert log =~ "ignoring"
      assert log =~ "detection/development"
    end
  end

  describe "compose propagator" do
    test "hardcoded Composite[TraceContext, Baggage]; YAML propagator block ignored" do
      assert {Otel.API.Propagator.TextMap.Composite,
              [Otel.API.Propagator.TextMap.TraceContext, Otel.API.Propagator.TextMap.Baggage]} =
               compose!(%{}).propagator

      # Any YAML `propagator:` block is silently ignored —
      # mirrors the `tracer_provider.sampler` / `limits` ignore
      # policy. Result is unchanged.
      assert {Otel.API.Propagator.TextMap.Composite, _} =
               compose!(%{"propagator" => %{"composite" => [%{"b3" => nil}]}}).propagator
    end
  end

  describe "end-to-end with v1.0.0 fixtures" do
    test "otel-getting-started.yaml composes the three pillars" do
      configs = e2e("otel-getting-started.yaml")

      [{Otel.SDK.Trace.SpanProcessor, batch}] = configs.trace.processors
      assert {Otel.OTLP.Trace.SpanExporter.HTTP, %{endpoint: endpoint}} = batch.exporter
      assert endpoint =~ "/v1/traces"

      [{Otel.SDK.Metrics.MetricReader.PeriodicExporting, _}] = configs.metrics.readers
      [{Otel.SDK.Logs.LogRecordProcessor, _}] = configs.logs.processors
    end

    test "otel-sdk-config.yaml ignores YAML sampler block; pillar limits still flow" do
      configs = e2e("otel-sdk-config.yaml")

      assert configs.trace.span_limits.attribute_count_limit == 128
      assert configs.trace.span_limits.event_count_limit == 128
    end

    test "otel-sdk-migration-config.yaml (env-var heavy) composes all pillars non-empty" do
      configs = e2e("otel-sdk-migration-config.yaml")

      assert [_ | _] = configs.trace.processors
      assert [_ | _] = configs.metrics.readers
      assert [_ | _] = configs.logs.processors
    end
  end
end
