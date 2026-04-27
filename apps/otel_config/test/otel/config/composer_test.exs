defmodule Otel.Config.ComposerTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureLog

  @fixtures_dir Path.expand("../../fixtures/v1.0.0", __DIR__)

  describe "compose!/1 — top-level shape" do
    test "returns a map with :trace, :metrics, :logs keys" do
      result = Otel.Config.Composer.compose!(%{"file_format" => "1.0"})

      assert Map.has_key?(result, :trace)
      assert Map.has_key?(result, :metrics)
      assert Map.has_key?(result, :logs)
    end

    test "minimal model produces sensible defaults" do
      %{trace: trace, metrics: metrics, logs: logs} =
        Otel.Config.Composer.compose!(%{"file_format" => "1.0"})

      # Trace defaults: parentbased_always_on sampler, no processors
      assert {Otel.SDK.Trace.Sampler.ParentBased, _} = trace.sampler
      assert trace.processors == []
      assert %Otel.SDK.Trace.SpanLimits{} = trace.span_limits
      assert trace.id_generator == Otel.SDK.Trace.IdGenerator.Default

      # Metrics defaults: no readers, trace_based exemplar filter
      assert metrics.readers == []
      assert metrics.exemplar_filter == :trace_based

      # Logs defaults: no processors
      assert logs.processors == []
      assert %Otel.SDK.Logs.LogRecordLimits{} = logs.log_record_limits
    end
  end

  describe "compose_sampler" do
    test "always_on" do
      assert {Otel.SDK.Trace.Sampler.AlwaysOn, %{}} = sampler(%{"always_on" => nil})
    end

    test "always_off" do
      assert {Otel.SDK.Trace.Sampler.AlwaysOff, %{}} = sampler(%{"always_off" => nil})
    end

    test "trace_id_ratio_based with explicit ratio" do
      assert {Otel.SDK.Trace.Sampler.TraceIdRatioBased, 0.25} =
               sampler(%{"trace_id_ratio_based" => %{"ratio" => 0.25}})
    end

    test "trace_id_ratio_based without ratio defaults to 1.0" do
      assert {Otel.SDK.Trace.Sampler.TraceIdRatioBased, 1.0} =
               sampler(%{"trace_id_ratio_based" => nil})
    end

    test "parent_based with all defaults" do
      assert {Otel.SDK.Trace.Sampler.ParentBased, opts} =
               sampler(%{"parent_based" => %{"root" => %{"always_on" => nil}}})

      assert {Otel.SDK.Trace.Sampler.AlwaysOn, %{}} = opts.root
      assert {Otel.SDK.Trace.Sampler.AlwaysOn, %{}} = opts.remote_parent_sampled
      assert {Otel.SDK.Trace.Sampler.AlwaysOff, %{}} = opts.remote_parent_not_sampled
      assert {Otel.SDK.Trace.Sampler.AlwaysOn, %{}} = opts.local_parent_sampled
      assert {Otel.SDK.Trace.Sampler.AlwaysOff, %{}} = opts.local_parent_not_sampled
    end

    test "parent_based with all overrides" do
      assert {Otel.SDK.Trace.Sampler.ParentBased, opts} =
               sampler(%{
                 "parent_based" => %{
                   "root" => %{"trace_id_ratio_based" => %{"ratio" => 0.5}},
                   "remote_parent_sampled" => %{"always_off" => nil},
                   "remote_parent_not_sampled" => %{"always_on" => nil},
                   "local_parent_sampled" => %{"always_off" => nil},
                   "local_parent_not_sampled" => %{"always_on" => nil}
                 }
               })

      assert {Otel.SDK.Trace.Sampler.TraceIdRatioBased, 0.5} = opts.root
      assert {Otel.SDK.Trace.Sampler.AlwaysOff, %{}} = opts.remote_parent_sampled
      assert {Otel.SDK.Trace.Sampler.AlwaysOn, %{}} = opts.remote_parent_not_sampled
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
    test "batch processor with otlp_http exporter" do
      [{module, config}] =
        compose_processors([
          %{
            "batch" => %{
              "schedule_delay" => 100,
              "max_queue_size" => 50,
              "exporter" => %{"otlp_http" => %{"endpoint" => "http://x:4318/v1/traces"}}
            }
          }
        ])

      assert module == Otel.SDK.Trace.SpanProcessor.Batch
      assert config.exporter == {Otel.OTLP.Trace.SpanExporter.HTTP, %{endpoint: "http://x:4318/v1/traces"}}
      assert config.scheduled_delay_ms == 100
      assert config.max_queue_size == 50
      # Untouched fields take spec defaults
      assert config.export_timeout_ms == 30_000
      assert config.max_export_batch_size == 512
    end

    test "simple processor with console exporter" do
      [{module, config}] =
        compose_processors([%{"simple" => %{"exporter" => %{"console" => nil}}}])

      assert module == Otel.SDK.Trace.SpanProcessor.Simple
      assert config.exporter == {Otel.SDK.Trace.SpanExporter.Console, %{}}
    end

    test "raises when batch.exporter omitted" do
      assert_raise ArgumentError, ~r/exporter is required/, fn ->
        compose_processors([%{"batch" => %{"schedule_delay" => 100}}])
      end
    end

    test "raises on unsupported trace exporter" do
      assert_raise ArgumentError, ~r/unsupported trace exporter/, fn ->
        compose_processors([%{"simple" => %{"exporter" => %{"otlp_grpc" => %{}}}}])
      end
    end
  end

  describe "compose span_limits" do
    test "pillar limits override globals" do
      model = %{
        "attribute_limits" => %{"attribute_count_limit" => 32},
        "tracer_provider" => %{"limits" => %{"attribute_count_limit" => 256}}
      }

      assert Otel.Config.Composer.compose!(model).trace.span_limits.attribute_count_limit == 256
    end

    test "global limits flow through when pillar limits absent" do
      model = %{"attribute_limits" => %{"attribute_count_limit" => 32}}
      assert Otel.Config.Composer.compose!(model).trace.span_limits.attribute_count_limit == 32
    end

    test "schema-default 128 when neither set" do
      assert Otel.Config.Composer.compose!(%{}).trace.span_limits.attribute_count_limit == 128
    end
  end

  describe "compose metric readers" do
    test "periodic reader with otlp_http exporter" do
      [{module, config}] =
        compose_readers([
          %{
            "periodic" => %{
              "interval" => 5_000,
              "timeout" => 1_000,
              "exporter" => %{"otlp_http" => %{"endpoint" => "http://x:4318/v1/metrics"}}
            }
          }
        ])

      assert module == Otel.SDK.Metrics.MetricReader.PeriodicExporting
      assert config.export_interval_ms == 5_000
      assert config.export_timeout_ms == 1_000

      assert config.exporter ==
               {Otel.OTLP.Metrics.MetricExporter.HTTP, %{endpoint: "http://x:4318/v1/metrics"}}
    end

    test "raises on pull (Prometheus)" do
      assert_raise ArgumentError, ~r/pull MetricReader.*not implemented/, fn ->
        compose_readers([%{"pull" => %{}}])
      end
    end
  end

  describe "compose exemplar_filter" do
    test "always_on / always_off / trace_based pass through as atoms" do
      assert exemplar("always_on") == :always_on
      assert exemplar("always_off") == :always_off
      assert exemplar("trace_based") == :trace_based
    end

    test "absent → :trace_based default" do
      assert Otel.Config.Composer.compose!(%{}).metrics.exemplar_filter == :trace_based
    end
  end

  describe "compose log processors" do
    test "batch processor with otlp_http log exporter" do
      [{module, config}] =
        compose_log_processors([
          %{
            "batch" => %{
              "schedule_delay" => 200,
              "exporter" => %{"otlp_http" => %{"endpoint" => "http://x:4318/v1/logs"}}
            }
          }
        ])

      assert module == Otel.SDK.Logs.LogRecordProcessor.Batch
      assert config.scheduled_delay_ms == 200

      assert config.exporter ==
               {Otel.OTLP.Logs.LogRecordExporter.HTTP, %{endpoint: "http://x:4318/v1/logs"}}
    end

    test "logs batch processor schedule_delay defaults to 1000 (spec L168)" do
      [{_, config}] =
        compose_log_processors([%{"batch" => %{"exporter" => %{"console" => nil}}}])

      assert config.scheduled_delay_ms == 1_000
    end

    test "simple log processor" do
      [{module, _}] =
        compose_log_processors([%{"simple" => %{"exporter" => %{"console" => nil}}}])

      assert module == Otel.SDK.Logs.LogRecordProcessor.Simple
    end
  end

  describe "compose resource" do
    test "no resource section → just SDK baseline attributes" do
      resource = Otel.Config.Composer.compose!(%{}).trace.resource
      assert resource.attributes["telemetry.sdk.name"] == "otel"
      assert resource.attributes["telemetry.sdk.language"] == "elixir"
      assert is_binary(resource.attributes["telemetry.sdk.version"])
    end

    test "attributes_list (W3C Baggage format)" do
      model = %{"resource" => %{"attributes_list" => "service.name=foo,deployment.env=prod"}}
      resource = Otel.Config.Composer.compose!(model).trace.resource

      assert resource.attributes["service.name"] == "foo"
      assert resource.attributes["deployment.env"] == "prod"
    end

    test "attributes list (typed entries)" do
      model = %{
        "resource" => %{
          "attributes" => [
            %{"name" => "service.name", "value" => "bar"},
            %{"name" => "service.version", "value" => "1.2.3"}
          ]
        }
      }

      resource = Otel.Config.Composer.compose!(model).trace.resource
      assert resource.attributes["service.name"] == "bar"
      assert resource.attributes["service.version"] == "1.2.3"
    end

    test "structured attributes override attributes_list when keys overlap" do
      model = %{
        "resource" => %{
          "attributes_list" => "service.name=from_list",
          "attributes" => [%{"name" => "service.name", "value" => "from_structured"}]
        }
      }

      assert Otel.Config.Composer.compose!(model).trace.resource.attributes["service.name"] ==
               "from_structured"
    end

    test "warns + skips */development resource detection" do
      log =
        capture_log(fn ->
          Otel.Config.Composer.compose!(%{
            "resource" => %{
              "attributes_list" => "service.name=foo",
              "detection/development" => %{"detectors" => []}
            }
          })
        end)

      assert log =~ "ignoring"
      assert log =~ "detection/development"
    end

    test "schema_url passes through" do
      model = %{"resource" => %{"schema_url" => "https://example.com/schema/v1"}}
      assert Otel.Config.Composer.compose!(model).trace.resource.schema_url ==
               "https://example.com/schema/v1"
    end
  end

  describe "end-to-end with v1.0.0 fixtures" do
    test "otel-getting-started.yaml composes after Substitution + Parser + Schema" do
      configs =
        "otel-getting-started.yaml"
        |> load_fixture()
        |> Otel.Config.Substitution.substitute!()
        |> Otel.Config.Parser.parse_string!()
        |> tap(&Otel.Config.Schema.validate!/1)
        |> Otel.Config.Composer.compose!()

      # Trace: parent_based(always_on) + batch(otlp_http) per fixture
      assert {Otel.SDK.Trace.Sampler.ParentBased, %{root: {Otel.SDK.Trace.Sampler.AlwaysOn, %{}}}} =
               configs.trace.sampler

      [{Otel.SDK.Trace.SpanProcessor.Batch, batch_cfg}] = configs.trace.processors
      assert {Otel.OTLP.Trace.SpanExporter.HTTP, %{endpoint: endpoint}} = batch_cfg.exporter
      assert endpoint =~ "/v1/traces"

      # Metrics: periodic(otlp_http)
      [{Otel.SDK.Metrics.MetricReader.PeriodicExporting, _}] = configs.metrics.readers

      # Logs: batch(otlp_http)
      [{Otel.SDK.Logs.LogRecordProcessor.Batch, _}] = configs.logs.processors
    end

    test "otel-sdk-config.yaml (comprehensive) composes" do
      configs =
        "otel-sdk-config.yaml"
        |> load_fixture()
        |> Otel.Config.Substitution.substitute!()
        |> Otel.Config.Parser.parse_string!()
        |> tap(&Otel.Config.Schema.validate!/1)
        |> Otel.Config.Composer.compose!()

      # Comprehensive parent_based with all 5 child samplers wired
      {Otel.SDK.Trace.Sampler.ParentBased, parent_opts} = configs.trace.sampler
      assert {Otel.SDK.Trace.Sampler.AlwaysOn, %{}} = parent_opts.root
      assert {Otel.SDK.Trace.Sampler.AlwaysOn, %{}} = parent_opts.remote_parent_sampled
      assert {Otel.SDK.Trace.Sampler.AlwaysOff, %{}} = parent_opts.remote_parent_not_sampled

      # Span limits explicitly set in pillar
      assert configs.trace.span_limits.attribute_count_limit == 128
      assert configs.trace.span_limits.event_count_limit == 128
    end

    test "otel-sdk-migration-config.yaml (env-var heavy) composes" do
      configs =
        "otel-sdk-migration-config.yaml"
        |> load_fixture()
        |> Otel.Config.Substitution.substitute!()
        |> Otel.Config.Parser.parse_string!()
        |> tap(&Otel.Config.Schema.validate!/1)
        |> Otel.Config.Composer.compose!()

      # All three pillars produce non-empty processor / reader lists
      assert [_ | _] = configs.trace.processors
      assert [_ | _] = configs.metrics.readers
      assert [_ | _] = configs.logs.processors
    end
  end

  # ====== Test helpers ======

  defp sampler(spec) do
    Otel.Config.Composer.compose!(%{"tracer_provider" => %{"sampler" => spec}}).trace.sampler
  end

  defp compose_processors(processors) do
    Otel.Config.Composer.compose!(%{"tracer_provider" => %{"processors" => processors}}).trace.processors
  end

  defp compose_log_processors(processors) do
    Otel.Config.Composer.compose!(%{"logger_provider" => %{"processors" => processors}}).logs.processors
  end

  defp compose_readers(readers) do
    Otel.Config.Composer.compose!(%{"meter_provider" => %{"readers" => readers}}).metrics.readers
  end

  defp exemplar(value) do
    Otel.Config.Composer.compose!(%{"meter_provider" => %{"exemplar_filter" => value}}).metrics.exemplar_filter
  end

  defp load_fixture(filename) do
    @fixtures_dir |> Path.join(filename) |> File.read!()
  end
end
