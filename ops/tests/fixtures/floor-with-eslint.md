# Compliance Floor — ESLint enforcement

### Rule 1: No hardcoded secrets

```enforcement
version: 1
id: no-hardcoded-secrets
severity: blocking
enforce:
  pre-tool-use:
    type: file-pattern
    patterns: ['\.env$', 'secrets?\.yaml$', '\.pem$', '\.key$']
    action: block
```

### Rule 2: No eval

```enforcement
version: 1
id: no-eval
severity: warning
enforce:
  post-tool-use:
    type: eslint
    rule-id: no-eval
    rule-path: .claude/compliance/eslint/no-eval.json
    action: warn
```
