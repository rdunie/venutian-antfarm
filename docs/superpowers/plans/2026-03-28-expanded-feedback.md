# Expanded Behavioral Feedback Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Enable all agents to participate in behavioral feedback via a recommend-formalize-escalate lifecycle, with origin tier tracking and programmatic enforcement.

**Architecture:** Extend `ops/rewards-log.sh` (renamed to `ops/feedback-log.sh`) with four new subcommands (`recommend`, `formalize`, `reject`, `check-escalations`). Add origin tier tagging to existing direct entries. Add feedback pathways to fleet-config and escalation enforcement via hooks.

**Tech Stack:** Bash, jq, sha256sum (existing toolchain)

**Spec:** `docs/superpowers/specs/2026-03-28-expanded-feedback-design.md`

---

### Task 1: Rename rewards-log.sh to feedback-log.sh with backward-compat shim

**Files:**

- Rename: `ops/rewards-log.sh` -> `ops/feedback-log.sh`
- Create: `ops/rewards-log.sh` (deprecation shim)
- Rename: `ops/tests/test-rewards-log.sh` -> `ops/tests/test-feedback-log.sh`

- [ ] **Step 1: Rename the script**

```bash
git mv ops/rewards-log.sh ops/feedback-log.sh
```

- [ ] **Step 2: Update the script header and env var names**

In `ops/feedback-log.sh`, update the header comment block:

```bash
# feedback-log.sh — Behavioral feedback helper
#
# Single entry point for all ledger writes and queries.
# Agents never edit the ledger directly — always use this script.
#
# Usage:
#   ops/feedback-log.sh reprimand --issuer <agent> --subject <agent> ...
#   ops/feedback-log.sh kudo --issuer <agent> --subject <agent> ...
#   ops/feedback-log.sh recommend --issuer <agent> --subject <agent> --type <kudo|reprimand> ...
#   ops/feedback-log.sh formalize <P-id> --issuer <supervisor>
#   ops/feedback-log.sh reject <P-id> --issuer <supervisor> --reason "..."
#   ops/feedback-log.sh check-escalations
#   ops/feedback-log.sh profile <agent>
#   ops/feedback-log.sh tensions [--item <id>]
#
# Env vars (for testing — defaults to repo paths):
#   FEEDBACK_LEDGER    Override ledger path (REWARDS_LEDGER still works)
#   FEEDBACK_CHECKSUM  Override checksum path (REWARDS_CHECKSUM still works)
#   FINDINGS_REGISTER  Override findings register path
#   METRICS_LOG_FILE   Override metrics log path
```

Update the env var lines to support both old and new names:

```bash
LEDGER="${FEEDBACK_LEDGER:-${REWARDS_LEDGER:-$REPO_ROOT/.claude/rewards/ledger.md}}"
CHECKSUM="${FEEDBACK_CHECKSUM:-${REWARDS_CHECKSUM:-$REPO_ROOT/.claude/rewards/ledger-checksum.sha256}}"
```

Update the usage line:

```bash
echo "Usage: ops/feedback-log.sh <reprimand|kudo|recommend|formalize|reject|check-escalations|profile|tensions> [args...]" >&2
```

- [ ] **Step 3: Create the backward-compat shim**

Create `ops/rewards-log.sh`:

```bash
#!/usr/bin/env bash
# DEPRECATED: Use ops/feedback-log.sh instead. This shim will be removed in a future version.
echo "WARNING: ops/rewards-log.sh is deprecated. Use ops/feedback-log.sh instead." >&2
exec "$(cd "$(dirname "$0")" && pwd)/feedback-log.sh" "$@"
```

Make it executable: `chmod +x ops/rewards-log.sh`

- [ ] **Step 4: Rename the test file**

```bash
git mv ops/tests/test-rewards-log.sh ops/tests/test-feedback-log.sh
```

Update the `REWARDS_LOG` variable inside the test: rename it to `FEEDBACK_LOG` and change the path from `rewards-log.sh` to `feedback-log.sh`. Also update all references from `$REWARDS_LOG` to `$FEEDBACK_LOG` throughout the test file.

- [ ] **Step 5: Run existing tests to verify rename didn't break anything**

Run: `bash ops/tests/test-feedback-log.sh`
Expected: `21 passed, 0 failed, 21 total`

- [ ] **Step 6: Commit**

```bash
git add ops/feedback-log.sh ops/rewards-log.sh ops/tests/test-feedback-log.sh
git commit -m "refactor(#28): rename rewards-log.sh to feedback-log.sh with backward-compat shim"
```

---

### Task 2: Add origin tier tagging to existing direct entries

**Files:**

- Modify: `ops/feedback-log.sh` (reprimand and kudo subcommands)
- Modify: `ops/tests/test-feedback-log.sh`

- [ ] **Step 1: Write failing tests for origin tier on direct entries**

Add to the test file, in a new section `=== Origin Tier ===`:

```bash
echo ""
echo "=== Origin Tier ==="

# Reprimand from governance agent should have origin tier
"${FEEDBACK_LOG}" reprimand --issuer ciso --subject backend-specialist \
  --domain security --severity high \
  --description "Test governance tier" --evidence "test"
assert_contains "reprimand has governance origin tier" \
  "${LEDGER}" "Origin tier.*governance"

# Kudo from core agent should have core origin tier
"${FEEDBACK_LOG}" kudo --issuer product-owner --subject backend-specialist \
  --domain delivery \
  --description "Test core tier" --evidence "test"
assert_contains "kudo has core origin tier" \
  "${LEDGER}" "Origin tier.*core"
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `bash ops/tests/test-feedback-log.sh`
Expected: The two new origin tier tests FAIL (pattern not found)

- [ ] **Step 3: Add tier resolution helper and origin tier to reprimand/kudo**

Add a helper function after `update_checksum()` in `ops/feedback-log.sh`:

```bash
# Resolve agent tier from fleet-config.json
resolve_tier() {
  local agent="$1"
  local config="$REPO_ROOT/fleet-config.json"
  if [[ ! -f "$config" ]] || ! command -v jq &>/dev/null; then
    echo "unknown"
    return
  fi
  # Check governance array
  if jq -e --arg a "$agent" '.agents.governance | index($a)' "$config" &>/dev/null; then
    echo "governance"
    return
  fi
  # Check core array
  if jq -e --arg a "$agent" '.agents.core | index($a)' "$config" &>/dev/null; then
    echo "core"
    return
  fi
  echo "specialist"
}
```

In the `reprimand)` case, after the `**Evidence:**` line in the heredoc, add:

```bash
local_tier=$(resolve_tier "$ISSUER")
```

And add this line to the ledger append block (after Evidence):

```bash
echo "**Origin tier:** ${local_tier}"
```

Do the same for the `kudo)` case.

- [ ] **Step 4: Run tests to verify they pass**

Run: `bash ops/tests/test-feedback-log.sh`
Expected: All tests pass including the two new origin tier tests

- [ ] **Step 5: Commit**

```bash
git add ops/feedback-log.sh ops/tests/test-feedback-log.sh
git commit -m "feat(#28): add origin tier tagging to direct feedback entries"
```

---

### Task 3: Add `recommend` subcommand with supervisor resolution

**Files:**

- Modify: `ops/feedback-log.sh`
- Modify: `ops/tests/test-feedback-log.sh`

This task requires a `fleet-config.json` in the test environment. The test should create a minimal one in the temp directory.

- [ ] **Step 1: Write failing tests for recommend**

Add a new section `=== Recommend ===` to the test file. The tests use the same env var override pattern as existing tests (`FEEDBACK_LEDGER`, `FEEDBACK_CHECKSUM`, etc.) plus `REPO_ROOT` for fleet-config resolution. Define a helper variable `ENVS` to reduce repetition. Before the tests, create a minimal fleet-config.json in the temp dir:

```bash
echo ""
echo "=== Recommend ==="

