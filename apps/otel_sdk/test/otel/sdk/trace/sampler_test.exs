defmodule Otel.SDK.Trace.SamplerTest.TestSampler do
  @behaviour Otel.SDK.Trace.Sampler

  @impl true
  def setup(opts), do: opts

  @impl true
  def description(_config), do: "TestSampler"

  @impl true
  def should_sample(_ctx, _trace_id, _links, _name, _kind, _attributes, _config) do
    {:record_and_sample, %{}, %Otel.API.Trace.TraceState{}}
  end
end

defmodule Otel.SDK.Trace.SamplerTest do
  use ExUnit.Case, async: true

  describe "new/1" do
    test "creates sampler from module and opts" do
      sampler =
        Otel.SDK.Trace.Sampler.new({Otel.SDK.Trace.SamplerTest.TestSampler, %{}})

      assert {Otel.SDK.Trace.SamplerTest.TestSampler, "TestSampler", %{}} = sampler
    end
  end

  describe "should_sample/7" do
    test "delegates to sampler module" do
      sampler =
        Otel.SDK.Trace.Sampler.new({Otel.SDK.Trace.SamplerTest.TestSampler, %{}})

      result =
        Otel.SDK.Trace.Sampler.should_sample(
          sampler,
          %{},
          123,
          [],
          "test_span",
          :internal,
          %{}
        )

      assert {:record_and_sample, %{}, %Otel.API.Trace.TraceState{}} = result
    end
  end

  describe "description/1" do
    test "returns sampler description" do
      sampler =
        Otel.SDK.Trace.Sampler.new({Otel.SDK.Trace.SamplerTest.TestSampler, %{}})

      assert Otel.SDK.Trace.Sampler.description(sampler) == "TestSampler"
    end
  end
end
