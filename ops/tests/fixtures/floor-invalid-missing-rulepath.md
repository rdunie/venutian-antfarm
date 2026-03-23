# Compliance Floor — Invalid: semgrep rule with missing rule-path

### Rule 1: No eval

```enforcement
version: 1
id: missing-rulepath
severity: blocking
enforce:
  post-tool-use:
    type: semgrep
    rule-id: no-eval
    rule-path: .claude/compliance/semgrep/nonexistent.yaml
    action: block
```