# Helper: env var overrides for all new tests (matches existing pattern)
LEDGER="$TMPDIR/rewards/ledger.md"
CHECKSUM="$TMPDIR/rewards/ledger-checksum.sha256"
FINDINGS_REG="$TMPDIR/findings/register.md"
METRICS_FILE="$TMPDIR/metrics/events.jsonl"

# Create a minimal fleet-config for supervisor resolution
cat > "${TMPDIR}/fleet-config.json" <<'FLEET'
{
  "agents": {
    "governance": ["cro", "ciso", "ceo", "cto", "cfo", "coo", "cko"],
    "core": ["product-owner", "solution-architect", "scrum-master", "knowledge-ops", "platform-ops", "compliance-auditor"]
  },
  "rewards": {
    "escalation_deadline_days": 7
  },
  "pathways": {
    "declared": {
      "feedback": [
        "security-reviewer -> ciso",
        "backend-specialist -> solution-architect"
      ],
      "escalation": [
        "* -> solution-architect",
        "* -> scrum-master",
        "* -> product-owner"
      ],
      "governance": [
        "ciso -> cro",
        "cto -> solution-architect",
        "* -> ceo"
      ]
    }
  }
}
FLEET

# Test: recommend creates a P-entry
rec_exit=0
FEEDBACK_LEDGER="$LEDGER" FEEDBACK_CHECKSUM="$CHECKSUM" \
FINDINGS_REGISTER="$FINDINGS_REG" METRICS_LOG_FILE="$METRICS_FILE" \
REPO_ROOT="${TMPDIR}" "${FEEDBACK_LOG}" recommend --issuer security-reviewer --subject backend-specialist \
  --type reprimand --domain security --severity medium \
  --description "Shallow validation" --evidence "No sanitization" \
  --item 42 || rec_exit=$?
assert_exit "recommend exits 0" 0 "${rec_exit}"
assert_contains "P-001 created" "${LEDGER}" "P-001 \\[proposal\\]"
assert_contains "proposal has supervisor" "${LEDGER}" "Supervisor.*ciso"
assert_contains "proposal has status pending" "${LEDGER}" "Status.*pending"
assert_contains "proposal has escalation deadline" "${LEDGER}" "Escalation deadline"
assert_contains "proposal has type reprimand" "${LEDGER}" "Type.*reprimand"
assert_contains "proposal has origin tier specialist" "${LEDGER}" "Origin tier.*specialist"

# Test: recommend without --type fails
rec_notype_exit=0
"${FEEDBACK_LOG}" recommend --issuer security-reviewer --subject backend-specialist \
  --domain security --description "test" --evidence "test" 2>/dev/null || rec_notype_exit=$?
assert_exit "recommend without --type fails" 1 "${rec_notype_exit}"

# Test: recommend with fallback to escalation wildcard
rec_fallback_exit=0
FEEDBACK_LEDGER="$LEDGER" FEEDBACK_CHECKSUM="$CHECKSUM" \
FINDINGS_REGISTER="$FINDINGS_REG" METRICS_LOG_FILE="$METRICS_FILE" \
REPO_ROOT="${TMPDIR}" "${FEEDBACK_LOG}" recommend --issuer e2e-test-engineer --subject frontend-specialist \
  --type kudo --domain testing \
  --description "Great coverage" --evidence "100% coverage" || rec_fallback_exit=$?
assert_exit "recommend with fallback exits 0" 0 "${rec_fallback_exit}"
assert_contains "fallback supervisor is solution-architect" "${LEDGER}" "Supervisor.*solution-architect"
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `bash ops/tests/test-feedback-log.sh`
Expected: New recommend tests FAIL (unknown subcommand)

- [ ] **Step 3: Add flag parsing for --type and --reason**

In the flag parsing section of `ops/feedback-log.sh`, add after the `--evidence` case:

```bash
    --type)        TYPE="$2";        shift 2 ;;
    --reason)      REASON="$2";      shift 2 ;;
```

Add `TYPE="" REASON=""` to the variable initialization line alongside the other vars.

- [ ] **Step 4: Add supervisor resolution helper**

Add after the `resolve_tier()` function:

```bash
# Resolve supervisor for a specialist agent from fleet-config pathways
resolve_supervisor() {
  local issuer="$1"
  local config="$REPO_ROOT/fleet-config.json"
  if [[ ! -f "$config" ]] || ! command -v jq &>/dev/null; then
    echo ""
    return
  fi
  # Check explicit feedback pathways first
  local feedback_target
  feedback_target=$(jq -r --arg i "$issuer" \
    '.pathways.declared.feedback[]? | select(startswith($i + " -> ")) | split(" -> ")[1]' \
    "$config" 2>/dev/null | head -1)
  if [[ -n "$feedback_target" ]]; then
    echo "$feedback_target"
    return
  fi
  # Fall back to escalation wildcards (first match)
  local escalation_target
  escalation_target=$(jq -r \
    '.pathways.declared.escalation[]? | select(startswith("* -> ")) | split(" -> ")[1]' \
    "$config" 2>/dev/null | head -1)
  if [[ -n "$escalation_target" ]]; then
    echo "$escalation_target"
    return
  fi
  echo ""
}
```

- [ ] **Step 5: Implement the recommend subcommand**

Add a new case in the `case "$SUBCOMMAND"` block, before the `*)` default:

