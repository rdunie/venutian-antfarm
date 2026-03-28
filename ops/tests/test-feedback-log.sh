#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
FEEDBACK_LOG="${REPO_ROOT}/ops/feedback-log.sh"

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
  "$FEEDBACK_LOG" reprimand \
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
  "$FEEDBACK_LOG" kudo \
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
assert_contains "tension references both signals" "$TMPDIR/rewards/ledger.md" "R-001 vs K-001"
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
  "$FEEDBACK_LOG" reprimand \
    --issuer ciso --subject backend-specialist --domain security \
    --severity low --item 42 \
    --description "Minor issue" --evidence "..."

REWARDS_LEDGER="$TMPDIR/rewards/ledger.md" \
REWARDS_CHECKSUM="$TMPDIR/rewards/ledger-checksum.sha256" \
FINDINGS_REGISTER="$TMPDIR/findings/register.md" \
METRICS_LOG_FILE="$TMPDIR/metrics/events.jsonl" \
  "$FEEDBACK_LOG" kudo \
    --issuer po --subject backend-specialist --domain delivery \
    --item 43 \
    --description "Good work" --evidence "..."

assert_not_contains "no tension for different items" "$TMPDIR/rewards/ledger.md" "\\[tension\\]"

# ── Test: missing required args ────────────────────────────────────────
echo ""
echo "=== Validation ==="

EXIT_CODE=0
REWARDS_LEDGER="$TMPDIR/rewards/ledger.md" \
REWARDS_CHECKSUM="$TMPDIR/rewards/ledger-checksum.sha256" \
FINDINGS_REGISTER="$TMPDIR/findings/register.md" \
METRICS_LOG_FILE="$TMPDIR/metrics/events.jsonl" \
  "$FEEDBACK_LOG" reprimand --issuer ciso 2>/dev/null || EXIT_CODE=$?
assert_exit "reprimand without --subject fails" 1 "$EXIT_CODE"

EXIT_CODE=0
REWARDS_LEDGER="$TMPDIR/rewards/ledger.md" \
REWARDS_CHECKSUM="$TMPDIR/rewards/ledger-checksum.sha256" \
FINDINGS_REGISTER="$TMPDIR/findings/register.md" \
METRICS_LOG_FILE="$TMPDIR/metrics/events.jsonl" \
  "$FEEDBACK_LOG" reprimand --issuer ciso --subject x --domain y --description "z" --evidence "z" 2>/dev/null || EXIT_CODE=$?
assert_exit "reprimand without --severity fails" 1 "$EXIT_CODE"

# ── Test: profile query ─────────────────────────────────────────────
echo ""
echo "=== Profile query ==="
setup_ledger

REWARDS_LEDGER="$TMPDIR/rewards/ledger.md" \
REWARDS_CHECKSUM="$TMPDIR/rewards/ledger-checksum.sha256" \
FINDINGS_REGISTER="$TMPDIR/findings/register.md" \
METRICS_LOG_FILE="$TMPDIR/metrics/events.jsonl" \
  "$FEEDBACK_LOG" reprimand \
    --issuer ciso --subject test-agent --domain security \
    --severity high --item 10 \
    --description "Test reprimand" --evidence "Test evidence"

PROFILE_OUTPUT=$(REWARDS_LEDGER="$TMPDIR/rewards/ledger.md" \
  "$FEEDBACK_LOG" profile test-agent)

TOTAL=$((TOTAL + 1))
if echo "$PROFILE_OUTPUT" | grep -q "1 reprimand"; then
  echo -e "  ${GREEN}PASS${NC} profile shows reprimand count"
  PASS=$((PASS + 1))
else
  echo -e "  ${RED}FAIL${NC} profile should show 1 reprimand, got: $PROFILE_OUTPUT"
  FAIL=$((FAIL + 1))
fi

NO_PROFILE=$(REWARDS_LEDGER="$TMPDIR/rewards/ledger.md" \
  "$FEEDBACK_LOG" profile nonexistent-agent)

