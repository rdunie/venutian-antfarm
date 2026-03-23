# Compliance Floor — Invalid: skip field present

### Rule 1: No secret files

```enforcement
version: 1
id: skip-test
severity: blocking
skip: true
enforce:
  pre-tool-use:
    type: file-pattern
    patterns: ['\.env$']
    action: block
```
