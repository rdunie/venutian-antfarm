# Rewards System Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a behavioral feedback system (kudos, reprimands, tension detection) so governance and leadership agents can shape agent behavior over time.

**Architecture:** Ledger-first approach — a protected markdown file (`.claude/rewards/ledger.md`) is the primary artifact, managed exclusively through `ops/rewards-log.sh`. Metrics events provide the audit trail. Hook + checksum protection mirrors the compliance floor pattern.

**Tech Stack:** Bash (helper script), jq (JSON event construction), sha256sum (integrity checks), existing hook infrastructure.

**Spec:** `docs/superpowers/specs/2026-03-24-rewards-system-design.md`

---

### Task 1: Scaffold ledger files and template

**Files:**

- Create: `.claude/rewards/ledger.md`
- Create: `templates/rewards/ledger.md`

- [ ] **Step 1: Create the rewards directory and ledger file**

```markdown
# Behavioral Ledger

<!-- Append-only. Managed by ops/rewards-log.sh. Do not edit directly. -->
```

Write this to `.claude/rewards/ledger.md`.

- [ ] **Step 2: Create the template ledger**

Copy the same content to `templates/rewards/ledger.md`. This is what new projects start with.

- [ ] **Step 3: Add sentinel file to .gitignore**

Add this line to `.gitignore` after the existing compliance sentinel entry:

```
# Rewards sentinel file (transient, never committed)
.claude/rewards/.issuing
```

- [ ] **Step 4: Generate the initial checksum**

```bash
sha256sum .claude/rewards/ledger.md > .claude/rewards/ledger-checksum.sha256
```

- [ ] **Step 5: Commit**

```bash
git add .claude/rewards/ledger.md .claude/rewards/ledger-checksum.sha256 \
  templates/rewards/ledger.md .gitignore
git commit -m "feat: scaffold rewards ledger and template"
```

---

### Task 2: Add reward-issued and tension-detected events to metrics-log.sh

**Files:**

- Modify: `ops/metrics-log.sh`
- Test: `ops/tests/test-rewards-log.sh` (created in Task 4, but metric events testable here)

- [ ] **Step 1: Add new flag parsing for reward fields**

In the flag parsing `while` loop (around line 47-82 in `ops/metrics-log.sh`), add these cases before the `*)` catch-all:

```bash
    --reward-id) REWARD_ID_ARG="$2"; shift 2 ;;
    --subject) SUBJECT="$2"; shift 2 ;;
    --description) DESCRIPTION="$2"; shift 2 ;;
```

Also add the variable declarations near line 39-45:

```bash
REWARD_ID_ARG="" SUBJECT="" DESCRIPTION=""
```

Note: `--issuer` maps to the existing `--from` flag. `--domain` maps to the existing `--scope` flag. `--type` maps to `--change-type`. Reuse existing flags where semantics match, add new ones only where needed.

- [ ] **Step 2: Add reward-issued event handler**

Add before the `*)` error case (around line 334):

```bash
  reward-issued)
    if [[ -z "$CHANGE_TYPE" ]]; then
      echo "ERROR: reward-issued requires --type (kudo|reprimand)" >&2
      exit 1
    fi
    emit_event "$(jq -cn --arg ts "$TS" --arg event "$EVENT_TYPE" \
       --arg type "$CHANGE_TYPE" --arg issuer "$FROM" --arg subject "$SUBJECT" \
       --arg domain "$SCOPE" --arg severity "$SEVERITY" \
       --arg item "$ITEM" --arg reward_id "$REWARD_ID_ARG" --arg agent "$AGENT" \
       '{"ts":$ts,"event":$event,"type":$type,"issuer":$issuer,"subject":$subject,"domain":$domain,"severity":$severity,"item":$item,"reward_id":$reward_id,"agent":$agent} | with_entries(select(.value != ""))')"
    ;;
```

- [ ] **Step 3: Add tension-detected event handler**

Add after reward-issued:

```bash
  tension-detected)
    emit_event "$(jq -cn --arg ts "$TS" --arg event "$EVENT_TYPE" \
       --arg reward_ids "$DESCRIPTION" --arg item "$ITEM" \
       --arg subject "$SUBJECT" --arg agent "$AGENT" \
       '{"ts":$ts,"event":$event,"reward_ids":$reward_ids,"item":$item,"subject":$subject,"agent":$agent} | with_entries(select(.value != ""))')"
    ;;
```

- [ ] **Step 4: Update the error message help text**

Add `reward-issued tension-detected` to the valid event types in the error message (around line 343):

```bash
    echo "             reward-issued tension-detected" >&2
```

- [ ] **Step 5: Run syntax check**

```bash
bash -n ops/metrics-log.sh
```

Expected: no output (clean parse).

- [ ] **Step 6: Smoke test the new events**