TOTAL=$((TOTAL + 1))
if echo "$NO_PROFILE" | grep -q "no behavioral signals"; then
  echo -e "  ${GREEN}PASS${NC} profile handles unknown agent"
  PASS=$((PASS + 1))
else
  echo -e "  ${RED}FAIL${NC} profile should say no signals for unknown agent"
  FAIL=$((FAIL + 1))
fi

# ── Test: tensions query ───────────────────────────────────────────────
echo ""
echo "=== Tensions query ==="

TENSIONS_OUTPUT=$(REWARDS_LEDGER="$TMPDIR/rewards/ledger.md" \
  "$FEEDBACK_LOG" tensions)

TOTAL=$((TOTAL + 1))
if echo "$TENSIONS_OUTPUT" | grep -q "(none)"; then
  echo -e "  ${GREEN}PASS${NC} tensions shows none when no tensions exist"
  PASS=$((PASS + 1))
else
  echo -e "  ${RED}FAIL${NC} tensions should show none, got: $TENSIONS_OUTPUT"
  FAIL=$((FAIL + 1))
fi

# ── Test: tensions --item filter ──────────────────────────────────────
echo ""
echo "=== Tensions --item filter ==="
setup_ledger

# Create reprimand + kudo on item 42 to trigger a tension
REWARDS_LEDGER="$TMPDIR/rewards/ledger.md" \
REWARDS_CHECKSUM="$TMPDIR/rewards/ledger-checksum.sha256" \
FINDINGS_REGISTER="$TMPDIR/findings/register.md" \
METRICS_LOG_FILE="$TMPDIR/metrics/events.jsonl" \
  "$FEEDBACK_LOG" reprimand \
    --issuer ciso --subject backend-specialist --domain security \
    --severity high --item 42 \
    --description "Skipped tests" --evidence "PR #87"

REWARDS_LEDGER="$TMPDIR/rewards/ledger.md" \
REWARDS_CHECKSUM="$TMPDIR/rewards/ledger-checksum.sha256" \
FINDINGS_REGISTER="$TMPDIR/findings/register.md" \
METRICS_LOG_FILE="$TMPDIR/metrics/events.jsonl" \
  "$FEEDBACK_LOG" kudo \
    --issuer po --subject backend-specialist --domain delivery \
    --item 42 \
    --description "Clean acceptance" --evidence "All AC passed"

# Query tensions for item 42 — should find the tension
TENSIONS_42=$(REWARDS_LEDGER="$TMPDIR/rewards/ledger.md" \
  "$FEEDBACK_LOG" tensions --item 42)

TOTAL=$((TOTAL + 1))
if echo "$TENSIONS_42" | grep -q "\\[tension\\].*item-42"; then
  echo -e "  ${GREEN}PASS${NC} tensions --item 42 finds the tension"
  PASS=$((PASS + 1))
else
  echo -e "  ${RED}FAIL${NC} tensions --item 42 should find tension, got: $TENSIONS_42"
  FAIL=$((FAIL + 1))
fi

# Query tensions for item 999 — should find none
TENSIONS_999=$(REWARDS_LEDGER="$TMPDIR/rewards/ledger.md" \
  "$FEEDBACK_LOG" tensions --item 999)

TOTAL=$((TOTAL + 1))
if echo "$TENSIONS_999" | grep -q "(none)"; then
  echo -e "  ${GREEN}PASS${NC} tensions --item 999 shows none"
  PASS=$((PASS + 1))
else
  echo -e "  ${RED}FAIL${NC} tensions --item 999 should show none, got: $TENSIONS_999"
  FAIL=$((FAIL + 1))
fi

# ── Test: origin tier tagging ─────────────────────────────────────────
echo ""
echo "=== Origin Tier ==="
setup_ledger

