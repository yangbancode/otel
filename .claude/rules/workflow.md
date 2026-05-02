## Spec sources — references-only

**Spec checks must come from the local `references/` submodules.
Never use AI training-data knowledge of the spec.**

The OTel spec, W3C documents, OTLP proto, and semantic conventions
all evolve frequently — sometimes monthly. Anything you "know" about
how OTel works that is not in `references/` is at best out of date
and at worst flatly wrong. The training cutoff of any AI assistant
is months behind the live spec.

Concrete rules for every spec-related step:

- **Open the file.** Don't paraphrase from memory; quote the actual
  text in `references/<spec>/...`.
- **Check the pin.** `git -C references/opentelemetry-specification
  describe --tags HEAD` tells you what version is authoritative for
  this checkout. Different developers / different times may see
  different text — the pin is the truth.
- **Don't assume cross-language SDK conventions are spec.** Java's
  narrow `AttributeKey<T>` or Go's strongly-typed attributes are SDK
  choices, not necessarily what the OTel spec mandates. Confirm in
  the spec file.
- **Don't trust your prior verifications.** A passed review is valid
  only against the spec version it ran on. After a submodule
  advance, prior conclusions can silently become stale (PR #304/#305
  + cleanup PR caught LogRecord attribute drift caused exactly by
  this — see "Spec submodule update" below).

This rule applies to everything in this repo that cites a spec —
moduledocs, function docs, comments, commit messages, PR bodies,
sub-agent prompts, code review responses.

## Task Workflow

When a user requests a task that involves code changes:

1. **Classify the task** — determine the type (`feat`, `fix`, `docs`, `refactor`, `test`, `chore`, `ci`) and scope by asking the user if unclear
2. **Create a branch** — `<type>/<short-description>` from `main` before making any changes
3. **Research** — read the relevant specs together with the erlang reference (`references/opentelemetry-erlang/`):
   - OTel Specification — `references/opentelemetry-specification/`
   - W3C Trace Context — `references/w3c-trace-context/` (wire format for `traceparent` / `tracestate`)
   - W3C Baggage — `references/w3c-baggage/` (wire format for `baggage`)
   - OTLP Proto — `references/opentelemetry-proto/`

   Per the references-only rule above: the spec text you act on
   MUST come from these files, not from training data.
4. **Implement** — write code and tests based on spec + erlang reference. Apply all available config/limits/features from prior decisions immediately — do not defer to "next decision"
5. **Code conventions** — verify against `.claude/rules/code-conventions.md`:
   - No alias: full module names only
   - `@spec` with parameter names on all `def` and `defp`
6. **Spec verification** — run parallel AI Agents to verify implementation against the official OTel spec. Sub-agent prompts MUST instruct the agent to verify only against `references/`, not training data, and to record the spec submodule pin. Fix any gaps found.
7. **Quality checks** — run `mix clean` first to clear compile cache, then run in order:
   - `mix format --check-formatted`
   - `mix compile --warnings-as-errors`
   - `mix test --warnings-as-errors --cover` (100% threshold)
   - `mix credo --strict`
   - `mix dialyzer`
8. **Update docs** — if the change touches an architectural decision, update or add a doc under `.claude/docs/architecture/`. Otherwise update the affected module's `@moduledoc` so the rationale stays with the code. For spec-aligned modules, include a `## Spec verification` line recording the submodule pin (see `.claude/skills/spec-module-review/SKILL.md` § Workflow integration step 7).
9. **Push and create PR** — push the branch and create a PR following git conventions

Skip this workflow for questions, exploration, or tasks that do not produce code changes.

## Spec submodule update

When the `references/<spec>` submodule pin moves (intentionally,
e.g. to pull in newer spec text), spec-aligned modules verified
against the prior pin can silently become stale — a "Pattern D"
drift in spec-module-review terms. Treat the submodule update
itself as a multi-PR sequence:

### 1. Submodule advance PR

Bump the pin in a single isolated commit. PR body MUST list the
diff summary so a reviewer (or future you) can see what changed:

```bash
cd references/opentelemetry-specification
PREV=$(git describe --tags 'HEAD@{1}' 2>/dev/null || git log -2 --format=%H | tail -1)
git log --oneline $PREV..HEAD
git log $PREV..HEAD CHANGELOG.md
```

Quote the CHANGELOG diff verbatim in the PR body. Do not
modify any application code in this PR.

### 2. Affected-modules sweep

After the submodule PR merges, identify which modules cite areas
the CHANGELOG diff touched. For each section heading in the
diff (e.g. "Logs", "Common", "Traces"), grep the codebase:

```bash
# example for Logs changes
rg -l 'logs/sdk\.md|logs/api\.md|logs/data-model\.md' apps/*/lib
```

Open each match and re-run `spec-module-review` Phase 1 against
the new pin. The CHANGELOG entries you read in step 1 are the
list of things that may have flipped since the prior verification.

### 3. Re-verification PRs

Each affected module gets a separate PR closing whatever drift
the new spec text exposed. Commit body MUST record the new pin
per `spec-module-review` SKILL § Workflow integration step 7.

### Why this is its own workflow

A submodule advance can silently invalidate dozens of moduledoc
claims and `@type` definitions at once. Without a structured
sweep, those drifts surface only when an unrelated review or a
user-initiated audit happens to touch the affected area — possibly
months later, with multiple intervening "verifications" still
asserting the old (no-longer-current) shape. The LogRecord
attribute saga (PRs #304/#305 plus cleanup) is the canonical
cautionary tale.

## AI Model Usage

- Main model: **Opus 4.7 (1M context)**
- Sub-agents (research, verification, exploration): **Opus 4.7** — use `model: "opus"` parameter on Agent calls