```bash
METRICS_LOG_FILE=/tmp/test-rewards-events.jsonl \
  ops/metrics-log.sh reward-issued --type kudo --from ciso --subject backend-specialist \
    --scope security --item 42 --reward-id K-001
cat /tmp/test-rewards-events.jsonl
rm /tmp/test-rewards-events.jsonl
```

Expected: JSON line with event=reward-issued, type=kudo, issuer=ciso, subject=backend-specialist.

- [ ] **Step 7: Commit**

```bash
git add ops/metrics-log.sh
git commit -m "feat: add reward-issued and tension-detected metric events"
```

---

### Task 3: Create ops/rewards-log.sh — write operations (reprimand, kudo, tension)

**Files:**

- Create: `ops/rewards-log.sh`

This is the core script. Build it in two parts: write operations first (this task), read operations second (Task 5).

- [ ] **Step 1: Write the test for reprimand issuance**

Create `ops/tests/test-rewards-log.sh` with the test harness (follow `test-compile-floor.sh` pattern):

```bash
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
REWARDS_LOG="${REPO_ROOT}/ops/rewards-log.sh"

PASS=0
FAIL=0
TOTAL=0

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

assert_exit() {
  local label="$1" expected="$2" actual="$3"
  TOTAL=$((TOTAL + 1))
  if [[ "$actual" -eq "$expected" ]]; then
    echo -e "  ${GREEN}PASS${NC} ${label}"
    PASS=$((PASS + 1))
  else
    echo -e "  ${RED}FAIL${NC} ${label} — expected exit ${expected}, got ${actual}"
    FAIL=$((FAIL + 1))
  fi
}

assert_contains() {
  local label="$1" file="$2" pattern="$3"
  TOTAL=$((TOTAL + 1))
  if grep -qE "$pattern" "$file" 2>/dev/null; then
    echo -e "  ${GREEN}PASS${NC} ${label}"
    PASS=$((PASS + 1))
  else
    echo -e "  ${RED}FAIL${NC} ${label} — pattern not found in ${file}: ${pattern}"
    FAIL=$((FAIL + 1))
  fi
}

assert_not_contains() {
  local label="$1" file="$2" pattern="$3"
  TOTAL=$((TOTAL + 1))
  if ! grep -qE "$pattern" "$file" 2>/dev/null; then
    echo -e "  ${GREEN}PASS${NC} ${label}"
    PASS=$((PASS + 1))
  else
    echo -e "  ${RED}FAIL${NC} ${label} — pattern should not be in ${file}: ${pattern}"
    FAIL=$((FAIL + 1))
  fi
}

# Setup temp dir
TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

setup_ledger() {
  mkdir -p "$TMPDIR/rewards"
  cat > "$TMPDIR/rewards/ledger.md" <<'LEDGER'
# Behavioral Ledger

<!-- Append-only. Managed by ops/rewards-log.sh. Do not edit directly. -->
LEDGER
  mkdir -p "$TMPDIR/findings"
  cat > "$TMPDIR/findings/register.md" <<'FINDINGS'
# Findings Register

## Active Findings

(none yet)
FINDINGS
  mkdir -p "$TMPDIR/metrics"
  : > "$TMPDIR/metrics/events.jsonl"
}

# ── Test: reprimand basic ──────────────────────────────────────────────
echo "=== Reprimand issuance ==="
setup_ledger

REWARDS_LEDGER="$TMPDIR/rewards/ledger.md" \
REWARDS_CHECKSUM="$TMPDIR/rewards/ledger-checksum.sha256" \
FINDINGS_REGISTER="$TMPDIR/findings/register.md" \
METRICS_LOG_FILE="$TMPDIR/metrics/events.jsonl" \
  "$REWARDS_LOG" reprimand \
    --issuer ciso --subject backend-specialist --domain security \
    --severity high --item 42 \
    --description "Skipped edge-case testing" \
    --evidence "PR #87 had no expiry tests"
EXIT_CODE=$?

assert_exit "reprimand exits 0" 0 "$EXIT_CODE"
assert_contains "ledger has reprimand header" "$TMPDIR/rewards/ledger.md" "R-001 \\[reprimand\\]"
assert_contains "ledger has severity" "$TMPDIR/rewards/ledger.md" "\\*\\*Severity:\\*\\* high"
assert_contains "ledger has subject section" "$TMPDIR/rewards/ledger.md" "^## backend-specialist"
assert_contains "metric event emitted" "$TMPDIR/metrics/events.jsonl" '"event":"reward-issued"'
assert_contains "checksum updated" "$TMPDIR/rewards/ledger-checksum.sha256" "[a-f0-9]{64}"

# ── Test: kudo basic ───────────────────────────────────────────────────
echo ""
echo "=== Kudo issuance ==="

REWARDS_LEDGER="$TMPDIR/rewards/ledger.md" \
REWARDS_CHECKSUM="$TMPDIR/rewards/ledger-checksum.sha256" \
FINDINGS_REGISTER="$TMPDIR/findings/register.md" \
METRICS_LOG_FILE="$TMPDIR/metrics/events.jsonl" \
  "$REWARDS_LOG" kudo \
    --issuer po --subject backend-specialist --domain delivery \
    --item 42 \
    --description "Clean first-pass AC acceptance" \
    --evidence "All 5 AC passed first review"
EXIT_CODE=$?

assert_exit "kudo exits 0" 0 "$EXIT_CODE"
assert_contains "ledger has kudo header" "$TMPDIR/rewards/ledger.md" "K-001 \\[kudo\\]"
assert_contains "kudo under same subject section" "$TMPDIR/rewards/ledger.md" "^## backend-specialist"

# ── Test: tension detection ────────────────────────────────────────────
echo ""
echo "=== Tension detection ==="

# The kudo above (K-001) + reprimand (R-001) are on the same item+subject
# Tension should have been auto-generated after the kudo was issued
assert_contains "tension entry in ledger" "$TMPDIR/rewards/ledger.md" "T-001 \\[tension\\]"
assert_contains "tension references both signals" "$TMPDIR/rewards/ledger.md" "K-001 vs R-001"
assert_contains "tension finding in register" "$TMPDIR/findings/register.md" "boundary-tension"
assert_contains "tension metric event" "$TMPDIR/metrics/events.jsonl" '"event":"tension-detected"'

# ── Test: no tension on different items ────────────────────────────────
echo ""
echo "=== No false tension ==="
setup_ledger

REWARDS_LEDGER="$TMPDIR/rewards/ledger.md" \
REWARDS_CHECKSUM="$TMPDIR/rewards/ledger-checksum.sha256" \
FINDINGS_REGISTER="$TMPDIR/findings/register.md" \
METRICS_LOG_FILE="$TMPDIR/metrics/events.jsonl" \
  "$REWARDS_LOG" reprimand \
    --issuer ciso --subject backend-specialist --domain security \
    --severity low --item 42 \
    --description "Minor issue" --evidence "..."

REWARDS_LEDGER="$TMPDIR/rewards/ledger.md" \
REWARDS_CHECKSUM="$TMPDIR/rewards/ledger-checksum.sha256" \
FINDINGS_REGISTER="$TMPDIR/findings/register.md" \
METRICS_LOG_FILE="$TMPDIR/metrics/events.jsonl" \
  "$REWARDS_LOG" kudo \
    --issuer po --subject backend-specialist --domain delivery \
    --item 43 \
    --description "Good work" --evidence "..."

assert_not_contains "no tension for different items" "$TMPDIR/rewards/ledger.md" "\\[tension\\]"

# ── Test: missing required args ────────────────────────────────────────
echo ""
echo "=== Validation ==="

REWARDS_LEDGER="$TMPDIR/rewards/ledger.md" \
REWARDS_CHECKSUM="$TMPDIR/rewards/ledger-checksum.sha256" \
FINDINGS_REGISTER="$TMPDIR/findings/register.md" \
METRICS_LOG_FILE="$TMPDIR/metrics/events.jsonl" \
  "$REWARDS_LOG" reprimand --issuer ciso 2>/dev/null
EXIT_CODE=$?
assert_exit "reprimand without --subject fails" 1 "$EXIT_CODE"

REWARDS_LEDGER="$TMPDIR/rewards/ledger.md" \
REWARDS_CHECKSUM="$TMPDIR/rewards/ledger-checksum.sha256" \
FINDINGS_REGISTER="$TMPDIR/findings/register.md" \
METRICS_LOG_FILE="$TMPDIR/metrics/events.jsonl" \
  "$REWARDS_LOG" reprimand --issuer ciso --subject x --domain y --description "z" --evidence "z" 2>/dev/null
EXIT_CODE=$?
assert_exit "reprimand without --severity fails" 1 "$EXIT_CODE"

# ── Summary ────────────────────────────────────────────────────────────
echo ""
echo "========================================"
echo -e "Results: ${PASS} passed, ${FAIL} failed, ${TOTAL} total"
echo "========================================"
[[ "$FAIL" -eq 0 ]] && exit 0 || exit 1
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
chmod +x ops/tests/test-rewards-log.sh
bash ops/tests/test-rewards-log.sh
```

