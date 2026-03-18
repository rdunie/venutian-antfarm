#!/usr/bin/env bash
# ops/pathways.sh -- Agent communication pathway analysis.
# Compares declared pathways (fleet-config.json) against actual pathways (handoff events).
# The delta is the signal: undeclared paths = innovation or governance bypass.
#
# Usage: ops/pathways.sh [--since DATE]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Read config
FLEET_CONFIG="$REPO_ROOT/fleet-config.json"
LOG_FILE=""
if [[ -f "$FLEET_CONFIG" ]] && command -v jq &>/dev/null; then
  CONFIG_FILE=$(jq -r '.metrics.file // empty' "$FLEET_CONFIG" 2>/dev/null || echo "")
  [[ -n "$CONFIG_FILE" ]] && LOG_FILE="$REPO_ROOT/$CONFIG_FILE"
fi
LOG_FILE="${LOG_FILE:-${METRICS_LOG_FILE:-$REPO_ROOT/.claude/metrics/events.jsonl}}"

# ── Flag parsing ──────────────────────────────────────────────────────────────
SINCE=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --since) SINCE="$2"; shift 2 ;;
    *) echo "Unknown flag: $1" >&2; exit 1 ;;
  esac
done

if [[ -z "$SINCE" ]]; then
  if date -u -d "30 days ago" +%Y-%m-%dT%H:%M:%SZ &>/dev/null; then
    SINCE=$(date -u -d "30 days ago" +%Y-%m-%dT%H:%M:%SZ)
  else
    SINCE=$(date -u -v-30d +%Y-%m-%dT%H:%M:%SZ)
  fi
elif [[ "$SINCE" =~ ^([0-9]+)d$ ]]; then
  local_days="${BASH_REMATCH[1]}"
  if date -u -d "${local_days} days ago" +%Y-%m-%dT%H:%M:%SZ &>/dev/null; then
    SINCE=$(date -u -d "${local_days} days ago" +%Y-%m-%dT%H:%M:%SZ)
  else
    SINCE=$(date -u -v-"${local_days}"d +%Y-%m-%dT%H:%M:%SZ)
  fi
fi

# ── Helpers ───────────────────────────────────────────────────────────────────
filtered_events() {
  if [[ ! -f "$LOG_FILE" ]] || [[ ! -s "$LOG_FILE" ]]; then
    return 0
  fi
  jq -c --arg since "$SINCE" 'select(.ts >= $since)' "$LOG_FILE" 2>/dev/null || true
}

# ══════════════════════════════════════════════════════════════════════════════
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║              COMMUNICATION PATHWAYS                        ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

events=$(filtered_events)

# ── 1. Infer actual pathways from handoff events ─────────────────────────────
echo "  ACTUAL PATHWAYS (inferred from handoff-sent events)"
echo ""

actual_paths=""
if [[ -n "$events" ]]; then
  actual_paths=$(echo "$events" | jq -r 'select(.event=="handoff-sent") | "\(.from) -> \(.to)"' 2>/dev/null | sort | uniq -c | sort -rn)
fi

if [[ -n "$actual_paths" ]]; then
  printf "  %-30s %-28s %s\n" "From" "To" "Count"
  printf "  %-30s %-28s %s\n" "----" "--" "-----"
  while IFS= read -r line; do
    count=$(echo "$line" | awk '{print $1}')
    path=$(echo "$line" | sed 's/^ *[0-9]* *//')
    from_agent=$(echo "$path" | awk -F' -> ' '{print $1}')
    to_agent=$(echo "$path" | awk -F' -> ' '{print $2}')
    printf "  %-30s %-28s %s\n" "$from_agent" "$to_agent" "$count"
  done <<< "$actual_paths"
else
  echo "  (no handoff events logged yet)"
fi
echo ""

