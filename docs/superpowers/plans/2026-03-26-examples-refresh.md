# Examples Refresh Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Update all 5 progressive examples to the current framework baseline — `floors/` directory, CRO rename, fleet-config floors section, prioritize_cadence, rewards config, and progressive enforcement blocks.

**Architecture:** Each example gets the same structural migration (floor file move, fleet-config updates, CRO rename). Examples 03-05 additionally get enforcement blocks in their compliance floors. Example 05 gets a behavioral floor. Each example is a self-contained task. Validation: compile enforcement blocks in examples 03-05 using the simplified compiler.

**Tech Stack:** Bash, JSON, Markdown, YAML (enforcement blocks)

**Spec:** `docs/superpowers/specs/2026-03-26-examples-refresh-design.md`

---

## File Structure

### Moved Files (All Examples)

| From                             | To                                |
| -------------------------------- | --------------------------------- |
| `examples/*/compliance-floor.md` | `examples/*/floors/compliance.md` |

### Renamed Files

| From                                                                   | To                                                      |
| ---------------------------------------------------------------------- | ------------------------------------------------------- |
| `examples/04-compliance-heavy/.claude/overrides/compliance-officer.md` | `examples/04-compliance-heavy/.claude/overrides/cro.md` |

### New Files

| File                                                                 | Purpose                                  |
| -------------------------------------------------------------------- | ---------------------------------------- |
| `examples/05-operational-maturity/floors/behavioral.md`              | Behavioral floor with enforcement blocks |
| `examples/04-compliance-heavy/ops/checks/verify-audit-log.sh`        | Placeholder custom-script                |
| `examples/05-operational-maturity/ops/checks/verify-transactions.sh` | Placeholder custom-script                |

### Modified Files (All Examples)

| File                                        | Change                                              |
| ------------------------------------------- | --------------------------------------------------- |
| `examples/*/fleet-config.json`              | Add floors, CRO rename, prioritize_cadence, rewards |
| `examples/*/README.md`                      | Update paths and feature descriptions               |
| `examples/04-compliance-heavy/setup.sh`     | Update paths, CRO references                        |
| `examples/05-operational-maturity/setup.sh` | Compile floors, CRO references                      |
| `examples/README.md`                        | New progression table                               |

---

## Task 1: Example 01-getting-started

**Files:**

- Move: `examples/01-getting-started/compliance-floor.md` → `examples/01-getting-started/floors/compliance.md`
- Modify: `examples/01-getting-started/fleet-config.json`
- Modify: `examples/01-getting-started/README.md`

- [ ] **Step 1: Move the compliance floor**

```bash
mkdir -p examples/01-getting-started/floors
git mv examples/01-getting-started/compliance-floor.md examples/01-getting-started/floors/compliance.md
```

- [ ] **Step 2: Update fleet-config.json**

Add after `pace` section:

```json
"floors": {
  "compliance": {
    "file": "floors/compliance.md",
    "guardian": "cro",
    "compiled_dir": ".claude/floors/compliance/compiled"
  }
},
"prioritize_cadence": "per-iteration",
"rewards": { "ledger": ".claude/rewards/ledger.jsonl" },
```

Replace `"compliance-officer"` with `"cro"` in `agents.governance`.

Replace `"* -> compliance-officer"` with `"* -> cro"` in `pathways.declared.governance`.

Validate: `jq . examples/01-getting-started/fleet-config.json > /dev/null`

- [ ] **Step 3: Update README.md**

Update the Structure section to show `floors/compliance.md` instead of `compliance-floor.md`. Update description to mention CRO. Keep it minimal — this is the getting-started example.

- [ ] **Step 4: Commit**

```bash
git add examples/01-getting-started/
git commit -m "refactor(#14): update 01-getting-started for multi-floor baseline"
```

---

## Task 2: Example 02-ecommerce

**Files:**

- Move: `examples/02-ecommerce/compliance-floor.md` → `examples/02-ecommerce/floors/compliance.md`
- Modify: `examples/02-ecommerce/fleet-config.json`
- Modify: `examples/02-ecommerce/README.md`

