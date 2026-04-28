defmodule Otel.SDK.Metrics.ViewTest do
  use ExUnit.Case, async: true

  defp instrument(overrides \\ %{}) do
    Map.merge(
      %Otel.API.Metrics.Instrument{
        name: "http.request.duration",
        kind: :histogram,
        unit: "ms",
        description: "Request duration",
        advisory: [],
        scope: %Otel.API.InstrumentationScope{
          name: "my_lib",
          version: "1.0.0",
          schema_url: "https://example.com"
        }
      },
      overrides
    )
  end

  defp view(criteria \\ %{}, config \\ %{}) do
    {:ok, view} = Otel.SDK.Metrics.View.new(criteria, config)
    view
  end

  describe "new/2" do
    test "round-trips criteria + config; defaults to %{} for both" do
      assert %Otel.SDK.Metrics.View{criteria: %{}, config: %{}} = view()

      v = view(%{name: "x", type: :histogram}, %{name: "renamed", description: "Renamed"})
      assert v.criteria == %{name: "x", type: :histogram}
      assert v.config == %{name: "renamed", description: "Renamed"}
    end

    # Spec metrics/sdk.md L850-L854: a wildcard view MUST NOT specify
    # a stream name (it would assign the same name to many streams).
    test "rejects wildcard criteria paired with a stream-name override" do
      assert {:error, "wildcard view must not specify a stream name"} =
               Otel.SDK.Metrics.View.new(%{name: "*"}, %{name: "override"})

      assert {:ok, _} = Otel.SDK.Metrics.View.new(%{name: "*"}, %{description: "All"})
    end
  end

  describe "matches?/2" do
    test "empty criteria and \"*\" wildcard both match every instrument" do
      assert Otel.SDK.Metrics.View.matches?(view(), instrument())
      assert Otel.SDK.Metrics.View.matches?(view(%{name: "*"}), instrument())
    end

    test "name match is case-insensitive" do
      assert Otel.SDK.Metrics.View.matches?(view(%{name: "HTTP.Request.Duration"}), instrument())
      refute Otel.SDK.Metrics.View.matches?(view(%{name: "other.metric"}), instrument())
    end

    test "single-criterion match: type, unit, meter_name, meter_version, meter_schema_url" do
      cases = [
        {%{type: :histogram}, %{type: :counter}},
        {%{unit: "ms"}, %{unit: "s"}},
        {%{meter_name: "my_lib"}, %{meter_name: "other_lib"}},
        {%{meter_version: "1.0.0"}, %{meter_version: "2.0.0"}},
        {%{meter_schema_url: "https://example.com"}, %{meter_schema_url: "https://other.com"}}
      ]

      for {match_criteria, miss_criteria} <- cases do
        assert Otel.SDK.Metrics.View.matches?(view(match_criteria), instrument())
        refute Otel.SDK.Metrics.View.matches?(view(miss_criteria), instrument())
      end
    end

    test "multi-criterion: ALL conditions must match" do
      assert Otel.SDK.Metrics.View.matches?(
               view(%{name: "http.request.duration", type: :histogram}),
               instrument()
             )

      refute Otel.SDK.Metrics.View.matches?(
               view(%{name: "http.request.duration", type: :counter}),
               instrument()
             )
    end

    test "unknown criteria key crashes (no silent accept-all)" do
      assert_raise FunctionClauseError, fn ->
        Otel.SDK.Metrics.View.matches?(view(%{unknown_key: "value"}), instrument())
      end
    end
  end

  describe "name/2 + description/2 — view config wins, instrument falls back" do
    test "view name/description override; missing falls back to instrument" do
      assert Otel.SDK.Metrics.View.name(view(%{}, %{name: "custom"}), instrument()) ==
               "custom"

      assert Otel.SDK.Metrics.View.name(view(), instrument()) == "http.request.duration"

      assert Otel.SDK.Metrics.View.description(view(%{}, %{description: "Custom"}), instrument()) ==
               "Custom"

      assert Otel.SDK.Metrics.View.description(view(), instrument()) == "Request duration"
    end
  end
end
