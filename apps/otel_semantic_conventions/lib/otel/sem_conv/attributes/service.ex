defmodule Otel.SemConv.Attributes.Service do
  # This is an auto-generated file
  @moduledoc """
  OpenTelemetry Semantic Conventions for Service attributes.
  """

  @doc """
  The string ID of the service instance.

      iex> Otel.SemConv.Attributes.Service.service_instance_id()
      :"service.instance.id"
  """
  @spec service_instance_id :: :"service.instance.id"
  def service_instance_id do
    :"service.instance.id"
  end

  @doc """
  Logical name of the service.

      iex> Otel.SemConv.Attributes.Service.service_name()
      :"service.name"
  """
  @spec service_name :: :"service.name"
  def service_name do
    :"service.name"
  end

  @doc """
  A namespace for `service.name`.

      iex> Otel.SemConv.Attributes.Service.service_namespace()
      :"service.namespace"
  """
  @spec service_namespace :: :"service.namespace"
  def service_namespace do
    :"service.namespace"
  end

  @doc """
  The version string of the service component. The format is not defined by these conventions.

      iex> Otel.SemConv.Attributes.Service.service_version()
      :"service.version"
  """
  @spec service_version :: :"service.version"
  def service_version do
    :"service.version"
  end
end
