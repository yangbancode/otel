defmodule Otel.SDK.Trace.Sampler.AlwaysOffTest do
  use ExUnit.Case, async: true

  @sampler Otel.SDK.Trace.Sampler.new({Otel.SDK.Trace.Sampler.AlwaysOff, %{}})

  # Spec trace/sdk.md L191-L194: AlwaysOff drops every span and
  # adds no attributes; description is "AlwaysOffSampler".

  test "should_sample/7 returns :drop with no extra attributes" do
    assert {:drop, %{}, _ts} =
             Otel.SDK.Trace.Sampler.should_sample(@sampler, %{}, 123, [], "span", :internal, %{})
  end

  test ~s|description/1 returns "AlwaysOffSampler"| do
    assert Otel.SDK.Trace.Sampler.description(@sampler) == "AlwaysOffSampler"
  end
end
