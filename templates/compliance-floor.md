# Compliance Floor

Non-negotiable rules that override all autonomy tiers, pace settings, and process decisions. The compliance floor encompasses security, data governance, audit requirements, regulatory controls, access policies, and domain-specific compliance rules.

## How to Define Your Compliance Floor

Keep it to 3-5 rules. Each rule should be:

- **Absolute** -- no exceptions, no "unless..."
- **Enforceable** -- can be checked by hooks, tests, or review
- **Clear** -- any agent can understand and apply it without ambiguity

## Template Rules (replace with your domain's rules)

1. **No hardcoded secrets.** All credentials, API keys, and tokens must be managed through environment variables or a secrets manager. Never committed to version control.

2. **Authentication on every endpoint.** No API endpoint is accessible without authentication. No anonymous access to data-modifying operations.

3. **All data changes are auditable.** Every create, update, and delete operation must produce an audit trail (who, what, when, from where).

4. **Sensitive data requires consent tracking.** Personal data collection and processing must be linked to a consent record. No processing without documented consent.

5. **No data leaks through logs or external services.** Sensitive data must not appear in log output, error messages, LLM prompts, or data sent to third-party services.

## Enforcement

Where possible, enforce compliance floor rules through hooks in `.claude/settings.json`:

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Edit|Write",
        "hooks": [
          {
            "type": "command",
            "command": "echo \"$CLAUDE_FILE_PATH\" | grep -qE '(\\.env|secrets?\\.yaml)$' && echo 'BLOCKED: Cannot edit sensitive file' && exit 2 || exit 0"
          }
        ]
      }
    ]
  }
}
```

Hook enforcement is deterministic and zero-cost (no LLM tokens). Use it for rules that can be checked with simple file/pattern matching. Use agent memory and review processes for rules that require judgment.