```bash
  recommend)
    [[ -z "$ISSUER" ]]      && echo "ERROR: --issuer required" >&2 && exit 1
    [[ -z "$SUBJECT" ]]     && echo "ERROR: --subject required" >&2 && exit 1
    [[ -z "$TYPE" ]]        && echo "ERROR: --type required (kudo|reprimand)" >&2 && exit 1
    [[ -z "$DOMAIN" ]]      && echo "ERROR: --domain required" >&2 && exit 1
    [[ -z "$DESCRIPTION" ]] && echo "ERROR: --description required" >&2 && exit 1
    [[ -z "$EVIDENCE" ]]    && echo "ERROR: --evidence required" >&2 && exit 1
    if [[ "$TYPE" == "reprimand" && -z "$SEVERITY" ]]; then
      echo "ERROR: --severity required for reprimand recommendations" >&2
      exit 1
    fi

    local_supervisor=$(resolve_supervisor "$ISSUER")
    if [[ -z "$local_supervisor" ]]; then
      echo "ERROR: no feedback pathway or escalation fallback found for issuer '$ISSUER'" >&2
      exit 1
    fi

    local_id=$(next_id "P")
    ts="$(date -u +%Y-%m-%d)"

    # Calculate escalation deadline (no 'local' — we're in a case block, not a function)
    deadline_days=7
    config="$REPO_ROOT/fleet-config.json"
    if [[ -f "$config" ]] && command -v jq &>/dev/null; then
      deadline_days=$(jq -r '.rewards.escalation_deadline_days // 7' "$config" 2>/dev/null || echo 7)
    fi
    deadline=$(date -u -d "+${deadline_days} days" +%Y-%m-%d 2>/dev/null || date -u -v+${deadline_days}d +%Y-%m-%d 2>/dev/null || echo "unknown")

    # Ensure subject section exists
    if ! grep -q "^## ${SUBJECT}$" "$LEDGER" 2>/dev/null; then
      echo "" >> "$LEDGER"
      echo "## ${SUBJECT}" >> "$LEDGER"
    fi

    {
      echo ""
      echo "### ${local_id} [proposal] ${ts} — ${ISSUER} / ${DOMAIN}"
      echo ""
      echo "**Type:** ${TYPE}"
      [[ -n "$SEVERITY" ]] && echo "**Severity:** ${SEVERITY}"
      echo "**Subject:** ${SUBJECT}"
      echo "**Domain:** ${DOMAIN}"
      [[ -n "$ITEM" ]] && echo "**Item:** ${ITEM}"
      echo "**Description:** ${DESCRIPTION}"
      echo "**Evidence:** ${EVIDENCE}"
      echo "**Supervisor:** ${local_supervisor}"
      echo "**Origin tier:** specialist"
      echo "**Status:** pending"
      echo "**Escalation deadline:** ${deadline}"
    } >> "$LEDGER"

    # Emit metric event
    "$SCRIPT_DIR/metrics-log.sh" feedback-proposed \
      --from "$ISSUER" --subject "$SUBJECT" --type "$TYPE" \
      --scope "$DOMAIN" --severity "$SEVERITY" \
      ${ITEM:+--item "$ITEM"} --proposal "$local_id" \
      --to "$local_supervisor" 2>/dev/null || true

    update_checksum
    echo "proposal_id=$local_id"
    ;;
```

- [ ] **Step 6: Run tests to verify they pass**

Run: `bash ops/tests/test-feedback-log.sh`
Expected: All tests pass including new recommend tests

- [ ] **Step 7: Commit**

```bash
git add ops/feedback-log.sh ops/tests/test-feedback-log.sh
git commit -m "feat(#28): add recommend subcommand with supervisor resolution"
```

---

### Task 4: Add `formalize` and `reject` subcommands

**Files:**

- Modify: `ops/feedback-log.sh`
- Modify: `ops/tests/test-feedback-log.sh`

- [ ] **Step 1: Write failing tests for formalize and reject**

Add a new section `=== Formalize/Reject ===`:

```bash
echo ""
echo "=== Formalize/Reject ==="

# Setup: create a proposal to formalize
FEEDBACK_LEDGER="$LEDGER" FEEDBACK_CHECKSUM="$CHECKSUM" \
FINDINGS_REGISTER="$FINDINGS_REG" METRICS_LOG_FILE="$METRICS_FILE" \
REPO_ROOT="${TMPDIR}" "${FEEDBACK_LOG}" recommend --issuer security-reviewer --subject backend-specialist \
  --type reprimand --domain security --severity high \
  --description "Formalize test" --evidence "test evidence" --item 99 >/dev/null

# Get the proposal ID (last P-xxx in ledger)
FORMAL_PID=$(grep -oE 'P-[0-9]+' "$LEDGER" | tail -1)

# Test: formalize creates R-entry with origin
formal_exit=0
FEEDBACK_LEDGER="$LEDGER" FEEDBACK_CHECKSUM="$CHECKSUM" \
FINDINGS_REGISTER="$FINDINGS_REG" METRICS_LOG_FILE="$METRICS_FILE" \
REPO_ROOT="${TMPDIR}" "${FEEDBACK_LOG}" formalize "$FORMAL_PID" --issuer ciso || formal_exit=$?
assert_exit "formalize exits 0" 0 "${formal_exit}"
assert_contains "formalized entry has Origin" "${LEDGER}" "Origin.*${FORMAL_PID}"
assert_contains "formalized entry has specialist tier" "${LEDGER}" "Origin tier.*specialist"
assert_contains "P-entry updated to formalized" "${LEDGER}" "Status.*formalized"

# Test: formalize wrong supervisor fails
FEEDBACK_LEDGER="$LEDGER" FEEDBACK_CHECKSUM="$CHECKSUM" \
FINDINGS_REGISTER="$FINDINGS_REG" METRICS_LOG_FILE="$METRICS_FILE" \
REPO_ROOT="${TMPDIR}" "${FEEDBACK_LOG}" recommend --issuer security-reviewer --subject backend-specialist \
  --type kudo --domain security \
  --description "Wrong sup test" --evidence "test" >/dev/null
WRONG_PID=$(grep -oE 'P-[0-9]+' "$LEDGER" | tail -1)
wrong_sup_exit=0
FEEDBACK_LEDGER="$LEDGER" FEEDBACK_CHECKSUM="$CHECKSUM" \
FINDINGS_REGISTER="$FINDINGS_REG" METRICS_LOG_FILE="$METRICS_FILE" \
REPO_ROOT="${TMPDIR}" "${FEEDBACK_LOG}" formalize "$WRONG_PID" --issuer ceo 2>/dev/null || wrong_sup_exit=$?
assert_exit "formalize wrong supervisor fails" 1 "${wrong_sup_exit}"

# Test: reject with reason
FEEDBACK_LEDGER="$LEDGER" FEEDBACK_CHECKSUM="$CHECKSUM" \
FINDINGS_REGISTER="$FINDINGS_REG" METRICS_LOG_FILE="$METRICS_FILE" \
REPO_ROOT="${TMPDIR}" "${FEEDBACK_LOG}" recommend --issuer security-reviewer --subject backend-specialist \
  --type reprimand --domain security --severity low \
  --description "Reject test" --evidence "test" >/dev/null
REJECT_PID=$(grep -oE 'P-[0-9]+' "$LEDGER" | tail -1)
reject_exit=0
FEEDBACK_LEDGER="$LEDGER" FEEDBACK_CHECKSUM="$CHECKSUM" \
FINDINGS_REGISTER="$FINDINGS_REG" METRICS_LOG_FILE="$METRICS_FILE" \
REPO_ROOT="${TMPDIR}" "${FEEDBACK_LOG}" reject "$REJECT_PID" --issuer ciso --reason "Insufficient evidence" || reject_exit=$?
assert_exit "reject exits 0" 0 "${reject_exit}"
assert_contains "P-entry updated to rejected" "${LEDGER}" "Status.*rejected"
assert_contains "reject reason recorded" "${LEDGER}" "Insufficient evidence"

# Test: reject without reason fails
FEEDBACK_LEDGER="$LEDGER" FEEDBACK_CHECKSUM="$CHECKSUM" \
FINDINGS_REGISTER="$FINDINGS_REG" METRICS_LOG_FILE="$METRICS_FILE" \
REPO_ROOT="${TMPDIR}" "${FEEDBACK_LOG}" recommend --issuer security-reviewer --subject backend-specialist \
  --type kudo --domain security \
  --description "No reason test" --evidence "test" >/dev/null
NOREASON_PID=$(grep -oE 'P-[0-9]+' "$LEDGER" | tail -1)
noreason_exit=0
FEEDBACK_LEDGER="$LEDGER" FEEDBACK_CHECKSUM="$CHECKSUM" \
FINDINGS_REGISTER="$FINDINGS_REG" METRICS_LOG_FILE="$METRICS_FILE" \
REPO_ROOT="${TMPDIR}" "${FEEDBACK_LOG}" reject "$NOREASON_PID" --issuer ciso 2>/dev/null || noreason_exit=$?
assert_exit "reject without reason fails" 1 "${noreason_exit}"
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `bash ops/tests/test-feedback-log.sh`
Expected: New formalize/reject tests FAIL

- [ ] **Step 3: Add ledger-reading helpers**

Add after `resolve_supervisor()`:

```bash
# Read a field value from a P-entry in the ledger
read_proposal_field() {
  local pid="$1"
  local field="$2"
  sed -n "/^### ${pid} /,/^### /p" "$LEDGER" | grep "^\*\*${field}:\*\*" | head -1 | sed "s/.*\*\*${field}:\*\* //"
}

