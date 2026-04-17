defmodule Otel.SemConv.Metrics.DotNet do
  # This is an auto-generated file
  @moduledoc """
  OpenTelemetry Semantic Conventions for DotNet metrics.
  """

  @doc """
  The number of .NET assemblies that are currently loaded.

  Instrument: `updowncounter`
  Unit: `{assembly}`

      iex> Otel.SemConv.Metrics.DotNet.dotnet_assembly_count()
      "dotnet.assembly.count"
  """
  @spec dotnet_assembly_count :: String.t()
  def dotnet_assembly_count do
    "dotnet.assembly.count"
  end

  @doc """
  The number of exceptions that have been thrown in managed code.

  Instrument: `counter`
  Unit: `{exception}`

      iex> Otel.SemConv.Metrics.DotNet.dotnet_exceptions()
      "dotnet.exceptions"
  """
  @spec dotnet_exceptions :: String.t()
  def dotnet_exceptions do
    "dotnet.exceptions"
  end

  @doc """
  The number of garbage collections that have occurred since the process has started.

  Instrument: `counter`
  Unit: `{collection}`

      iex> Otel.SemConv.Metrics.DotNet.dotnet_gc_collections()
      "dotnet.gc.collections"
  """
  @spec dotnet_gc_collections :: String.t()
  def dotnet_gc_collections do
    "dotnet.gc.collections"
  end

  @doc """
  The _approximate_ number of bytes allocated on the managed GC heap since the process has started. The returned value does not include any native allocations.

  Instrument: `counter`
  Unit: `By`

      iex> Otel.SemConv.Metrics.DotNet.dotnet_gc_heap_total_allocated()
      "dotnet.gc.heap.total_allocated"
  """
  @spec dotnet_gc_heap_total_allocated :: String.t()
  def dotnet_gc_heap_total_allocated do
    "dotnet.gc.heap.total_allocated"
  end

  @doc """
  The heap fragmentation, as observed during the latest garbage collection.

  Instrument: `updowncounter`
  Unit: `By`

      iex> Otel.SemConv.Metrics.DotNet.dotnet_gc_last_collection_heap_fragmentation_size()
      "dotnet.gc.last_collection.heap.fragmentation.size"
  """
  @spec dotnet_gc_last_collection_heap_fragmentation_size :: String.t()
  def dotnet_gc_last_collection_heap_fragmentation_size do
    "dotnet.gc.last_collection.heap.fragmentation.size"
  end

  @doc """
  The managed GC heap size (including fragmentation), as observed during the latest garbage collection.

  Instrument: `updowncounter`
  Unit: `By`

      iex> Otel.SemConv.Metrics.DotNet.dotnet_gc_last_collection_heap_size()
      "dotnet.gc.last_collection.heap.size"
  """
  @spec dotnet_gc_last_collection_heap_size :: String.t()
  def dotnet_gc_last_collection_heap_size do
    "dotnet.gc.last_collection.heap.size"
  end

  @doc """
  The amount of committed virtual memory in use by the .NET GC, as observed during the latest garbage collection.

  Instrument: `updowncounter`
  Unit: `By`

      iex> Otel.SemConv.Metrics.DotNet.dotnet_gc_last_collection_memory_committed_size()
      "dotnet.gc.last_collection.memory.committed_size"
  """
  @spec dotnet_gc_last_collection_memory_committed_size :: String.t()
  def dotnet_gc_last_collection_memory_committed_size do
    "dotnet.gc.last_collection.memory.committed_size"
  end

  @doc """
  The total amount of time paused in GC since the process has started.

  Instrument: `counter`
  Unit: `s`

      iex> Otel.SemConv.Metrics.DotNet.dotnet_gc_pause_time()
      "dotnet.gc.pause.time"
  """
  @spec dotnet_gc_pause_time :: String.t()
  def dotnet_gc_pause_time do
    "dotnet.gc.pause.time"
  end

  @doc """
  The amount of time the JIT compiler has spent compiling methods since the process has started.

  Instrument: `counter`
  Unit: `s`

      iex> Otel.SemConv.Metrics.DotNet.dotnet_jit_compilation_time()
      "dotnet.jit.compilation.time"
  """
  @spec dotnet_jit_compilation_time :: String.t()
  def dotnet_jit_compilation_time do
    "dotnet.jit.compilation.time"
  end

  @doc """
  Count of bytes of intermediate language that have been compiled since the process has started.

  Instrument: `counter`
  Unit: `By`

      iex> Otel.SemConv.Metrics.DotNet.dotnet_jit_compiled_il_size()
      "dotnet.jit.compiled_il.size"
  """
  @spec dotnet_jit_compiled_il_size :: String.t()
  def dotnet_jit_compiled_il_size do
    "dotnet.jit.compiled_il.size"
  end

  @doc """
  The number of times the JIT compiler (re)compiled methods since the process has started.

  Instrument: `counter`
  Unit: `{method}`

      iex> Otel.SemConv.Metrics.DotNet.dotnet_jit_compiled_methods()
      "dotnet.jit.compiled_methods"
  """
  @spec dotnet_jit_compiled_methods :: String.t()
  def dotnet_jit_compiled_methods do
    "dotnet.jit.compiled_methods"
  end

  @doc """
  The number of times there was contention when trying to acquire a monitor lock since the process has started.

  Instrument: `counter`
  Unit: `{contention}`

      iex> Otel.SemConv.Metrics.DotNet.dotnet_monitor_lock_contentions()
      "dotnet.monitor.lock_contentions"
  """
  @spec dotnet_monitor_lock_contentions :: String.t()
  def dotnet_monitor_lock_contentions do
    "dotnet.monitor.lock_contentions"
  end

  @doc """
  The number of processors available to the process.

  Instrument: `updowncounter`
  Unit: `{cpu}`

      iex> Otel.SemConv.Metrics.DotNet.dotnet_process_cpu_count()
      "dotnet.process.cpu.count"
  """
  @spec dotnet_process_cpu_count :: String.t()
  def dotnet_process_cpu_count do
    "dotnet.process.cpu.count"
  end

  @doc """
  CPU time used by the process.

  Instrument: `counter`
  Unit: `s`

      iex> Otel.SemConv.Metrics.DotNet.dotnet_process_cpu_time()
      "dotnet.process.cpu.time"
  """
  @spec dotnet_process_cpu_time :: String.t()
  def dotnet_process_cpu_time do
    "dotnet.process.cpu.time"
  end

  @doc """
  The number of bytes of physical memory mapped to the process context.

  Instrument: `updowncounter`
  Unit: `By`

      iex> Otel.SemConv.Metrics.DotNet.dotnet_process_memory_working_set()
      "dotnet.process.memory.working_set"
  """
  @spec dotnet_process_memory_working_set :: String.t()
  def dotnet_process_memory_working_set do
    "dotnet.process.memory.working_set"
  end

  @doc """
  The number of work items that are currently queued to be processed by the thread pool.

  Instrument: `updowncounter`
  Unit: `{work_item}`

      iex> Otel.SemConv.Metrics.DotNet.dotnet_thread_pool_queue_length()
      "dotnet.thread_pool.queue.length"
  """
  @spec dotnet_thread_pool_queue_length :: String.t()
  def dotnet_thread_pool_queue_length do
    "dotnet.thread_pool.queue.length"
  end

  @doc """
  The number of thread pool threads that currently exist.

  Instrument: `updowncounter`
  Unit: `{thread}`

      iex> Otel.SemConv.Metrics.DotNet.dotnet_thread_pool_thread_count()
      "dotnet.thread_pool.thread.count"
  """
  @spec dotnet_thread_pool_thread_count :: String.t()
  def dotnet_thread_pool_thread_count do
    "dotnet.thread_pool.thread.count"
  end

  @doc """
  The number of work items that the thread pool has completed since the process has started.

  Instrument: `counter`
  Unit: `{work_item}`

      iex> Otel.SemConv.Metrics.DotNet.dotnet_thread_pool_work_item_count()
      "dotnet.thread_pool.work_item.count"
  """
  @spec dotnet_thread_pool_work_item_count :: String.t()
  def dotnet_thread_pool_work_item_count do
    "dotnet.thread_pool.work_item.count"
  end

  @doc """
  The number of timer instances that are currently active.

  Instrument: `updowncounter`
  Unit: `{timer}`

      iex> Otel.SemConv.Metrics.DotNet.dotnet_timer_count()
      "dotnet.timer.count"
  """
  @spec dotnet_timer_count :: String.t()
  def dotnet_timer_count do
    "dotnet.timer.count"
  end
end