# Create fleet-config.json in TMPDIR for tier resolution
cat > "$TMPDIR/fleet-config.json" <<'CONFIG'
{
  "agents": {
    "governance": ["cro", "ciso", "ceo", "cto", "cfo", "coo", "cko"],
    "core": ["product-owner", "solution-architect", "scrum-master", "knowledge-ops", "platform-ops", "compliance-auditor"]
  },
  "rewards": { "escalation_deadline_days": 7 },
  "pathways": {
    "declared": {
      "feedback": ["security-reviewer -> ciso", "backend-specialist -> solution-architect"],
      "escalation": ["* -> solution-architect", "* -> scrum-master", "* -> product-owner"],
      "governance": ["ciso -> cro", "cto -> solution-architect", "* -> ceo"]
    }
  }
}
CONFIG

FEEDBACK_LEDGER="$TMPDIR/rewards/ledger.md" \
FEEDBACK_CHECKSUM="$TMPDIR/rewards/ledger-checksum.sha256" \
FINDINGS_REGISTER="$TMPDIR/findings/register.md" \
METRICS_LOG_FILE="$TMPDIR/metrics/events.jsonl" \
REPO_ROOT="${TMPDIR}" \
  "$FEEDBACK_LOG" reprimand \
    --issuer ciso --subject backend-specialist --domain security \
    --severity medium --item 10 \
    --description "Test governance tier" --evidence "Evidence A"
EXIT_CODE=$?

assert_exit "governance tier reprimand exits 0" 0 "$EXIT_CODE"
assert_contains "reprimand from ciso has governance tier" "$TMPDIR/rewards/ledger.md" "\*\*Origin tier:\*\* governance"

setup_ledger
FEEDBACK_LEDGER="$TMPDIR/rewards/ledger.md" \
FEEDBACK_CHECKSUM="$TMPDIR/rewards/ledger-checksum.sha256" \
FINDINGS_REGISTER="$TMPDIR/findings/register.md" \
METRICS_LOG_FILE="$TMPDIR/metrics/events.jsonl" \
REPO_ROOT="${TMPDIR}" \
  "$FEEDBACK_LOG" kudo \
    --issuer product-owner --subject backend-specialist --domain delivery \
    --description "Great work" --evidence "Evidence B"
EXIT_CODE=$?

assert_exit "core tier kudo exits 0" 0 "$EXIT_CODE"
assert_contains "kudo from product-owner has core tier" "$TMPDIR/rewards/ledger.md" "\*\*Origin tier:\*\* core"

# ── Test: recommend subcommand ────────────────────────────────────────
echo ""
echo "=== Recommend ==="
setup_ledger

LEDGER="$TMPDIR/rewards/ledger.md"
CHECKSUM="$TMPDIR/rewards/ledger-checksum.sha256"
FINDINGS_REG="$TMPDIR/findings/register.md"
METRICS_FILE="$TMPDIR/metrics/events.jsonl"

# Test: recommend creates a P-entry
rec_exit=0
FEEDBACK_LEDGER="$LEDGER" FEEDBACK_CHECKSUM="$CHECKSUM" \
FINDINGS_REGISTER="$FINDINGS_REG" METRICS_LOG_FILE="$METRICS_FILE" \
REPO_ROOT="${TMPDIR}" "${FEEDBACK_LOG}" recommend --issuer security-reviewer --subject backend-specialist \
  --type reprimand --domain security --severity medium \
  --description "Shallow validation" --evidence "No sanitization" \
  --item 42 || rec_exit=$?
assert_exit "recommend exits 0" 0 "${rec_exit}"
assert_contains "P-001 created" "$LEDGER" "P-001 \\[proposal\\]"
assert_contains "proposal has supervisor" "$LEDGER" "Supervisor.*ciso"
assert_contains "proposal has status pending" "$LEDGER" "Status.*pending"
assert_contains "proposal has escalation deadline" "$LEDGER" "Escalation deadline"
assert_contains "proposal has type reprimand" "$LEDGER" "Type.*reprimand"
assert_contains "proposal has origin tier specialist" "$LEDGER" "Origin tier.*specialist"

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
assert_contains "fallback supervisor is solution-architect" "$LEDGER" "Supervisor.*solution-architect"

