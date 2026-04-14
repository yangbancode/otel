defmodule Otel.SDK.Metrics.Meter do
  @moduledoc """
  SDK implementation of the Meter behaviour.

  Placeholder that returns `:ok` for all operations. Actual instrument
  registration, measurement recording, and view processing will be
  added in subsequent decisions.

  All functions are safe for concurrent use.
  """

  @behaviour Otel.API.Metrics.Meter

  # --- Synchronous Instruments ---

  @impl true
  def create_counter(_meter, _name, _opts), do: :ok

  @impl true
  def create_histogram(_meter, _name, _opts), do: :ok

  @impl true
  def create_gauge(_meter, _name, _opts), do: :ok

  @impl true
  def create_updown_counter(_meter, _name, _opts), do: :ok

  # --- Asynchronous Instruments ---

  @impl true
  def create_observable_counter(_meter, _name, _opts), do: :ok

  @impl true
  def create_observable_counter(_meter, _name, _callback, _callback_args, _opts), do: :ok

  @impl true
  def create_observable_gauge(_meter, _name, _opts), do: :ok

  @impl true
  def create_observable_gauge(_meter, _name, _callback, _callback_args, _opts), do: :ok

  @impl true
  def create_observable_updown_counter(_meter, _name, _opts), do: :ok

  @impl true
  def create_observable_updown_counter(_meter, _name, _callback, _callback_args, _opts), do: :ok

  # --- Recording ---

  @impl true
  def record(_meter, _name, _value, _attributes), do: :ok

  # --- Callback Registration ---

  @impl true
  def register_callback(_meter, _instruments, _callback, _callback_args, _opts), do: :ok

  # --- Enabled ---

  @impl true
  def enabled?(_meter, _opts), do: true
end