- [ ] **Step 1: Move the compliance floor**

```bash
mkdir -p examples/02-ecommerce/floors
git mv examples/02-ecommerce/compliance-floor.md examples/02-ecommerce/floors/compliance.md
```

- [ ] **Step 2: Update fleet-config.json**

Same pattern as Task 1: add `floors`, `prioritize_cadence`, `rewards` sections. Rename `compliance-officer` → `cro` in agents and pathways.

Validate: `jq . examples/02-ecommerce/fleet-config.json > /dev/null`

- [ ] **Step 3: Update README.md**

Update structure section and references.

- [ ] **Step 4: Commit**

```bash
git add examples/02-ecommerce/
git commit -m "refactor(#14): update 02-ecommerce for multi-floor baseline"
```

---

## Task 3: Example 03-multi-team (introduces enforcement blocks)

**Files:**

- Move: `examples/03-multi-team/compliance-floor.md` → `examples/03-multi-team/floors/compliance.md`
- Modify: `examples/03-multi-team/floors/compliance.md` (add enforcement blocks)
- Modify: `examples/03-multi-team/fleet-config.json`
- Modify: `examples/03-multi-team/README.md`

- [ ] **Step 1: Move the compliance floor**

```bash
mkdir -p examples/03-multi-team/floors
git mv examples/03-multi-team/compliance-floor.md examples/03-multi-team/floors/compliance.md
```

- [ ] **Step 2: Add enforcement blocks to the compliance floor**

Read the current floor content. After the relevant prose rules, add 2 enforcement blocks.

After the "no secrets in code" rule (or equivalent), add:

````markdown
```enforcement
version: 1
id: no-secrets-in-code
severity: blocking
enforce:
  pre-tool-use:
    type: file-pattern
    action: block
    patterns:
      - '\.env$'
      - 'secrets?\.yaml$'
      - 'credentials'
```
````

After the "use metrics-log.sh" rule (or equivalent — if none exists, add after the last rule), add:

````markdown
```enforcement
version: 1
id: no-direct-metrics
severity: blocking
enforce:
  pre-tool-use:
    type: file-pattern
    action: block
    patterns:
      - 'events\.jsonl$'
```
````

- [ ] **Step 3: Update fleet-config.json**

Same baseline pattern: add `floors`, `prioritize_cadence`, `rewards`. Rename CRO.

Validate: `jq . examples/03-multi-team/fleet-config.json > /dev/null`

- [ ] **Step 4: Validate enforcement blocks compile**

```bash
PATH="$HOME/.local/bin:$PATH" bash ops/compile-floor.sh --dry-run examples/03-multi-team/floors/compliance.md /tmp/test-03
```

Expected: exits 0, shows 2 rules found.

- [ ] **Step 5: Update README.md**

Update structure. Add note: "**New in this example:** Enforcement blocks — the compliance floor includes machine-enforceable rules that the compiler transforms into hook checks."

- [ ] **Step 6: Commit**

```bash
git add examples/03-multi-team/
git commit -m "feat(#14): update 03-multi-team with enforcement blocks"
```

---

## Task 4: Example 04-compliance-heavy (full enforcement + CRO override)

**Files:**

- Move: `examples/04-compliance-heavy/compliance-floor.md` → `examples/04-compliance-heavy/floors/compliance.md`
- Modify: `examples/04-compliance-heavy/floors/compliance.md` (add enforcement blocks)
- Rename: `examples/04-compliance-heavy/.claude/overrides/compliance-officer.md` → `.claude/overrides/cro.md`
- Modify: `examples/04-compliance-heavy/.claude/overrides/cro.md` (update extends)
- Create: `examples/04-compliance-heavy/ops/checks/verify-audit-log.sh`
- Modify: `examples/04-compliance-heavy/fleet-config.json`
- Modify: `examples/04-compliance-heavy/setup.sh`
- Modify: `examples/04-compliance-heavy/README.md`

- [ ] **Step 1: Move the compliance floor**

```bash
mkdir -p examples/04-compliance-heavy/floors
git mv examples/04-compliance-heavy/compliance-floor.md examples/04-compliance-heavy/floors/compliance.md
```

