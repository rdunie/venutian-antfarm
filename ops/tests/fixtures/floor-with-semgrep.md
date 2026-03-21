# Compliance Floor — Semgrep Fixture

## Rules

### Rule 1

**No hardcoded secrets.** Secrets, credentials, and private keys must never be hardcoded in source files. Use environment variable references or secret management tooling.

```enforcement
version: 1
id: no-hardcoded-secrets
severity: blocking
enforce:
  pre-tool-use:
    type: file-pattern
    patterns: ['\.env$']
    action: block
  post-tool-use:
    type: semgrep
    rule-id: no-hardcoded-secrets
    rule-path: .claude/compliance/semgrep/no-hardcoded-secrets.yaml
    action: block
```

### Rule 2

**No eval.** Dynamic code evaluation is prohibited. It bypasses static analysis and creates injection vulnerabilities.

```enforcement
version: 1
id: no-eval
severity: blocking
enforce:
  pre-tool-use:
    type: content-pattern
    patterns: ['eval\(']
    action: block
  ci:
    type: eslint
    rule-id: no-eval
    rule-path: .claude/compliance/eslint/no-eval.json
    action: block
```
