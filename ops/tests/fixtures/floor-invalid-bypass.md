# Compliance Floor

## Rules

### Rule 1

**No secrets in files.** Secrets must not be committed to the repository. This rule has a forbidden bypass field.

```enforcement
version: 1
id: bypass-rule
severity: blocking
bypass: true
enforce:
  pre-tool-use:
    type: file-pattern
    patterns: ['\.env$', '\.pem$']
    action: block
```