# Update a P-entry's status line in the ledger (append-friendly: adds new status line)
update_proposal_status() {
  local pid="$1"
  local new_status="$2"
  local tmpfile
  tmpfile=$(mktemp)
  awk -v pid="### ${pid} " -v new_status="$new_status" '
    $0 ~ pid { in_entry=1 }
    in_entry && /^\*\*Status:\*\*/ { print "**Status:** " new_status; in_entry=0; next }
    in_entry && /^### / && !($0 ~ pid) { in_entry=0 }
    { print }
  ' "$LEDGER" > "$tmpfile" && mv "$tmpfile" "$LEDGER"
}
```

- [ ] **Step 4: Implement formalize subcommand**

Add before the `*)` default case:

```bash
  formalize)
    # First positional arg is the P-id
    local_pid=""
    if [[ -n "$SUBJECT" && "$SUBJECT" =~ ^P-[0-9]+ ]]; then
      local_pid="$SUBJECT"
      SUBJECT=""
    fi
    [[ -z "$local_pid" ]] && echo "ERROR: formalize requires a proposal ID (e.g., P-001)" >&2 && exit 1
    [[ -z "$ISSUER" ]]    && echo "ERROR: --issuer required" >&2 && exit 1

    # Validate proposal exists and is pending (no 'local' — case block, not function)
    if ! grep -q "^### ${local_pid} \[proposal\]" "$LEDGER" 2>/dev/null; then
      echo "ERROR: proposal '${local_pid}' not found in ledger" >&2
      exit 1
    fi
    p_status=$(read_proposal_field "$local_pid" "Status")
    if [[ ! "$p_status" =~ ^pending ]]; then
      echo "ERROR: proposal '${local_pid}' is not pending (status: ${p_status})" >&2
      exit 1
    fi
    p_supervisor=$(read_proposal_field "$local_pid" "Supervisor")
    if [[ "$ISSUER" != "$p_supervisor" ]]; then
      echo "ERROR: issuer '${ISSUER}' is not the assigned supervisor '${p_supervisor}' for ${local_pid}" >&2
      exit 1
    fi

    # Read proposal fields
    p_type=$(read_proposal_field "$local_pid" "Type")
    p_severity=$(read_proposal_field "$local_pid" "Severity")
    p_subject=$(read_proposal_field "$local_pid" "Subject")
    p_domain=$(read_proposal_field "$local_pid" "Domain")
    p_item=$(read_proposal_field "$local_pid" "Item")
    p_description=$(read_proposal_field "$local_pid" "Description")
    p_evidence=$(read_proposal_field "$local_pid" "Evidence")

    # Determine new entry type
    new_prefix="K"
    [[ "$p_type" == "reprimand" ]] && new_prefix="R"
    new_id=$(next_id "$new_prefix")
    ts="$(date -u +%Y-%m-%d)"

    # Ensure subject section exists
    if ! grep -q "^## ${p_subject}$" "$LEDGER" 2>/dev/null; then
      echo "" >> "$LEDGER"
      echo "## ${p_subject}" >> "$LEDGER"
    fi

    # Append the formalized entry
    {
      echo ""
      echo "### ${new_id} [${p_type}] ${ts} — ${ISSUER} / ${p_domain}"
      echo ""
      [[ "$p_type" == "reprimand" && -n "$p_severity" ]] && echo "**Severity:** ${p_severity}"
      [[ -n "$p_item" ]] && echo "**Item:** ${p_item}"
      echo "**Description:** ${p_description}"
      echo "**Evidence:** ${p_evidence}"
      echo "**Origin:** ${local_pid}"
      echo "**Origin tier:** specialist"
    } >> "$LEDGER"

    # Update P-entry status
    update_proposal_status "$local_pid" "formalized (${new_id})"

    # Emit metric events
    "$SCRIPT_DIR/metrics-log.sh" feedback-formalized \
      --proposal "$local_pid" --reward-id "$new_id" \
      --from "$ISSUER" 2>/dev/null || true
    "$SCRIPT_DIR/metrics-log.sh" reward-issued \
      --type "$p_type" --from "$ISSUER" --subject "$p_subject" \
      --scope "$p_domain" --severity "$p_severity" \
      ${p_item:+--item "$p_item"} --reward-id "$new_id" 2>/dev/null || true

    update_checksum

    # Check for tension (standard R/K entry triggers existing logic)
    check_tension "$p_type" "$p_subject" "$p_item" "$new_id"

    echo "reward_id=$new_id"
    ;;
```

- [ ] **Step 5: Implement reject subcommand**

Add before the `*)` default case:

```bash
  reject)
    local_pid=""
    if [[ -n "$SUBJECT" && "$SUBJECT" =~ ^P-[0-9]+ ]]; then
      local_pid="$SUBJECT"
      SUBJECT=""
    fi
    [[ -z "$local_pid" ]] && echo "ERROR: reject requires a proposal ID (e.g., P-001)" >&2 && exit 1
    [[ -z "$ISSUER" ]]    && echo "ERROR: --issuer required" >&2 && exit 1
    [[ -z "$REASON" ]]    && echo "ERROR: --reason required" >&2 && exit 1

    # Validate proposal exists and is pending (no 'local' — case block)
    if ! grep -q "^### ${local_pid} \[proposal\]" "$LEDGER" 2>/dev/null; then
      echo "ERROR: proposal '${local_pid}' not found in ledger" >&2
      exit 1
    fi
    p_status=$(read_proposal_field "$local_pid" "Status")
    if [[ ! "$p_status" =~ ^pending ]]; then
      echo "ERROR: proposal '${local_pid}' is not pending (status: ${p_status})" >&2
      exit 1
    fi
    p_supervisor=$(read_proposal_field "$local_pid" "Supervisor")
    if [[ "$ISSUER" != "$p_supervisor" ]]; then
      echo "ERROR: issuer '${ISSUER}' is not the assigned supervisor '${p_supervisor}' for ${local_pid}" >&2
      exit 1
    fi

    # Update P-entry status
    update_proposal_status "$local_pid" "rejected — ${REASON}"

    # Emit metric event
    "$SCRIPT_DIR/metrics-log.sh" feedback-rejected \
      --proposal "$local_pid" --from "$ISSUER" \
      --reason "$REASON" 2>/dev/null || true

    update_checksum
    echo "rejected=$local_pid"
    ;;
