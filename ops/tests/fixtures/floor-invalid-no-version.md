# Compliance Floor

## Rules

### Rule 1

**No secrets in files.** Secrets must not be committed to the repository. This rule is missing the required version field.

```enforcement
id: no-version-rule
severity: blocking
enforce:
  pre-tool-use:
    type: file-pattern
    patterns: ['\.env$', '\.pem$']
    action: block
```
