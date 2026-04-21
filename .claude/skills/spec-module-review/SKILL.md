---
name: spec-module-review
description: Review methodology for modules implementing a published specification (OTel, W3C, RFC, OTLP, Semantic Conventions). Apply whenever the user asks to review, audit, verify, refactor, or check spec-compliance of a file citing specifications — docstrings with section references like `§3.3.1.3.1` or `spec §3.3`, module paths under `apps/otel_api/lib/otel/api/`, or comments referencing specs under `references/`. Also triggers for requests like "verify citations", "find spec gaps", "check spec compliance", "is this aligned with the spec", or plain "review this file" when the file is spec-aligned. Use this even when the user doesn't explicitly say "review" — any task cross-checking code against a published specification qualifies.
---

# spec-module-review

Review methodology for otel modules implementing published specifications.
Distilled from the `Otel.API.Trace.TraceState` review (PRs #155–#159), where
multiple fake citations, hidden spec gaps, and bogus logic were found in
code that had already passed normal review.

## When this skill applies

Any review of a module that cites a published specification. Signals:
- `@doc` / `@moduledoc` with section numbers like `§3.3.1.3.1`
- Module path under `apps/otel_api/lib/otel/api/` (OTel API surface)
- Constants with spec-path comments (e.g. `# W3C §3.3.1.1: ...`)
- `references/` submodules present (`opentelemetry-specification`,
  `w3c-trace-context`, `w3c-baggage`, `opentelemetry-erlang`, etc.)

## Operating principle

**Verify with primary sources. Never trust a citation because it sounds
right.** Three of the fake citations caught in the tracestate review
looked entirely plausible until the actual spec file was opened. Keep
the referenced spec file open in parallel while reviewing any section
that claims alignment.

Memory is unreliable for spec text. Section numbers drift between spec
versions. Paraphrases invert meaning. Only the file under `references/`
is authoritative.

## The four phases

Work through the four phases in order. Later phases depend on the
foundation laid by earlier ones — simplification (Phase 2) is unsafe
until spec alignment (Phase 1) is confirmed.

---

## Phase 1 — Spec alignment verification

Ensure every claim the code makes about the spec is true.

### 1.1 Fake citation detection

For each spec citation in docstrings, comments, or commit messages, open
the cited spec file under `references/` and read the actual section.
Flag any of these patterns:

- Citation points to a section that doesn't define the claimed behaviour
- Citation paraphrases spec language but inverts meaning
  (SHOULD → MUST, minimum → maximum, propagate → reject,
  characters → bytes)
- Citation is a direct quote that doesn't appear in the spec

**Real examples from this project:**

| Claim | Reality |
|---|---|
| `"parser MUST discard whole"` | No such sentence exists in W3C Trace Context |
| `"the header exceeds 512 bytes (W3C §3.3.1.5 size cap)"` | §3.3.1.5 says "SHOULD propagate **at least** 512 **characters**" — a minimum propagation floor, not a maximum byte cap. Three inversions in one citation (SHOULD→MUST, minimum→maximum, characters→bytes) |
| `"matching opentelemetry-erlang ... individual malformed entries ... are dropped"` | Erlang actually whole-rejects on any invalid entry |

### 1.2 Hidden MUST/SHOULD gaps

Open the relevant spec section and walk it linearly. For every MUST and
SHOULD clause, ask: does the implementation enforce this? Don't assume;
grep for the behaviour.

**Real finds:**
- W3C §3.5 L379 "Adding a key/value pair MUST NOT result in the same
  key being present multiple times" — `add/3` wasn't checking duplicates
- W3C §3.3.1.1 L273 "right-most list-member should be removed" —
  `add/3` was returning unchanged at 32, not dropping and replacing
- `update/3` fallthrough to add-semantics wasn't respecting the 32-cap

### 1.3 Bogus implementation

Every conditional branch and every validation should trace back to a
spec clause OR a documented reference implementation behaviour. If a
branch has no basis in either, it's bogus — likely added from a
misreading that later review never revisited.

**Real example:** `decode/1` had `if byte_size(header) > 512, do:
%__MODULE__{}`. No W3C clause supports this. `opentelemetry-erlang`
has no such check either. Pure invention.

Checklist for each branch:
- Which spec clause does this implement?
- Does the reference implementation do the same?
- If neither, why is this here?

### 1.4 Reference implementation cross-check

When a docstring says "matching X" (e.g. `opentelemetry-erlang`), open
X and verify the actual behaviour. Claims drift over time. Verify fresh
each review.

In this project, the reference is `references/opentelemetry-erlang/`.
For Elixir modules implementing OTel primitives, the corresponding
Erlang file is almost always the one to cross-check. For W3C wire
formats, also cross-check against `references/w3c-trace-context/`
(pinned to `level-2` branch) or `references/w3c-baggage/`.

---

## Phase 2 — Simplification

Once alignment is confirmed, look for code doing more than its name
promises.

### 2.1 Single Responsibility

Compare each function's name to what it actually does. `decode/1` is
supposed to decode — parsing only. If it's also validating, enforcing
size caps, and running format checks, those belong elsewhere.

**Principle:** validation is a *mutation-time* concern. The API
contract "TraceState MUST at all times be valid" (OTel api.md L293)
applies to state produced by mutation operations, not to intermediate
parsing output. Size caps belong to the constant's consumer (e.g.
`@max_members` used inside `add/3`).