```

- [ ] **Step 6: Run tests to verify they pass**

Run: `bash ops/tests/test-feedback-log.sh`
Expected: All tests pass

- [ ] **Step 7: Commit**

```bash
git add ops/feedback-log.sh ops/tests/test-feedback-log.sh
git commit -m "feat(#28): add formalize and reject subcommands"
```

---

### Task 5: Add `check-escalations` subcommand

**Files:**

- Modify: `ops/feedback-log.sh`
- Modify: `ops/tests/test-feedback-log.sh`

- [ ] **Step 1: Write failing tests for check-escalations**

Add a new section `=== Escalation ===`:

```bash
echo ""
echo "=== Escalation ==="

# Create a proposal with a past deadline by backdating
# We do this by directly manipulating the ledger (test-only)
FEEDBACK_LEDGER="$LEDGER" FEEDBACK_CHECKSUM="$CHECKSUM" \
FINDINGS_REGISTER="$FINDINGS_REG" METRICS_LOG_FILE="$METRICS_FILE" \
REPO_ROOT="${TMPDIR}" "${FEEDBACK_LOG}" recommend --issuer security-reviewer --subject backend-specialist \
  --type reprimand --domain security --severity medium \
  --description "Stale proposal" --evidence "test" >/dev/null
STALE_PID=$(grep -oE 'P-[0-9]+' "$LEDGER" | tail -1)
# Backdate the deadline to yesterday
YESTERDAY=$(date -u -d "-1 day" +%Y-%m-%d 2>/dev/null || date -u -v-1d +%Y-%m-%d 2>/dev/null)
# Replace the deadline for this entry
TMPF=$(mktemp)
awk -v pid="### ${STALE_PID} " -v yesterday="$YESTERDAY" '
  $0 ~ pid { in_entry=1 }
  in_entry && /^\*\*Escalation deadline:\*\*/ { print "**Escalation deadline:** " yesterday; in_entry=0; next }
  in_entry && /^### / && !($0 ~ pid) { in_entry=0 }
  { print }
' "$LEDGER" > "$TMPF" && mv "$TMPF" "$LEDGER"

# Run check-escalations
esc_exit=0
FEEDBACK_LEDGER="$LEDGER" FEEDBACK_CHECKSUM="$CHECKSUM" \
FINDINGS_REGISTER="$FINDINGS_REG" METRICS_LOG_FILE="$METRICS_FILE" \
REPO_ROOT="${TMPDIR}" "${FEEDBACK_LOG}" check-escalations || esc_exit=$?
assert_exit "check-escalations exits 0" 0 "${esc_exit}"
assert_contains "escalated proposal has new supervisor" "${LEDGER}" "Supervisor.*cro"
assert_contains "escalated proposal status is pending" "${LEDGER}" "Status.*pending"

# Create a proposal that is NOT past deadline — should not be escalated
FEEDBACK_LEDGER="$LEDGER" FEEDBACK_CHECKSUM="$CHECKSUM" \
FINDINGS_REGISTER="$FINDINGS_REG" METRICS_LOG_FILE="$METRICS_FILE" \
REPO_ROOT="${TMPDIR}" "${FEEDBACK_LOG}" recommend --issuer backend-specialist --subject frontend-specialist \
  --type kudo --domain code-quality \
  --description "Fresh proposal" --evidence "test" >/dev/null
FRESH_PID=$(grep -oE 'P-[0-9]+' "$LEDGER" | tail -1)
FEEDBACK_LEDGER="$LEDGER" FEEDBACK_CHECKSUM="$CHECKSUM" \
FINDINGS_REGISTER="$FINDINGS_REG" METRICS_LOG_FILE="$METRICS_FILE" \
REPO_ROOT="${TMPDIR}" "${FEEDBACK_LOG}" check-escalations >/dev/null
# The fresh proposal should still have its original supervisor
fresh_sup=$(sed -n "/^### ${FRESH_PID} /,/^### /p" "$LEDGER" | grep '^\*\*Supervisor:\*\*' | head -1 | sed 's/.*\*\* //')
if [[ "$fresh_sup" == "solution-architect" ]]; then
  echo -e "  ${GREEN}PASS${NC} fresh proposal not escalated"
  PASS=$((PASS + 1))
else
  echo -e "  ${RED}FAIL${NC} fresh proposal should not be escalated, supervisor is: ${fresh_sup}"
  FAIL=$((FAIL + 1))
fi
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `bash ops/tests/test-feedback-log.sh`
Expected: New escalation tests FAIL

- [ ] **Step 3: Add escalation supervisor resolution helper**

Add after `resolve_supervisor()`:

```bash
# Resolve the next-tier supervisor for escalation (who supervises the current supervisor)
resolve_escalation_target() {
  local current_supervisor="$1"
  local config="$REPO_ROOT/fleet-config.json"
  if [[ ! -f "$config" ]] || ! command -v jq &>/dev/null; then
    echo "ceo"
    return
  fi
  # Look for a governance pathway where current_supervisor is on the left side
  local target
  target=$(jq -r --arg s "$current_supervisor" \
    '.pathways.declared.governance[]? | select(startswith($s + " -> ")) | split(" -> ")[1]' \
    "$config" 2>/dev/null | head -1)
  if [[ -n "$target" ]]; then
    echo "$target"
    return
  fi
  # Terminal fallback: CEO
  echo "ceo"
}
```

- [ ] **Step 4: Implement check-escalations subcommand**

Add before the `*)` default case:

