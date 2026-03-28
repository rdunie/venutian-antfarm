# Signal Bus Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Extract event emission into a shared write library and add a filtered read library with topic subscriptions, creating the foundation for a signal bus.

**Architecture:** Extract `emit_event()` and backend config from `ops/metrics-log.sh` into `ops/lib/signal-emit.sh`. Create `ops/lib/signal-read.sh` with composable jq filters, topic prefix matching, and `--source` abstraction. Both libraries are sourceable and usable as CLI.

**Tech Stack:** Bash, jq (existing toolchain)

**Spec:** `docs/superpowers/specs/2026-03-28-signal-bus-design.md`

---

### Task 1: Create the emit library (`ops/lib/signal-emit.sh`)

**Files:**

- Create: `ops/lib/signal-emit.sh`

- [ ] **Step 1: Create the lib directory**

```bash
mkdir -p ops/lib
```

- [ ] **Step 2: Create signal-emit.sh**

Create `ops/lib/signal-emit.sh`:

```bash
#!/usr/bin/env bash
# signal-emit.sh — shared event emission library
#
# Source this file, then call: signal_emit "$json_line"
# Reads backend config from fleet-config.json.
#
# Env vars:
#   METRICS_LOG_FILE  Override log path
#   REPO_ROOT         Override repo root (for fleet-config.json lookup)

# Guard against double-sourcing
[[ -n "${_SIGNAL_EMIT_LOADED:-}" ]] && return 0
_SIGNAL_EMIT_LOADED=1

# ── Backend config (loaded once on source) ────────────────────────────────
_SIGNAL_REPO_ROOT="${REPO_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
_SIGNAL_FLEET_CONFIG="${_SIGNAL_REPO_ROOT}/fleet-config.json"
_SIGNAL_BACKEND="jsonl"
_SIGNAL_WEBHOOK_URL=""

if [[ -f "$_SIGNAL_FLEET_CONFIG" ]] && command -v jq &>/dev/null; then
  _SIGNAL_BACKEND=$(jq -r '.metrics.backend // "jsonl"' "$_SIGNAL_FLEET_CONFIG" 2>/dev/null || echo "jsonl")
  _SIGNAL_WEBHOOK_URL=$(jq -r '.metrics.webhook // empty' "$_SIGNAL_FLEET_CONFIG" 2>/dev/null || echo "")
  METRICS_LOG_FILE="${METRICS_LOG_FILE:-$(jq -r '.metrics.file // empty' "$_SIGNAL_FLEET_CONFIG" 2>/dev/null || echo "")}"
fi

METRICS_LOG_FILE="${METRICS_LOG_FILE:-${_SIGNAL_REPO_ROOT}/.claude/metrics/events.jsonl}"

# Ensure log directory exists
mkdir -p "$(dirname "$METRICS_LOG_FILE")"

# ── Emit function ─────────────────────────────────────────────────────────
signal_emit() {
  local json_line="$1"
  case "$_SIGNAL_BACKEND" in
    jsonl)
      echo "$json_line" >> "$METRICS_LOG_FILE"
      ;;
    webhook)
      echo "$json_line" >> "$METRICS_LOG_FILE"  # always persist locally
      if [[ -n "$_SIGNAL_WEBHOOK_URL" ]]; then
        curl -s -X POST -H "Content-Type: application/json" \
          -d "$json_line" "$_SIGNAL_WEBHOOK_URL" >/dev/null 2>&1 || true
      fi
      ;;
    statsd|opentelemetry)
      echo "$json_line" >> "$METRICS_LOG_FILE"
      echo "WARNING: $_SIGNAL_BACKEND backend not yet implemented, falling back to JSONL" >&2
      ;;
    *)
      echo "$json_line" >> "$METRICS_LOG_FILE"
      ;;
  esac
}
```

Make it executable: `chmod +x ops/lib/signal-emit.sh`

- [ ] **Step 3: Verify syntax**

Run: `bash -n ops/lib/signal-emit.sh`
Expected: No output (clean)

- [ ] **Step 4: Commit**

```bash
git add ops/lib/signal-emit.sh
git commit -m "feat(#24): create signal-emit.sh shared write library"
```

---

### Task 2: Refactor metrics-log.sh to use the emit library

**Files:**

