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

  describe "new/2" do
    test "creates view with empty criteria" do
      assert {:ok, %Otel.SDK.Metrics.View{criteria: %{}, config: %{}}} =
               Otel.SDK.Metrics.View.new()
    end

    test "creates view with criteria and config" do
      assert {:ok, view} =
               Otel.SDK.Metrics.View.new(
                 %{name: "http.request.duration", type: :histogram},
                 %{name: "http.duration", description: "Renamed"}
               )

      assert view.criteria == %{name: "http.request.duration", type: :histogram}
      assert view.config == %{name: "http.duration", description: "Renamed"}
    end

    test "rejects wildcard with stream name override" do
      assert {:error, "wildcard view must not specify a stream name"} =
               Otel.SDK.Metrics.View.new(%{name: "*"}, %{name: "override"})
    end

    test "allows wildcard without stream name" do
      assert {:ok, _view} = Otel.SDK.Metrics.View.new(%{name: "*"}, %{description: "All"})
    end
  end

  describe "matches?/2" do
    test "empty criteria matches all instruments" do
      {:ok, view} = Otel.SDK.Metrics.View.new()
      assert Otel.SDK.Metrics.View.matches?(view, instrument())
    end

    test "wildcard name matches all instruments" do
      {:ok, view} = Otel.SDK.Metrics.View.new(%{name: "*"})
      assert Otel.SDK.Metrics.View.matches?(view, instrument())
    end

    test "matches by exact name (case-insensitive)" do
      {:ok, view} = Otel.SDK.Metrics.View.new(%{name: "HTTP.Request.Duration"})
      assert Otel.SDK.Metrics.View.matches?(view, instrument())
    end

    test "does not match different name" do
      {:ok, view} = Otel.SDK.Metrics.View.new(%{name: "other.metric"})
      refute Otel.SDK.Metrics.View.matches?(view, instrument())
    end

    test "matches by type" do
      {:ok, view} = Otel.SDK.Metrics.View.new(%{type: :histogram})
      assert Otel.SDK.Metrics.View.matches?(view, instrument())
    end

    test "does not match different type" do
      {:ok, view} = Otel.SDK.Metrics.View.new(%{type: :counter})
      refute Otel.SDK.Metrics.View.matches?(view, instrument())
    end

    test "matches by unit" do
      {:ok, view} = Otel.SDK.Metrics.View.new(%{unit: "ms"})
      assert Otel.SDK.Metrics.View.matches?(view, instrument())
    end

    test "does not match different unit" do
      {:ok, view} = Otel.SDK.Metrics.View.new(%{unit: "s"})
      refute Otel.SDK.Metrics.View.matches?(view, instrument())
    end

    test "matches by meter_name" do
      {:ok, view} = Otel.SDK.Metrics.View.new(%{meter_name: "my_lib"})
      assert Otel.SDK.Metrics.View.matches?(view, instrument())
    end

    test "does not match different meter_name" do
      {:ok, view} = Otel.SDK.Metrics.View.new(%{meter_name: "other_lib"})
      refute Otel.SDK.Metrics.View.matches?(view, instrument())
    end

    test "matches by meter_version" do
      {:ok, view} = Otel.SDK.Metrics.View.new(%{meter_version: "1.0.0"})
      assert Otel.SDK.Metrics.View.matches?(view, instrument())
    end

    test "does not match different meter_version" do
      {:ok, view} = Otel.SDK.Metrics.View.new(%{meter_version: "2.0.0"})
      refute Otel.SDK.Metrics.View.matches?(view, instrument())
    end

    test "matches by meter_schema_url" do
      {:ok, view} = Otel.SDK.Metrics.View.new(%{meter_schema_url: "https://example.com"})
      assert Otel.SDK.Metrics.View.matches?(view, instrument())
    end

    test "does not match different meter_schema_url" do
      {:ok, view} = Otel.SDK.Metrics.View.new(%{meter_schema_url: "https://other.com"})
      refute Otel.SDK.Metrics.View.matches?(view, instrument())
    end

    test "additive criteria: all must match" do
      {:ok, view} = Otel.SDK.Metrics.View.new(%{name: "http.request.duration", type: :histogram})
      assert Otel.SDK.Metrics.View.matches?(view, instrument())

      {:ok, view2} = Otel.SDK.Metrics.View.new(%{name: "http.request.duration", type: :counter})
      refute Otel.SDK.Metrics.View.matches?(view2, instrument())
    end

    test "unknown criteria key is ignored (matches)" do
      {:ok, view} = Otel.SDK.Metrics.View.new(%{unknown_key: "value"})
      assert Otel.SDK.Metrics.View.matches?(view, instrument())
    end
  end

  describe "stream_name/2" do
    test "returns view name when configured" do
      {:ok, view} = Otel.SDK.Metrics.View.new(%{}, %{name: "custom_name"})
      assert "custom_name" == Otel.SDK.Metrics.View.stream_name(view, instrument())
    end

    test "falls back to instrument name" do
      {:ok, view} = Otel.SDK.Metrics.View.new()
      assert "http.request.duration" == Otel.SDK.Metrics.View.stream_name(view, instrument())
    end
  end

  describe "stream_description/2" do
    test "returns view description when configured" do
      {:ok, view} = Otel.SDK.Metrics.View.new(%{}, %{description: "Custom desc"})
      assert "Custom desc" == Otel.SDK.Metrics.View.stream_description(view, instrument())
    end

    test "falls back to instrument description" do
      {:ok, view} = Otel.SDK.Metrics.View.new()

      assert "Request duration" ==
               Otel.SDK.Metrics.View.stream_description(view, instrument())
    end
  end
end
