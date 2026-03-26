# Compliance Floor — SaaS Platform

Non-negotiable rules that override all autonomy tiers, pace settings, and process decisions.

## Rules

1. **Tenant data isolation.** Every database query must be scoped to the requesting tenant. No cross-tenant data leakage.

2. **No secrets in code.** API keys, passwords, and tokens must use environment variables, never hardcoded values.

```enforcement
version: 1
id: no-secrets-in-code
severity: blocking
enforce:
  pre-tool-use:
    type: file-pattern
    action: block
    patterns:
      - '\.env$'
      - 'secrets?\.yaml$'
      - 'credentials'
```

3. **Security review before staging.** No code reaches staging or prod without passing security-reviewer assessment.

4. **Plan before build.** Non-trivial work items must have an approved plan before implementation begins.

5. **No direct metrics writes.** All metrics must flow through `ops/metrics-log.sh`. Direct writes to the event log are forbidden.

```enforcement
version: 1
id: no-direct-metrics
severity: blocking
enforce:
  pre-tool-use:
    type: file-pattern
    action: block
    patterns:
      - 'events\.jsonl$'
```

## Enforcement

- Rule 1: Integration tests validate tenant scoping on every query path
- Rule 3: Deploy script checks for security-reviewer approval before staging/prod
