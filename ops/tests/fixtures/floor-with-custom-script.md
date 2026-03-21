# Compliance Floor — Custom Script Fixture

## Rules

### Rule 1

**No FIXME comments in production.** FIXME markers indicate unfinished work and must not be present in committed code.

```enforcement
version: 1
id: no-fixme
severity: blocking
enforce:
  pre-tool-use:
    type: custom-script
    script: ops/tests/fixtures/test-custom-check.sh
    action: block
  post-tool-use:
    type: content-pattern
    patterns: ['FIXME']
    action: block
```
