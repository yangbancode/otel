defmodule Otel.SemanticConventions.Attributes.UserAgent do
  # This is an auto-generated file
  @moduledoc """
  OpenTelemetry Semantic Conventions for User_Agent attributes.
  """

  @doc """
  Value of the [HTTP User-Agent](https://www.rfc-editor.org/rfc/rfc9110.html#field.user-agent) header sent by the client.

      iex> Otel.SemanticConventions.Attributes.UserAgent.user_agent_original()
      "user_agent.original"
  """
  @spec user_agent_original :: String.t()
  def user_agent_original do
    "user_agent.original"
  end
end