# ── Test: formalize and reject ────────────────────────────────────────
echo ""
echo "=== Formalize/Reject ==="
setup_ledger

# Create a proposal first
FEEDBACK_LEDGER="$LEDGER" FEEDBACK_CHECKSUM="$CHECKSUM" \
FINDINGS_REGISTER="$FINDINGS_REG" METRICS_LOG_FILE="$METRICS_FILE" \
REPO_ROOT="${TMPDIR}" "${FEEDBACK_LOG}" recommend \
  --issuer security-reviewer --subject backend-specialist \
  --type reprimand --domain security --severity medium \
  --description "Shallow validation" --evidence "No sanitization" \
  --item 42 > /dev/null

# Test: formalize by correct supervisor creates R-entry with Origin
form_exit=0
FEEDBACK_LEDGER="$LEDGER" FEEDBACK_CHECKSUM="$CHECKSUM" \
FINDINGS_REGISTER="$FINDINGS_REG" METRICS_LOG_FILE="$METRICS_FILE" \
REPO_ROOT="${TMPDIR}" "${FEEDBACK_LOG}" formalize P-001 --issuer ciso || form_exit=$?
assert_exit "formalize exits 0" 0 "${form_exit}"
assert_contains "formalize creates R-entry" "$LEDGER" "R-001 \\[reprimand\\]"
assert_contains "formalize sets Origin field" "$LEDGER" "\\*\\*Origin:\\*\\* P-001"
assert_contains "formalize sets Origin tier specialist" "$LEDGER" "\\*\\*Origin tier:\\*\\* specialist"
assert_contains "proposal status updated to formalized" "$LEDGER" "Status.*formalized.*R-001"

# Test: wrong supervisor cannot formalize
form_wrong_exit=0
FEEDBACK_LEDGER="$LEDGER" FEEDBACK_CHECKSUM="$CHECKSUM" \
FINDINGS_REGISTER="$FINDINGS_REG" METRICS_LOG_FILE="$METRICS_FILE" \
REPO_ROOT="${TMPDIR}" "${FEEDBACK_LOG}" formalize P-001 --issuer cto 2>/dev/null || form_wrong_exit=$?
assert_exit "wrong supervisor formalize fails" 1 "${form_wrong_exit}"

# Test: formalize non-pending proposal fails
form_nonpending_exit=0
FEEDBACK_LEDGER="$LEDGER" FEEDBACK_CHECKSUM="$CHECKSUM" \
FINDINGS_REGISTER="$FINDINGS_REG" METRICS_LOG_FILE="$METRICS_FILE" \
REPO_ROOT="${TMPDIR}" "${FEEDBACK_LOG}" formalize P-001 --issuer ciso 2>/dev/null || form_nonpending_exit=$?
assert_exit "formalize already-formalized proposal fails" 1 "${form_nonpending_exit}"

# Test: reject with reason updates proposal status
setup_ledger
FEEDBACK_LEDGER="$LEDGER" FEEDBACK_CHECKSUM="$CHECKSUM" \
FINDINGS_REGISTER="$FINDINGS_REG" METRICS_LOG_FILE="$METRICS_FILE" \
REPO_ROOT="${TMPDIR}" "${FEEDBACK_LOG}" recommend \
  --issuer security-reviewer --subject backend-specialist \
  --type reprimand --domain security --severity low \
  --description "Minor issue" --evidence "See PR" > /dev/null

rej_exit=0
FEEDBACK_LEDGER="$LEDGER" FEEDBACK_CHECKSUM="$CHECKSUM" \
FINDINGS_REGISTER="$FINDINGS_REG" METRICS_LOG_FILE="$METRICS_FILE" \
REPO_ROOT="${TMPDIR}" "${FEEDBACK_LOG}" reject P-001 --issuer ciso --reason "Insufficient evidence" || rej_exit=$?
assert_exit "reject exits 0" 0 "${rej_exit}"
assert_contains "reject updates status" "$LEDGER" "Status.*rejected.*Insufficient evidence"