```bash
  check-escalations)
    today=$(date -u +%Y-%m-%d)
    escalated_count=0

    # Find all pending proposals with past deadlines
    current_pid=""
    current_deadline=""
    current_supervisor=""
    while IFS= read -r line; do
      if [[ "$line" =~ ^###\ (P-[0-9]+)\ \[proposal\] ]]; then
        current_pid="${BASH_REMATCH[1]}"
        current_deadline=""
        current_supervisor=""
      fi
      if [[ -n "$current_pid" && "$line" =~ ^\*\*Status:\*\*\ pending ]]; then
        : # still pending (possibly escalated), keep processing
      elif [[ -n "$current_pid" && "$line" =~ ^\*\*Status:\*\* ]]; then
        current_pid=""  # not pending (formalized/rejected), skip
      fi
      if [[ -n "$current_pid" && "$line" =~ ^\*\*Escalation\ deadline:\*\*\ (.+) ]]; then
        current_deadline="${BASH_REMATCH[1]}"
      fi
      if [[ -n "$current_pid" && "$line" =~ ^\*\*Supervisor:\*\*\ (.+) ]]; then
        current_supervisor="${BASH_REMATCH[1]}"
      fi
      # When we have all fields and hit the next entry or EOF, check deadline
      if [[ -n "$current_pid" && -n "$current_deadline" && -n "$current_supervisor" ]]; then
        if [[ "$current_deadline" < "$today" || "$current_deadline" == "$today" ]]; then
          # Escalate this proposal (no 'local' — case block)
          new_supervisor=$(resolve_escalation_target "$current_supervisor")
          deadline_days=7
          config="$REPO_ROOT/fleet-config.json"
          if [[ -f "$config" ]] && command -v jq &>/dev/null; then
            deadline_days=$(jq -r '.rewards.escalation_deadline_days // 7' "$config" 2>/dev/null || echo 7)
          fi
          new_deadline=$(date -u -d "+${deadline_days} days" +%Y-%m-%d 2>/dev/null || date -u -v+${deadline_days}d +%Y-%m-%d 2>/dev/null || echo "unknown")

          # Update supervisor
          tmpfile=$(mktemp)
          awk -v pid="### ${current_pid} " -v new_sup="$new_supervisor" '
            $0 ~ pid { in_entry=1 }
            in_entry && /^\*\*Supervisor:\*\*/ { print "**Supervisor:** " new_sup; in_entry=0; next }
            in_entry && /^### / && !($0 ~ pid) { in_entry=0 }
            { print }
          ' "$LEDGER" > "$tmpfile" && mv "$tmpfile" "$LEDGER"

          # Update deadline
          tmpfile=$(mktemp)
          awk -v pid="### ${current_pid} " -v new_dl="$new_deadline" '
            $0 ~ pid { in_entry=1 }
            in_entry && /^\*\*Escalation deadline:\*\*/ { print "**Escalation deadline:** " new_dl; in_entry=0; next }
            in_entry && /^### / && !($0 ~ pid) { in_entry=0 }
            { print }
          ' "$LEDGER" > "$tmpfile" && mv "$tmpfile" "$LEDGER"

          # Update status to note escalation but keep pending
          update_proposal_status "$current_pid" "pending (escalated from ${current_supervisor})"

          # Add finding
          if [[ -f "$FINDINGS" ]]; then
            ts="$(date -u +%Y-%m-%d)"
            finding_entry="### [${ts}] normal -- Feedback proposal ${current_pid} escalated

**Found by:** feedback-system (auto)
**Category:** escalation
**Description:** Proposal ${current_pid} was not acted on by ${current_supervisor} before deadline. Escalated to ${new_supervisor}.
**Proposed action:** ${new_supervisor} should formalize or reject ${current_pid}
**Status:** open"
            if grep -q "^(none yet)" "$FINDINGS"; then
              tmpfile=$(mktemp)
              awk -v entry="$finding_entry" '{ if ($0 == "(none yet)") print entry; else print }' "$FINDINGS" > "$tmpfile" && mv "$tmpfile" "$FINDINGS"
            elif grep -q "^## Resolved Findings" "$FINDINGS"; then
              tmpfile=$(mktemp)
              awk -v entry="$finding_entry" '{ if ($0 == "## Resolved Findings") { print ""; print entry; print "" } print }' "$FINDINGS" > "$tmpfile" && mv "$tmpfile" "$FINDINGS"
            else
              echo "" >> "$FINDINGS"
              echo "$finding_entry" >> "$FINDINGS"
            fi
          fi

          # Emit metric
          "$SCRIPT_DIR/metrics-log.sh" feedback-escalated \
            --proposal "$current_pid" --from "$current_supervisor" \
            --to "$new_supervisor" 2>/dev/null || true

          echo "escalated: ${current_pid} (${current_supervisor} -> ${new_supervisor})"
          escalated_count=$((escalated_count + 1))
        fi
        current_pid=""
        current_deadline=""
        current_supervisor=""
      fi
    done < "$LEDGER"

    if [[ "$escalated_count" -eq 0 ]]; then
      echo "No proposals past deadline."
    fi
    update_checksum
    ;;
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `bash ops/tests/test-feedback-log.sh`
Expected: All tests pass

- [ ] **Step 6: Commit**

```bash
git add ops/feedback-log.sh ops/tests/test-feedback-log.sh
git commit -m "feat(#28): add check-escalations subcommand with auto-escalation"
```

---

### Task 6: Extend profile subcommand and add formalization nudge

**Files:**

- Modify: `ops/feedback-log.sh`
- Modify: `ops/tests/test-feedback-log.sh`

- [ ] **Step 1: Write failing tests for profile extensions**

Add a new section `=== Profile Extensions ===`:

```bash
echo ""
echo "=== Profile Extensions ==="

setup_ledger

# Create some entries with different tiers
FEEDBACK_LEDGER="$LEDGER" FEEDBACK_CHECKSUM="$CHECKSUM" \
FINDINGS_REGISTER="$FINDINGS_REG" METRICS_LOG_FILE="$METRICS_FILE" \
"${FEEDBACK_LOG}" reprimand --issuer ciso --subject backend-specialist \
  --domain security --severity high --description "tier test" --evidence "test"

FEEDBACK_LEDGER="$LEDGER" FEEDBACK_CHECKSUM="$CHECKSUM" \
FINDINGS_REGISTER="$FINDINGS_REG" METRICS_LOG_FILE="$METRICS_FILE" \
REPO_ROOT="${TMPDIR}" "${FEEDBACK_LOG}" recommend --issuer security-reviewer \
  --subject backend-specialist --type kudo --domain security \
  --description "pending test" --evidence "test"

# Profile should show origin tier breakdown and pending proposals
profile_output=$(FEEDBACK_LEDGER="$LEDGER" FEEDBACK_CHECKSUM="$CHECKSUM" \
  "${FEEDBACK_LOG}" profile backend-specialist)
assert_exit "profile exits 0" 0 $?

echo "$profile_output" > "$TMPDIR/profile-output.txt"
assert_contains "profile shows pending proposals" "$TMPDIR/profile-output.txt" "pending"
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `bash ops/tests/test-feedback-log.sh`
Expected: Profile extension tests FAIL

- [ ] **Step 3: Extend profile subcommand**

In the `profile)` case, after the existing "Recent" section, add:

```bash
    # Pending proposals
    pending_count=$(sed -n "/^## ${SUBJECT}$/,/^## [^#]/p" "$LEDGER" | grep -c "\\[proposal\\]" || true)
    pending_pending=$(sed -n "/^## ${SUBJECT}$/,/^## [^#]/p" "$LEDGER" | grep -c "Status.*pending" || true)
    if [[ "$pending_count" -gt 0 ]]; then
      echo "Proposals: ${pending_count} total (${pending_pending} pending)"
    fi

    # By origin tier
    echo "By tier:"
    for tier in governance core specialist; do
      tier_count=$(sed -n "/^## ${SUBJECT}$/,/^## [^#]/p" "$LEDGER" | grep -c "Origin tier.*${tier}" || true)
      [[ "$tier_count" -gt 0 ]] && echo "  ${tier} (${tier_count})"
    done
```

- [ ] **Step 4: Add formalization nudge to kudo/reprimand**

At the end of both the `reprimand)` and `kudo)` cases (after `echo "reward_id=$local_id"`), add:

