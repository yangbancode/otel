## Task Workflow

When a user requests a task that involves code changes:

1. **Classify the task** — determine the type (`feat`, `fix`, `docs`, `refactor`, `test`, `chore`, `ci`) and scope by asking the user if unclear
2. **Create a branch** — `<type>/<short-description>` from `main` before making any changes
3. **Research** — read the OTel spec (`references/opentelemetry-specification/`) and the erlang reference (`references/opentelemetry-erlang/`) together
4. **Implement** — write code and tests based on spec + erlang reference. Apply all available config/limits/features from prior decisions immediately — do not defer to "next decision"
5. **Code conventions** — verify against `.claude/rules/code-conventions.md`:
   - No alias: full module names only
   - `@spec` with parameter names on all `def` and `defp`
6. **Spec verification** — run parallel AI Agents to verify implementation against the official OTel spec. Fix any gaps found
7. **Quality checks** — run in order:
   - `mix format --check-formatted`
   - `mix compile --warnings-as-errors`
   - `mix test --warnings-as-errors --cover` (100% threshold)
   - `mix credo --strict`
   - `mix dialyzer`
8. **Update docs** — update Decision document, Compliance checkboxes, and `decisions.md` checkboxes
9. **Push and create PR** — push the branch and create a PR following git conventions

Skip this workflow for questions, exploration, or tasks that do not produce code changes.