- [ ] **Step 2: Rename the CO override to CRO**

```bash
git mv examples/04-compliance-heavy/.claude/overrides/compliance-officer.md examples/04-compliance-heavy/.claude/overrides/cro.md
```

Update the `extends` line inside the file from `extends: harness/compliance-officer` to `extends: harness/cro`.

- [ ] **Step 3: Create the custom-script placeholder**

```bash
mkdir -p examples/04-compliance-heavy/ops/checks
```

Write `examples/04-compliance-heavy/ops/checks/verify-audit-log.sh`:

```bash
#!/usr/bin/env bash
# Placeholder: verifies audit log integrity for HIPAA compliance.
# Real implementation would check log completeness and tamper evidence.
echo "Audit log integrity: OK"
exit 0
```

Make executable: `chmod +x examples/04-compliance-heavy/ops/checks/verify-audit-log.sh`

- [ ] **Step 4: Add enforcement blocks to the compliance floor**

Read the current floor (7 rules, healthcare/HIPAA domain). Add 3 enforcement blocks after relevant rules:

Block 1 — after Rule 1 (PHI encryption) or Rule 4 (No PHI in logs):

````markdown
```enforcement
version: 1
id: no-phi-in-config
severity: blocking
enforce:
  pre-tool-use:
    type: file-pattern
    action: block
    patterns:
      - '\.env$'
      - 'secrets?\.yaml$'
      - 'phi-config'
```
````

Block 2 — after Rule 4 (No PHI in logs):

````markdown
```enforcement
version: 1
id: no-phi-in-source
severity: blocking
enforce:
  post-tool-use:
    type: content-pattern
    action: block
    patterns:
      - 'SSN[:=]\s*\d{3}-\d{2}-\d{4}'
      - 'DOB[:=]\s*\d{4}-\d{2}-\d{2}'
```
````

Block 3 — after Rule 3 (Audit every PHI access):

````markdown
```enforcement
version: 1
id: audit-log-integrity
severity: warning
enforce:
  post-tool-use:
    type: custom-script
    action: warn
    script: ops/checks/verify-audit-log.sh
```
````

- [ ] **Step 5: Update fleet-config.json**

Baseline additions plus CRO rename. This example has more governance pathways — update all `compliance-officer` references.

Validate: `jq . examples/04-compliance-heavy/fleet-config.json > /dev/null`

- [ ] **Step 6: Update setup.sh**

Replace `compliance-floor.md` references with `floors/compliance.md`. Replace CO references with CRO. The setup seeds a compliance proposal — update the comment that references CO to say CRO.

- [ ] **Step 7: Validate enforcement blocks compile**

```bash
PATH="$HOME/.local/bin:$PATH" bash ops/compile-floor.sh --dry-run examples/04-compliance-heavy/floors/compliance.md /tmp/test-04
```

Expected: exits 0, shows 3 rules found.

- [ ] **Step 8: Update README.md**

Update structure (floors/, cro.md override, ops/checks/). Add note: "**New in this example:** Full enforcement coverage — file-pattern, content-pattern, and custom-script check types. CRO override for HIPAA domain."

- [ ] **Step 9: Commit**

```bash
git add examples/04-compliance-heavy/
git commit -m "feat(#14): update 04-compliance-heavy with enforcement blocks and CRO override"
```

---

## Task 5: Example 05-operational-maturity (multi-floor + behavioral floor)

**Files:**

- Move: `examples/05-operational-maturity/compliance-floor.md` → `examples/05-operational-maturity/floors/compliance.md`
- Modify: `examples/05-operational-maturity/floors/compliance.md` (add enforcement blocks)
- Create: `examples/05-operational-maturity/floors/behavioral.md`
- Create: `examples/05-operational-maturity/ops/checks/verify-transactions.sh`
- Modify: `examples/05-operational-maturity/fleet-config.json`
- Modify: `examples/05-operational-maturity/setup.sh`
- Modify: `examples/05-operational-maturity/README.md`

- [ ] **Step 1: Move the compliance floor**

