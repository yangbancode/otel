defmodule Otel.SDK.Trace.Sampler.AlwaysOnTest do
  use ExUnit.Case, async: true

  @sampler Otel.SDK.Trace.Sampler.new({Otel.SDK.Trace.Sampler.AlwaysOn, %{}})

  # Spec trace/sdk.md L185-L189: AlwaysOn samples every span and
  # adds no attributes; description is "AlwaysOnSampler".

  test "should_sample/7 returns :record_and_sample with no extra attributes" do
    assert {:record_and_sample, %{}, _ts} =
             Otel.SDK.Trace.Sampler.should_sample(@sampler, %{}, 123, [], "span", :internal, %{})
  end

  test ~s|description/1 returns "AlwaysOnSampler"| do
    assert Otel.SDK.Trace.Sampler.description(@sampler) == "AlwaysOnSampler"
  end
end
