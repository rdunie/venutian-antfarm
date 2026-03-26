# Behavioral Floor — Fintech API

> This file is guarded by the COO. Changes go through `/floor propose behavioral` or `/behavioral propose`.

## Process Quality

### Rule 1

**We MUST ALWAYS** run the full validation cycle (test, typecheck, build) before handoff to the next agent.

### Rule 2

**We MUST NEVER** begin implementation without a corresponding backlog item.

```enforcement
version: 1
id: no-deferred-fixes
severity: warning
enforce:
  post-tool-use:
    type: content-pattern
    action: warn
    patterns:
      - 'TODO|FIXME|HACK|XXX'
```
