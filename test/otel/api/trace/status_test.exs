defmodule Otel.API.Trace.StatusTest do
  use ExUnit.Case, async: true

  test "default struct is :unset with empty description" do
    assert %Otel.API.Trace.Status{} == %Otel.API.Trace.Status{code: :unset, description: ""}
  end

  describe "new/2" do
    test ":error preserves the supplied description" do
      assert Otel.API.Trace.Status.new(:error, "something failed") ==
               %Otel.API.Trace.Status{code: :error, description: "something failed"}
    end

    test ":error defaults description to empty string" do
      assert Otel.API.Trace.Status.new(:error) ==
               %Otel.API.Trace.Status{code: :error, description: ""}
    end

    # Spec trace/api.md L599-L600: "Description MUST be IGNORED for
    # StatusCode Ok & Unset values."
    test ":ok and :unset discard any caller-supplied description" do
      assert Otel.API.Trace.Status.new(:ok, "ignored") ==
               %Otel.API.Trace.Status{code: :ok, description: ""}

      assert Otel.API.Trace.Status.new(:unset, "ignored") ==
               %Otel.API.Trace.Status{code: :unset, description: ""}
    end

    test ":ok and :unset default to empty description" do
      assert Otel.API.Trace.Status.new(:ok) == %Otel.API.Trace.Status{code: :ok}
      assert Otel.API.Trace.Status.new(:unset) == %Otel.API.Trace.Status{code: :unset}
    end
  end
end