# Test: reject without --reason fails
rej_noreason_exit=0
FEEDBACK_LEDGER="$LEDGER" FEEDBACK_CHECKSUM="$CHECKSUM" \
FINDINGS_REGISTER="$FINDINGS_REG" METRICS_LOG_FILE="$METRICS_FILE" \
REPO_ROOT="${TMPDIR}" "${FEEDBACK_LOG}" reject P-001 --issuer ciso 2>/dev/null || rej_noreason_exit=$?
assert_exit "reject without --reason fails" 1 "${rej_noreason_exit}"

# ── Test: check-escalations ───────────────────────────────────────────
echo ""
echo "=== Escalation ==="
setup_ledger

# Create a proposal then backdate its deadline
FEEDBACK_LEDGER="$LEDGER" FEEDBACK_CHECKSUM="$CHECKSUM" \
FINDINGS_REGISTER="$FINDINGS_REG" METRICS_LOG_FILE="$METRICS_FILE" \
REPO_ROOT="${TMPDIR}" "${FEEDBACK_LOG}" recommend \
  --issuer security-reviewer --subject backend-specialist \
  --type reprimand --domain security --severity medium \
  --description "Shallow validation" --evidence "No sanitization" > /dev/null

# Backdate deadline to yesterday so it triggers escalation
yesterday=$(date -u -d "-1 day" +%Y-%m-%d 2>/dev/null || date -u -v-1d +%Y-%m-%d 2>/dev/null || echo "2020-01-01")
tmpfile=$(mktemp)
awk -v old_dl="$(grep '\*\*Escalation deadline:\*\*' "$LEDGER" | head -1 | sed 's/.*\*\* //')" \
    -v new_dl="$yesterday" '{
  if ($0 ~ /\*\*Escalation deadline:\*\*/) {
    gsub(old_dl, new_dl)
  }
  print
}' "$LEDGER" > "$tmpfile" && mv "$tmpfile" "$LEDGER"

# Run check-escalations
esc_exit=0
ESC_OUTPUT=$(FEEDBACK_LEDGER="$LEDGER" FEEDBACK_CHECKSUM="$CHECKSUM" \
FINDINGS_REGISTER="$FINDINGS_REG" METRICS_LOG_FILE="$METRICS_FILE" \
REPO_ROOT="${TMPDIR}" "${FEEDBACK_LOG}" check-escalations) || esc_exit=$?
assert_exit "check-escalations exits 0" 0 "${esc_exit}"

# ciso -> cro per governance pathway in fleet-config.json
assert_contains "supervisor escalated to cro" "$LEDGER" "Supervisor.*cro"
assert_contains "status still pending after escalation" "$LEDGER" "Status.*pending"

# Test: fresh (non-expired) proposal is NOT escalated
setup_ledger
FEEDBACK_LEDGER="$LEDGER" FEEDBACK_CHECKSUM="$CHECKSUM" \
FINDINGS_REGISTER="$FINDINGS_REG" METRICS_LOG_FILE="$METRICS_FILE" \
REPO_ROOT="${TMPDIR}" "${FEEDBACK_LOG}" recommend \
  --issuer security-reviewer --subject frontend-specialist \
  --type kudo --domain testing \
  --description "Great coverage" --evidence "100%" > /dev/null

ESC_OUTPUT2=$(FEEDBACK_LEDGER="$LEDGER" FEEDBACK_CHECKSUM="$CHECKSUM" \
FINDINGS_REGISTER="$FINDINGS_REG" METRICS_LOG_FILE="$METRICS_FILE" \
REPO_ROOT="${TMPDIR}" "${FEEDBACK_LOG}" check-escalations)

TOTAL=$((TOTAL + 1))
if echo "$ESC_OUTPUT2" | grep -q "escalated=0"; then
  echo -e "  ${GREEN}PASS${NC} fresh proposal not escalated"
  PASS=$((PASS + 1))