```bash
    # Nudge: check if issuer has pending proposals to review
    if [[ -f "$LEDGER" ]]; then
      pending_for_issuer=$(grep -c "Supervisor.*${ISSUER}" "$LEDGER" 2>/dev/null || true)
      pending_status=$(grep -B5 "Supervisor.*${ISSUER}" "$LEDGER" 2>/dev/null | grep -c "Status.*pending" || true)
      if [[ "$pending_status" -gt 0 ]]; then
        echo "NOTICE: You have ${pending_status} pending proposal(s) awaiting your review. Use 'ops/feedback-log.sh formalize <P-id>' or 'reject <P-id>'." >&2
      fi
    fi
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `bash ops/tests/test-feedback-log.sh`
Expected: All tests pass

- [ ] **Step 6: Commit**

```bash
git add ops/feedback-log.sh ops/tests/test-feedback-log.sh
git commit -m "feat(#28): extend profile with tier breakdown and pending proposals, add formalization nudge"
```

---

### Task 7: Add new metric events to metrics-log.sh

**Files:**

- Modify: `ops/metrics-log.sh`

- [ ] **Step 1: Add the four new event handlers**

In `ops/metrics-log.sh`, add before the `*)` default case (after the `preflight-remediation` case):

```bash
  feedback-proposed)
    emit_event "$(jq -cn --arg ts "$TS" --arg event "$EVENT_TYPE" \
       --arg issuer "$FROM" --arg subject "$SUBJECT" --arg type "$DEPLOY_TYPE" \
       --arg domain "$SCOPE" --arg severity "$SEVERITY" \
       --arg item "$ITEM" --arg proposal_id "$PROPOSAL" --arg supervisor "$TO" \
       --arg agent "$AGENT" \
       '{"ts":$ts,"event":$event,"issuer":$issuer,"subject":$subject,"type":$type,"domain":$domain,"severity":$severity,"item":$item,"proposal_id":$proposal_id,"supervisor":$supervisor,"agent":$agent} | with_entries(select(.value != ""))')"
    ;;

  feedback-formalized)
    emit_event "$(jq -cn --arg ts "$TS" --arg event "$EVENT_TYPE" \
       --arg proposal_id "$PROPOSAL" --arg reward_id "$REWARD_ID_ARG" \
       --arg formalizer "$FROM" --arg agent "$AGENT" \
       '{"ts":$ts,"event":$event,"proposal_id":$proposal_id,"reward_id":$reward_id,"formalizer":$formalizer,"agent":$agent} | with_entries(select(.value != ""))')"
    ;;

  feedback-rejected)
    emit_event "$(jq -cn --arg ts "$TS" --arg event "$EVENT_TYPE" \
       --arg proposal_id "$PROPOSAL" --arg rejector "$FROM" \
       --arg reason "$REASON" --arg agent "$AGENT" \
       '{"ts":$ts,"event":$event,"proposal_id":$proposal_id,"rejector":$rejector,"reason":$reason,"agent":$agent} | with_entries(select(.value != ""))')"
    ;;

  feedback-escalated)
    emit_event "$(jq -cn --arg ts "$TS" --arg event "$EVENT_TYPE" \
       --arg proposal_id "$PROPOSAL" --arg from_supervisor "$FROM" \
       --arg to_supervisor "$TO" --arg agent "$AGENT" \
       '{"ts":$ts,"event":$event,"proposal_id":$proposal_id,"from_supervisor":$from_supervisor,"to_supervisor":$to_supervisor,"agent":$agent} | with_entries(select(.value != ""))')"
    ;;
```

- [ ] **Step 2: Update the error message valid types list**

In the `*)` default case, add the new event types to the last echo line:

```bash
echo "             reward-issued tension-detected preflight-remediation" >&2
```

Change to:

```bash
echo "             reward-issued tension-detected preflight-remediation" >&2
echo "             feedback-proposed feedback-formalized feedback-rejected feedback-escalated" >&2
```

- [ ] **Step 3: Verify syntax**

Run: `bash -n ops/metrics-log.sh`
Expected: No output (clean syntax)

- [ ] **Step 4: Commit**

```bash
git add ops/metrics-log.sh
git commit -m "feat(#28): add feedback-proposed/formalized/rejected/escalated metric events"
```

---

### Task 8: Update fleet-config template

**Files:**

- Modify: `templates/fleet-config.json`

- [ ] **Step 1: Add escalation_deadline_days to rewards section**

In `templates/fleet-config.json`, replace:

```json
"rewards": {},
"rewards_note": "Placeholder for adaptive weighting configuration (see #25). Currently unused — v1 uses unweighted signals.",
```

With:

```json
"rewards": {
  "escalation_deadline_days": 7
},
"rewards_note": "escalation_deadline_days: days before unacted specialist proposals auto-escalate. Adaptive weighting configuration (see #25) will be added here.",
```

- [ ] **Step 2: Add feedback pathway to pathways.declared**

In the `pathways.declared` object, add after the `governance` array:

```json
"feedback": [
  "backend-specialist -> solution-architect",
  "security-reviewer -> ciso",
  "frontend-specialist -> product-owner",
  "e2e-test-engineer -> product-owner"
],
"feedback_note": "Specialist-to-supervisor mapping for behavioral feedback proposals. Fallback: escalation wildcards."
```

- [ ] **Step 3: Add compliance-auditor to core agents array**

In the `agents.core` array, add `"compliance-auditor"`:

```json
"core": [
  "product-owner",
  "solution-architect",
  "scrum-master",
  "knowledge-ops",
  "platform-ops",
  "compliance-auditor"
],
```

- [ ] **Step 4: Commit**

```bash
git add templates/fleet-config.json
git commit -m "feat(#28): add feedback pathways, escalation deadline, compliance-auditor to fleet-config"
```

---

### Task 9: Update agent definitions (rename + formalization responsibility)

**Files:**

- Modify: `.claude/agents/cro.md`, `.claude/agents/ciso.md`, `.claude/agents/ceo.md`, `.claude/agents/cto.md`, `.claude/agents/cfo.md`, `.claude/agents/coo.md`, `.claude/agents/cko.md`, `.claude/agents/product-owner.md`, `.claude/agents/solution-architect.md`, `.claude/agents/scrum-master.md`
- Modify: `.claude/agents/knowledge-ops.md`, `.claude/agents/platform-ops.md`, `.claude/agents/compliance-auditor.md`

- [ ] **Step 1: Rename rewards-log.sh to feedback-log.sh in all 10 existing agents**

In each of the 10 agents that currently reference `rewards-log.sh`, replace:

```
ops/rewards-log.sh
```

With:

```
ops/feedback-log.sh
```

These agents are: cro, ciso, ceo, cto, cfo, coo, cko, product-owner, solution-architect, scrum-master.

- [ ] **Step 2: Add formalization responsibility to all 13 agents**

In each agent's `## Behavioral Feedback` section, add after the existing content:

```markdown
When you have pending proposals from specialist agents awaiting your review, act on them promptly. Use `ops/feedback-log.sh formalize <P-id>` to confirm a proposal or `ops/feedback-log.sh reject <P-id> --reason "..."` to decline it with explanation. Unacted proposals will auto-escalate.
```

- [ ] **Step 3: Add behavioral feedback sections to 3 new agents**

For `knowledge-ops.md`, `platform-ops.md`, and `compliance-auditor.md`, add a new `## Behavioral Feedback` section:

```markdown
## Behavioral Feedback

You may issue kudos and reprimands within your domain scope using `ops/feedback-log.sh`.

- **Reprimands:** When an agent's work falls short of standards in your domain. Include evidence and severity.
- **Kudos:** When an agent demonstrates excellence in your domain. Include evidence.
- **Judgment:** Issue feedback at natural review points (Phase 4 Review, retros, audits). Do not issue feedback for every minor observation — reserve it for patterns or notable events.

When issuing feedback on the same item where another agent has already issued opposing feedback, a tension will be auto-generated. This is expected and healthy.

When you have pending proposals from specialist agents awaiting your review, act on them promptly. Use `ops/feedback-log.sh formalize <P-id>` to confirm a proposal or `ops/feedback-log.sh reject <P-id> --reason "..."` to decline it with explanation. Unacted proposals will auto-escalate.
```

