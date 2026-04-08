## Commit Messages

Use Conventional Commits format, written in English.

```
<type>[optional scope]: <description>

[optional body]

[optional footer(s)]
```

### Types

- `feat`: new feature
- `fix`: bug fix
- `docs`: documentation changes
- `refactor`: code improvement without behavior change
- `test`: add or update tests
- `chore`: build, config, dependency changes
- `ci`: CI/CD configuration changes

### Scopes

`trace`, `metrics`, `logs`, `baggage`, `exporter`, `context`

### Rules

- Subject starts lowercase, imperative mood, no trailing period
- Subject under 50 characters, body wraps at 72 characters
- Body focuses on why, not what

## Branch Strategy

Follow GitHub Flow.

- `main`: always deployable
- `feat/<description>`: new feature
- `fix/<description>`: bug fix
- `docs/<description>`: documentation
- `refactor/<description>`: refactoring

Merge to main via PR. Use squash merge by default.
