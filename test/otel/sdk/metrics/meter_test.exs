defmodule Otel.SDK.Metrics.MeterTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureLog

  defp restart_sdk(env) do
    Application.stop(:otel)
    for {pillar, opts} <- env, do: Application.put_env(:otel, pillar, opts)
    Application.ensure_all_started(:otel)

    on_exit(fn ->
      Application.stop(:otel)
      for {pillar, _} <- env, do: Application.delete_env(:otel, pillar)
    end)
  end

  defp meter_for(scope_name \\ "test_lib") do
    {_, config} =
      Otel.SDK.Metrics.MeterProvider.get_meter(
        Otel.SDK.Metrics.MeterProvider,
        %Otel.API.InstrumentationScope{name: scope_name}
      )

    {Otel.SDK.Metrics.Meter, config}
  end

  defp config_of({_, config}), do: config

  defp datapoints(meter, name, agg_module \\ Otel.SDK.Metrics.Aggregation.Sum) do
    cfg = config_of(meter)
    agg_module.collect(cfg.metrics_tab, {name, cfg.scope}, %{})
  end

  setup do
    restart_sdk(metrics: [exporter: :none])
    %{meter: meter_for()}
  end

  describe "instrument creation" do
    test "create_* returns a typed Instrument struct for every kind", %{meter: meter} do
      assert %{name: "c", kind: :counter} =
               Otel.SDK.Metrics.Meter.create_counter(meter, "c", [])

      assert %{name: "h", kind: :histogram} =
               Otel.SDK.Metrics.Meter.create_histogram(meter, "h", [])

      assert %{name: "g", kind: :gauge} =
               Otel.SDK.Metrics.Meter.create_gauge(meter, "g", [])

      assert %{name: "udc", kind: :updown_counter} =
               Otel.SDK.Metrics.Meter.create_updown_counter(meter, "udc", [])

      assert %{name: "oc", kind: :observable_counter} =
               Otel.SDK.Metrics.Meter.create_observable_counter(meter, "oc", [])

      assert %{name: "og", kind: :observable_gauge} =
               Otel.SDK.Metrics.Meter.create_observable_gauge(meter, "og", [])

      assert %{name: "oudc", kind: :observable_updown_counter} =
               Otel.SDK.Metrics.Meter.create_observable_updown_counter(meter, "oudc", [])
    end

    test "observable kinds also accept the with-callback /5 form", %{meter: meter} do
      cb = fn _args -> [%Otel.API.Metrics.Measurement{value: 1}] end

      for {fun, kind} <- [
            {:create_observable_counter, :observable_counter},
            {:create_observable_gauge, :observable_gauge},
            {:create_observable_updown_counter, :observable_updown_counter}
          ] do
        result = apply(Otel.SDK.Metrics.Meter, fun, [meter, "n_#{kind}", cb, nil, []])
        assert result.kind == kind
      end
    end
  end

  describe "instrument opts" do
    test "unit + description + advisory pass through verbatim; nil → \"\" / []", %{meter: meter} do
      result =
        Otel.SDK.Metrics.Meter.create_counter(meter, "req",
          unit: "1",
          description: "Requests",
          advisory: [attributes: ["method", "status"]]
        )

      assert result.unit == "1"
      assert result.description == "Requests"
      assert result.advisory == [attributes: ["method", "status"]]

      nil_opts =
        Otel.SDK.Metrics.Meter.create_counter(meter, "nilopts", unit: nil, description: nil)

      assert nil_opts.unit == ""
      assert nil_opts.description == ""

      hist =
        Otel.SDK.Metrics.Meter.create_histogram(meter, "dur",
          advisory: [explicit_bucket_boundaries: [1, 5, 10]]
        )

      assert hist.advisory == [explicit_bucket_boundaries: [1, 5, 10]]
    end

    # Spec metrics/api.md L196-L211 MUST: unit ≥63 chars,
    # description ≥1023 chars, both case-sensitive, BMP support.
    test "unit ≥63 chars / description ≥1023 chars / case-sensitive / BMP characters", %{
      meter: meter
    } do
      lower = Otel.SDK.Metrics.Meter.create_counter(meter, "bytes_lower", unit: "kb")
      upper = Otel.SDK.Metrics.Meter.create_counter(meter, "bytes_upper", unit: "kB")
      assert lower.unit == "kb"
      assert upper.unit == "kB"

      long_unit = String.duplicate("a", 63)
      long_desc = String.duplicate("d", 1023)

      result =
        Otel.SDK.Metrics.Meter.create_counter(meter, "long",
          unit: long_unit,
          description: long_desc
        )

      assert result.unit == long_unit
      assert result.description == long_desc

      bmp = "Request count — 요청 ★ €"
      bmp_result = Otel.SDK.Metrics.Meter.create_counter(meter, "bmp", description: bmp)
      assert bmp_result.description == bmp
    end
  end

  describe "duplicate detection (within and across scopes)" do
    test "same scope: identical → same struct; case-insensitive → first-seen name wins" do
      meter = meter_for()

      first = Otel.SDK.Metrics.Meter.create_counter(meter, "RequestCount", unit: "1")
      assert first == Otel.SDK.Metrics.Meter.create_counter(meter, "RequestCount", unit: "1")

      case_dup = Otel.SDK.Metrics.Meter.create_counter(meter, "requestcount", unit: "1")
      assert case_dup.name == "RequestCount"
    end

    test "different scopes are independent namespaces (same name, different kind)" do
      meter_a = meter_for("lib_a")
      meter_b = meter_for("lib_b")

      assert Otel.SDK.Metrics.Meter.create_counter(meter_a, "requests", []).kind == :counter

      assert Otel.SDK.Metrics.Meter.create_histogram(meter_b, "requests", []).kind ==
               :histogram
    end
  end

  describe "duplicate conflict resolution" do
    test "conflicting unit/description/kind/advisory all return first-seen instrument", %{
      meter: meter
    } do
      pairs = [
        # {first_args, second_fn, second_args}
        {{"desc_dup", [unit: "1", description: "alpha"]},
         &Otel.SDK.Metrics.Meter.create_counter/3, [unit: "1", description: "beta"]},
        {{"unit_dup", [unit: "1", description: "a"]}, &Otel.SDK.Metrics.Meter.create_counter/3,
         [unit: "ms", description: "a"]},
        {{"kind_dup", [unit: "1"]}, &Otel.SDK.Metrics.Meter.create_histogram/3, [unit: "1"]},
        {{"both_dup", [unit: "1"]}, &Otel.SDK.Metrics.Meter.create_histogram/3, [unit: "ms"]}
      ]

      for {{name, first_opts}, second_fn, second_opts} <- pairs do
        first = Otel.SDK.Metrics.Meter.create_counter(meter, name, first_opts)
        second = second_fn.(meter, name, second_opts)
        assert second == first
      end

      # Histogram-only advisory conflict — first advisory wins.
      hist1 =
        Otel.SDK.Metrics.Meter.create_histogram(meter, "adv_dup",
          advisory: [explicit_bucket_boundaries: [1, 5, 10]]
        )

      hist2 =
        Otel.SDK.Metrics.Meter.create_histogram(meter, "adv_dup",
          advisory: [explicit_bucket_boundaries: [100, 200]]
        )

      assert hist2 == hist1
      assert hist2.advisory == [explicit_bucket_boundaries: [1, 5, 10]]
    end

    # Spec metrics/sdk.md L917-L930 — duplicate registration emits a
    # warning naming the conflicting field; identical re-registration
    # is silent.
    test "logs warning on conflicting duplicate; silent on identical re-registration", %{
      meter: meter
    } do
      log_conflict =
        capture_log(fn ->
          Otel.SDK.Metrics.Meter.create_counter(meter, "warn_dup", unit: "1")
          Otel.SDK.Metrics.Meter.create_counter(meter, "warn_dup", unit: "ms")
        end)

      assert log_conflict =~ "duplicate instrument registration"
      assert log_conflict =~ "warn_dup"
      assert log_conflict =~ ":unit"

      log_identical =
        capture_log(fn ->
          Otel.SDK.Metrics.Meter.create_counter(meter, "noop_dup", unit: "1", description: "x")
          Otel.SDK.Metrics.Meter.create_counter(meter, "noop_dup", unit: "1", description: "x")
        end)

      refute log_identical =~ "duplicate instrument registration"
    end

    test "view that overrides description suppresses description-only conflict warning" do
      Otel.SDK.Metrics.MeterProvider.add_view(
        Otel.SDK.Metrics.MeterProvider,
        %{name: "desc_dup"},
        %{description: "Canonical"}
      )

      meter = meter_for("lib")

      first =
        Otel.SDK.Metrics.Meter.create_counter(meter, "desc_dup", unit: "1", description: "first")

      second =
        Otel.SDK.Metrics.Meter.create_counter(meter, "desc_dup", unit: "1", description: "second")

      assert second == first
    end
  end

  describe "record/3" do
    test "uses default aggregation per kind; aggregates across attribute sets", %{meter: meter} do
      counter = Otel.SDK.Metrics.Meter.create_counter(meter, "req", [])
      Otel.SDK.Metrics.Meter.record(counter, 5, %{"method" => "GET"})
      Otel.SDK.Metrics.Meter.record(counter, 3, %{"method" => "GET"})
      Otel.SDK.Metrics.Meter.record(counter, 1, %{"method" => "POST"})

      sum_dps = datapoints(meter, "req", Otel.SDK.Metrics.Aggregation.Sum)
      by_attr = Map.new(sum_dps, &{&1.attributes, &1.value})
      assert by_attr[%{"method" => "GET"}] == 8
      assert by_attr[%{"method" => "POST"}] == 1

      gauge = Otel.SDK.Metrics.Meter.create_gauge(meter, "temp", [])
      Otel.SDK.Metrics.Meter.record(gauge, 20, %{})
      Otel.SDK.Metrics.Meter.record(gauge, 25, %{})
      [dp] = datapoints(meter, "temp", Otel.SDK.Metrics.Aggregation.LastValue)
      assert dp.value == 25

      hist = Otel.SDK.Metrics.Meter.create_histogram(meter, "latency", [])
      Otel.SDK.Metrics.Meter.record(hist, 50, %{})
      Otel.SDK.Metrics.Meter.record(hist, 150, %{})

      [dp] = datapoints(meter, "latency", Otel.SDK.Metrics.Aggregation.ExplicitBucketHistogram)
      assert dp.value.count == 2
      assert dp.value.sum == 200
      assert dp.value.min == 50
      assert dp.value.max == 150
    end

    test "record on an unregistered instrument is a no-op (returns :ok)", %{meter: meter} do
      cfg = config_of(meter)

      ghost = %Otel.API.Metrics.Instrument{
        meter: meter,
        name: "ghost",
        kind: :counter,
        scope: cfg.scope
      }

      assert :ok == Otel.SDK.Metrics.Meter.record(ghost, 1, %{})
    end

    test "View attribute_keys filter (include / exclude) restricts the recorded attribute set" do
      Otel.SDK.Metrics.MeterProvider.add_view(
        Otel.SDK.Metrics.MeterProvider,
        %{name: "filtered"},
        %{attribute_keys: {:include, ["method"]}}
      )

      Otel.SDK.Metrics.MeterProvider.add_view(
        Otel.SDK.Metrics.MeterProvider,
        %{name: "excluded"},
        %{attribute_keys: {:exclude, ["path"]}}
      )

      meter = meter_for("lib")

      Otel.SDK.Metrics.Meter.record(
        Otel.SDK.Metrics.Meter.create_counter(meter, "filtered", []),
        1,
        %{"method" => "GET", "path" => "/api"}
      )

      [dp_inc] = datapoints(meter, "filtered")
      assert dp_inc.attributes == %{"method" => "GET"}

      Otel.SDK.Metrics.Meter.record(
        Otel.SDK.Metrics.Meter.create_counter(meter, "excluded", []),
        1,
        %{"method" => "GET", "path" => "/api"}
      )

      [dp_exc] = datapoints(meter, "excluded")
      assert dp_exc.attributes == %{"method" => "GET"}
    end
  end

  describe "callback registration + run_callbacks" do
    test "inline callback (create_*/5) and register_callback/5 both feed the right instrument",
         %{meter: meter} do
      cfg = config_of(meter)

      cb = fn _args ->
        [%Otel.API.Metrics.Measurement{value: 42, attributes: %{"host" => "a"}}]
      end

      Otel.SDK.Metrics.Meter.create_observable_gauge(meter, "cpu", cb, nil, [])
      assert :ets.tab2list(cfg.callbacks_tab) != []

      Otel.SDK.Metrics.Meter.run_callbacks(cfg)

      [%{value: 42, attributes: %{"host" => "a"}}] =
        datapoints(meter, "cpu", Otel.SDK.Metrics.Aggregation.LastValue)

      assert :ok == Otel.SDK.Metrics.Meter.run_callbacks(config_of(meter_for("empty")))
    end

    test "register_callback/5 returns a tagged handle; unregister_callback removes it",
         %{meter: meter} do
      inst = Otel.SDK.Metrics.Meter.create_observable_counter(meter, "regd", [])
      cb = fn _args -> [%Otel.API.Metrics.Measurement{value: 1}] end

      reg = Otel.API.Metrics.Meter.register_callback(meter, [inst], cb, nil, [])
      assert {Otel.SDK.Metrics.Meter, {ref, _}} = reg
      assert is_reference(ref)

      cfg = config_of(meter)
      before_count = length(:ets.tab2list(cfg.callbacks_tab))

      assert :ok = Otel.API.Metrics.Meter.unregister_callback(reg)
      assert length(:ets.tab2list(cfg.callbacks_tab)) < before_count
    end

    # Spec L1302-L1303 — multi-instrument callbacks return
    # [{instrument, measurement}] pairs; each measurement is routed
    # to its paired instrument only.
    test "multi-instrument callback routes paired measurements per instrument", %{meter: meter} do
      usage = Otel.SDK.Metrics.Meter.create_observable_counter(meter, "usage", [])
      pressure = Otel.SDK.Metrics.Meter.create_observable_gauge(meter, "pressure", [])

      cb = fn _args ->
        [
          {usage, %Otel.API.Metrics.Measurement{value: 42, attributes: %{"id" => "a"}}},
          {pressure, %Otel.API.Metrics.Measurement{value: 1013, attributes: %{"id" => "a"}}}
        ]
      end

      Otel.API.Metrics.Meter.register_callback(meter, [usage, pressure], cb, nil, [])
      Otel.SDK.Metrics.Meter.run_callbacks(config_of(meter))

      [u_dp] = datapoints(meter, "usage", Otel.SDK.Metrics.Aggregation.Sum)
      [p_dp] = datapoints(meter, "pressure", Otel.SDK.Metrics.Aggregation.LastValue)

      assert u_dp.value == 42
      assert p_dp.value == 1013
    end
  end

  describe "cardinality limits" do
    test "default aggregation_cardinality_limit is 2000", %{meter: meter} do
      cfg = config_of(meter)
      Otel.SDK.Metrics.Meter.create_counter(meter, "card_test", [])

      [{_, stream}] = :ets.lookup(cfg.streams_tab, {cfg.scope, "card_test"})
      assert stream.aggregation_cardinality_limit == 2000
    end

    test "overflow attribute set absorbs all attribute sets past the limit; existing keys unaffected" do
      Otel.SDK.Metrics.MeterProvider.add_view(
        Otel.SDK.Metrics.MeterProvider,
        %{name: "limited"},
        %{aggregation_cardinality_limit: 3}
      )

      meter = meter_for("lib")
      counter = Otel.SDK.Metrics.Meter.create_counter(meter, "limited", [])

      for k <- ~w(a b c) do
        Otel.SDK.Metrics.Meter.record(counter, 1, %{"k" => k})
      end

      # Pre-existing key 'a' keeps incrementing on its own bucket;
      # later distinct keys 'd' and 'e' route to the overflow set.
      Otel.SDK.Metrics.Meter.record(counter, 5, %{"k" => "a"})
      Otel.SDK.Metrics.Meter.record(counter, 1, %{"k" => "d"})
      Otel.SDK.Metrics.Meter.record(counter, 1, %{"k" => "e"})

      dps = datapoints(meter, "limited")
      overflow = Enum.find(dps, &(&1.attributes == %{"otel.metric.overflow" => true}))
      normal = Enum.reject(dps, &(&1.attributes == %{"otel.metric.overflow" => true}))

      assert overflow.value == 2
      assert length(normal) == 3

      a_dp = Enum.find(dps, &(&1.attributes == %{"k" => "a"}))
      assert a_dp.value == 6
    end

    # Spec metrics/sdk.md §"Asynchronous instrument cardinality
    # limits" L864-L866 SHOULD — first-observed attribute sets are
    # pinned and survive across delta collect cycles.
    test "async first-observed attributes are pinned across delta collect cycles" do
      Otel.SDK.Metrics.MeterProvider.add_view(
        Otel.SDK.Metrics.MeterProvider,
        %{name: "async_card"},
        %{aggregation_cardinality_limit: 2}
      )

      meter = meter_for("lib")
      cfg = config_of(meter)
      cycle = :counters.new(1, [])

      cb = fn _args ->
        :counters.add(cycle, 1, 1)
        n = :counters.get(cycle, 1)

        [
          %Otel.API.Metrics.Measurement{value: 1, attributes: %{"k" => "a"}},
          %Otel.API.Metrics.Measurement{value: 1, attributes: %{"k" => "b"}},
          %Otel.API.Metrics.Measurement{value: 1, attributes: %{"late" => "x_#{n}"}},
          %Otel.API.Metrics.Measurement{value: 1, attributes: %{"late" => "y_#{n}"}}
        ]
      end

      Otel.SDK.Metrics.Meter.create_observable_counter(meter, "async_card", cb, nil, [])
      Otel.SDK.Metrics.Meter.run_callbacks(cfg)

      pinned =
        :ets.foldl(
          fn entry, acc ->
            case elem(entry, 0) do
              {"async_card", _, _, attrs} -> [attrs | acc]
              _ -> acc
            end
          end,
          [],
          cfg.observed_attrs_tab
        )

      assert %{"k" => "a"} in pinned
      assert %{"k" => "b"} in pinned
      assert length(pinned) == 2

      # Simulate a delta collect cycle.
      :ets.delete_all_objects(cfg.metrics_tab)
      Otel.SDK.Metrics.Meter.run_callbacks(cfg)

      pinned_after =
        :ets.foldl(
          fn entry, acc ->
            case elem(entry, 0) do
              {"async_card", _, _, attrs} -> [attrs | acc]
              _ -> acc
            end
          end,
          [],
          cfg.observed_attrs_tab
        )

      assert MapSet.new(pinned_after) == MapSet.new(pinned)

      metrics_keys =
        :ets.foldl(
          fn entry, acc ->
            case elem(entry, 0) do
              {"async_card", _, _, attrs} -> [attrs | acc]
              _ -> acc
            end
          end,
          [],
          cfg.metrics_tab
        )

      assert %{"otel.metric.overflow" => true} in metrics_keys
      assert Enum.filter(metrics_keys, &Map.has_key?(&1, "late")) == []
    end
  end

  describe "enabled?/2 — true unless every matching view is Drop" do
    test "registered instrument with default views → true; with all-Drop view → false" do
      meter = meter_for()

      assert true ==
               Otel.SDK.Metrics.Meter.enabled?(
                 Otel.SDK.Metrics.Meter.create_counter(meter, "active", []),
                 []
               )

      Otel.SDK.Metrics.MeterProvider.add_view(
        Otel.SDK.Metrics.MeterProvider,
        %{name: "dropped"},
        %{aggregation: Otel.SDK.Metrics.Aggregation.Drop}
      )

      drop_meter = meter_for("lib")

      refute Otel.SDK.Metrics.Meter.enabled?(
               Otel.SDK.Metrics.Meter.create_counter(drop_meter, "dropped", []),
               []
             )
    end

    test "instrument with one Drop view + one non-Drop view → true (any non-Drop wins)" do
      provider = Otel.SDK.Metrics.MeterProvider

      Otel.SDK.Metrics.MeterProvider.add_view(provider, %{name: "partial_drop"}, %{
        aggregation: Otel.SDK.Metrics.Aggregation.Drop
      })

      Otel.SDK.Metrics.MeterProvider.add_view(provider, %{type: :counter}, %{name: "renamed"})

      meter = meter_for("lib")

      assert Otel.SDK.Metrics.Meter.enabled?(
               Otel.SDK.Metrics.Meter.create_counter(meter, "partial_drop", []),
               []
             )
    end

    test "unregistered instrument: false when wildcard Drop view matches; true with no matching views" do
      Otel.SDK.Metrics.MeterProvider.add_view(
        Otel.SDK.Metrics.MeterProvider,
        %{name: "*"},
        %{aggregation: Otel.SDK.Metrics.Aggregation.Drop}
      )

      meter = meter_for("lib")
      cfg = config_of(meter)

      ghost = %Otel.API.Metrics.Instrument{
        meter: meter,
        name: "not_yet_created",
        kind: :counter,
        scope: cfg.scope
      }

      refute Otel.SDK.Metrics.Meter.enabled?(ghost, [])

      restart_sdk(metrics: [exporter: :none])
      meter2 = meter_for()
      cfg2 = config_of(meter2)

      no_view = %Otel.API.Metrics.Instrument{
        meter: meter2,
        name: "unknown",
        kind: :counter,
        scope: cfg2.scope
      }

      assert Otel.SDK.Metrics.Meter.enabled?(no_view, [])
    end
  end

  describe "match_views/2 — view matching produces 1+ Stream(s) per instrument" do
    @inst %Otel.API.Metrics.Instrument{
      name: "requests",
      kind: :counter,
      unit: "1",
      description: "Request count",
      advisory: [],
      scope: %Otel.API.InstrumentationScope{name: "lib"}
    }

    test "no view → 1 stream from instrument; matching view overrides; non-matching falls back" do
      assert [%Otel.SDK.Metrics.Stream{name: "requests"}] =
               Otel.SDK.Metrics.Meter.match_views([], @inst)

      {:ok, match} =
        Otel.SDK.Metrics.View.new(
          %{name: "requests"},
          %{name: "req_total", description: "Total requests"}
        )

      assert [%Otel.SDK.Metrics.Stream{name: "req_total", description: "Total requests"}] =
               Otel.SDK.Metrics.Meter.match_views([match], @inst)

      {:ok, miss} = Otel.SDK.Metrics.View.new(%{name: "other_metric"}, %{name: "renamed"})

      assert [%Otel.SDK.Metrics.Stream{name: "requests"}] =
               Otel.SDK.Metrics.Meter.match_views([miss], @inst)
    end

    test "multiple matching views → multiple streams (warns on stream-name collision)" do
      hist_inst = %{@inst | name: "latency", kind: :histogram, unit: "ms"}

      {:ok, by_type} = Otel.SDK.Metrics.View.new(%{type: :histogram}, %{name: "stream_a"})
      {:ok, by_unit} = Otel.SDK.Metrics.View.new(%{unit: "ms"}, %{name: "stream_b"})

      streams = Otel.SDK.Metrics.Meter.match_views([by_type, by_unit], hist_inst)
      assert Enum.map(streams, & &1.name) == ["stream_a", "stream_b"]

      {:ok, dup1} = Otel.SDK.Metrics.View.new(%{type: :counter}, %{name: "same_name"})
      {:ok, dup2} = Otel.SDK.Metrics.View.new(%{unit: "1"}, %{name: "same_name"})

      assert length(Otel.SDK.Metrics.Meter.match_views([dup1, dup2], @inst)) == 2
    end
  end
end
