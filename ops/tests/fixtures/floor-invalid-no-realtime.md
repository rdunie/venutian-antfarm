# Compliance Floor

## Rules

### Rule 1

**No unsafe patterns in CI.** This rule is enforced only at CI time via semgrep, with no real-time pre-tool-use or post-tool-use hook.

```enforcement
version: 1
id: ci-only-rule
severity: blocking
enforce:
  ci:
    type: semgrep
    rule-id: bad-rule
    rule-path: rules/bad.yaml
```
