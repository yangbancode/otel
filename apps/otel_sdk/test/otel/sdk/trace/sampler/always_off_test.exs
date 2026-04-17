defmodule Otel.SDK.Trace.Sampler.AlwaysOffTest do
  use ExUnit.Case, async: true

  test "always returns drop" do
    sampler = Otel.SDK.Trace.Sampler.new({Otel.SDK.Trace.Sampler.AlwaysOff, %{}})

    {decision, attrs, _ts} =
      Otel.SDK.Trace.Sampler.should_sample(
        sampler,
        %{},
        Otel.API.Trace.TraceId.new(<<123::128>>),
        [],
        "span",
        :internal,
        []
      )

    assert decision == :drop
    assert attrs == []
  end

  test "description is AlwaysOffSampler" do
    sampler = Otel.SDK.Trace.Sampler.new({Otel.SDK.Trace.Sampler.AlwaysOff, %{}})
    assert Otel.SDK.Trace.Sampler.description(sampler) == "AlwaysOffSampler"
  end
end
