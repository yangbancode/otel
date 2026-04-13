defmodule Otel.SDK.Trace.SpanStorage do
  @moduledoc """
  ETS-backed storage for active spans.

  A GenServer that owns the ETS table. The table is `public` with
  `write_concurrency` and `read_concurrency` so any process can
  read/write spans without going through this server.
  """

  use GenServer

  @table_name :otel_span_table

  # --- Client API ---

  @spec start_link(opts :: keyword()) :: GenServer.on_start()
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Inserts a span into the table.
  """
  @spec insert(span :: Otel.SDK.Trace.Span.t()) :: true
  def insert(span) do
    :ets.insert(@table_name, {span.span_id, span})
  end

  @doc """
  Looks up a span by span_id.
  """
  @spec get(span_id :: non_neg_integer()) :: Otel.SDK.Trace.Span.t() | nil
  def get(span_id) do
    case :ets.lookup(@table_name, span_id) do
      [{^span_id, span}] -> span
      [] -> nil
    end
  end

  @doc """
  Removes and returns a span by span_id.
  """
  @spec take(span_id :: non_neg_integer()) :: Otel.SDK.Trace.Span.t() | nil
  def take(span_id) do
    case :ets.take(@table_name, span_id) do
      [{^span_id, span}] -> span
      [] -> nil
    end
  end

  @doc """
  Returns the ETS table name.
  """
  @spec table_name() :: atom()
  def table_name, do: @table_name

  # --- Server Callbacks ---

  @impl true
  def init(_opts) do
    table =
      :ets.new(@table_name, [
        :named_table,
        :public,
        :set,
        {:write_concurrency, true},
        {:read_concurrency, true}
      ])

    {:ok, %{table: table}}
  end
end