else
  echo -e "  ${RED}FAIL${NC} fresh proposal should not be escalated, got: $ESC_OUTPUT2"
  FAIL=$((FAIL + 1))
fi

echo ""
echo "=== Profile Extensions ==="
setup_ledger

# Create entries with different tiers
FEEDBACK_LEDGER="$TMPDIR/rewards/ledger.md" \
FEEDBACK_CHECKSUM="$TMPDIR/rewards/ledger-checksum.sha256" \
FINDINGS_REGISTER="$TMPDIR/findings/register.md" \
METRICS_LOG_FILE="$TMPDIR/metrics/events.jsonl" \
REPO_ROOT="${TMPDIR}" \
  "${FEEDBACK_LOG}" reprimand --issuer ciso --subject backend-specialist \
  --domain security --severity high --description "tier test" --evidence "test"

FEEDBACK_LEDGER="$TMPDIR/rewards/ledger.md" \
FEEDBACK_CHECKSUM="$TMPDIR/rewards/ledger-checksum.sha256" \
FINDINGS_REGISTER="$TMPDIR/findings/register.md" \
METRICS_LOG_FILE="$TMPDIR/metrics/events.jsonl" \
REPO_ROOT="${TMPDIR}" \
  "${FEEDBACK_LOG}" recommend --issuer security-reviewer --subject backend-specialist \
  --type kudo --domain security \
  --description "pending test" --evidence "test"

profile_output=$(FEEDBACK_LEDGER="$TMPDIR/rewards/ledger.md" \
  FEEDBACK_CHECKSUM="$TMPDIR/rewards/ledger-checksum.sha256" \
  "${FEEDBACK_LOG}" profile backend-specialist)

echo "$profile_output" > "$TMPDIR/profile-output.txt"
assert_contains "profile shows pending proposals" "$TMPDIR/profile-output.txt" "pending"
assert_contains "profile shows tier breakdown" "$TMPDIR/profile-output.txt" "tier"

# ── Test: weighted score ──────────────────────────────────────────────
echo ""
echo "=== Weighted Score ==="
setup_ledger

LEDGER="$TMPDIR/rewards/ledger.md"
CHECKSUM="$TMPDIR/rewards/ledger-checksum.sha256"
FINDINGS_REG="$TMPDIR/findings/register.md"
METRICS_FILE="$TMPDIR/metrics/events.jsonl"

# Write fleet-config with weighting for score tests
cat > "$TMPDIR/fleet-config.json" <<'CONFIG'
{
  "agents": {
    "governance": ["cro", "ciso", "ceo", "cto", "cfo", "coo", "cko"],
    "core": ["product-owner", "solution-architect", "scrum-master", "knowledge-ops", "platform-ops", "compliance-auditor"]
  },
  "rewards": {
    "escalation_deadline_days": 7,
    "weighting": {
      "tier_multipliers": {
        "governance": 1.0,
        "core": 0.8,
        "specialist": 0.5
      },
      "type_multipliers": {
        "kudo": 1.0,
        "reprimand": 1.5
      },
      "domain_multipliers": {
        "security": 1.5,
        "_default": 1.0
      },
      "decay": {
        "cliff_items": 10,
        "post_cliff_multiplier": 0.25
      }
    }
  },
  "pathways": {
    "declared": {
      "feedback": ["security-reviewer -> ciso", "backend-specialist -> solution-architect"],
      "escalation": ["* -> solution-architect", "* -> scrum-master", "* -> product-owner"],
      "governance": ["ciso -> cro", "cto -> solution-architect", "* -> ceo"]
    }
  }
}
CONFIG

# Test 1: governance kudo for backend-specialist (tier=1.0, type=1.0, domain=1.0, decay=1.0)
FEEDBACK_LEDGER="$LEDGER" FEEDBACK_CHECKSUM="$CHECKSUM" \
FINDINGS_REGISTER="$FINDINGS_REG" METRICS_LOG_FILE="$METRICS_FILE" \
REPO_ROOT="${TMPDIR}" "${FEEDBACK_LOG}" kudo \
  --issuer ciso --subject backend-specialist --domain delivery \
  --description "Good work" --evidence "All tests pass" > /dev/null

