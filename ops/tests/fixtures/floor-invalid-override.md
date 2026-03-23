# Compliance Floor — Invalid: override field present

### Rule 1: No secret files

```enforcement
version: 1
id: override-test
severity: blocking
override: always
enforce:
  pre-tool-use:
    type: file-pattern
    patterns: ['\.env$']
    action: block
```
