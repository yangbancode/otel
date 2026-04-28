{:ok, _} = Application.ensure_all_started(:otel)
ExUnit.start()