# ── 2. Load declared pathways from fleet-config.json ─────────────────────────
declared_paths=""
if [[ -f "$FLEET_CONFIG" ]] && command -v jq &>/dev/null; then
  declared_paths=$(jq -r '
    .pathways.declared // {} |
    to_entries[] |
    .key as $category |
    .value[] |
    "\($category)|\(.)"
  ' "$FLEET_CONFIG" 2>/dev/null || true)
fi

if [[ -n "$declared_paths" ]]; then
  echo "  DECLARED PATHWAYS (from fleet-config.json)"
  echo ""
  printf "  %-12s %-43s %s\n" "Category" "Pathway" "Active?"
  printf "  %-12s %-43s %s\n" "--------" "-------" "-------"

  while IFS='|' read -r category pathway; do
    is_active="no"
    if [[ "$pathway" == *"*"* ]]; then
      # Wildcard: "* -> target" — check if any actual path ends with target
      target=$(echo "$pathway" | awk -F' -> ' '{print $2}')
      source_side=$(echo "$pathway" | awk -F' -> ' '{print $1}')
      if [[ "$source_side" == "*" && -n "$actual_paths" ]]; then
        echo "$actual_paths" | grep -q " -> ${target}$" && is_active="yes"
      elif [[ "$target" == "*" && -n "$actual_paths" ]]; then
        echo "$actual_paths" | grep -q "^[[:space:]]*[0-9]* *${source_side} -> " && is_active="yes"
      fi
    else
      if [[ -n "$actual_paths" ]] && echo "$actual_paths" | grep -qF "$pathway"; then
        is_active="yes"
      fi
    fi
    printf "  %-12s %-43s %s\n" "$category" "$pathway" "$is_active"
  done <<< "$declared_paths"
  echo ""

  # ── 3. Delta analysis ──────────────────────────────────────────────────────
  echo "  PATHWAY DELTA"
  echo ""

  # Undeclared paths (actual but not declared)
  undeclared_count=0
  undeclared_lines=""
  if [[ -n "$actual_paths" ]]; then
    while IFS= read -r line; do
      path=$(echo "$line" | sed 's/^ *[0-9]* *//')
      from_agent=$(echo "$path" | awk -F' -> ' '{print $1}')
      to_agent=$(echo "$path" | awk -F' -> ' '{print $2}')
      count=$(echo "$line" | awk '{print $1}')

      is_declared=false
      while IFS='|' read -r _cat dpathway; do
        [[ "$dpathway" == "$path" ]] && is_declared=true && break
        [[ "$dpathway" == "* -> $to_agent" ]] && is_declared=true && break
        [[ "$dpathway" == "$from_agent -> *" ]] && is_declared=true && break
      done <<< "$declared_paths"

      if [[ "$is_declared" == "false" ]]; then
        undeclared_count=$((undeclared_count + 1))
        undeclared_lines="${undeclared_lines}    ! ${path} (${count}x)\n"
      fi
    done <<< "$actual_paths"
  fi

  # Unused declared paths
  unused_count=0
  unused_lines=""
  while IFS='|' read -r category pathway; do
    [[ "$pathway" == *"*"* ]] && continue
    if [[ -z "$actual_paths" ]] || ! echo "$actual_paths" | grep -qF "$pathway"; then
      unused_count=$((unused_count + 1))
      unused_lines="${unused_lines}    - ${pathway} (${category})\n"
    fi
  done <<< "$declared_paths"

  if [[ "$undeclared_count" -gt 0 ]]; then
    echo "  Undeclared paths ($undeclared_count):"
    printf "$undeclared_lines"
    echo ""
    echo "  These paths were used but not declared in fleet-config.json."
    echo "  Evaluate: innovation (add to declared) or bypass (address)."
    echo ""
  fi

  if [[ "$unused_count" -gt 0 ]]; then
    echo "  Unused declared paths ($unused_count):"
    printf "$unused_lines"
    echo ""
    echo "  These paths were declared but never used in the time window."
    echo "  May indicate over-declared topology or unexercised workflows."
    echo ""
  fi

  if [[ "$undeclared_count" -eq 0 && "$unused_count" -eq 0 ]]; then
    echo "  All actual paths match declared paths. Topology is clean."
    echo ""
  fi
else
  echo "  No declared pathways in fleet-config.json."
  echo "  Add \"pathways.declared\" to enable delta analysis."
  echo ""
fi

# ── 4. Communication density ─────────────────────────────────────────────────
unique_agents=0
unique_paths=0
if [[ -n "$actual_paths" ]]; then
  unique_paths=$(echo "$actual_paths" | grep -c . || true)
  unique_agents=$(echo "$events" | jq -r 'select(.event=="handoff-sent") | .from, .to' 2>/dev/null | sort -u | grep -c . || true)
fi

echo "  FLEET DENSITY"
echo "    Active agents in handoffs: $unique_agents"
echo "    Unique communication paths: $unique_paths"
if [[ "$unique_agents" -gt 1 ]]; then
  max_paths=$(( unique_agents * (unique_agents - 1) ))
  density_pct=0
  [[ "$max_paths" -gt 0 ]] && density_pct=$(awk "BEGIN{printf \"%d\", ($unique_paths/$max_paths)*100}")
  echo "    Density: ${density_pct}% of possible paths (${unique_paths}/${max_paths})"
  echo ""
  if [[ "$density_pct" -gt 70 ]]; then
    echo "    WARNING: High density may indicate coordination overhead."
    echo "    Consider whether all paths are necessary."
  elif [[ "$density_pct" -lt 20 && "$unique_agents" -gt 3 ]]; then
    echo "    NOTE: Low density with many agents may indicate bottlenecks."
    echo "    Check if one agent is on every critical path."
  fi
fi
echo ""

# ── 5. Top communicators ─────────────────────────────────────────────────────
if [[ -n "$events" ]]; then
  echo "  TOP COMMUNICATORS"
  echo ""
  printf "  %-30s %-10s %-10s %s\n" "Agent" "Sent" "Received" "Total"
  printf "  %-30s %-10s %-10s %s\n" "-----" "----" "--------" "-----"

  # Get all agents involved in handoffs
  all_agents=$(echo "$events" | jq -r 'select(.event=="handoff-sent") | .from, .to' 2>/dev/null | sort -u)
  if [[ -n "$all_agents" ]]; then
    while IFS= read -r agent; do
      sent=$(echo "$events" | jq -r --arg a "$agent" 'select(.event=="handoff-sent" and .from==$a)' 2>/dev/null | grep -c . || true)
      received=$(echo "$events" | jq -r --arg a "$agent" 'select(.event=="handoff-sent" and .to==$a)' 2>/dev/null | grep -c . || true)
      total=$((sent + received))
      printf "  %-30s %-10s %-10s %s\n" "$agent" "$sent" "$received" "$total"
    done <<< "$all_agents" | sort -t$'\t' -k4 -rn
  fi
  echo ""
fi