- [ ] **Step 4: Commit**

```bash
git add .claude/agents/*.md
git commit -m "feat(#28): update all agent definitions with feedback-log.sh and formalization responsibility"
```

---

### Task 10: Add behavioral feedback to specialist agent templates

**Files:**

- Modify: `templates/agents/backend-specialist.md`
- Modify: `templates/agents/frontend-specialist.md`
- Modify: `templates/agents/security-reviewer.md`
- Modify: `templates/agents/e2e-test-engineer.md`
- Modify: `templates/agents/infrastructure-ops.md`

- [ ] **Step 1: Add behavioral feedback section to each specialist template**

Append to each template file:

```markdown
## Behavioral Feedback

You may propose behavioral feedback using `ops/feedback-log.sh recommend`. Your proposals route to your designated supervisor for formalization. You cannot issue kudos or reprimands directly.

- **Propose reprimands:** When another agent's work falls short of standards in your domain. Include evidence and severity.
- **Propose kudos:** When another agent demonstrates excellence observable from your domain. Include evidence.
- **Judgment:** Propose feedback at natural review points (after receiving handoffs, during reviews). Reserve proposals for patterns or notable events, not every minor observation.
```

Additionally, add domain-specific trigger guidance to each:

For `security-reviewer.md`, add after the general section:

```markdown
**When to propose:** After reviewing code, if you find critical vulnerabilities that should have been caught earlier, propose a reprimand. If the code demonstrates strong security practices, propose a kudo.
```

For `e2e-test-engineer.md`:

```markdown
**When to propose:** When tests reveal systematic quality issues or exceptional test coverage from the originating specialist, propose feedback.
```

For `backend-specialist.md`:

```markdown
**When to propose:** When receiving handoffs with unclear requirements or excellent specifications, propose feedback about the sender's work quality.
```

For `frontend-specialist.md`:

```markdown
**When to propose:** When API contracts or component interfaces from other specialists are well-designed or problematic, propose feedback.
```

For `infrastructure-ops.md`:

```markdown
**When to propose:** When deployments reveal configuration quality issues or when infrastructure code from specialists is well-structured, propose feedback.
```

- [ ] **Step 2: Commit**

```bash
git add templates/agents/*.md
git commit -m "feat(#28): add behavioral feedback with domain triggers to specialist templates"
```

---

### Task 11: Update hooks and skills

**Files:**

- Modify: `.claude/settings.json`
- Modify: `.claude/skills/handoff/SKILL.md`
- Modify: `.claude/skills/retro/SKILL.md`

- [ ] **Step 1: Update SessionStart hook to run check-escalations**

In `.claude/settings.json`, add a new hook entry to the `SessionStart` hooks array (after the existing entries):

```json
{
  "type": "command",
  "command": "[ -f ops/feedback-log.sh ] && bash ops/feedback-log.sh check-escalations 2>/dev/null || true"
}
```

- [ ] **Step 2: Update SubagentStop hook to prompt feedback**

In `.claude/settings.json`, update the SubagentStop message hook. Replace the existing command:

```
echo '[PO] Agent completed. If this was a specialist build, consider /po review. If this was a reviewer, check findings register.' || true
```

With:

```
echo '[PO] Agent completed. If this was a specialist build, consider /po review. If this was a reviewer, check findings register. Before finishing, consider whether any agent you interacted with deserves behavioral feedback — use ops/feedback-log.sh recommend if so.' || true
```

- [ ] **Step 3: Update handoff skill with feedback prompt**

In `.claude/skills/handoff/SKILL.md`, in the "Workflow: Send" section after the handoff artifact format, add:

```markdown
3. **Feedback prompt.** After receiving a handoff, evaluate the sender's work quality. If it warrants behavioral feedback (positive or negative), use `ops/feedback-log.sh recommend` to propose it to your supervisor.
```

- [ ] **Step 4: Update retro skill with check-escalations**

In `.claude/skills/retro/SKILL.md`, in the "Workflow" section, add as a new step before "Gather metrics":

```markdown
0. **Check escalations.** Run `ops/feedback-log.sh check-escalations` to process any stale proposals before the retro begins.
```

- [ ] **Step 5: Verify settings.json syntax**

Run: `cat .claude/settings.json | jq .`
Expected: Valid JSON output (no parse errors)

- [ ] **Step 6: Commit**

```bash
git add .claude/settings.json .claude/skills/handoff/SKILL.md .claude/skills/retro/SKILL.md
git commit -m "feat(#28): add escalation check to hooks, feedback prompts to skills"
```

---

### Task 12: Update CLAUDE.md documentation

**Files:**

- Modify: `CLAUDE.md`

- [ ] **Step 1: Update the Rewards commands section**

In the `### Rewards` subsection under `## Commands`, rename to `### Feedback` and update all command references from `ops/rewards-log.sh` to `ops/feedback-log.sh`. Add the new subcommands:

````bash
### Feedback

```bash
# Issue behavioral feedback (governance/core agents)
ops/feedback-log.sh reprimand --issuer <agent> --subject <agent> --domain <domain> \
  --severity low|medium|high [--item <id>] --description "..." --evidence "..."
ops/feedback-log.sh kudo --issuer <agent> --subject <agent> --domain <domain> \
  [--item <id>] --description "..." --evidence "..."

# Propose feedback (specialist agents)
ops/feedback-log.sh recommend --issuer <agent> --subject <agent> --type kudo|reprimand \
  --domain <domain> [--severity low|medium|high] [--item <id>] \
  --description "..." --evidence "..."

# Supervisor actions on proposals
ops/feedback-log.sh formalize <P-id> --issuer <supervisor>
ops/feedback-log.sh reject <P-id> --issuer <supervisor> --reason "..."

# Escalation enforcement
ops/feedback-log.sh check-escalations

# Query behavioral profiles
ops/feedback-log.sh profile <agent>
ops/feedback-log.sh tensions [--item <id>]
````

- [ ] **Step 2: Commit**

```bash
git add CLAUDE.md
git commit -m "docs(#28): update CLAUDE.md with feedback-log.sh commands"
```

---

### Task 13: Run full test suite and verify

**Files:** None (verification only)

- [ ] **Step 1: Run compiler tests**

Run: `bash ops/tests/test-compile-floor.sh`
Expected: `146/146 passed, 0 failed`

- [ ] **Step 2: Run feedback tests**

Run: `bash ops/tests/test-feedback-log.sh`
Expected: All tests pass (original 21 + new tests)

- [ ] **Step 3: Syntax check all scripts**

Run: `bash -n ops/feedback-log.sh && bash -n ops/rewards-log.sh && bash -n ops/metrics-log.sh && echo "All OK"`
Expected: `All OK`

- [ ] **Step 4: Verify shim forwards correctly**

Run: `bash ops/rewards-log.sh profile test-agent 2>&1`
Expected: Deprecation warning to stderr, then profile output

- [ ] **Step 5: Final commit if any fixups needed**

Only if previous steps required changes.
