defmodule Otel.SDK.Trace.Sampler.AlwaysOnTest do
  use ExUnit.Case, async: true

  test "always returns record_and_sample" do
    sampler = Otel.SDK.Trace.Sampler.new({Otel.SDK.Trace.Sampler.AlwaysOn, %{}})

    {decision, attrs, _ts} =
      Otel.SDK.Trace.Sampler.should_sample(sampler, %{}, 123, [], "span", :internal, %{})

    assert decision == :record_and_sample
    assert attrs == %{}
  end

  test "description is AlwaysOnSampler" do
    sampler = Otel.SDK.Trace.Sampler.new({Otel.SDK.Trace.Sampler.AlwaysOn, %{}})
    assert Otel.SDK.Trace.Sampler.description(sampler) == "AlwaysOnSampler"
  end
end
