defmodule Otel.ConfigTest do
  use ExUnit.Case, async: true

  test "module is loaded as part of the umbrella" do
    # Smoke test for the scaffold PR — the implementation lands in
    # follow-up PRs (see `Otel.Config` moduledoc roadmap).
    assert Code.ensure_loaded?(Otel.Config)
  end
end
