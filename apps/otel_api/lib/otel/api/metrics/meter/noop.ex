defmodule Otel.API.Metrics.Meter.Noop do
  @moduledoc """
  No-op Meter implementation.

  Used when no SDK is installed. All instrument creation returns `:ok`,
  and `enabled?` returns `false`.

  All functions are safe for concurrent use.
  """

  @behaviour Otel.API.Metrics.Meter

  @impl true
  def create_counter(_meter, _name, _opts), do: :ok

  @impl true
  def create_histogram(_meter, _name, _opts), do: :ok

  @impl true
  def create_gauge(_meter, _name, _opts), do: :ok

  @impl true
  def create_updown_counter(_meter, _name, _opts), do: :ok

  @impl true
  def create_observable_counter(_meter, _name, _opts), do: :ok

  @impl true
  def create_observable_gauge(_meter, _name, _opts), do: :ok

  @impl true
  def create_observable_updown_counter(_meter, _name, _opts), do: :ok

  @impl true
  def register_callback(_meter, _instruments, _callback, _callback_args, _opts), do: :ok

  @impl true
  def enabled?(_meter, _opts), do: false
end
