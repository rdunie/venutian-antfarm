# Programmatic Compliance Floor Enforcement

**Date:** 2026-03-21
**Status:** Draft
**Approach:** C — Annotated Markdown with compiled enforcement

## Problem

The compliance floor (`compliance-floor.md`) defines non-negotiable rules, but enforcement is static. Hooks in `settings.json` are hardcoded patterns that don't update when the floor evolves. The compliance auditor reads the floor dynamically, but that's LLM-based judgment — not programmatic enforcement. There is no mechanism that automatically derives deterministic checks from the floor document as it changes.

## Design Goals

- Rules and enforcement stay in sync — changing a rule automatically updates its checks
- Enforcement is honest about what each layer guarantees
- The compliance floor document remains the single source of truth
- Implementers can adopt enforcement progressively based on their threat model
- Agent context overhead is minimized — enforcement details stay out of agent prompts

## Non-Goals

- Replacing the compliance auditor agent (judgment-based rules still need LLM review)
- Building an external signing service (CI and GPG are sufficient)
- Per-agent identity within Claude Code (the platform doesn't support it)

---

## Section 1: Rule DSL Format

Each rule in `compliance-floor.md` retains its human-readable prose and gains a fenced `enforcement` block:

````markdown
1. **No hardcoded secrets.** All credentials, API keys, and tokens must be
   managed through environment variables or a secrets manager.

```enforcement
id: no-hardcoded-secrets
severity: blocking
enforce:
  pre-tool:
    type: file-pattern
    patterns: ['\.env$', '\.pem$', '\.key$', 'secrets?\.yaml$']
    action: block
  post-commit:
    type: semgrep
    rule-id: no-hardcoded-secrets
```
````

### Field Definitions

| Field                      | Required    | Description                                                                     |
| -------------------------- | ----------- | ------------------------------------------------------------------------------- |
| `id`                       | Yes         | Unique identifier, used to correlate across compiled artifacts                  |
| `severity`                 | Yes         | `blocking` (stops work) or `warning` (flags for review)                         |
| `enforce`                  | Yes         | Map of enforcement points, each declaring its check type                        |
| `enforce.<point>.type`     | Yes         | One of: `file-pattern`, `content-pattern`, `semgrep`, `eslint`, `custom-script` |
| `enforce.<point>.action`   | No          | `block` (exit 2, default) or `warn` (print warning, exit 0)                     |
| `enforce.<point>.patterns` | Conditional | Required for `file-pattern` and `content-pattern` types                         |
| `enforce.<point>.rule-id`  | Conditional | Required for `semgrep` and `eslint` types — references an existing rule file    |
| `enforce.<point>.script`   | Conditional | Required for `custom-script` type — path to validation script                   |

### Check Types

| Type              | What it does                | Valid enforcement points  |
| ----------------- | --------------------------- | ------------------------- |
| `file-pattern`    | Regex match on file path    | `pre-tool`                |
| `content-pattern` | Regex match on file content | `pre-tool`, `post-commit` |
| `semgrep`         | AST-level code analysis     | `post-commit`, `ci`       |
| `eslint`          | JS/TS linting rule          | `post-commit`, `ci`       |
| `custom-script`   | Runs a user-provided script | any                       |

### Validation Constraints

- Every rule MUST have at least one real-time enforcement point (`pre-tool` or `post-commit`). Rules that only declare `ci` are rejected by the compiler.
- The compiler rejects enforcement blocks containing `bypass`, `skip`, or `override` fields.

---

## Section 2: Compiler

A shell script `ops/compile-floor.sh` reads `compliance-floor.md`, extracts enforcement blocks, validates them, and produces compiled artifacts.

### Inputs

- `compliance-floor.md` (the annotated source of truth)

### Outputs

| Artifact           | Path                                                    | Purpose                                             |
| ------------------ | ------------------------------------------------------- | --------------------------------------------------- |
| Prose-only floor   | `.claude/compliance/compiled/compliance-floor.prose.md` | What most agents load — enforcement blocks stripped |
| Hook commands      | `.claude/compliance/compiled/hooks.json`                | Pre-tool and post-commit hook commands              |
| Semgrep ruleset    | `.claude/compliance/compiled/semgrep-rules.yaml`        | All semgrep rules batched into one file             |
| ESLint config      | `.claude/compliance/compiled/eslint-rules.json`         | All eslint rules batched                            |
| Coverage report    | `.claude/compliance/compiled/coverage-report.md`        | Per-rule enforcement breakdown + trust summary      |
| Staleness manifest | `.claude/compliance/compiled/manifest.sha256`           | Source checksum + artifact checksums                |

### Compiler Behavior

1. Extract all ` ```enforcement ` blocks via `sed`/`awk`
2. Parse YAML fields with `yq` (lightweight, single binary)
3. Validate: every rule has `id`, `severity`, at least one non-CI enforcement point. Reject `bypass`/`skip`/`override` fields.
4. Group rules by check type and enforcement point (batch — don't run semgrep N times)
5. Generate hook commands per enforcement point per check type
6. Generate semgrep/eslint configs from rule definitions
7. Produce prose file by stripping enforcement blocks from source
8. Write coverage report with trust summary
9. Write staleness manifest (SHA-256 of source + SHA-256 of each artifact + proposal ID)

### Three Modes

| Mode                | When                | Writes files?        | Exits non-zero on            |
| ------------------- | ------------------- | -------------------- | ---------------------------- |
| `compile` (default) | `/compliance apply` | Yes                  | Invalid rules                |
| `--dry-run`         | Iterating on rules  | No, prints to stdout | Invalid rules                |
| `--verify`          | CI, SessionStart    | No                   | Artifacts don't match source |

### Dependencies

- `yq` — for YAML parsing. Single static binary, no runtime dependencies. The compiler checks for it and prints install instructions if missing.

### Integration

The compiler runs automatically at the end of the `/compliance apply` workflow — after the CO writes the floor change, before the sentinel is removed. This ensures the floor cannot change without recompilation.

### Generated Artifact Headers

Every generated file includes a header:

```
# GENERATED by ops/compile-floor.sh from compliance-floor.md
# Do not edit — changes will be overwritten. Proposal: <id>
```

---

## Section 3: Enforcement Layers

Three layers, each honest about what it guarantees.

### Layer 1: Hooks (Behavioral Guardrails)

The compiled `hooks.json` produces hook commands that get merged into `settings.json`. Example generated output for a `file-pattern` pre-tool rule:

```json
{
  "matcher": "Edit|Write",
  "hooks": [
    {
      "type": "command",
      "command": "echo \"$CLAUDE_FILE_PATH\" | grep -qE '(\\.env|\\.pem|\\.key|secrets?\\.yaml)$' && echo 'BLOCKED [no-hardcoded-secrets]: Cannot edit sensitive file' && exit 2 || exit 0"
    }
  ]
}
```

For `content-pattern` post-commit rules, the hook runs the pattern against `$CLAUDE_FILE_PATH` content after each write. For semgrep/eslint post-commit rules, the hook runs the batched ruleset against the changed file.

**Guarantee:** Catches accidental violations in real-time. Routes agents toward the CO workflow. Does NOT prevent a determined bypass — any agent can write files.

### Layer 2: Git (Audit Trail)

All compiled artifacts are committed alongside floor changes:

- Every compliance change produces a visible diff (prose change + compiled output change)
- `git log --all -- compliance-floor.md .claude/compliance/compiled/` shows full history
- The user sees exactly what enforcement changed in every PR

**Guarantee:** No change is invisible. Tampering is detectable through review.

### Layer 3: CI (True Enforcer)

A CI job runs on every PR:

1. Check out the repo
2. Run `ops/compile-floor.sh --verify` — recompile from source and diff against committed artifacts
3. If diff is non-empty → compiled artifacts were hand-edited or compiler wasn't run → **fail the build**
4. Run compiled semgrep/eslint rulesets against the full codebase → **fail the build** on blocking violations

**Guarantee:** No code merges to main that violates the floor. Runs outside Claude Code — no agent can influence it.

---

## Section 4: Implementer Configuration Tiers

### Tier 1: Foundation (MUST)

Every implementer gets this. Non-optional. Comes with the framework.

- Annotated `compliance-floor.md` with enforcement blocks
- `ops/compile-floor.sh` with compile/dry-run/verify modes
- Compiled prose floor (what agents read)
- Coverage report with trust summary
- Staleness manifest for drift detection
- PreToolUse hooks generated from compiled output
- Compiler runs as part of `/compliance apply`

### Tier 2: Collaboration Controls (SHOULD)

Recommended for any team with more than one person or any project heading toward production.

- Git branch protection on `main` — require PR + CI pass
- `CODEOWNERS` for `compliance-floor.md` and `.claude/compliance/` — human must approve
- CI verification job — `ops/compile-floor.sh --verify` + compiled linter rulesets
- Post-commit hooks for semgrep/eslint

### Tier 3: Hardened (MAY)

For regulated environments, high-security contexts, or defense in depth.

- CI-based artifact signing (signing key in GitHub Actions secrets)
- GPG commit signing with passphrase-protected key for compliance changes
- External audit log via pluggable metrics backend
- Custom-script rules for team-specific validation

### Tier 4: Anti-Patterns (SHOULD NOT)

Each anti-pattern has a designed alternative that makes the right path easier.

| Anti-pattern                                 | Why people try it                 | Designed alternative                                                                                                                   |
| -------------------------------------------- | --------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------- |
| Moving floor outside filesystem              | Want a trust boundary             | Trust boundary is git + CI + CODEOWNERS (Tier 2)                                                                                       |
| Per-rule bypass mechanisms                   | Urgent change blocked by a rule   | CO expedited path (Type 1 fast-track with single user confirmation). Compiler rejects `bypass`/`skip` fields as syntax errors.         |
| File permissions as enforcement              | Unix instinct (`chmod 444`)       | Hooks are stronger (intercept at tool level). Generated headers serve the same "don't touch" signal. CI `--verify` catches hand-edits. |
| Duplicating rules in floor + separate config | Already have semgrep/eslint rules | Enforcement blocks reference existing rules via `rule-id`. Compiler validates references exist.                                        |
| Running compiler outside `/compliance apply` | Want to test rule syntax          | `--dry-run` mode for experimentation. Staleness manifest flags artifacts without change-log entries.                                   |

### Decision Guide

```
Q: Is this a solo/hobby project?
   → Tier 1 is sufficient.

Q: Does anyone else see this code, or will it run in production?
   → Add Tier 2.

Q: Are you in a regulated industry, or do you handle sensitive data?
   → Add Tier 3 controls relevant to your compliance requirements.
```

---

## Section 5: Signing & Integrity

Integrity verification scales with the implementer's threat model.

### Tier 1: Staleness Detection

The compiler writes `manifest.sha256`:

```
source: <sha256 of compliance-floor.md>
compiled-from: <proposal ID>
artifacts:
  compliance-floor.prose.md: <sha256>
  hooks.json: <sha256>
  semgrep-rules.yaml: <sha256>
  eslint-rules.json: <sha256>
```

SessionStart runs `--verify` to check source/artifact consistency.

**Proves:** Source and artifacts are in sync. Does NOT prove who compiled them.

### Tier 2: CI-Based Signing

A GitHub Actions job signs artifacts after verification:

```yaml
- name: Verify compliance artifacts
  run: ops/compile-floor.sh --verify

- name: Sign compliance artifacts
  run: |
    sha256sum .claude/compliance/compiled/* > /tmp/artifact-hashes.txt
    openssl dgst -sha256 -sign <(echo "$SIGNING_KEY") \
      -out .claude/compliance/compiled/signature.sig \
      /tmp/artifact-hashes.txt
  env:
    SIGNING_KEY: ${{ secrets.COMPLIANCE_SIGNING_KEY }}
```

SessionStart verifies the signature against the public key (committed to the repo).

**Proves:** Artifacts are the same ones CI verified. No local tampering after merge.

### Tier 3: Human-Gated Signing

Adds GPG commit signing:

- Passphrase-protected GPG key configured in git
- Branch protection requires signed commits for compliance paths
- Agents cannot enter passphrases interactively — requires human presence

**Proves:** A human with the private key authorized the change AND CI verified artifacts.

### Verification Matrix

| Check                       | Tier 1                 | Tier 2                     | Tier 3                               |
| --------------------------- | ---------------------- | -------------------------- | ------------------------------------ |
| Source/artifact drift       | Staleness manifest     | Staleness manifest         | Staleness manifest                   |
| Artifact hand-editing       | Staleness manifest     | CI signature               | CI signature                         |
| Unauthorized compilation    | Change-log entry check | CI re-compiles from source | CI re-compiles from source           |
| Agent impersonating CO      | Not detected           | Detected post-merge        | Blocked (GPG passphrase)             |
| Local tampering after merge | Not detected           | Signature mismatch         | Signature mismatch + unsigned commit |

---

## Section 6: Intent Declaration

Every modification to the compliance surface area requires explicit user acknowledgment — even through authorized paths. No silent compliance changes.

### Compliance Surface Area

| Path pattern                           | Why it's sensitive                                      |
| -------------------------------------- | ------------------------------------------------------- |
| `compliance-floor.md`                  | Source of truth for all rules                           |
| `.claude/compliance/**`                | Proposals, change log, targets, compiled artifacts      |
| `ops/compile-floor.sh`                 | Modifying the compiler changes all enforcement          |
| `.claude/agents/compliance-officer.md` | Changing CO instructions changes who guards the floor   |
| `.claude/agents/compliance-auditor.md` | Changing auditor instructions changes what gets checked |

### Hook Logic

For the compliance floor and compliance directory (sentinel-gated files):

```
PreToolUse (Edit|Write):
  1. Is file in compliance surface area?
     → No: pass through (exit 0)
     → Yes: continue

  2. Is the sentinel (.applying) active?
     → No: BLOCK (exit 2) — "Compliance file protected. Use /compliance propose."
     → Yes: WARN (exit 1) — prompt user:
       "Compliance modification: <filename> via proposal #<id>. Approve?"
```

For compiled artifacts and infrastructure files (no sentinel path):

```
PreToolUse (Edit|Write):
  1. Is file a compiled artifact?
     → WARN (exit 1): "This is generated by ops/compile-floor.sh.
       Manual edits will be overwritten. Proceed?"

  2. Is file the compiler script?
     → WARN (exit 1): "This modifies the compliance compiler.
       Changes affect all rule enforcement. Proceed?"

  3. Is file a compliance agent definition?
     → WARN (exit 1): "This modifies a compliance agent's instructions.
       Changes affect compliance governance. Proceed?"
```

### Guarantees

- The user sees every compliance-sensitive write in real-time, regardless of which agent initiates it
- The CO workflow is not blocked — but it is never invisible
- Read access is unrestricted — intent declaration only fires on writes

---

## Agent Context Optimization

Most agents reference `compliance-floor.prose.md` (the compiled prose-only version) instead of the full annotated floor. This keeps enforcement metadata (regex patterns, semgrep rule IDs, enforcement point configs) out of agent context.

| Agent              | Reads                       | Why                                                |
| ------------------ | --------------------------- | -------------------------------------------------- |
| Compliance Officer | Full `compliance-floor.md`  | Owns the source of truth, runs the compiler        |
| Compliance Auditor | `compliance-floor.prose.md` | Needs rules for judgment, not enforcement metadata |
| All other agents   | `compliance-floor.prose.md` | Need to understand rules, not how they're enforced |

---

## Coverage Report Trust Summary

The coverage report ends with a plain-language statement of what each enforcement layer guarantees:

```markdown
## What Each Layer Guarantees

- **Hooks:** Catch accidental violations in real-time (behavioral, bypassable by any agent)
- **Git + CODEOWNERS:** Human must approve compliance file changes (server-enforced)
- **CI --verify:** No violating code merges to main (external, not agent-influenced)
- **Intent declaration:** User sees every compliance-sensitive write (behavioral, prompt-based)
```

This replaces the need for separate anti-pattern documentation — implementers read the trust summary and understand where real enforcement lives.

---

## Dependencies

| Dependency | Required by                | Install                               |
| ---------- | -------------------------- | ------------------------------------- |
| `yq`       | Compiler (YAML parsing)    | Single static binary, no runtime deps |
| `semgrep`  | Code-level rules (Tier 2+) | `pip install semgrep` or binary       |
| `eslint`   | JS/TS rules (Tier 2+)      | `npm install eslint`                  |
| `openssl`  | CI signing (Tier 2+)       | Usually pre-installed                 |
| `gpg`      | Commit signing (Tier 3)    | Usually pre-installed                 |

---

## Open Questions

1. Should the compiler support custom check types beyond the five defined (file-pattern, content-pattern, semgrep, eslint, custom-script)?
2. Should compiled hooks be merged into `settings.json` automatically, or should the implementer manually reference them?
3. What is the migration path for existing hardcoded hooks in `settings.json` — replace them with compiled equivalents, or keep both?
