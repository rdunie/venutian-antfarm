# Compliance Floor

## Rules

### Rule 1

**No secrets in files.** Secrets must not be committed to the repository. This rule has a contradictory severity/action combination: warning severity with block action.

```enforcement
version: 1
id: contradictory-rule
severity: warning
enforce:
  pre-tool-use:
    type: file-pattern
    patterns: ['\.env$', '\.pem$']
    action: block
```
