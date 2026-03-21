# Compliance Floor

## Rules

### Rule 1

**No hardcoded secrets.** Secrets, credentials, private keys, and environment variables must never be hardcoded in source files. Use environment variable references or secret management tooling.

```enforcement
version: 1
id: no-hardcoded-secrets
severity: blocking
enforce:
  pre-tool-use:
    type: file-pattern
    patterns: ['\.env$', '\.pem$', '\.key$']
    action: block
```

### Rule 2

**No console.log in production.** Debug logging via console.log must not appear in production code. Use structured logging with appropriate log levels.

```enforcement
version: 1
id: no-console-log
severity: warning
enforce:
  post-tool-use:
    type: content-pattern
    patterns: ['console\.log\(']
    action: warn
```

### Rule 3

**All data changes are auditable.** Every mutation to persistent data must produce an audit record that identifies the actor, timestamp, and change description. This is a judgment-only rule enforced through design review.
