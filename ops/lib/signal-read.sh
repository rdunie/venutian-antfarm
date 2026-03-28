#!/usr/bin/env bash
# signal-read.sh — shared event query library
#
# CLI: ops/lib/signal-read.sh --type <type> [--topic <prefix>] [--agent <name>]
#                              [--since Nd|Nh] [--source local] [--format json|count]
#
# Sourceable: source ops/lib/signal-read.sh; signal_query --topic feedback --since 7d
#
# Requires: jq

# ── Dependency check (only in CLI mode) ───────────────────────────────────
# Note: set -euo pipefail is in the CLI block at the bottom to avoid
# corrupting the caller's shell options when sourced.

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

# ── Input validation ──────────────────────────────────────────────────────
_signal_validate_param() {
  local name="$1" value="$2"
  if [[ "$value" =~ [^a-zA-Z0-9_.:-] ]]; then
    echo "ERROR: invalid ${name} value: ${value} (must be alphanumeric, dots, hyphens, underscores, colons)" >&2
    return 1
  fi
}

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
      *) echo "WARNING: unknown argument '$1' ignored" >&2; shift ;;
    esac
  done

  # Validate inputs to prevent jq injection
  if [[ -n "$type" ]];  then _signal_validate_param "type" "$type" || return 1; fi
  if [[ -n "$topic" ]]; then _signal_validate_param "topic" "$topic" || return 1; fi
  if [[ -n "$agent" ]]; then _signal_validate_param "agent" "$agent" || return 1; fi

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
    else
      echo "WARNING: could not compute cutoff for --since '${since}'; returning unfiltered results" >&2
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
  set -euo pipefail
  if ! command -v jq &>/dev/null; then
    echo "ERROR: signal-read.sh requires jq. Install jq to use event queries." >&2
    exit 1
  fi
  signal_query "$@"
fi