**Real result:** `decode/1` shrank from 20 lines with if/else branches
and helper functions (`build_from_header`, `parse_pair`) to a single
`Enum.reduce` pipeline (PRs #158 + #159). Validation moved to `add/3`
and `update/3` where it belongs.

### 2.2 Happy-path-only

See `.claude/rules/code-conventions.md`. Remove:
- `case _ -> []` fallbacks
- `when is_binary(x)` guards when `@spec` already declares the type
- `{:ok, _} | :error` return tuples
- nil-coalescing on malformed external data
- silent filtering of invalid entries

Use direct pattern match (`[k, v] = split(...)`) and trust the caller.
Malformed input raises `MatchError`; the finalization phase (see
`docs/decisions/error-handling.md`) will decide how to surface these.

**Not error handling** (keep these):
- Spec-mandated fallbacks (e.g. Noop dispatcher when no SDK registered)
- Public-API type gates at entry points
- Exception-recording contracts (`Trace.with_span/5`'s `catch`)
- Lifecycle flags (`:shut_down`, supervisor trees)

### 2.3 YAGNI on API surface

For each public function, grep for lib callsites (exclude tests):

```
rg 'Module\.function_name' apps/*/lib/
```

Test-only APIs are suspects. Single-callsite APIs with a specific
usage pattern (like `size(ts) > 0` for empty-check) often signal that
a purpose-built function would express intent better.

**Real example:** `size/1` had one lib callsite — `size(ts) > 0` to
decide whether to inject a header. Replaced with `empty?/1`, which
reads as intent rather than arithmetic (PR #159). The reverse
direction of the if/else branch was flipped too (`empty? → carrier`
vs `size > 0 → setter`) to avoid negation.

### 2.4 Visibility & encapsulation

Public types and functions need visibility that matches intent. Audit
both directions — what should be hidden and what should be exposed.

**Hide (encapsulation):**
- If `@type t` is public, external code can depend on the internal
  field layout. When the internal representation is not part of the
  public contract, declare it `@opaque`. Dialyzer honours this
  boundary and warns on field access outside the module.
- The same logic applies to `defstruct` fields being pattern-matched
  externally — if they leak, provide accessor functions instead.

**Expose (surface widening):**
- A `defp` predicate that external callers might reasonably want
  should probably be `def`. A format validator (`valid_key?/1`,
  `valid_value?/1`) is a canonical example — callers often need to
  pre-check input before calling mutators. Keeping such predicates
  private forces callers to duplicate the regex.
- `def` but unused in lib → belongs to YAGNI (2.3, opposite direction).

**Relationship with 2.3:**
- 2.3 removes API that has no consumer (*shrink*).
- 2.4 adds/adjusts visibility where consumers exist but can't reach
  the API, or where private structure leaks (*shape*).
- Together they form an API-surface audit: the right shape with the
  right reach.

**Real examples from this project:**
- `@type t :: %__MODULE__{...}` → `@opaque t` (PR #152 `make
  TraceState opaque`). Hides the `members:` field from external
  pattern matching; callers must use the public API.
- `defp valid_key?`/`defp valid_value?` → `def valid_key?`/`def
  valid_value?` (PR #150 `tracestate regex and validator surface`).
  Lets callers pre-validate before `add/update`.

**Checklist:**
- Does any public `@type` reveal internal fields that could change?
  → consider `@opaque`.
- Does any `defp` predicate check a module-owned invariant that
  callers might also want to check? → consider promoting to `def`.
- Is any public function unused in lib? → consider removing (2.3).

---

## Phase 3 — Decision methodology

How to handle conflicts between user feedback and project constraints.

### 3.1 Trade-off presentation

When user feedback conflicts with another project rule — credo checks,
`code-conventions.md`, spec MUSTs, existing architectural decisions —
**never silently pick**. Present 2–3 concrete options with trade-offs
and ask.

**Real example (from PR #158 development):** user asked to inline the
`parse_pair` helper into the `Enum.flat_map` lambda. Credo's
`Refactor.Nesting` check (max 2) rejected the resulting depth-3
lambda/if structure.

Options presented:
- (A) Use `||` fallback to avoid inner `if` — technically passes
  credo, but introduces cryptic boolean-list-coercion syntax
- (B) Re-introduce a helper with meaningful role (32-member guard
  clause) — loses pure inline benefit but gains declarative shape
- (C) Raise credo `max_nesting` to 3 project-wide — weakens the gate
  for every other file

User picks. Each option's downside is stated explicitly so the
decision is informed.

### 3.2 Spec layer disambiguation

Spec-aligned modules often sit at the intersection of multiple specs.
Label every citation with its layer. When two specs appear to
conflict, identify the *scope* of each clause.

**Real example:** W3C Trace Context §3.3.1.6 grants parsers discretion
on partially-parsed pairs ("to the best of its ability"). OTel api.md
L293 says "TraceState MUST at all times be valid". Apparent conflict —
does the parser have to validate or not?

Resolution: identify the MUST's scope. OTel L293 is about the
TraceState *object*'s invariants, which are established by mutation
operations (`add`/`update`) — not by parsing. Parsing is W3C's
territory and §3.3.1.6 discretion applies there. The two specs don't
actually conflict once scope is clear.

---

## Phase 4 — Test minimalism

### 4.1 Structural regression protection

When a boundary is expressed structurally in the code, a dedicated
regression test for "this boundary doesn't leak" is redundant.

**Real example:** `@max_members` is used only inside `add/3`. For the
32-cap to re-appear in `decode/1`, someone would have to explicitly
import the constant into a function that currently doesn't reference
it. That's a structural barrier code review catches naturally; a
dedicated "decode preserves 33 entries" test was adding noise without
adding protection.

The test was initially kept as "regression defence" but removed in
PR #159 once the structural argument was made explicit.

### 4.2 Behaviour over counts

Prefer behaviour-centric assertions over count assertions. They catch
more regression modes.

| Count assertion (narrow) | Behaviour assertion (broader) |
|---|---|
| `size(ts) == 32` | `get(ts, "dropped_key") == ""` + `get(ts, "added_key") == value` + `get(ts, "second_oldest") == "val2"` |
| `size(ts) == 0` | `empty?(ts)` |
| `size(ts) == 1` after dedup | `encode(ts) == "key=second"` |

Example: if `add/3` had a bug dropping the wrong entry, `size == 32`
still passes (still 32 entries) but `get(ts, "second_oldest") ==
"val2"` fails. The behaviour assertion catches it; the count doesn't.

---

## Workflow integration

This skill operates within `.claude/rules/workflow.md`. After review
identifies changes, the standard flow applies:

1. **Classify** — `fix` (closing spec gap, removing bogus logic),
   `refactor` (SRP, YAGNI), or `docs` (docstring-only correction)
2. **Branch** — `<type>/<short-description>` from `main`
3. **Implement** — apply changes
4. **Code conventions** — verify against `.claude/rules/code-conventions.md`
   (full module names, `@spec` with parameter names, happy-path only)
5. **Quality gates** — run in order:
   ```
   mix clean
   mix format --check-formatted
   mix compile --warnings-as-errors
   mix test --warnings-as-errors --cover
   mix credo --strict
   mix dialyzer
   ```
6. **Update docs** — Decision document, `compliance.md` checkboxes,
   `decisions.md` checkboxes if relevant
7. **PR** — single commit preferred; PR title = commit subject, PR
   body = commit body verbatim (per `git-conventions.md` and
   `memory/feedback_pr_body_verbatim.md`)

## Communication style

- Korean first, English for technical terms as needed
- Concise; feedback typically arrives as `질문)` or `피드백)`
- State findings factually with spec line references (e.g.
  `W3C §3.5 L379`); let the user decide direction
- When options conflict (Phase 3.1), present clearly with trade-offs
  and wait for the pick — don't assume

## Related files

- `.claude/rules/workflow.md` — overall task workflow
- `.claude/rules/code-conventions.md` — happy-path, `@spec`, no-alias
- `.claude/rules/documentation.md` — `@doc` role markers
- `.claude/rules/git-conventions.md` — commit/PR format
- `docs/decisions/` — existing design decisions (read before proposing
  changes that might conflict)
- `docs/decisions/error-handling.md` — policy for malformed input
- `docs/decisions/logging-convention.md` — SHOULD-log policy
- `references/` — spec submodules (verify here, always)
