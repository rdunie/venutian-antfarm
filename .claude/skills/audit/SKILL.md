---
name: audit
description: "Run a compliance audit against the compliance floor. Dispatches the compliance-auditor agent."
argument-hint: "[item-id] [--scope full|diff]"
---

# Audit

Dispatch a compliance audit against the rules in `compliance-floor.md`. The compliance-auditor agent is dispatched during Review (Phase 4) of the work item lifecycle, but this skill allows on-demand auditing at any point. See `.claude/agents/compliance-auditor.md` for the agent's mandate.

## Usage

- `/audit` -- Audit current changes against the compliance floor
- `/audit 42` -- Audit a specific work item
- `/audit --scope diff` -- Audit only changed files (faster)
- `/audit --scope full` -- Full compliance floor audit

## Workflow

1. **Parse arguments.** Extract item ID (optional) and scope (default: diff).

2. **Determine scope.**
   - `diff`: Identify files changed since the last commit (or since item was promoted, if item ID provided).
   - `full`: Audit the entire codebase against the compliance floor.

3. **Dispatch compliance-auditor agent.** Send the agent with:
   - The compliance floor rules from `compliance-floor.md`
   - The scope (file list for diff, or "full codebase")
   - The item ID if provided (for context on what changed and why)

4. **Present results.** Show the audit output in the compliance-auditor's standard format:

   ```
   ## Compliance Audit: Item #<id>

   ### Rules Checked
   | # | Rule | Status | Notes |
   |---|------|--------|-------|
   | 1 | <rule text> | PASS/FAIL/WARN | <details> |

   ### Violations
   #### [BLOCKING] <rule> — <location>
   - **What:** <description>
   - **Fix:** <recommendation>

   ### Summary
   - Rules checked: X
   - Passed: X
   - Violations: X (Y blocking, Z warning)
   - Verdict: PASS / FAIL (blocks deploy)
   ```

5. **If violations found.** For each blocking violation, recommend which domain owner should fix it. Log findings for patterns (e.g., the same rule violated repeatedly).

## Model Tiering

| Subcommand | Model  | Rationale                                                          |
| ---------- | ------ | ------------------------------------------------------------------ |
| `/audit`   | Sonnet | The compliance-auditor agent is already Sonnet; this dispatches it |

## Extensibility

Implementers add domain-specific audit rules by defining them in `compliance-floor.md`. For deeper integration (e.g., automated SAST scans, policy-as-code), override this skill to run additional checks alongside the compliance-auditor agent.
