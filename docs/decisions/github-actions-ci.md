# GitHub Actions CI

## Question

How to set up continuous integration for the umbrella project? What checks should run on every PR?

## Decision

### CI Pipeline

Single GitHub Actions workflow that runs on every PR and push to `main`. Five steps in order:

1. **Compile** (`mix compile --warnings-as-errors`) — catch compilation errors and warnings
2. **Format** (`mix format --check-formatted`) — enforce consistent code style
3. **Test + Coverage** (`mix test --cover`) — run all tests with 100% coverage threshold
4. **Credo** (`mix credo --strict`) — static analysis for code consistency
5. **Dialyzer** (`mix dialyzer`) — type checking via PLT analysis

### Runtime Versions

Use the same versions pinned in `.mise.toml`:
- Erlang/OTP 28
- Elixir 1.19

### Caching

Cache `_build`, `deps`, and Dialyzer PLT files keyed by `mix.lock` hash to speed up subsequent runs.

### Module: GitHub Actions workflow

Location: `.github/workflows/ci.yml`

## Compliance
