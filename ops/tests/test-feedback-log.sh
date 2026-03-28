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

# ── Summary ────────────────────────────────────────────────────────────
echo ""
echo "========================================"
echo -e "Results: ${PASS} passed, ${FAIL} failed, ${TOTAL} total"
echo "========================================"
[[ "$FAIL" -eq 0 ]] && exit 0 || exit 1
