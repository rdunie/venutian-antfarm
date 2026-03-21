# Compliance Floor

Non-negotiable rules that override all autonomy tiers, pace settings, and process decisions. The compliance floor encompasses security, data governance, audit requirements, regulatory controls, access policies, and domain-specific compliance rules.

## How to Define Your Compliance Floor

Keep it to 3-5 rules. Each rule should be:

- **Absolute** -- no exceptions, no "unless..."
- **Enforceable** -- can be checked by hooks, tests, or review
- **Clear** -- any agent can understand and apply it without ambiguity

## Template Rules (replace with your domain's rules)

1. **No hardcoded secrets.** All credentials, API keys, and tokens must be managed through environment variables or a secrets manager. Never committed to version control.

```enforcement
version: 1
id: no-hardcoded-secrets
severity: blocking
enforce:
  pre-tool-use:
    type: file-pattern
    patterns: ['\.env$', 'secrets?\.yaml$', '\.pem$', '\.key$']
    action: block
```

2. **Authentication on every endpoint.** No API endpoint is accessible without authentication. No anonymous access to data-modifying operations.

3. **All data changes are auditable.** Every create, update, and delete operation must produce an audit trail (who, what, when, from where).

4. **Sensitive data requires consent tracking.** Personal data collection and processing must be linked to a consent record. No processing without documented consent.

5. **No data leaks through logs or external services.** Sensitive data must not appear in log output, error messages, LLM prompts, or data sent to third-party services.

## Enforcement

Rules with an `enforcement` block are processed by the compliance floor compiler (`ops/compile-floor.sh`). The compiler:

1. **Extracts** each `enforcement` block and validates its schema (version, id, severity, enforce points).
2. **Generates** `enforce.sh` — a standalone hook script with deterministic file-pattern checks for all rules that declare `pre-tool-use` or `post-tool-use` enforcement.
3. **Writes** a `manifest.sha256` linking the source floor to generated artifacts (tamper-evident).
4. **Reports** coverage — which rules are enforced mechanically vs. judgment-only.

Run the compiler after every compliance change:

```bash
ops/compile-floor.sh --dry-run compliance-floor.md     # preview, no writes
ops/compile-floor.sh --proposal <id> compliance-floor.md .claude/compliance/artifacts/
```

Rules without an `enforcement` block are judgment-only: agents and reviewers are responsible for verifying conformance. Add enforcement blocks incrementally as your rules mature.
