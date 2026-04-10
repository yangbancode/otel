## Task Workflow

When a user requests a task that involves code changes:

1. **Classify the task** — determine the type (`feat`, `fix`, `docs`, `refactor`, `test`, `chore`, `ci`) and scope by asking the user if unclear
2. **Create a branch** — `<type>/<short-description>` from `main` before making any changes
3. **Research** — read the OTel spec (`docs/references/opentelemetry-specification/`) and the erlang reference (`/tmp/opentelemetry-erlang`) together
4. **Implement** — write code and tests based on spec + erlang reference
5. **Spec verification** — run parallel AI Agents to verify implementation against the official OTel spec. Fix any gaps found
6. **Quality checks** — run in order:
   - `mix format --check-formatted`
   - `mix compile --warnings-as-errors`
   - `mix test --cover` (100% threshold)
   - `mix credo --strict`
   - `mix dialyzer`
7. **Update docs** — update Decision document, Compliance checkboxes, and `decisions.md` checkboxes
8. **Push and create PR** — push the branch and create a PR following git conventions

Skip this workflow for questions, exploration, or tasks that do not produce code changes.
