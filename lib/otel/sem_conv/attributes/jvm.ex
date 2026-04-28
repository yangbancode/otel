defmodule Otel.SemConv.Attributes.JVM do
  # This is an auto-generated file
  @moduledoc """
  OpenTelemetry Semantic Conventions for JVM attributes.
  """

  @doc """
  Name of the garbage collector action.

      iex> Otel.SemConv.Attributes.JVM.jvm_gc_action()
      "jvm.gc.action"
  """
  @spec jvm_gc_action :: String.t()
  def jvm_gc_action do
    "jvm.gc.action"
  end

  @doc """
  Name of the garbage collector.

      iex> Otel.SemConv.Attributes.JVM.jvm_gc_name()
      "jvm.gc.name"
  """
  @spec jvm_gc_name :: String.t()
  def jvm_gc_name do
    "jvm.gc.name"
  end

  @doc """
  Name of the memory pool.

      iex> Otel.SemConv.Attributes.JVM.jvm_memory_pool_name()
      "jvm.memory.pool.name"
  """
  @spec jvm_memory_pool_name :: String.t()
  def jvm_memory_pool_name do
    "jvm.memory.pool.name"
  end

  @typedoc """
  The type of memory.
  """
  @type jvm_memory_type_values :: %{
          :heap => String.t(),
          :non_heap => String.t()
        }

  @doc """
  The type of memory.

      iex> Otel.SemConv.Attributes.JVM.jvm_memory_type()
      "jvm.memory.type"
  """
  @spec jvm_memory_type :: String.t()
  def jvm_memory_type do
    "jvm.memory.type"
  end

  @doc """
  Enum values for `jvm_memory_type`.

      iex> Otel.SemConv.Attributes.JVM.jvm_memory_type_values()[:heap]
      "heap"
  """
  @spec jvm_memory_type_values :: jvm_memory_type_values()
  def jvm_memory_type_values do
    %{
      :heap => "heap",
      :non_heap => "non_heap"
    }
  end

  @doc """
  Whether the thread is daemon or not.

      iex> Otel.SemConv.Attributes.JVM.jvm_thread_daemon()
      "jvm.thread.daemon"
  """
  @spec jvm_thread_daemon :: String.t()
  def jvm_thread_daemon do
    "jvm.thread.daemon"
  end

  @typedoc """
  State of the thread.
  """
  @type jvm_thread_state_values :: %{
          :new => String.t(),
          :runnable => String.t(),
          :blocked => String.t(),
          :waiting => String.t(),
          :timed_waiting => String.t(),
          :terminated => String.t()
        }

  @doc """
  State of the thread.

      iex> Otel.SemConv.Attributes.JVM.jvm_thread_state()
      "jvm.thread.state"
  """
  @spec jvm_thread_state :: String.t()
  def jvm_thread_state do
    "jvm.thread.state"
  end

  @doc """
  Enum values for `jvm_thread_state`.

      iex> Otel.SemConv.Attributes.JVM.jvm_thread_state_values()[:new]
      "new"
  """
  @spec jvm_thread_state_values :: jvm_thread_state_values()
  def jvm_thread_state_values do
    %{
      :new => "new",
      :runnable => "runnable",
      :blocked => "blocked",
      :waiting => "waiting",
      :timed_waiting => "timed_waiting",
      :terminated => "terminated"
    }
  end
end