Expected: FAIL (rewards-log.sh doesn't exist yet).

- [ ] **Step 3: Write ops/rewards-log.sh**

Create `ops/rewards-log.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

# ---------------------------------------------------------------------------
# rewards-log.sh — Behavioral feedback helper
#
# Single entry point for all ledger writes and queries.
# Agents never edit the ledger directly — always use this script.
#
# Usage:
#   ops/rewards-log.sh reprimand --issuer <agent> --subject <agent> ...
#   ops/rewards-log.sh kudo --issuer <agent> --subject <agent> ...
#   ops/rewards-log.sh profile <agent>
#   ops/rewards-log.sh tensions [--item <id>]
#
# Env vars (for testing — defaults to repo paths):
#   REWARDS_LEDGER    Override ledger path
#   REWARDS_CHECKSUM  Override checksum path
#   FINDINGS_REGISTER Override findings register path
#   METRICS_LOG_FILE  Override metrics log path
# ---------------------------------------------------------------------------

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

LEDGER="${REWARDS_LEDGER:-$REPO_ROOT/.claude/rewards/ledger.md}"
CHECKSUM="${REWARDS_CHECKSUM:-$REPO_ROOT/.claude/rewards/ledger-checksum.sha256}"
FINDINGS="${FINDINGS_REGISTER:-$REPO_ROOT/.claude/findings/register.md}"
export METRICS_LOG_FILE="${METRICS_LOG_FILE:-$REPO_ROOT/.claude/metrics/events.jsonl}"

if [[ $# -eq 0 ]]; then
  echo "Usage: ops/rewards-log.sh <reprimand|kudo|profile|tensions> [args...]" >&2
  exit 1
fi

SUBCOMMAND="$1"; shift

# ── Parse flags ──────────────────────────────────────────────────────────
ISSUER="" SUBJECT="" DOMAIN="" SEVERITY="" ITEM="" DESCRIPTION="" EVIDENCE=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --issuer)      ISSUER="$2";      shift 2 ;;
    --subject)     SUBJECT="$2";     shift 2 ;;
    --domain)      DOMAIN="$2";      shift 2 ;;
    --severity)    SEVERITY="$2";    shift 2 ;;
    --item)        ITEM="$2";        shift 2 ;;
    --description) DESCRIPTION="$2"; shift 2 ;;
    --evidence)    EVIDENCE="$2";    shift 2 ;;
    *) # Positional (used by profile/tensions)
       if [[ -z "$SUBJECT" ]]; then SUBJECT="$1"; fi
       shift ;;
  esac
done

# ── Helpers ──────────────────────────────────────────────────────────────

update_checksum() {
  sha256sum "$LEDGER" > "$CHECKSUM"
}

# Get the next ID for a given prefix (R, K, or T)
next_id() {
  local prefix="$1"
  local count
  count=$(grep -cE "^### ${prefix}-[0-9]+" "$LEDGER" 2>/dev/null || echo 0)
  printf "%s-%03d" "$prefix" "$((count + 1))"
}

# Check for tension: opposing signal types on same item + subject
check_tension() {
  local new_type="$1" new_subject="$2" new_item="$3" new_id="$4"

  [[ -z "$new_item" ]] && return 0  # No item = no conflict possible

  local opposing_type
  if [[ "$new_type" == "kudo" ]]; then
    opposing_type="reprimand"
  else
    opposing_type="kudo"
  fi

  # Search ledger for opposing signal on same item + subject
  # Look within the subject's section for entries with the same item
  local in_section=0
  local opposing_id=""
  while IFS= read -r line; do
    if [[ "$line" =~ ^##\  ]] && [[ ! "$line" =~ ^###\  ]]; then
      if [[ "$line" == "## $new_subject" ]]; then
        in_section=1
      else
        in_section=0
      fi
    fi
    if [[ "$in_section" -eq 1 ]] && [[ "$line" =~ ^###\ ([RK]-[0-9]+)\ \\[${opposing_type}\\] ]]; then
      local candidate_id="${BASH_REMATCH[1]}"
      # Check if this entry has the same item
      local next_lines
      next_lines=$(sed -n "/^### ${candidate_id} /,/^### /p" "$LEDGER" | head -10)
      if echo "$next_lines" | grep -q "^\*\*Item:\*\* ${new_item}$"; then
        opposing_id="$candidate_id"
        break
      fi
    fi
  done < "$LEDGER"

  [[ -z "$opposing_id" ]] && return 0

  # Generate tension entry
  local tension_id
  tension_id=$(next_id "T")
  local ts
  ts="$(date -u +%Y-%m-%d)"

  # Determine order: earlier ID first
  local first_id="$opposing_id"
  local second_id="$new_id"

  cat >> "$LEDGER" <<EOF

### ${tension_id} [tension] ${ts} — auto / item-${new_item}

**Signals:** ${first_id} vs ${second_id}
**Description:** Opposing feedback on item ${new_item} for ${new_subject}
**Status:** open
**Referred to:** SM for retro
EOF

  # Add finding to register
  if [[ -f "$FINDINGS" ]]; then
    local finding_entry
    finding_entry=$(cat <<EOF

### [${ts}] normal -- Behavioral tension on item ${new_item}

**Found by:** rewards-system (auto)
**Category:** boundary-tension
**Description:** ${first_id} and ${second_id} are opposing feedback for ${new_subject} on item ${new_item}. SM should surface in retro.
**Proposed action:** Review during next retro (Phase 8)
**Status:** open
EOF
)
    # Insert before "## Resolved Findings" or append to Active Findings
    if grep -q "^(none yet)" "$FINDINGS"; then
      sed -i "s/^(none yet)/${finding_entry//\//\\/}/" "$FINDINGS" 2>/dev/null || \
        echo "$finding_entry" >> "$FINDINGS"
    else
      # Append before Resolved section
      sed -i "/^## Resolved Findings/i\\${finding_entry}" "$FINDINGS" 2>/dev/null || \
        echo "$finding_entry" >> "$FINDINGS"
    fi
  fi

  # Emit tension-detected metric
  "$SCRIPT_DIR/metrics-log.sh" tension-detected \
    --description "${first_id},${second_id}" \
    --item "$new_item" --subject "$new_subject" 2>/dev/null || true

  update_checksum
}

# ── Subcommands ──────────────────────────────────────────────────────────

case "$SUBCOMMAND" in

  reprimand)
    # Validate required fields
    [[ -z "$ISSUER" ]]      && echo "ERROR: --issuer required" >&2 && exit 1
    [[ -z "$SUBJECT" ]]     && echo "ERROR: --subject required" >&2 && exit 1
    [[ -z "$DOMAIN" ]]      && echo "ERROR: --domain required" >&2 && exit 1
    [[ -z "$SEVERITY" ]]    && echo "ERROR: --severity required for reprimands" >&2 && exit 1
    [[ -z "$DESCRIPTION" ]] && echo "ERROR: --description required" >&2 && exit 1
    [[ -z "$EVIDENCE" ]]    && echo "ERROR: --evidence required" >&2 && exit 1

    local_id=$(next_id "R")
    ts="$(date -u +%Y-%m-%d)"

    # Ensure subject section exists
    if ! grep -q "^## ${SUBJECT}$" "$LEDGER" 2>/dev/null; then
      echo "" >> "$LEDGER"
      echo "## ${SUBJECT}" >> "$LEDGER"
    fi

    # Append reprimand entry
    cat >> "$LEDGER" <<EOF

### ${local_id} [reprimand] ${ts} — ${ISSUER} / ${DOMAIN}

**Severity:** ${SEVERITY}
$([ -n "$ITEM" ] && echo "**Item:** ${ITEM}")
**Description:** ${DESCRIPTION}
**Evidence:** ${EVIDENCE}
EOF

    # Emit metric event
    "$SCRIPT_DIR/metrics-log.sh" reward-issued \
      --type reprimand --from "$ISSUER" --subject "$SUBJECT" \
      --scope "$DOMAIN" --severity "$SEVERITY" \
      ${ITEM:+--item "$ITEM"} --reward-id "$local_id" 2>/dev/null || true

    update_checksum

    # Check for tension
    check_tension "reprimand" "$SUBJECT" "$ITEM" "$local_id"

    echo "reward_id=$local_id"
    ;;

  kudo)
    [[ -z "$ISSUER" ]]      && echo "ERROR: --issuer required" >&2 && exit 1
    [[ -z "$SUBJECT" ]]     && echo "ERROR: --subject required" >&2 && exit 1
    [[ -z "$DOMAIN" ]]      && echo "ERROR: --domain required" >&2 && exit 1
    [[ -z "$DESCRIPTION" ]] && echo "ERROR: --description required" >&2 && exit 1
    [[ -z "$EVIDENCE" ]]    && echo "ERROR: --evidence required" >&2 && exit 1

    local_id=$(next_id "K")
    ts="$(date -u +%Y-%m-%d)"

    if ! grep -q "^## ${SUBJECT}$" "$LEDGER" 2>/dev/null; then
      echo "" >> "$LEDGER"
      echo "## ${SUBJECT}" >> "$LEDGER"
    fi

    cat >> "$LEDGER" <<EOF

### ${local_id} [kudo] ${ts} — ${ISSUER} / ${DOMAIN}

$([ -n "$ITEM" ] && echo "**Item:** ${ITEM}")
**Description:** ${DESCRIPTION}
**Evidence:** ${EVIDENCE}
EOF

    "$SCRIPT_DIR/metrics-log.sh" reward-issued \
      --type kudo --from "$ISSUER" --subject "$SUBJECT" \
      --scope "$DOMAIN" \
      ${ITEM:+--item "$ITEM"} --reward-id "$local_id" 2>/dev/null || true

    update_checksum

    check_tension "kudo" "$SUBJECT" "$ITEM" "$local_id"

    echo "reward_id=$local_id"
    ;;

  profile)
    # Read-only: display agent behavioral profile
    [[ -z "$SUBJECT" ]] && echo "Usage: ops/rewards-log.sh profile <agent>" >&2 && exit 1

    if ! grep -q "^## ${SUBJECT}$" "$LEDGER" 2>/dev/null; then
      echo "${SUBJECT}: no behavioral signals recorded"
      exit 0
    fi

    # Count signals
    local kudos reprimands tensions
    kudos=$(sed -n "/^## ${SUBJECT}$/,/^## [^#]/p" "$LEDGER" | grep -c "\\[kudo\\]" || echo 0)
    reprimands=$(sed -n "/^## ${SUBJECT}$/,/^## [^#]/p" "$LEDGER" | grep -c "\\[reprimand\\]" || echo 0)
    tensions=$(sed -n "/^## ${SUBJECT}$/,/^## [^#]/p" "$LEDGER" | grep -c "\\[tension\\]" || echo 0)
    local open_tensions
    open_tensions=$(sed -n "/^## ${SUBJECT}$/,/^## [^#]/p" "$LEDGER" | grep -c "Status:\\*\\* open" || echo 0)

    echo "${SUBJECT}: ${kudos} kudos, ${reprimands} reprimands, ${tensions} tensions (${open_tensions} open)"

    # By domain
    echo "By domain:"
    sed -n "/^## ${SUBJECT}$/,/^## [^#]/p" "$LEDGER" | \
      grep -oP '— \w+ / \K\w+' | sort | uniq -c | sort -rn | \
      while read -r count domain; do
        echo "  ${domain} (${count})"
      done

    # Recent entries (last 5)
    echo "Recent:"
    sed -n "/^## ${SUBJECT}$/,/^## [^#]/p" "$LEDGER" | \
      grep "^### [RKT]-" | tail -5 | \
      while IFS= read -r line; do
        echo "  ${line#\#\#\# }"
      done
    ;;

  tensions)
    # Show open tensions, optionally filtered by item
    echo "Open tensions:"
    if [[ -n "$ITEM" ]]; then
      grep -B0 -A5 "\\[tension\\]" "$LEDGER" | grep -B5 "item-${ITEM}" | grep "\\[tension\\]" || echo "  (none)"
    else
      grep "\\[tension\\]" "$LEDGER" | while IFS= read -r line; do
        echo "  ${line#\#\#\# }"
      done
      [[ $(grep -c "\\[tension\\]" "$LEDGER" 2>/dev/null) -eq 0 ]] && echo "  (none)"
    fi
    ;;

  *)
    echo "ERROR: Unknown subcommand '$SUBCOMMAND'" >&2
    echo "Valid: reprimand, kudo, profile, tensions" >&2
    exit 1
    ;;
esac
```

- [ ] **Step 4: Make executable and run syntax check**

```bash
chmod +x ops/rewards-log.sh
bash -n ops/rewards-log.sh
```

Expected: no output (clean parse).

- [ ] **Step 5: Run the tests**

```bash
bash ops/tests/test-rewards-log.sh
```

Expected: All tests pass.

- [ ] **Step 6: Fix any test failures, re-run until green**

Iterate on the script until all tests pass. Common issues: regex escaping in grep, sed portability, edge cases in section detection.

- [ ] **Step 7: Commit**

```bash
git add ops/rewards-log.sh ops/tests/test-rewards-log.sh
git commit -m "feat: add rewards-log.sh with reprimand, kudo, tension detection, profile, and tensions queries"
```

---

### Task 4: Add hook protection for the ledger

**Files:**

- Modify: `.claude/settings.json`

**Important:** Per CLAUDE.md gotchas, use Write (full rewrite) for `settings.json`, not Edit.

- [ ] **Step 1: Read current settings.json**

Read the file to get the current content.

- [ ] **Step 2: Add PreToolUse hook for ledger file protection**

Add a new entry in the `PreToolUse` → `Edit|Write` hooks array (after the compliance floor protection hook):

```json
{
  "type": "command",
  "command": "echo \"$CLAUDE_FILE_PATH\" | grep -qE 'rewards/ledger\\.md$|rewards/ledger-checksum' && { [ -f .claude/rewards/.issuing ] && find .claude/rewards/.issuing -mmin -1 -print -quit 2>/dev/null | grep -q . && exit 0 || echo 'BLOCKED: Rewards ledger is protected. Use ops/rewards-log.sh to issue feedback.' && exit 2; } || exit 0"
}
```

- [ ] **Step 3: Add PreToolUse hook for direct ledger writes via Bash**

Add to the `PreToolUse` → `Bash` hooks array:

```json
{
  "type": "command",
  "command": "echo \"$CLAUDE_TOOL_INPUT\" | grep -q 'rewards/ledger' && echo 'BLOCKED: Use ops/rewards-log.sh instead of writing the rewards ledger directly' && exit 2 || exit 0"
}
```

- [ ] **Step 4: Add SessionStart hook for checksum verification**

Add to the `SessionStart` hooks array:

```json
{
  "type": "command",
  "command": "[ -f .claude/rewards/ledger-checksum.sha256 ] && [ -f .claude/rewards/ledger.md ] && { EXPECTED=$(sha256sum .claude/rewards/ledger.md | cut -d' ' -f1); ACTUAL=$(cut -d' ' -f1 .claude/rewards/ledger-checksum.sha256); [ \"$EXPECTED\" = \"$ACTUAL\" ] && echo '[CO] Rewards ledger integrity verified.' || echo '[CO] WARNING: Rewards ledger checksum mismatch. Possible tampering. Run git checkout to restore.'; } || true"
}
```

- [ ] **Step 5: Write the complete settings.json**

Use the Write tool to write the full updated `settings.json`.

- [ ] **Step 6: Validate JSON**

```bash
cat .claude/settings.json | jq . > /dev/null
```

Expected: exit 0 (valid JSON).

- [ ] **Step 7: Commit**

```bash
git add .claude/settings.json
git commit -m "feat: add hook protection for rewards ledger"
```

---

### Task 5: Update agent definitions — CO ledger guardianship

**Files:**

- Modify: `.claude/agents/compliance-officer.md`

- [ ] **Step 1: Read the current CO agent definition**

Read `.claude/agents/compliance-officer.md` to confirm section structure.

- [ ] **Step 2: Add §7 Ledger Guardianship**

Insert after §6 (CEO Autonomy Monitoring), before `## Autonomy Model`:

```markdown
### 7. Ledger Guardianship

Monitor `.claude/rewards/ledger.md` integrity. On SessionStart, verify the checksum in `.claude/rewards/ledger-checksum.sha256`. If a mismatch is detected:

1. Restore via `git checkout <commit> -- .claude/rewards/ledger.md`
2. Log `compliance-violation` event
3. Issue a reprimand to the tampering agent (if identifiable)
```

- [ ] **Step 3: Add §Behavioral Feedback to CO**

Insert before `## Communication Style`:

```markdown
## Behavioral Feedback

You may issue kudos and reprimands within your domain scope using `ops/rewards-log.sh`.

- **Reprimands:** When an agent's work falls short of compliance standards. Include evidence and severity.
- **Kudos:** When an agent demonstrates proactive compliance or clean audit results. Include evidence.
- **Judgment:** Issue feedback at natural review points (Phase 4 Review, retros, audits). Do not issue feedback for every minor observation — reserve it for patterns or notable events.

When issuing feedback on the same item where another agent has already issued opposing feedback, a tension will be auto-generated. This is expected and healthy.
```

- [ ] **Step 4: Commit**

```bash
git add .claude/agents/compliance-officer.md
git commit -m "feat: add ledger guardianship and behavioral feedback to CO agent"
```

---

### Task 6: Update agent definitions — SM behavioral profile review

**Files:**

- Modify: `.claude/agents/scrum-master.md`

- [ ] **Step 1: Read the current SM agent definition**

Read `.claude/agents/scrum-master.md` to confirm section structure.

- [ ] **Step 2: Add §7 Behavioral Profile Review**

Insert after §6 (Impediment Removal), before `## Autonomy Model`:

```markdown
### 7. Behavioral Profile Review

During retros (Phase 8), review the subject agent's behavioral profile via `ops/rewards-log.sh profile <agent>`. Surface tensions, patterns, and repeat signals. Include behavioral observations in the retro summary.
```

- [ ] **Step 3: Commit**

```bash
git add .claude/agents/scrum-master.md
git commit -m "feat: add behavioral profile review to SM agent"
```

---

### Task 7: Update agent definitions — Behavioral Feedback section for remaining issuers

**Files:**

- Modify: `.claude/agents/ciso.md`
- Modify: `.claude/agents/ceo.md`
- Modify: `.claude/agents/cto.md`
- Modify: `.claude/agents/cfo.md`
- Modify: `.claude/agents/coo.md`
- Modify: `.claude/agents/cko.md`
- Modify: `.claude/agents/product-owner.md`
- Modify: `.claude/agents/solution-architect.md`

All 8 agents get the same `## Behavioral Feedback` section, inserted before `## Communication Style` (or the equivalent closing section). The section text is identical to the one added to CO in Task 5, Step 3 — only the domain-specific examples in the leading sentence may vary. For v1, use the generic text for all agents (domain scope is enforced by convention, not code).

- [ ] **Step 1: Read each agent file to confirm insertion point**

For each of the 8 agents, find the section before `## Communication Style` or `## Executive Memory` or the final section.

- [ ] **Step 2: Add the Behavioral Feedback section to all 8 agents**

Insert in each file:

```markdown
## Behavioral Feedback

You may issue kudos and reprimands within your domain scope using `ops/rewards-log.sh`.

- **Reprimands:** When an agent's work falls short of standards in your domain. Include evidence and severity.
- **Kudos:** When an agent demonstrates excellence in your domain. Include evidence.
- **Judgment:** Issue feedback at natural review points (Phase 4 Review, retros, audits). Do not issue feedback for every minor observation — reserve it for patterns or notable events.

When issuing feedback on the same item where another agent has already issued opposing feedback, a tension will be auto-generated. This is expected and healthy.
```

- [ ] **Step 3: Commit all 8 at once**

```bash
git add .claude/agents/ciso.md .claude/agents/ceo.md .claude/agents/cto.md \
  .claude/agents/cfo.md .claude/agents/coo.md .claude/agents/cko.md \
  .claude/agents/product-owner.md .claude/agents/solution-architect.md
git commit -m "feat: add behavioral feedback section to 8 issuer agents"
```

---

### Task 8: Update fleet-config template and CLAUDE.md

**Files:**

- Modify: `templates/fleet-config.json`
- Modify: `CLAUDE.md`

- [ ] **Step 1: Add rewards section to fleet-config template**

In `templates/fleet-config.json`, add after the `"knowledge"` section:

```json
  "rewards": {},
  "rewards_note": "Placeholder for adaptive weighting configuration (see #25). Currently unused — v1 uses unweighted signals."
```

- [ ] **Step 2: Document rewards-log.sh in CLAUDE.md**

In the `## Commands` section, add a `### Rewards` subsection after `### Metrics`:

````markdown
### Rewards

```bash
# Issue behavioral feedback
ops/rewards-log.sh reprimand --issuer <agent> --subject <agent> --domain <domain> \
  --severity low|medium|high [--item <id>] --description "..." --evidence "..."
ops/rewards-log.sh kudo --issuer <agent> --subject <agent> --domain <domain> \
  [--item <id>] --description "..." --evidence "..."

# Query behavioral profiles
ops/rewards-log.sh profile <agent>
ops/rewards-log.sh tensions [--item <id>]
```
````

````

- [ ] **Step 3: Commit**

```bash
git add templates/fleet-config.json CLAUDE.md
git commit -m "docs: add rewards-log.sh commands and fleet-config rewards placeholder"
````

---

### Task 9: End-to-end validation

**Files:** None modified — validation only.

- [ ] **Step 1: Run the full test suite**

```bash
bash ops/tests/test-rewards-log.sh
```

Expected: All tests pass.

- [ ] **Step 2: Syntax check all modified scripts**

```bash
bash -n ops/rewards-log.sh
bash -n ops/metrics-log.sh
```

Expected: clean parse for both.

- [ ] **Step 3: Validate settings.json**

```bash
cat .claude/settings.json | jq . > /dev/null
```

Expected: exit 0.

- [ ] **Step 4: Smoke test end-to-end in a temp directory**

```bash
TMPDIR=$(mktemp -d)
mkdir -p "$TMPDIR/rewards" "$TMPDIR/findings" "$TMPDIR/metrics"
cp .claude/rewards/ledger.md "$TMPDIR/rewards/"
cp .claude/findings/register.md "$TMPDIR/findings/"
touch "$TMPDIR/metrics/events.jsonl"

REWARDS_LEDGER="$TMPDIR/rewards/ledger.md" \
REWARDS_CHECKSUM="$TMPDIR/rewards/ledger-checksum.sha256" \
FINDINGS_REGISTER="$TMPDIR/findings/register.md" \
METRICS_LOG_FILE="$TMPDIR/metrics/events.jsonl" \
  ops/rewards-log.sh reprimand \
    --issuer ciso --subject backend-specialist --domain security \
    --severity high --item 42 \
    --description "Missing auth tests" --evidence "PR #99"

REWARDS_LEDGER="$TMPDIR/rewards/ledger.md" \
REWARDS_CHECKSUM="$TMPDIR/rewards/ledger-checksum.sha256" \
FINDINGS_REGISTER="$TMPDIR/findings/register.md" \
METRICS_LOG_FILE="$TMPDIR/metrics/events.jsonl" \
  ops/rewards-log.sh kudo \
    --issuer po --subject backend-specialist --domain delivery \
    --item 42 \
    --description "Fast delivery" --evidence "AC passed"

REWARDS_LEDGER="$TMPDIR/rewards/ledger.md" \
REWARDS_CHECKSUM="$TMPDIR/rewards/ledger-checksum.sha256" \
  ops/rewards-log.sh profile backend-specialist

REWARDS_LEDGER="$TMPDIR/rewards/ledger.md" \
  ops/rewards-log.sh tensions

rm -rf "$TMPDIR"
```

Expected: Reprimand issued, kudo issued, tension auto-detected, profile shows 1K/1R/1T, tensions shows 1 open.

- [ ] **Step 5: Verify checksum protection works**

```bash
sha256sum .claude/rewards/ledger.md > /tmp/expected-checksum.txt
diff <(cut -d' ' -f1 /tmp/expected-checksum.txt) <(cut -d' ' -f1 .claude/rewards/ledger-checksum.sha256)
rm /tmp/expected-checksum.txt
```

Expected: no diff (checksum matches).
