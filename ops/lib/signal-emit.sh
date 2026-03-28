#!/usr/bin/env bash
# Shared signal emission library for the metrics/signal bus.
# Source this file; do not execute directly.
#
# Provides:
#   signal_emit <json_line>   -- dispatch a JSON event to the configured backend
#   METRICS_LOG_FILE          -- resolved log file path (consumers may reference directly)
#
# Usage:
#   source "$(cd "$(dirname "$0")" && pwd)/lib/signal-emit.sh"
#   signal_emit '{"ts":"...","event":"..."}'

# Double-source guard
[[ -n "${_SIGNAL_EMIT_LOADED:-}" ]] && return 0
_SIGNAL_EMIT_LOADED=1

# ── Locate repo root relative to this library file ────────────────────────────
_SIGNAL_REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
_SIGNAL_FLEET_CONFIG="$_SIGNAL_REPO_ROOT/fleet-config.json"

# ── Read backend config from fleet-config.json ───────────────────────────────
_SIGNAL_BACKEND="jsonl"
_SIGNAL_WEBHOOK_URL=""
if [[ -f "$_SIGNAL_FLEET_CONFIG" ]] && command -v jq &>/dev/null; then
  _SIGNAL_BACKEND=$(jq -r '.metrics.backend // "jsonl"' "$_SIGNAL_FLEET_CONFIG" 2>/dev/null || echo "jsonl")
  _SIGNAL_WEBHOOK_URL=$(jq -r '.metrics.webhook // empty' "$_SIGNAL_FLEET_CONFIG" 2>/dev/null || echo "")
  METRICS_LOG_FILE="${METRICS_LOG_FILE:-$(jq -r '.metrics.file // empty' "$_SIGNAL_FLEET_CONFIG" 2>/dev/null || echo "")}"
fi

METRICS_LOG_FILE="${METRICS_LOG_FILE:-$_SIGNAL_REPO_ROOT/.claude/metrics/events.jsonl}"

# ── Ensure log directory exists ───────────────────────────────────────────────
if ! mkdir -p "$(dirname "$METRICS_LOG_FILE")" 2>/dev/null; then
  echo "ERROR: signal-emit.sh: cannot create metrics directory $(dirname "$METRICS_LOG_FILE")" >&2
fi
touch "$METRICS_LOG_FILE" 2>/dev/null || true

# ── Backend dispatch ──────────────────────────────────────────────────────────
signal_emit() {
  local json_line="$1"
  case "$_SIGNAL_BACKEND" in
    jsonl)
      echo "$json_line" >> "$METRICS_LOG_FILE"
      ;;
    webhook)
      if [[ -n "$_SIGNAL_WEBHOOK_URL" ]]; then
        echo "$json_line" >> "$METRICS_LOG_FILE"  # always persist locally
        echo "$json_line" | curl -s -X POST -H "Content-Type: application/json" --data-binary @- "$_SIGNAL_WEBHOOK_URL" >/dev/null 2>&1 \
          || echo "WARNING: webhook dispatch failed (curl exit $?). Event persisted to local JSONL." >&2
      else
        echo "$json_line" >> "$METRICS_LOG_FILE"
      fi
      ;;
    statsd|opentelemetry)
      # Future: implement StatsD/OTEL dispatch
      # For now, fall back to JSONL
      echo "$json_line" >> "$METRICS_LOG_FILE"
      echo "WARNING: $_SIGNAL_BACKEND backend not yet implemented, falling back to JSONL" >&2
      ;;
    *)
      echo "$json_line" >> "$METRICS_LOG_FILE"
      echo "WARNING: unknown backend '$_SIGNAL_BACKEND', falling back to JSONL" >&2
      ;;
  esac
}