- Modify: `ops/metrics-log.sh`

- [ ] **Step 1: Replace the backend config and emit_event in metrics-log.sh**

In `ops/metrics-log.sh`, replace lines 18-130 (the backend config block, the log file setup, and the `emit_event()` function) with:

```bash
# ── Source shared emit library ────────────────────────────────────────────
source "$SCRIPT_DIR/lib/signal-emit.sh"

# Backward compat: alias for any internal references
emit_event() { signal_emit "$@"; }
```

Keep everything else: the shebang, SCRIPT_DIR/REPO_ROOT, the arg parsing, the AGENT variable, the TS timestamp, and all the event handler case blocks.

Specifically, remove:

- Lines 18-26 (fleet config reading) — now in the library
- Lines 28 (METRICS_LOG_FILE fallback) — now in the library
- Lines 99-101 (mkdir/touch) — now in the library
- Lines 106-130 (emit_event function) — replaced by signal_emit

Keep:

- Line 29: `AGENT="${AGENT_NAME:-unknown}"` stays
- Line 103: `TS="$(date -u +%Y-%m-%dT%H:%M:%SZ)"` stays
- All event handler case blocks stay unchanged (they call `emit_event` which now aliases to `signal_emit`)

- [ ] **Step 2: Run existing tests to verify behavioral equivalence**

Run: `bash ops/tests/test-feedback-log.sh`
Expected: 65 passed (feedback-log.sh calls metrics-log.sh internally — if emit is broken, these fail)

Run: `bash ops/tests/test-compile-floor.sh 2>&1 | grep Results:`
Expected: 146/146 passed

- [ ] **Step 3: Verify syntax**

Run: `bash -n ops/metrics-log.sh`
Expected: No output

- [ ] **Step 4: Commit**

```bash
git add ops/metrics-log.sh
git commit -m "refactor(#24): extract emit_event from metrics-log.sh to signal-emit.sh library"
```

---

### Task 3: Create the read library (`ops/lib/signal-read.sh`)

**Files:**

- Create: `ops/lib/signal-read.sh`
- Create: `ops/tests/test-signal-bus.sh`

- [ ] **Step 1: Write tests for the read library**

Create `ops/tests/test-signal-bus.sh`:

```bash
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

# All events are within last 30 days
since_all=$(METRICS_LOG_FILE="$EVENTS_FILE" "$SIGNAL_READ" --since 30d --source local)
since_all_count=$(echo "$since_all" | grep -c '.' || true)
assert_equals "since 30d returns all 7 events" "7" "$since_all_count"

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
```

Make executable: `chmod +x ops/tests/test-signal-bus.sh`

- [ ] **Step 2: Run tests to verify they fail**

