#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
SIGNAL_READ="${REPO_ROOT}/ops/lib/signal-read.sh"

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

assert_equals() {
  local label="$1" expected="$2" actual="$3"
  TOTAL=$((TOTAL + 1))
  if [[ "$actual" == "$expected" ]]; then
    echo -e "  ${GREEN}PASS${NC} ${label}"
    PASS=$((PASS + 1))
  else
    echo -e "  ${RED}FAIL${NC} ${label} — expected '${expected}', got '${actual}'"
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

TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

# Create test events
EVENTS_FILE="$TMPDIR/events.jsonl"
cat > "$EVENTS_FILE" <<'EVENTS'
{"ts":"2026-03-20T10:00:00Z","event":"feedback-proposed","agent":"security-reviewer","subject":"backend-specialist"}
{"ts":"2026-03-21T10:00:00Z","event":"feedback-formalized","agent":"ciso","proposal_id":"P-001"}
{"ts":"2026-03-22T10:00:00Z","event":"item-accepted","agent":"product-owner","item":"42"}
{"ts":"2026-03-23T10:00:00Z","event":"item-promoted","agent":"product-owner","item":"43"}
{"ts":"2026-03-24T10:00:00Z","event":"compliance-violation","agent":"cro","rule":"no-secrets"}
{"ts":"2026-03-25T10:00:00Z","event":"reward-issued","agent":"ciso","type":"kudo","subject":"backend-specialist"}
{"ts":"2026-03-26T10:00:00Z","event":"feedback-rejected","agent":"ciso","proposal_id":"P-002"}
EVENTS

# ── Type filter ──────────────────────────────────────────────────────────
echo "=== Type Filter ==="

type_output=$(METRICS_LOG_FILE="$EVENTS_FILE" "$SIGNAL_READ" --type feedback-proposed --source local)
type_count=$(echo "$type_output" | grep -c '.' || true)
assert_equals "type filter returns 1 result" "1" "$type_count"

echo "$type_output" > "$TMPDIR/type-out.txt"
assert_contains "type filter has correct event" "$TMPDIR/type-out.txt" "feedback-proposed"

# ── Topic filter ─────────────────────────────────────────────────────────
echo ""
echo "=== Topic Filter ==="

topic_output=$(METRICS_LOG_FILE="$EVENTS_FILE" "$SIGNAL_READ" --topic feedback --source local)
topic_count=$(echo "$topic_output" | grep -c '.' || true)
assert_equals "topic filter returns 3 feedback events" "3" "$topic_count"

item_topic_output=$(METRICS_LOG_FILE="$EVENTS_FILE" "$SIGNAL_READ" --topic item --source local)
item_count=$(echo "$item_topic_output" | grep -c '.' || true)
assert_equals "item topic returns 2 events" "2" "$item_count"

# ── Agent filter ─────────────────────────────────────────────────────────
echo ""
echo "=== Agent Filter ==="

agent_output=$(METRICS_LOG_FILE="$EVENTS_FILE" "$SIGNAL_READ" --agent ciso --source local)
agent_count=$(echo "$agent_output" | grep -c '.' || true)
assert_equals "agent filter returns 3 ciso events" "3" "$agent_count"

# ── Since filter ─────────────────────────────────────────────────────────
echo ""
echo "=== Since Filter ==="

# All events are within last year (use large window to avoid date fragility)
since_all=$(METRICS_LOG_FILE="$EVENTS_FILE" "$SIGNAL_READ" --since 365d --source local)
since_all_count=$(echo "$since_all" | grep -c '.' || true)
assert_equals "since 365d returns all 7 events" "7" "$since_all_count"

# ── Format count ─────────────────────────────────────────────────────────
echo ""
echo "=== Format Count ==="

count_output=$(METRICS_LOG_FILE="$EVENTS_FILE" "$SIGNAL_READ" --topic feedback --format count --source local)
assert_equals "count format returns 3" "3" "$count_output"

# ── Combined filters ─────────────────────────────────────────────────────
echo ""
echo "=== Combined Filters ==="

combined_output=$(METRICS_LOG_FILE="$EVENTS_FILE" "$SIGNAL_READ" --topic feedback --agent ciso --source local)
combined_count=$(echo "$combined_output" | grep -c '.' || true)
assert_equals "topic+agent combined returns 2" "2" "$combined_count"

# ── Empty result ─────────────────────────────────────────────────────────
echo ""
echo "=== Empty Result ==="

empty_output=$(METRICS_LOG_FILE="$EVENTS_FILE" "$SIGNAL_READ" --type nonexistent --source local)
empty_count=$(echo "$empty_output" | grep -c '.' || true)
assert_equals "nonexistent type returns 0" "0" "$empty_count"

# ── Missing file ─────────────────────────────────────────────────────────
echo ""
echo "=== Missing File ==="

missing_exit=0
missing_output=$(METRICS_LOG_FILE="$TMPDIR/nonexistent.jsonl" "$SIGNAL_READ" --type item-accepted --source local) || missing_exit=$?
assert_exit "missing file exits 0" 0 "$missing_exit"
missing_count=$(echo "$missing_output" | grep -c '.' || true)
assert_equals "missing file returns 0 results" "0" "$missing_count"

# ── Malformed JSONL ──────────────────────────────────────────────────────
echo ""
echo "=== Malformed JSONL ==="

MALFORMED_FILE="$TMPDIR/malformed.jsonl"
cat > "$MALFORMED_FILE" <<'MAL'
{"ts":"2026-03-20T10:00:00Z","event":"item-accepted","item":"1"}
this is not json
{"ts":"2026-03-21T10:00:00Z","event":"item-accepted","item":"2"}
MAL

malformed_output=$(METRICS_LOG_FILE="$MALFORMED_FILE" "$SIGNAL_READ" --type item-accepted --source local)
malformed_count=$(echo "$malformed_output" | grep -c '.' || true)
assert_equals "malformed lines skipped, 2 valid results" "2" "$malformed_count"

# ── Results ──────────────────────────────────────────────────────────────
echo ""
echo "========================================"
echo "Results: ${PASS} passed, ${FAIL} failed, ${TOTAL} total"
echo "========================================"
[[ "$FAIL" -gt 0 ]] && exit 1
exit 0
