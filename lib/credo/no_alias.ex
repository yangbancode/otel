defmodule Credo.Check.Warning.NoAlias do
  use Credo.Check,
    base_priority: :high,
    category: :warning,
    explanations: [
      check: """
      `alias` is not allowed in this project. Use full module names instead.

      This keeps module references explicit and unambiguous across the
      entire codebase.

      # Not allowed
      alias Otel.API.Trace.SpanContext
      SpanContext.new(...)

      # Use instead
      Otel.API.Trace.SpanContext.new(...)
      """
    ]

  @impl true
  def run(%SourceFile{} = source_file, params) do
    issue_meta = IssueMeta.for(source_file, params)

    source_file
    |> Credo.Code.prewalk(&traverse(&1, &2, issue_meta))
    |> Enum.reverse()
  end

  defp traverse({:alias, meta, _args} = ast, issues, issue_meta) do
    issue = issue_for(issue_meta, meta[:line])
    {ast, [issue | issues]}
  end

  defp traverse(ast, issues, _issue_meta) do
    {ast, issues}
  end

  defp issue_for(issue_meta, line_no) do
    format_issue(issue_meta,
      message: "`alias` is not allowed. Use the full module name instead.",
      line_no: line_no
    )
  end
end
