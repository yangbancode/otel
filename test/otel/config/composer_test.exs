defmodule Otel.Config.ComposerTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureLog

  @fixtures_dir Path.expand("../../fixtures/v1.0.0", __DIR__)

  defp compose!(model), do: Otel.Config.Composer.compose!(model)

  defp sampler(spec) do
    compose!(%{"tracer_provider" => %{"sampler" => spec}}).trace.sampler
  end

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
    |> Otel.Config.Substitution.substitute!()
    |> Otel.Config.Parser.parse_string!()
    |> tap(&Otel.Config.Schema.validate!/1)
    |> compose!()
  end

  describe "compose!/1 top-level" do
    test "minimal model returns three pillars with sensible defaults" do
      %{trace: trace, metrics: metrics, logs: logs} = compose!(%{"file_format" => "1.0"})

      assert {Otel.SDK.Trace.Sampler.ParentBased, _} = trace.sampler
      assert trace.processors == []
      assert %Otel.SDK.Trace.SpanLimits{} = trace.span_limits
      assert trace.id_generator == Otel.SDK.Trace.IdGenerator.Default

      assert metrics.readers == []
      assert metrics.exemplar_filter == :trace_based

      assert logs.processors == []
      assert %Otel.SDK.Logs.LogRecordLimits{} = logs.log_record_limits
    end
  end

  describe "compose sampler" do
    test "primitive samplers and ratio default" do
      assert {Otel.SDK.Trace.Sampler.AlwaysOn, %{}} = sampler(%{"always_on" => nil})
      assert {Otel.SDK.Trace.Sampler.AlwaysOff, %{}} = sampler(%{"always_off" => nil})

      assert {Otel.SDK.Trace.Sampler.TraceIdRatioBased, 0.25} =
               sampler(%{"trace_id_ratio_based" => %{"ratio" => 0.25}})

      assert {Otel.SDK.Trace.Sampler.TraceIdRatioBased, 1.0} =
               sampler(%{"trace_id_ratio_based" => nil})
    end

    test "parent_based: defaults and overrides" do
      assert {Otel.SDK.Trace.Sampler.ParentBased, defaults} =
               sampler(%{"parent_based" => %{"root" => %{"always_on" => nil}}})

      assert {Otel.SDK.Trace.Sampler.AlwaysOn, %{}} = defaults.root
      assert {Otel.SDK.Trace.Sampler.AlwaysOn, %{}} = defaults.remote_parent_sampled
      assert {Otel.SDK.Trace.Sampler.AlwaysOff, %{}} = defaults.remote_parent_not_sampled
      assert {Otel.SDK.Trace.Sampler.AlwaysOn, %{}} = defaults.local_parent_sampled
      assert {Otel.SDK.Trace.Sampler.AlwaysOff, %{}} = defaults.local_parent_not_sampled

      assert {Otel.SDK.Trace.Sampler.ParentBased, custom} =
               sampler(%{
                 "parent_based" => %{
                   "root" => %{"trace_id_ratio_based" => %{"ratio" => 0.5}},
                   "remote_parent_sampled" => %{"always_off" => nil},
                   "remote_parent_not_sampled" => %{"always_on" => nil}
                 }
               })

      assert {Otel.SDK.Trace.Sampler.TraceIdRatioBased, 0.5} = custom.root
      assert {Otel.SDK.Trace.Sampler.AlwaysOff, %{}} = custom.remote_parent_sampled
      assert {Otel.SDK.Trace.Sampler.AlwaysOn, %{}} = custom.remote_parent_not_sampled
    end

    test "raises on unsupported sampler" do
      assert_raise ArgumentError, ~r/unsupported sampler/, fn ->
        sampler(%{"jaeger_remote" => nil})
      end
    end

    test "warns + falls back when sampler is */development" do
      log =
        capture_log(fn ->
          assert {Otel.SDK.Trace.Sampler.ParentBased, _} =
                   sampler(%{"my_experimental/development" => nil})
        end)

      assert log =~ "ignoring"
      assert log =~ "my_experimental/development"
    end
  end

  describe "compose span processors" do
    test "batch and simple processors with their exporters" do
      [{Otel.SDK.Trace.SpanProcessor.Batch, batch}] =
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

      [{Otel.SDK.Trace.SpanProcessor.Simple, simple}] =
        processors([%{"simple" => %{"exporter" => %{"console" => nil}}}])

      assert simple.exporter == {Otel.SDK.Trace.SpanExporter.Console, %{}}
    end

    test "concrete key alongside */development sibling — picks the concrete one" do
      [{module, _}] =
        processors([
          %{
            "batch" => %{"exporter" => %{"console" => nil}},
            "experimental_xyz/development" => %{"some" => "data"}
          }
        ])

      assert module == Otel.SDK.Trace.SpanProcessor.Batch
    end

    test "rejection cases: missing exporter / unknown exporter / unknown processor / all-development" do
      assert_raise ArgumentError, ~r/exporter is required/, fn ->
        processors([%{"batch" => %{"schedule_delay" => 100}}])
      end

      assert_raise ArgumentError, ~r/unsupported trace exporter/, fn ->
        processors([%{"simple" => %{"exporter" => %{"otlp_grpc" => %{}}}}])
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

  describe "compose span_limits" do
    test "pillar limits override globals; globals flow when pillar absent; schema default 128" do
      with_pillar = %{
        "attribute_limits" => %{"attribute_count_limit" => 32},
        "tracer_provider" => %{"limits" => %{"attribute_count_limit" => 256}}
      }

      assert compose!(with_pillar).trace.span_limits.attribute_count_limit == 256

      globals_only = %{"attribute_limits" => %{"attribute_count_limit" => 32}}
      assert compose!(globals_only).trace.span_limits.attribute_count_limit == 32

      assert compose!(%{}).trace.span_limits.attribute_count_limit == 128
    end

    test "tracer_provider.limits attribute_value_length_limit override" do
      model = %{"tracer_provider" => %{"limits" => %{"attribute_value_length_limit" => 100}}}
      assert compose!(model).trace.span_limits.attribute_value_length_limit == 100
    end
  end

  describe "compose metric readers" do
    test "periodic reader with otlp_http and console exporters" do
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

      [{_, console}] = readers([%{"periodic" => %{"exporter" => %{"console" => nil}}}])
      assert console.exporter == {Otel.SDK.Metrics.MetricExporter.Console, %{}}
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
    test "always_on / always_off / trace_based pass through; default :trace_based" do
      assert exemplar("always_on") == :always_on
      assert exemplar("always_off") == :always_off
      assert exemplar("trace_based") == :trace_based

      assert compose!(%{}).metrics.exemplar_filter == :trace_based

      assert_raise ArgumentError, ~r/unsupported exemplar_filter/, fn ->
        exemplar("custom")
      end
    end
  end

  describe "compose log processors" do
    test "batch and simple processors with their exporters; spec default schedule_delay 1000" do
      [{Otel.SDK.Logs.LogRecordProcessor.Batch, batch}] =
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

      [{_, default}] = log_processors([%{"batch" => %{"exporter" => %{"console" => nil}}}])
      assert default.scheduled_delay_ms == 1_000

      [{Otel.SDK.Logs.LogRecordProcessor.Simple, _}] =
        log_processors([%{"simple" => %{"exporter" => %{"console" => nil}}}])
    end

    test "rejection cases: unknown processor / missing exporter / unknown exporter" do
      assert_raise ArgumentError, ~r/unsupported log processor/, fn ->
        log_processors([%{"my_custom" => %{}}])
      end

      assert_raise ArgumentError, ~r/processor.exporter is required/, fn ->
        log_processors([%{"simple" => %{}}])
      end

      assert_raise ArgumentError, ~r/unsupported logs exporter/, fn ->
        log_processors([%{"simple" => %{"exporter" => %{"otlp_grpc" => %{}}}}])
      end
    end

    test "logger_provider.limits attribute_value_length_limit override" do
      model = %{"logger_provider" => %{"limits" => %{"attribute_value_length_limit" => 64}}}
      assert compose!(model).logs.log_record_limits.attribute_value_length_limit == 64
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
      list_only = compose!(%{"resource" => %{"attributes_list" => "service.name=foo,deployment.env=prod"}}).trace.resource
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
    test "absent → Noop; single composite entry → module directly" do
      assert compose!(%{}).propagator == Otel.API.Propagator.TextMap.Noop

      assert compose!(%{"propagator" => %{"composite" => [%{"tracecontext" => nil}]}}).propagator ==
               Otel.API.Propagator.TextMap.TraceContext
    end

    test "composite list of two → Composite; composite + composite_list dedup" do
      two =
        compose!(%{
          "propagator" => %{
            "composite" => [%{"tracecontext" => nil}, %{"baggage" => nil}]
          }
        }).propagator

      assert {Otel.API.Propagator.TextMap.Composite,
              [Otel.API.Propagator.TextMap.TraceContext, Otel.API.Propagator.TextMap.Baggage]} =
               two

      merged =
        compose!(%{
          "propagator" => %{
            "composite" => [%{"tracecontext" => nil}],
            "composite_list" => "baggage,tracecontext"
          }
        }).propagator

      assert {Otel.API.Propagator.TextMap.Composite,
              [Otel.API.Propagator.TextMap.TraceContext, Otel.API.Propagator.TextMap.Baggage]} =
               merged
    end

    test "composite_list (post-substitution comma string)" do
      parsed = compose!(%{"propagator" => %{"composite_list" => "tracecontext,baggage"}}).propagator

      assert {Otel.API.Propagator.TextMap.Composite,
              [Otel.API.Propagator.TextMap.TraceContext, Otel.API.Propagator.TextMap.Baggage]} =
               parsed
    end

    test "empty composite_list / none in composite → Noop" do
      assert compose!(%{"propagator" => %{"composite_list" => ""}}).propagator ==
               Otel.API.Propagator.TextMap.Noop

      assert compose!(%{"propagator" => %{"composite" => [%{"none" => nil}]}}).propagator ==
               Otel.API.Propagator.TextMap.Noop
    end

    test "unknown propagator name warns + ignored; b3 not implemented raises" do
      log =
        capture_log(fn ->
          assert compose!(%{
                   "propagator" => %{
                     "composite" => [%{"tracecontext" => nil}, %{"mycustom" => nil}]
                   }
                 }).propagator == Otel.API.Propagator.TextMap.TraceContext
        end)

      assert log =~ "unknown propagator name"
      assert log =~ "mycustom"

      assert_raise ArgumentError, ~r/not implemented in this SDK/, fn ->
        compose!(%{"propagator" => %{"composite" => [%{"b3" => nil}]}})
      end
    end
  end

  describe "end-to-end with v1.0.0 fixtures" do
    test "otel-getting-started.yaml composes the three pillars" do
      configs = e2e("otel-getting-started.yaml")

      assert {Otel.SDK.Trace.Sampler.ParentBased,
              %{root: {Otel.SDK.Trace.Sampler.AlwaysOn, %{}}}} = configs.trace.sampler

      [{Otel.SDK.Trace.SpanProcessor.Batch, batch}] = configs.trace.processors
      assert {Otel.OTLP.Trace.SpanExporter.HTTP, %{endpoint: endpoint}} = batch.exporter
      assert endpoint =~ "/v1/traces"

      [{Otel.SDK.Metrics.MetricReader.PeriodicExporting, _}] = configs.metrics.readers
      [{Otel.SDK.Logs.LogRecordProcessor.Batch, _}] = configs.logs.processors
    end

    test "otel-sdk-config.yaml wires all five parent_based children + pillar limits" do
      configs = e2e("otel-sdk-config.yaml")

      {Otel.SDK.Trace.Sampler.ParentBased, parent_opts} = configs.trace.sampler
      assert {Otel.SDK.Trace.Sampler.AlwaysOn, %{}} = parent_opts.root
      assert {Otel.SDK.Trace.Sampler.AlwaysOn, %{}} = parent_opts.remote_parent_sampled
      assert {Otel.SDK.Trace.Sampler.AlwaysOff, %{}} = parent_opts.remote_parent_not_sampled

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
