## Task Workflow

When a user requests a task that involves code changes:

1. **Classify the task** — determine the type (`feat`, `fix`, `docs`, `refactor`, `test`, `chore`, `ci`) and scope by asking the user if unclear
2. **Create a branch** — `<type>/<short-description>` from `main` before making any changes
3. **Work on the task** — make changes, commit following git conventions
4. **Push and create PR** — push the branch and create a PR with the commit message body as the PR description

Skip this workflow for questions, exploration, or tasks that do not produce code changes.