Run: `bash ops/tests/test-signal-bus.sh`
Expected: FAIL (signal-read.sh doesn't exist yet)

- [ ] **Step 3: Create signal-read.sh**

Create `ops/lib/signal-read.sh`:

```bash
#!/usr/bin/env bash
# signal-read.sh — shared event query library
#
# CLI: ops/lib/signal-read.sh --type <type> [--topic <prefix>] [--agent <name>]
#                              [--since Nd|Nh] [--source local] [--format json|count]
#
# Sourceable: source ops/lib/signal-read.sh; signal_query --topic feedback --since 7d
#
# Requires: jq

set -euo pipefail

# ── Dependency check ──────────────────────────────────────────────────────
if ! command -v jq &>/dev/null; then
  echo "ERROR: signal-read.sh requires jq. Install jq to use event queries." >&2
  exit 1
fi

# ── Defaults ──────────────────────────────────────────────────────────────
_SR_REPO_ROOT="${REPO_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
_SR_FLEET_CONFIG="${_SR_REPO_ROOT}/fleet-config.json"

# Resolve METRICS_LOG_FILE if not set
if [[ -z "${METRICS_LOG_FILE:-}" ]]; then
  if [[ -f "$_SR_FLEET_CONFIG" ]] && command -v jq &>/dev/null; then
    METRICS_LOG_FILE=$(jq -r '.metrics.file // empty' "$_SR_FLEET_CONFIG" 2>/dev/null || echo "")
  fi
  METRICS_LOG_FILE="${METRICS_LOG_FILE:-${_SR_REPO_ROOT}/.claude/metrics/events.jsonl}"
fi

# ── Query function ────────────────────────────────────────────────────────
signal_query() {
  local type="" topic="" agent="" since="" source_type="local" format="json"

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --type)   type="$2";        shift 2 ;;
      --topic)  topic="$2";       shift 2 ;;
      --agent)  agent="$2";       shift 2 ;;
      --since)  since="$2";       shift 2 ;;
      --source) source_type="$2"; shift 2 ;;
      --format) format="$2";      shift 2 ;;
      *) shift ;;
    esac
  done

  # Resolve source file
  local source_file=""
  case "$source_type" in
    local)
      source_file="$METRICS_LOG_FILE"
      ;;
    *)
      echo "ERROR: unknown source '${source_type}'. Supported: local" >&2
      return 1
      ;;
  esac

  # Guard: source file must exist
  if [[ ! -f "$source_file" ]]; then
    if [[ "$format" == "count" ]]; then
      echo "0"
    fi
    return 0
  fi

  # Build jq filter
  local jq_filter='select(1)'

  # --type: exact match
  if [[ -n "$type" ]]; then
    jq_filter="$jq_filter | select(.event == \"$type\")"
  fi

  # --topic: prefix match with trailing hyphen
  if [[ -n "$topic" ]]; then
    jq_filter="$jq_filter | select(.event | startswith(\"${topic}-\"))"
  fi

  # --agent: match agent field
  if [[ -n "$agent" ]]; then
    jq_filter="$jq_filter | select(.agent == \"$agent\")"
  fi

  # --since: compute cutoff timestamp
  if [[ -n "$since" ]]; then
    local since_value since_unit since_cutoff
    since_value="${since%[dh]}"
    since_unit="${since: -1}"
    case "$since_unit" in
      d) since_cutoff=$(date -u -d "-${since_value} days" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u -v-${since_value}d +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || echo "") ;;
      h) since_cutoff=$(date -u -d "-${since_value} hours" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u -v-${since_value}H +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || echo "") ;;
      *) since_cutoff="" ;;
    esac
    if [[ -n "$since_cutoff" ]]; then
      jq_filter="$jq_filter | select(.ts >= \"$since_cutoff\")"
    fi
  fi

  # Execute query
  if [[ "$format" == "count" ]]; then
    jq -c -R "fromjson? | $jq_filter" "$source_file" | jq -s 'length'
  else
    jq -c -R "fromjson? | $jq_filter" "$source_file"
  fi
}

# ── CLI mode (when executed, not sourced) ─────────────────────────────────
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  signal_query "$@"
fi
```

Make executable: `chmod +x ops/lib/signal-read.sh`

- [ ] **Step 4: Run tests to verify they pass**

Run: `bash ops/tests/test-signal-bus.sh`
Expected: All tests pass

- [ ] **Step 5: Verify syntax**

Run: `bash -n ops/lib/signal-read.sh`
Expected: No output

- [ ] **Step 6: Commit**

```bash
git add ops/lib/signal-read.sh ops/tests/test-signal-bus.sh
git commit -m "feat(#24): create signal-read.sh query library with filter, topic, source abstraction"
```

---

### Task 4: Add emit library tests

**Files:**

- Modify: `ops/tests/test-signal-bus.sh`

- [ ] **Step 1: Add emit tests to test-signal-bus.sh**

Add a new section at the top of the test file (before the read tests), after the TMPDIR setup:

```bash
# ── Emit Library Tests ───────────────────────────────────────────────────
echo "=== Emit Library ==="

EMIT_FILE="$TMPDIR/emit-test.jsonl"

# Source the emit library
METRICS_LOG_FILE="$EMIT_FILE" source "${REPO_ROOT}/ops/lib/signal-emit.sh"

# Test: signal_emit writes to file
signal_emit '{"ts":"2026-03-28T00:00:00Z","event":"test-event","agent":"test"}'
emit_exit=$?
assert_exit "signal_emit exits 0" 0 "$emit_exit"

emit_count=$(wc -l < "$EMIT_FILE" | tr -d ' ')
assert_equals "emit wrote 1 line" "1" "$emit_count"

assert_contains "emitted event has correct content" "$EMIT_FILE" "test-event"

# Test: second emit appends
signal_emit '{"ts":"2026-03-28T00:01:00Z","event":"test-event-2","agent":"test"}'
emit_count2=$(wc -l < "$EMIT_FILE" | tr -d ' ')
assert_equals "emit appended (2 lines)" "2" "$emit_count2"

# Reset for read tests
_SIGNAL_EMIT_LOADED=""
```

- [ ] **Step 2: Run tests**

Run: `bash ops/tests/test-signal-bus.sh`
Expected: All tests pass (emit + read)

- [ ] **Step 3: Commit**

```bash
git add ops/tests/test-signal-bus.sh
git commit -m "test(#24): add emit library tests to signal bus test suite"
```

---

### Task 5: Create framework documentation

**Files:**

- Create: `docs/SIGNAL-BUS.md`

- [ ] **Step 1: Write the signal bus guide**

Create `docs/SIGNAL-BUS.md`:

````markdown
# Signal Bus

Event communication libraries for the agent fleet harness. Provides shared read and write abstractions over the metrics event log.

## Write Path

### Using the emit library

Source `ops/lib/signal-emit.sh` and call `signal_emit`:

```bash
source ops/lib/signal-emit.sh
signal_emit '{"ts":"...","event":"my-event","agent":"my-agent"}'
```
````

The library reads backend config from `fleet-config.json` (jsonl, webhook, etc.) and dispatches accordingly. Always persists locally to `events.jsonl`.

### Using metrics-log.sh (CLI)

For structured event emission with validation, use the CLI entry point:

```bash
ops/metrics-log.sh <event-type> [--flags...]
```

This validates event types and constructs JSON before calling `signal_emit`.

## Read Path

### CLI usage

```bash
ops/lib/signal-read.sh --type feedback-proposed --since 7d
ops/lib/signal-read.sh --topic feedback --agent backend-specialist
ops/lib/signal-read.sh --topic item --format count --source local
```

### Sourceable library

```bash
source ops/lib/signal-read.sh
signal_query --topic feedback --since 30d
```

### Flags

| Flag       | Description                                          |
| ---------- | ---------------------------------------------------- |
| `--type`   | Exact event type match                               |
| `--topic`  | Prefix match (e.g., `feedback` matches `feedback-*`) |
| `--agent`  | Filter by agent field                                |
| `--since`  | Time window (`Nd` or `Nh`)                           |
| `--source` | Event source (`local` in v1)                         |
| `--format` | `json` (default) or `count`                          |

## Topics

Topics are derived from event-type prefixes (split on first `-`):

| Topic        | Matches                                                                       |
| ------------ | ----------------------------------------------------------------------------- |
| `feedback`   | feedback-proposed, feedback-formalized, feedback-rejected, feedback-escalated |
| `compliance` | compliance-proposed, compliance-approved, compliance-violation, ...           |
| `item`       | item-promoted, item-accepted                                                  |
| `reward`     | reward-issued                                                                 |
| `agent`      | agent-invoked                                                                 |

No configuration needed — the event-type prefix IS the topic.

## Extension Points

The `--source` flag abstracts the event store. v1 supports `local` (reads `events.jsonl`). Future sources can be added without changing the consumer API:

- `--source remote --endpoint <url>` — remote event store
- `--source aggregate` — merge multiple sources

````

- [ ] **Step 2: Commit**

```bash
git add docs/SIGNAL-BUS.md
git commit -m "docs(#24): add signal bus framework documentation"
````

---

### Task 6: Run full test suite and verify

**Files:** None (verification only)

- [ ] **Step 1: Run signal bus tests**

Run: `bash ops/tests/test-signal-bus.sh`
Expected: All tests pass

- [ ] **Step 2: Run feedback tests**

Run: `bash ops/tests/test-feedback-log.sh`
Expected: 65/65 passed (behavioral equivalence after metrics-log.sh refactor)

- [ ] **Step 3: Run compiler tests**

Run: `bash ops/tests/test-compile-floor.sh`
Expected: 146/146 passed

- [ ] **Step 4: Syntax check all scripts**

Run: `bash -n ops/lib/signal-emit.sh && bash -n ops/lib/signal-read.sh && bash -n ops/metrics-log.sh && echo "All OK"`
Expected: `All OK`

- [ ] **Step 5: Final commit if any fixups needed**

Only if previous steps required changes.
