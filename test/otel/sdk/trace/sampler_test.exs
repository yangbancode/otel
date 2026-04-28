defmodule Otel.SDK.Trace.SamplerTest do
  use ExUnit.Case, async: true

  defmodule TestSampler do
    @moduledoc false
    @behaviour Otel.SDK.Trace.Sampler

    @impl true
    def setup(opts), do: opts
    @impl true
    def description(_config), do: "TestSampler"
    @impl true
    def should_sample(_ctx, _trace_id, _links, _name, _kind, _attributes, _config),
      do: {:record_and_sample, %{}, Otel.API.Trace.TraceState.new()}
  end

  @sampler Otel.SDK.Trace.Sampler.new({TestSampler, %{}})

  test "new/1 returns {module, description, config} tuple" do
    assert @sampler == {TestSampler, "TestSampler", %{}}
  end

  test "should_sample/7 delegates to the sampler module" do
    assert {:record_and_sample, %{}, %Otel.API.Trace.TraceState{}} =
             Otel.SDK.Trace.Sampler.should_sample(@sampler, %{}, 123, [], "n", :internal, %{})
  end

  test "description/1 returns the sampler module's description" do
    assert Otel.SDK.Trace.Sampler.description(@sampler) == "TestSampler"
  end
end