```bash
mkdir -p examples/05-operational-maturity/floors
git mv examples/05-operational-maturity/compliance-floor.md examples/05-operational-maturity/floors/compliance.md
```

- [ ] **Step 2: Create the custom-script placeholder**

```bash
mkdir -p examples/05-operational-maturity/ops/checks
```

Write `examples/05-operational-maturity/ops/checks/verify-transactions.sh`:

```bash
#!/usr/bin/env bash
# Placeholder: verifies transaction validation rules are enforced.
# Real implementation would check transaction processing logic.
echo "Transaction validation: OK"
exit 0
```

Make executable: `chmod +x examples/05-operational-maturity/ops/checks/verify-transactions.sh`

- [ ] **Step 3: Add enforcement blocks to the compliance floor**

Read the current floor (5 rules, fintech domain). Add 3 enforcement blocks:

Block 1 — after the secrets/credentials rule:

````markdown
```enforcement
version: 1
id: no-secrets-in-code
severity: blocking
enforce:
  pre-tool-use:
    type: file-pattern
    action: block
    patterns:
      - '\.env$'
      - 'credentials'
      - 'secrets?\.yaml$'
```
````

Block 2 — after the API key rule:

````markdown
```enforcement
version: 1
id: no-hardcoded-keys
severity: blocking
enforce:
  post-tool-use:
    type: content-pattern
    action: block
    patterns:
      - 'api[_-]?key\s*[:=]\s*["'\''][A-Za-z0-9]{20,}'
      - 'secret\s*[:=]\s*["'\''][A-Za-z0-9]{20,}'
```
````

Block 3 — transaction validation:

````markdown
```enforcement
version: 1
id: transaction-validation
severity: warning
enforce:
  post-tool-use:
    type: custom-script
    action: warn
    script: ops/checks/verify-transactions.sh
```
````

- [ ] **Step 4: Create the behavioral floor**

Write `examples/05-operational-maturity/floors/behavioral.md` with the following content:

The file starts with a title, blockquote, and two prose rules, then an enforcement block:

Title: `# Behavioral Floor — Fintech API`

Blockquote: `> This file is guarded by the COO. Changes go through /floor propose behavioral or /behavioral propose.`

Section: `## Process Quality`

Rule 1: `**We MUST ALWAYS** run the full validation cycle (test, typecheck, build) before handoff to the next agent.`

Rule 2: `**We MUST NEVER** begin implementation without a corresponding backlog item.`

Then an enforcement block (fenced with ` ```enforcement ` / ` ``` `):

```yaml
version: 1
id: no-deferred-fixes
severity: warning
enforce:
  post-tool-use:
    type: content-pattern
    action: warn
    patterns:
      - "TODO|FIXME|HACK|XXX"
```

- [ ] **Step 5: Update fleet-config.json**

Add both floors:

```json
"floors": {
  "compliance": {
    "file": "floors/compliance.md",
    "guardian": "cro",
    "compiled_dir": ".claude/floors/compliance/compiled"
  },
  "behavioral": {
    "file": "floors/behavioral.md",
    "guardian": "coo",
    "compiled_dir": ".claude/floors/behavioral/compiled"
  }
},
"prioritize_cadence": "per-session",
"rewards": { "ledger": ".claude/rewards/ledger.jsonl" },
```

Rename CRO in agents and pathways.

Validate: `jq . examples/05-operational-maturity/fleet-config.json > /dev/null`

- [ ] **Step 6: Update setup.sh**

Add floor compilation after metrics seeding:

```bash
# Compile governance floors
if command -v gomplate &>/dev/null; then
  echo "Compiling governance floors..."
  PATH="$HOME/.local/bin:$PATH" bash "$WORKTREE_ROOT/ops/compile-floor.sh" \
    "$WORKTREE_ROOT/examples/05-operational-maturity/floors/compliance.md" \
    "$WORKTREE_ROOT/.claude/floors/compliance/compiled"
  PATH="$HOME/.local/bin:$PATH" bash "$WORKTREE_ROOT/ops/compile-floor.sh" \
    "$WORKTREE_ROOT/examples/05-operational-maturity/floors/behavioral.md" \
    "$WORKTREE_ROOT/.claude/floors/behavioral/compiled"
  echo "Compiled: compliance + behavioral floors"
else
  echo "Note: gomplate not installed — skipping floor compilation"
fi
```

