# Compliance Floor — Invalid: file-pattern at post-tool-use

### Rule 1: No secret files

```enforcement
version: 1
id: wrong-point-test
severity: blocking
enforce:
  post-tool-use:
    type: file-pattern
    patterns: ['\.env$']
    action: block
```
