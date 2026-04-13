# Start SpanStorage once for all tests.
# GenServer owns the ETS table — if it dies, the table is lost.
# Starting here prevents table disappearance between test files.
{:ok, _} = Otel.SDK.Trace.SpanStorage.start_link()

ExUnit.start()