Update CRO references in any comments.

- [ ] **Step 7: Validate enforcement blocks compile**

```bash
PATH="$HOME/.local/bin:$PATH" bash ops/compile-floor.sh --dry-run examples/05-operational-maturity/floors/compliance.md /tmp/test-05c
PATH="$HOME/.local/bin:$PATH" bash ops/compile-floor.sh --dry-run examples/05-operational-maturity/floors/behavioral.md /tmp/test-05b
```

Expected: compliance exits 0 with 3 rules, behavioral exits 0 with 1 rule.

- [ ] **Step 8: Update README.md**

Update structure (floors/, behavioral.md, ops/checks/). Add note: "**New in this example:** Multi-floor governance — compliance floor (CRO) and behavioral floor (COO). Full enforcement block coverage. Per-session triage cadence. Floor compilation in setup."

- [ ] **Step 9: Commit**

```bash
git add examples/05-operational-maturity/
git commit -m "feat(#14): update 05-operational-maturity with multi-floor and behavioral floor"
```

---

## Task 6: Update Top-Level Examples README

**Files:**

- Modify: `examples/README.md`

- [ ] **Step 1: Update the progression table**

Replace the current table with:

```markdown
| Example                                             | Focus                           | Specialists                  | Compliance Rules | Enforcement Blocks | Floors                  | Pace  | Setup Hook                     |
| --------------------------------------------------- | ------------------------------- | ---------------------------- | ---------------- | ------------------ | ----------------------- | ----- | ------------------------------ |
| [01-getting-started](01-getting-started/)           | Full lifecycle, minimum config  | 1 (developer)                | 3                | 0                  | compliance              | Crawl | —                              |
| [02-ecommerce](02-ecommerce/)                       | Multi-specialist, inheritance   | 2 (frontend + backend)       | 5                | 0                  | compliance              | Crawl | —                              |
| [03-multi-team](03-multi-team/)                     | Review gates, enforcement intro | 2 + 1 reviewer               | 4                | 2                  | compliance              | Crawl | —                              |
| [04-compliance-heavy](04-compliance-heavy/)         | Regulated domain, thick floor   | 1 + 1 reviewer               | 7                | 3                  | compliance              | Crawl | Seeds proposals                |
| [05-operational-maturity](05-operational-maturity/) | Mature fleet, multi-floor       | 3 (frontend + backend + e2e) | 5+2              | 4                  | compliance + behavioral | Walk  | Seeds metrics, compiles floors |
```

- [ ] **Step 2: Update any `compliance-floor.md` references to `floors/compliance.md`**

- [ ] **Step 3: Commit**

```bash
git add examples/README.md
git commit -m "docs(#14): update examples README with new progression table"
```

---

## Task 7: Verify test-example.sh Works

**Files:**

- None modified (verification only)

- [ ] **Step 1: Check that test-example.sh doesn't hardcode compliance-floor.md**

```bash
grep -n 'compliance-floor' ops/test-example.sh
```

If any references found, update them. If none, no changes needed.

- [ ] **Step 2: Dry-run test for 01-getting-started**

```bash
bash ops/test-example.sh 01-getting-started 2>&1 | head -20
```

Verify it can set up the worktree without errors. Clean up:

```bash
bash ops/test-example.sh --cleanup 01-getting-started
```

- [ ] **Step 3: Commit if changes were needed, otherwise skip**

---

## Key Files Reference

| File                                                           | Why                                         |
| -------------------------------------------------------------- | ------------------------------------------- |
| `docs/superpowers/specs/2026-03-26-examples-refresh-design.md` | The spec                                    |
| `examples/*/fleet-config.json`                                 | Fleet configs being updated                 |
| `examples/*/compliance-floor.md`                               | Being moved to `floors/compliance.md`       |
| `ops/compile-floor.sh`                                         | Used to validate enforcement blocks compile |
| `ops/test-example.sh`                                          | Used to verify examples still work          |
