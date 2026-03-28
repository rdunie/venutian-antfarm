# Signal Bus Architecture — Read/Write Libraries for Event Communication

**Issue:** [#24](https://github.com/rdunie/venutian-antfarm/issues/24)
**Date:** 2026-03-28
**Status:** Draft

## Problem

All event producers (feedback-log.sh, compile-floor.sh, hooks) call metrics-log.sh directly, and all consumers (dora.sh, pathways.sh, feedback-log.sh [also a producer]) read events.jsonl with ad-hoc grep/jq. There is no shared abstraction for either reading or writing events. Adding a new event type requires editing metrics-log.sh's case block. Adding a new consumer requires reimplementing filter logic. The write path's backend dispatch (jsonl, webhook) is locked inside metrics-log.sh, unreusable by future producers.

## Goals

1. **Shared write library** -- extract emit_event and backend dispatch from metrics-log.sh into a sourceable library that any producer can use.
2. **Shared read library** -- provide filtered, source-aware reads with topic subscriptions derived from event-type prefix convention.
3. **Source abstraction** -- the read library accepts `--source local` (v1), designed so future sources (remote, webhook ingestion) can be added without changing the consumer API.
4. **Zero behavioral change** -- metrics-log.sh continues to work exactly as before. Existing callers see no difference.
5. **Multi-session extensibility** -- the source abstraction and library separation lay the groundwork for cross-session event communication.

## Non-Goals

- Migrating existing consumers (dora.sh, feedback-log.sh, pathways.sh) to use signal-read.sh -- that's follow-up work.
- Running a persistent bus process or daemon -- the framework operates within single Claude Code sessions.
- Log rotation or indexing -- current scale (< 1000 events per project) doesn't warrant it.
- Built-in aggregation in the read library -- consumers pipe to jq for their own aggregation needs.

## Design

### 1. Write Library (`ops/lib/signal-emit.sh`)

Extracted from `metrics-log.sh`. A sourceable bash library that provides:

```bash
# Source and call:
source ops/lib/signal-emit.sh
signal_emit "$json_line"
```

The library:

1. Reads backend config from fleet-config.json on first source (`_SIGNAL_BACKEND`, `_SIGNAL_WEBHOOK_URL`, `METRICS_LOG_FILE`)
2. Ensures the log file directory exists
3. Dispatches to the configured backend (jsonl, webhook, with stubs for statsd/otel)

```bash
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

**metrics-log.sh refactor:** Replace the inline `emit_event()` function with `source "$SCRIPT_DIR/lib/signal-emit.sh"` and rename all `emit_event` calls to `signal_emit`. The backend config loading (fleet-config.json read) moves into the library's initialization block. All 30+ event handlers stay in metrics-log.sh unchanged -- only the dispatch plumbing moves.

### 2. Read Library (`ops/lib/signal-read.sh`)

Both a standalone CLI and a sourceable library:

```bash
# As CLI:
ops/lib/signal-read.sh --type feedback-proposed --since 7d
ops/lib/signal-read.sh --topic feedback --agent backend-specialist
ops/lib/signal-read.sh --source local --type item-accepted --format count

# As sourced library:
source ops/lib/signal-read.sh
signal_query --topic feedback --since 30d
```

**Flags:**

| Flag       | Description                              | Example                                  |
| ---------- | ---------------------------------------- | ---------------------------------------- |
| `--type`   | Exact event type match                   | `--type feedback-proposed`               |
| `--topic`  | Prefix match on event type               | `--topic feedback` (matches feedback-\*) |
| `--agent`  | Filter by agent field                    | `--agent backend-specialist`             |
| `--since`  | Time window (Nd or Nh)                   | `--since 7d`                             |
| `--source` | Event source (default: `local`)          | `--source local`                         |
| `--format` | Output format: `json` (default), `count` | `--format count`                         |

**Prerequisites:** The library requires `jq`. On invocation, check `command -v jq` and exit 1 with a clear error if missing (consistent with `ops/compile-floor.sh`'s gomplate check).

**Implementation:** All flags compose into a single `jq` select expression. One process spawn, one pass through the file:

```bash
jq_filter='select(1)'  # base: match all

# --type: exact match
[[ -n "$type" ]] && jq_filter="$jq_filter | select(.event == \"$type\")"

# --topic: prefix match (includes trailing hyphen to prevent "item" matching "itemized-cost")
[[ -n "$topic" ]] && jq_filter="$jq_filter | select(.event | startswith(\"${topic}-\"))"

# --agent: match agent field
[[ -n "$agent" ]] && jq_filter="$jq_filter | select(.agent == \"$agent\")"

# --since: time window (ISO 8601 lexicographic comparison — correct for fixed-width timestamps)
# Cutoff computed via GNU date: date -u -d "-${N} days" +%Y-%m-%dT%H:%M:%SZ
[[ -n "$since_cutoff" ]] && jq_filter="$jq_filter | select(.ts >= \"$since_cutoff\")"

# Guard: source file must exist
[[ ! -f "$source_file" ]] && { echo "[]" | jq -c '.[]'; return 0; }

# Execute with fromjson? to silently skip malformed lines
jq -c -R "fromjson? | $jq_filter" "$source_file"
```

For `--format count`: pipe to `jq -s 'length'`.

**Error handling:** The `fromjson?` operator silently skips unparseable lines (truncated writes, concurrent appends). If the source file is empty or missing, the query returns an empty result set (0 for count). No errors propagated to consumers.

**`--source local`** reads from `$METRICS_LOG_FILE`. Future sources add new cases to a source resolver function. The consumer API (`signal_query`) doesn't change.

**Date portability:** `--since` conversion uses GNU coreutils `date -u -d`. BSD/macOS compatibility is consistent with the rest of the framework (which already uses GNU date conventions).

### 3. Topic Convention

Topics are derived from event-type prefixes by splitting on the first `-`:

| Event Type             | Topic        |
| ---------------------- | ------------ |
| `feedback-proposed`    | `feedback`   |
| `feedback-formalized`  | `feedback`   |
| `compliance-proposed`  | `compliance` |
| `compliance-violation` | `compliance` |
| `item-promoted`        | `item`       |
| `item-accepted`        | `item`       |
| `reward-issued`        | `reward`     |
| `agent-invoked`        | `agent`      |

No configuration needed. The prefix IS the topic. `--topic feedback` generates `select(.event | startswith("feedback-"))`. The trailing hyphen prevents ambiguity (e.g., `--topic item` won't match a hypothetical `itemized-cost` event).

### 4. Performance

**Write path:** Unchanged. One file append per event (or append + curl for webhook).

**Read path:** Single `jq` pass over the JSONL file. All filters composed into one `select()` expression. `--since` provides the most impactful filter -- chronologically ordered events mean jq can discard old lines quickly.

**Expected scale:** < 1000 events per project lifetime. Single jq pass over 1000 lines: < 100ms. No indexing, rotation, or caching needed at this scale.

**Future scale:** If projects exceed 10K events, log rotation (separate concern) or indexed storage (new `--source` backend) would address it without changing the consumer API.

### 5. Multi-Session Extensibility

The `--source` flag is the extension point. v1 implements only `local` (reads JSONL file). Future sources:

- `--source remote --endpoint https://...` -- reads from a remote event store
- `--source webhook-inbox` -- reads from a local webhook ingestion buffer
- `--source aggregate` -- merges multiple local/remote sources

Consumers written against `signal_query --topic feedback --since 7d` work unchanged across all source backends. The library resolves the source internally.

## File Inventory

### New Files

| File                           | Purpose                                                  |
| ------------------------------ | -------------------------------------------------------- |
| `ops/lib/signal-emit.sh`       | Shared write library: `signal_emit()` + backend dispatch |
| `ops/lib/signal-read.sh`       | Shared read library: `signal_query()` + CLI interface    |
| `ops/tests/test-signal-bus.sh` | Tests for both emit and read libraries                   |

### New Documentation

| File                 | Purpose                                                                           |
| -------------------- | --------------------------------------------------------------------------------- |
| `docs/SIGNAL-BUS.md` | Framework documentation for signal bus libraries (usage, topics, extension points) |

### Modified Files

| File                 | Change                                                                                               |
| -------------------- | ---------------------------------------------------------------------------------------------------- |
| `ops/metrics-log.sh` | Source `signal-emit.sh`, replace `emit_event()` with `signal_emit()`, move backend config to library |

### Not Changed

- `ops/feedback-log.sh` -- consumer migration is follow-up work
- `ops/dora.sh` -- consumer migration is follow-up work
- `ops/pathways.sh` -- consumer migration is follow-up work
- `templates/fleet-config.json` -- no new config needed (topic convention is zero-config)

## Related Issues

- [#13](https://github.com/rdunie/venutian-antfarm/issues/13) -- Rewards system (producer, completed)
- [#28](https://github.com/rdunie/venutian-antfarm/issues/28) -- Expanded feedback (producer, completed)
- [#25](https://github.com/rdunie/venutian-antfarm/issues/25) -- Adaptive weighting (consumer of item-accepted events, completed)
- [#21](https://github.com/rdunie/venutian-antfarm/issues/21) -- Multi-context orchestration (future: enables cross-session sources)