# Test 2: governance reprimand for backend-specialist (tier=1.0, type=1.5, domain=1.0, decay=1.0)
FEEDBACK_LEDGER="$LEDGER" FEEDBACK_CHECKSUM="$CHECKSUM" \
FINDINGS_REGISTER="$FINDINGS_REG" METRICS_LOG_FILE="$METRICS_FILE" \
REPO_ROOT="${TMPDIR}" "${FEEDBACK_LOG}" reprimand \
  --issuer ciso --subject backend-specialist --domain delivery \
  --severity high --description "Missed edge case" --evidence "PR #99" > /dev/null

# Test 3: assert score output
SCORE_OUTPUT=$(FEEDBACK_LEDGER="$LEDGER" FEEDBACK_CHECKSUM="$CHECKSUM" \
FINDINGS_REGISTER="$FINDINGS_REG" METRICS_LOG_FILE="$METRICS_FILE" \
REPO_ROOT="${TMPDIR}" "${FEEDBACK_LOG}" score backend-specialist)

echo "$SCORE_OUTPUT" > "$TMPDIR/score-output.txt"
assert_contains "score has net=" "$TMPDIR/score-output.txt" "^net="
assert_contains "score has kudos=" "$TMPDIR/score-output.txt" "^kudos="
assert_contains "score has reprimands=" "$TMPDIR/score-output.txt" "^reprimands="
assert_contains "score has signals=2" "$TMPDIR/score-output.txt" "^signals=2$"
assert_contains "score has recent=" "$TMPDIR/score-output.txt" "^recent="

# Test 4: kudo for security-reviewer in security domain → domain multiplier 1.5
setup_ledger
: > "$METRICS_FILE"

FEEDBACK_LEDGER="$LEDGER" FEEDBACK_CHECKSUM="$CHECKSUM" \
FINDINGS_REGISTER="$FINDINGS_REG" METRICS_LOG_FILE="$METRICS_FILE" \
REPO_ROOT="${TMPDIR}" "${FEEDBACK_LOG}" kudo \
  --issuer ciso --subject security-reviewer --domain security \
  --description "Good audit" --evidence "Found vuln" > /dev/null

SCORE_SEC=$(FEEDBACK_LEDGER="$LEDGER" FEEDBACK_CHECKSUM="$CHECKSUM" \
FINDINGS_REGISTER="$FINDINGS_REG" METRICS_LOG_FILE="$METRICS_FILE" \
REPO_ROOT="${TMPDIR}" "${FEEDBACK_LOG}" score security-reviewer)

echo "$SCORE_SEC" > "$TMPDIR/score-sec.txt"
assert_contains "security domain kudo has kudos=1.5" "$TMPDIR/score-sec.txt" "^kudos=1.5$"

# Test 5: score for nonexistent agent
SCORE_NONE=$(FEEDBACK_LEDGER="$LEDGER" FEEDBACK_CHECKSUM="$CHECKSUM" \
FINDINGS_REGISTER="$FINDINGS_REG" METRICS_LOG_FILE="$METRICS_FILE" \
REPO_ROOT="${TMPDIR}" "${FEEDBACK_LOG}" score nonexistent-agent)

echo "$SCORE_NONE" > "$TMPDIR/score-none.txt"
assert_contains "nonexistent agent net=0.0" "$TMPDIR/score-none.txt" "^net=0.0$"
assert_contains "nonexistent agent signals=0" "$TMPDIR/score-none.txt" "^signals=0$"

# ── Summary ────────────────────────────────────────────────────────────
echo ""
echo "========================================"
echo -e "Results: ${PASS} passed, ${FAIL} failed, ${TOTAL} total"
echo "========================================"
[[ "$FAIL" -eq 0 ]] && exit 0 || exit 1
