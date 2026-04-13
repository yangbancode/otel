defmodule Otel.SDK.ConfigurationTest do
  use ExUnit.Case

  @default_config Otel.SDK.Configuration.default_config()

  setup do
    env_vars = [
      "OTEL_TRACES_SAMPLER",
      "OTEL_TRACES_SAMPLER_ARG",
      "OTEL_SPAN_ATTRIBUTE_COUNT_LIMIT",
      "OTEL_SPAN_ATTRIBUTE_VALUE_LENGTH_LIMIT",
      "OTEL_SPAN_EVENT_COUNT_LIMIT",
      "OTEL_SPAN_LINK_COUNT_LIMIT",
      "OTEL_EVENT_ATTRIBUTE_COUNT_LIMIT",
      "OTEL_LINK_ATTRIBUTE_COUNT_LIMIT"
    ]

    Enum.each(env_vars, &System.delete_env/1)

    on_exit(fn ->
      Enum.each(env_vars, &System.delete_env/1)
    end)

    :ok
  end

  describe "merge/2 without env vars" do
    test "returns default merged with app config" do
      config = Otel.SDK.Configuration.merge(%{})
      assert config.sampler == @default_config.sampler
      assert config.span_limits == %Otel.SDK.Trace.SpanLimits{}
    end

    test "app config overrides defaults" do
      app = %{sampler: {Otel.SDK.Trace.Sampler.AlwaysOff, %{}}}
      config = Otel.SDK.Configuration.merge(app)
      assert config.sampler == {Otel.SDK.Trace.Sampler.AlwaysOff, %{}}
    end
  end

  describe "OTEL_TRACES_SAMPLER" do
    test "always_on" do
      System.put_env("OTEL_TRACES_SAMPLER", "always_on")
      config = Otel.SDK.Configuration.merge(%{})
      assert config.sampler == {Otel.SDK.Trace.Sampler.AlwaysOn, %{}}
    end

    test "always_off" do
      System.put_env("OTEL_TRACES_SAMPLER", "always_off")
      config = Otel.SDK.Configuration.merge(%{})
      assert config.sampler == {Otel.SDK.Trace.Sampler.AlwaysOff, %{}}
    end

    test "traceidratio with arg" do
      System.put_env("OTEL_TRACES_SAMPLER", "traceidratio")
      System.put_env("OTEL_TRACES_SAMPLER_ARG", "0.5")
      config = Otel.SDK.Configuration.merge(%{})

      assert config.sampler ==
               {Otel.SDK.Trace.Sampler.TraceIdRatioBased, %{probability: 0.5}}
    end

    test "traceidratio without arg defaults to 1.0" do
      System.put_env("OTEL_TRACES_SAMPLER", "traceidratio")
      config = Otel.SDK.Configuration.merge(%{})

      assert config.sampler ==
               {Otel.SDK.Trace.Sampler.TraceIdRatioBased, %{probability: 1.0}}
    end

    test "parentbased_always_on" do
      System.put_env("OTEL_TRACES_SAMPLER", "parentbased_always_on")
      config = Otel.SDK.Configuration.merge(%{})

      assert config.sampler ==
               {Otel.SDK.Trace.Sampler.ParentBased,
                %{root: {Otel.SDK.Trace.Sampler.AlwaysOn, %{}}}}
    end

    test "parentbased_always_off" do
      System.put_env("OTEL_TRACES_SAMPLER", "parentbased_always_off")
      config = Otel.SDK.Configuration.merge(%{})

      assert config.sampler ==
               {Otel.SDK.Trace.Sampler.ParentBased,
                %{root: {Otel.SDK.Trace.Sampler.AlwaysOff, %{}}}}
    end

    test "parentbased_traceidratio with arg" do
      System.put_env("OTEL_TRACES_SAMPLER", "parentbased_traceidratio")
      System.put_env("OTEL_TRACES_SAMPLER_ARG", "0.25")
      config = Otel.SDK.Configuration.merge(%{})

      assert config.sampler ==
               {Otel.SDK.Trace.Sampler.ParentBased,
                %{root: {Otel.SDK.Trace.Sampler.TraceIdRatioBased, %{probability: 0.25}}}}
    end

    test "case insensitive" do
      System.put_env("OTEL_TRACES_SAMPLER", "ALWAYS_OFF")
      config = Otel.SDK.Configuration.merge(%{})
      assert config.sampler == {Otel.SDK.Trace.Sampler.AlwaysOff, %{}}
    end

    test "env var overrides app config" do
      System.put_env("OTEL_TRACES_SAMPLER", "always_off")
      app = %{sampler: {Otel.SDK.Trace.Sampler.AlwaysOn, %{}}}
      config = Otel.SDK.Configuration.merge(app)
      assert config.sampler == {Otel.SDK.Trace.Sampler.AlwaysOff, %{}}
    end

    test "empty value treated as unset" do
      System.put_env("OTEL_TRACES_SAMPLER", "")
      config = Otel.SDK.Configuration.merge(%{})
      assert config.sampler == @default_config.sampler
    end

    test "unknown sampler name ignored" do
      System.put_env("OTEL_TRACES_SAMPLER", "unknown_sampler")
      config = Otel.SDK.Configuration.merge(%{})
      assert config.sampler == nil
    end

    test "traceidratio with invalid arg defaults to 1.0" do
      System.put_env("OTEL_TRACES_SAMPLER", "traceidratio")
      System.put_env("OTEL_TRACES_SAMPLER_ARG", "not_a_number")
      config = Otel.SDK.Configuration.merge(%{})

      assert config.sampler ==
               {Otel.SDK.Trace.Sampler.TraceIdRatioBased, %{probability: 1.0}}
    end
  end

  describe "OTEL_SPAN_* limits" do
    test "sets attribute_count_limit" do
      System.put_env("OTEL_SPAN_ATTRIBUTE_COUNT_LIMIT", "64")
      config = Otel.SDK.Configuration.merge(%{})
      assert config.span_limits.attribute_count_limit == 64
    end

    test "sets attribute_value_length_limit" do
      System.put_env("OTEL_SPAN_ATTRIBUTE_VALUE_LENGTH_LIMIT", "256")
      config = Otel.SDK.Configuration.merge(%{})
      assert config.span_limits.attribute_value_length_limit == 256
    end

    test "unparseable value_length_limit defaults to infinity" do
      System.put_env("OTEL_SPAN_ATTRIBUTE_VALUE_LENGTH_LIMIT", "none")
      config = Otel.SDK.Configuration.merge(%{})
      assert config.span_limits.attribute_value_length_limit == :infinity
    end

    test "sets event_count_limit" do
      System.put_env("OTEL_SPAN_EVENT_COUNT_LIMIT", "32")
      config = Otel.SDK.Configuration.merge(%{})
      assert config.span_limits.event_count_limit == 32
    end

    test "sets link_count_limit" do
      System.put_env("OTEL_SPAN_LINK_COUNT_LIMIT", "16")
      config = Otel.SDK.Configuration.merge(%{})
      assert config.span_limits.link_count_limit == 16
    end

    test "sets attribute_per_event_limit" do
      System.put_env("OTEL_EVENT_ATTRIBUTE_COUNT_LIMIT", "32")
      config = Otel.SDK.Configuration.merge(%{})
      assert config.span_limits.attribute_per_event_limit == 32
    end

    test "sets attribute_per_link_limit" do
      System.put_env("OTEL_LINK_ATTRIBUTE_COUNT_LIMIT", "32")
      config = Otel.SDK.Configuration.merge(%{})
      assert config.span_limits.attribute_per_link_limit == 32
    end

    test "empty span limit value treated as unset" do
      System.put_env("OTEL_SPAN_ATTRIBUTE_COUNT_LIMIT", "")
      config = Otel.SDK.Configuration.merge(%{})
      assert config.span_limits.attribute_count_limit == 128
    end

    test "unparseable span limit value defaults to 0" do
      System.put_env("OTEL_SPAN_ATTRIBUTE_COUNT_LIMIT", "not_a_number")
      config = Otel.SDK.Configuration.merge(%{})
      assert config.span_limits.attribute_count_limit == 0
    end

    test "preserves unset limits as defaults" do
      System.put_env("OTEL_SPAN_ATTRIBUTE_COUNT_LIMIT", "64")
      config = Otel.SDK.Configuration.merge(%{})
      assert config.span_limits.attribute_count_limit == 64
      assert config.span_limits.event_count_limit == 128
    end
  end
end
