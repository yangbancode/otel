defmodule Otel.SemanticConventions.Metrics.JVM do
  # This is an auto-generated file
  @moduledoc """
  OpenTelemetry Semantic Conventions for JVM metrics.
  """

  @doc """
  Number of classes currently loaded.

  Instrument: `updowncounter`
  Unit: `{class}`

      iex> Otel.SemanticConventions.Metrics.JVM.jvm_class_count()
      "jvm.class.count"
  """
  @spec jvm_class_count :: String.t()
  def jvm_class_count do
    "jvm.class.count"
  end

  @doc """
  Number of classes loaded since JVM start.

  Instrument: `counter`
  Unit: `{class}`

      iex> Otel.SemanticConventions.Metrics.JVM.jvm_class_loaded()
      "jvm.class.loaded"
  """
  @spec jvm_class_loaded :: String.t()
  def jvm_class_loaded do
    "jvm.class.loaded"
  end

  @doc """
  Number of classes unloaded since JVM start.

  Instrument: `counter`
  Unit: `{class}`

      iex> Otel.SemanticConventions.Metrics.JVM.jvm_class_unloaded()
      "jvm.class.unloaded"
  """
  @spec jvm_class_unloaded :: String.t()
  def jvm_class_unloaded do
    "jvm.class.unloaded"
  end

  @doc """
  Number of processors available to the Java virtual machine.

  Instrument: `updowncounter`
  Unit: `{cpu}`

      iex> Otel.SemanticConventions.Metrics.JVM.jvm_cpu_count()
      "jvm.cpu.count"
  """
  @spec jvm_cpu_count :: String.t()
  def jvm_cpu_count do
    "jvm.cpu.count"
  end

  @doc """
  Recent CPU utilization for the process as reported by the JVM.

  Instrument: `gauge`
  Unit: `1`

      iex> Otel.SemanticConventions.Metrics.JVM.jvm_cpu_recent_utilization()
      "jvm.cpu.recent_utilization"
  """
  @spec jvm_cpu_recent_utilization :: String.t()
  def jvm_cpu_recent_utilization do
    "jvm.cpu.recent_utilization"
  end

  @doc """
  CPU time used by the process as reported by the JVM.

  Instrument: `counter`
  Unit: `s`

      iex> Otel.SemanticConventions.Metrics.JVM.jvm_cpu_time()
      "jvm.cpu.time"
  """
  @spec jvm_cpu_time :: String.t()
  def jvm_cpu_time do
    "jvm.cpu.time"
  end

  @doc """
  Duration of JVM garbage collection actions.

  Instrument: `histogram`
  Unit: `s`

      iex> Otel.SemanticConventions.Metrics.JVM.jvm_gc_duration()
      "jvm.gc.duration"
  """
  @spec jvm_gc_duration :: String.t()
  def jvm_gc_duration do
    "jvm.gc.duration"
  end

  @doc """
  Measure of memory committed.

  Instrument: `updowncounter`
  Unit: `By`

      iex> Otel.SemanticConventions.Metrics.JVM.jvm_memory_committed()
      "jvm.memory.committed"
  """
  @spec jvm_memory_committed :: String.t()
  def jvm_memory_committed do
    "jvm.memory.committed"
  end

  @doc """
  Measure of max obtainable memory.

  Instrument: `updowncounter`
  Unit: `By`

      iex> Otel.SemanticConventions.Metrics.JVM.jvm_memory_limit()
      "jvm.memory.limit"
  """
  @spec jvm_memory_limit :: String.t()
  def jvm_memory_limit do
    "jvm.memory.limit"
  end

  @doc """
  Measure of memory used.

  Instrument: `updowncounter`
  Unit: `By`

      iex> Otel.SemanticConventions.Metrics.JVM.jvm_memory_used()
      "jvm.memory.used"
  """
  @spec jvm_memory_used :: String.t()
  def jvm_memory_used do
    "jvm.memory.used"
  end

  @doc """
  Measure of memory used, as measured after the most recent garbage collection event on this pool.

  Instrument: `updowncounter`
  Unit: `By`

      iex> Otel.SemanticConventions.Metrics.JVM.jvm_memory_used_after_last_gc()
      "jvm.memory.used_after_last_gc"
  """
  @spec jvm_memory_used_after_last_gc :: String.t()
  def jvm_memory_used_after_last_gc do
    "jvm.memory.used_after_last_gc"
  end

  @doc """
  Number of executing platform threads.

  Instrument: `updowncounter`
  Unit: `{thread}`

      iex> Otel.SemanticConventions.Metrics.JVM.jvm_thread_count()
      "jvm.thread.count"
  """
  @spec jvm_thread_count :: String.t()
  def jvm_thread_count do
    "jvm.thread.count"
  end
end
