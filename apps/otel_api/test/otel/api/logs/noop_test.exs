defmodule Otel.API.Logs.NoopTest do
  use ExUnit.Case, async: true

  @noop {Otel.API.Logs.Logger.Noop, []}

  describe "Noop Logger" do
    test "emit returns :ok" do
      ctx = Otel.API.Ctx.get_current()

      assert :ok ==
               Otel.API.Logs.Logger.Noop.emit(@noop, ctx, %{
                 body: Otel.API.Common.AnyValue.string("test")
               })
    end

    test "enabled? returns false" do
      assert false == Otel.API.Logs.Logger.Noop.enabled?(@noop, [])
    end

    test "emit accepts any log record fields" do
      ctx = Otel.API.Ctx.get_current()

      assert :ok ==
               Otel.API.Logs.Logger.Noop.emit(@noop, ctx, %{
                 timestamp: 1_000_000,
                 observed_timestamp: 1_000_000,
                 severity_number: 9,
                 severity_text: "INFO",
                 body:
                   Otel.API.Common.AnyValue.kvlist(%{
                     "nested" => Otel.API.Common.AnyValue.string("value")
                   }),
                 attributes: [
                   Otel.API.Common.Attribute.new("key", Otel.API.Common.AnyValue.string("val"))
                 ],
                 event_name: "my.event"
               })
    end
  end
end
