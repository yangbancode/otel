defmodule Otel.API.Trace.StatusTest do
  use ExUnit.Case, async: true

  describe "new/1,2" do
    test "creates an unset status with empty description" do
      status = Otel.API.Trace.Status.new(:unset)

      assert status.code == :unset
      assert status.description == ""
    end

    test "creates an ok status" do
      status = Otel.API.Trace.Status.new(:ok)

      assert status.code == :ok
      assert status.description == ""
    end

    test "creates an error status with description" do
      status = Otel.API.Trace.Status.new(:error, "something failed")

      assert status.code == :error
      assert status.description == "something failed"
    end

    test "description defaults to empty string" do
      status = Otel.API.Trace.Status.new(:error)
      assert status.description == ""
    end

    test ":ok discards description per spec L599-L600 MUST IGNORE" do
      status = Otel.API.Trace.Status.new(:ok, "should be ignored")

      assert status.code == :ok
      assert status.description == ""
    end

    test ":unset discards description per spec L599-L600 MUST IGNORE" do
      status = Otel.API.Trace.Status.new(:unset, "should be ignored")

      assert status.code == :unset
      assert status.description == ""
    end
  end

  describe "struct defaults" do
    test "default struct is unset with empty description" do
      status = %Otel.API.Trace.Status{}

      assert status.code == :unset
      assert status.description == ""
    end
  end
end
