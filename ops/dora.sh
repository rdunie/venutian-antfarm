#!/usr/bin/env bash
# ops/dora.sh -- DORA metrics dashboard for agent fleet.
# Reads events from .claude/metrics/events.jsonl (or METRICS_LOG_FILE override).
# Usage: ops/dora.sh [--dora] [--flow] [--sm] [--cost] [--item ITEM] [--since DATE]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Read log file from fleet config or default
FLEET_CONFIG="$REPO_ROOT/fleet-config.json"
if [[ -f "$FLEET_CONFIG" ]] && command -v jq &>/dev/null; then
  CONFIG_FILE=$(jq -r '.metrics.file // empty' "$FLEET_CONFIG" 2>/dev/null || echo "")
  [[ -n "$CONFIG_FILE" ]] && LOG_FILE="${METRICS_LOG_FILE:-$REPO_ROOT/$CONFIG_FILE}"
fi
LOG_FILE="${LOG_FILE:-${METRICS_LOG_FILE:-$REPO_ROOT/.claude/metrics/events.jsonl}}"

# ── Defaults ──────────────────────────────────────────────────────────────────
MODE="all"
SINCE=""
ITEM_FILTER=""

# ── Flag parsing ──────────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dora) MODE="dora"; shift ;;
    --flow) MODE="flow"; shift ;;
    --sm)   MODE="sm";   shift ;;
    --cost) MODE="cost"; shift ;;
    --pathways) MODE="pathways"; shift ;;
    --item) ITEM_FILTER="$2"; shift 2 ;;
    --since) SINCE="$2"; shift 2 ;;
    *) echo "Unknown flag: $1" >&2; exit 1 ;;
  esac
done

# ── Since date ────────────────────────────────────────────────────────────────
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

to_sessions() {
  local secs="${1:-0}"
  awk "BEGIN { printf \"%.2f\", $secs / 14400 }"
}

median() {
  local values
  values=$(sort -n)
  local count
  count=$(echo "$values" | grep -c . || true)
  if [[ "$count" -eq 0 ]]; then echo "0"; return; fi
  local mid=$(( (count + 1) / 2 ))
  echo "$values" | sed -n "${mid}p"
}

# ── DORA Metrics ──────────────────────────────────────────────────────────────
dora_metrics() {
  local events
  events=$(filtered_events)

  echo "================================================================"
  echo "                     DORA METRICS                               "
  echo "================================================================"
  echo ""

  local deploy_count=0 accepted_count=0
  if [[ -n "$events" ]]; then
    deploy_count=$(echo "$events" | jq -c 'select(.event == "ext-deployed")' | grep -c . || true)
    accepted_count=$(echo "$events" | jq -c 'select(.event == "item-accepted")' | grep -c . || true)
  fi
  local total_freq=$(( deploy_count + accepted_count ))

  echo "  DEPLOYMENT FREQUENCY (since ${SINCE:0:10})"
  echo "    deployments:   $deploy_count"
  echo "    item-accepted: $accepted_count"
  echo "    total:         $total_freq"
  echo ""

  # ── Lead Time ──
  local lead_times=""
  if [[ -n "$events" ]]; then
    local accepted_items
    accepted_items=$(echo "$events" | jq -r 'select(.event == "item-accepted") | .item' | sort -u)
    for item_id in $accepted_items; do
      local promoted_ts accepted_ts
      promoted_ts=$(echo "$events" | jq -r --arg id "$item_id" 'select(.event == "item-promoted" and .item == $id) | .ts' | head -1)
      accepted_ts=$(echo "$events" | jq -r --arg id "$item_id" 'select(.event == "item-accepted" and .item == $id) | .ts' | head -1)
      if [[ -n "$promoted_ts" && -n "$accepted_ts" ]]; then
        local p_epoch a_epoch
        p_epoch=$(date -u -d "$promoted_ts" +%s 2>/dev/null || echo 0)
        a_epoch=$(date -u -d "$accepted_ts" +%s 2>/dev/null || echo 0)
        local diff=$(( a_epoch - p_epoch ))
        if [[ "$diff" -ge 0 ]]; then
          lead_times="${lead_times}${diff}"$'\n'
        fi
      fi
    done
  fi

  local median_lead_secs median_lead_sessions
  if [[ -n "$lead_times" ]]; then
    median_lead_secs=$(echo "$lead_times" | grep -v '^$' | median)
    median_lead_sessions=$(to_sessions "$median_lead_secs")
  else
    median_lead_secs=0
    median_lead_sessions="0.00"
  fi
  echo "  LEAD TIME (item-promoted -> item-accepted)"
  echo "    median: ${median_lead_sessions} sessions (${median_lead_secs}s)"
  echo ""

  # ── Change Failure Rate ──
  local regression_count=0
  if [[ -n "$events" ]]; then
    regression_count=$(echo "$events" | jq -c 'select(.event == "bug-found" and .source == "regression")' | grep -c . || true)
  fi
  local cfr=0
  if [[ "$accepted_count" -gt 0 ]]; then
    cfr=$(awk "BEGIN { printf \"%d\", ($regression_count / $accepted_count) * 100 }")
  fi
  echo "  CHANGE FAILURE RATE"
  echo "    regressions: $regression_count / $accepted_count items = ${cfr}%"
  echo ""

  # ── Deployment Rework Rate ──
  local hotfix_count=0
  if [[ -n "$events" ]]; then
    hotfix_count=$(echo "$events" | jq -c 'select(.event == "ext-deployed" and .type != null and .type != "planned")' | grep -c . || true)
  fi
  local rework_rate=0
  if [[ "$deploy_count" -gt 0 ]]; then
    rework_rate=$(awk "BEGIN { printf \"%d\", ($hotfix_count / $deploy_count) * 100 }")
  fi
  echo "  DEPLOYMENT REWORK RATE"
  echo "    hotfix deploys: $hotfix_count / $deploy_count = ${rework_rate}%"
  echo ""

  # ── MTTR ──
  local mttr_times=""
  if [[ -n "$events" ]]; then
    local bug_events
    bug_events=$(echo "$events" | jq -c 'select(.event == "bug-found" and (.severity == "high" or .severity == "critical"))')
    if [[ -n "$bug_events" ]]; then
      while IFS= read -r bug_line; do
        local b_item b_id b_ts
        b_item=$(echo "$bug_line" | jq -r '.item')
        b_id=$(echo "$bug_line" | jq -r '.bug_id')
        b_ts=$(echo "$bug_line" | jq -r '.ts')
        local fix_ts
        fix_ts=$(echo "$events" | jq -r --arg item "$b_item" --arg bid "$b_id" \
          'select(.event == "bug-fixed" and .item == $item and .bug_id == $bid) | .ts' | head -1)
        if [[ -n "$fix_ts" && "$fix_ts" != "null" ]]; then
          local b_epoch f_epoch
          b_epoch=$(date -u -d "$b_ts" +%s 2>/dev/null || echo 0)
          f_epoch=$(date -u -d "$fix_ts" +%s 2>/dev/null || echo 0)
          local diff=$(( f_epoch - b_epoch ))
          if [[ "$diff" -ge 0 ]]; then
            mttr_times="${mttr_times}${diff}"$'\n'
          fi
        fi
      done <<< "$bug_events"
    fi
  fi

  local median_mttr_secs median_mttr_sessions
  if [[ -n "$mttr_times" ]]; then
    median_mttr_secs=$(echo "$mttr_times" | grep -v '^$' | median)
    median_mttr_sessions=$(to_sessions "$median_mttr_secs")
  else
    median_mttr_secs=0
    median_mttr_sessions="0.00"
  fi
  echo "  MTTR (high/critical bugs)"
  echo "    median: ${median_mttr_sessions} sessions (${median_mttr_secs}s)"
  echo ""
}

# ── Flow Quality ──────────────────────────────────────────────────────────────
flow_quality() {
  local events
  events=$(filtered_events)

  echo "================================================================"
  echo "                    FLOW QUALITY                                "
  echo "================================================================"
  echo ""

  echo "  FIRST-PASS YIELD (by handoff boundary)"

  local total_sends=0 total_accepted=0
  local tmpdir; tmpdir=$(mktemp -d); trap 'rm -rf "$tmpdir"' RETURN

  if [[ -n "$events" ]]; then
    while IFS= read -r send_line; do
      local s_item s_from s_to s_ts
      s_item=$(echo "$send_line" | jq -r '.item')
      s_from=$(echo "$send_line" | jq -r '.from')
      s_to=$(echo "$send_line" | jq -r '.to')
      s_ts=$(echo "$send_line" | jq -r '.ts')
      local key; key=$(echo "${s_from}___${s_to}" | tr '/' '_')

      local rejected=0
      rejected=$(echo "$events" | jq -r \
        --arg item "$s_item" --arg from "$s_from" --arg to "$s_to" --arg since "$s_ts" \
        'select(.event=="handoff-rejected" and .item==$item and .from==$from and .to==$to and .ts>$since) | 1' \
        2>/dev/null | wc -l | tr -d ' ')

      echo "1" >> "$tmpdir/${key}_sends"
      if [[ "$rejected" -eq 0 ]]; then
        echo "1" >> "$tmpdir/${key}_accepted"
      fi
      total_sends=$((total_sends + 1))
      if [[ "$rejected" -eq 0 ]]; then
        total_accepted=$((total_accepted + 1))
      fi
    done < <(echo "$events" | jq -rc 'select(.event=="handoff-sent")' 2>/dev/null)
  fi

  for sends_file in "$tmpdir"/*_sends; do
    [[ -f "$sends_file" ]] || continue
    local key_raw; key_raw=$(basename "$sends_file" _sends)
    local b_from; b_from="${key_raw%%___*}"
    local b_to; b_to="${key_raw##*___}"
    local s_count; s_count=$(wc -l < "$sends_file" | tr -d ' ')
    local a_count=0
    [[ -f "${sends_file%_sends}_accepted" ]] && a_count=$(wc -l < "${sends_file%_sends}_accepted" | tr -d ' ')
    local pct=0
    [[ "$s_count" -gt 0 ]] && pct=$(awk "BEGIN{printf \"%d\", ($a_count/$s_count)*100}")
    printf "    %-25s -> %-25s %d%%\n" "$b_from" "$b_to" "$pct"
  done

  local fleet_fpy=0
  [[ "$total_sends" -gt 0 ]] && fleet_fpy=$(awk "BEGIN{printf \"%d\", ($total_accepted/$total_sends)*100}")
  printf "    %-53s %d%%\n" "Fleet average" "$fleet_fpy"
  echo ""

  # ── Rework Cycles ──
  local rejection_count=0 accepted_count=0
  if [[ -n "$events" ]]; then
    rejection_count=$(echo "$events" | jq -c 'select(.event=="handoff-rejected")' | grep -c . || true)
    accepted_count=$(echo "$events" | jq -c 'select(.event=="item-accepted")' | grep -c . || true)
  fi
  local rework_median="0.0"
  [[ "$accepted_count" -gt 0 ]] && rework_median=$(awk "BEGIN{printf \"%.1f\", $rejection_count/$accepted_count}")
  echo "  REWORK CYCLES"
  echo "    Average  ${rework_median} cycles/item"
  echo ""

  # ── Task Outcomes ──
  local promoted_count=0 discarded_count=0 restarted_count=0
  if [[ -n "$events" ]]; then
    promoted_count=$(echo "$events" | jq -c 'select(.event=="item-promoted")' | grep -c . || true)
    discarded_count=$(echo "$events" | jq -c 'select(.event=="task-discarded")' | grep -c . || true)
    restarted_count=$(echo "$events" | jq -c 'select(.event=="task-restarted")' | grep -c . || true)
  fi
  local discard_pct=0 restart_pct=0
  [[ "$promoted_count" -gt 0 ]] && discard_pct=$(awk "BEGIN{printf \"%d\", ($discarded_count/$promoted_count)*100}")
  [[ "$promoted_count" -gt 0 ]] && restart_pct=$(awk "BEGIN{printf \"%d\", ($restarted_count/$promoted_count)*100}")
  echo "  TASK OUTCOMES"
  printf "    Abandoned  %d of %d promoted = %d%%\n" "$discarded_count" "$promoted_count" "$discard_pct"
  printf "    Restarted  %d of %d promoted = %d%%\n" "$restarted_count" "$promoted_count" "$restart_pct"
  echo ""

  # ── Blocked Time ──
  local total_blocked_secs=0 block_count=0
  if [[ -n "$events" ]]; then
    while IFS= read -r block_line; do
      local b_ts
      b_ts=$(echo "$block_line" | jq -r '.ts')
      local unblock_ts
      unblock_ts=$(echo "$events" | jq -r \
        --arg item "$(echo "$block_line" | jq -r '.item')" --arg since "$b_ts" \
        'select(.event=="task-unblocked" and .item==$item and .ts>$since) | .ts' \
        2>/dev/null | head -1)
      if [[ -n "$unblock_ts" && "$unblock_ts" != "null" ]]; then
        local b_epoch u_epoch
        b_epoch=$(date -u -d "$b_ts" +%s 2>/dev/null || echo 0)
        u_epoch=$(date -u -d "$unblock_ts" +%s 2>/dev/null || echo 0)
        total_blocked_secs=$((total_blocked_secs + u_epoch - b_epoch))
        block_count=$((block_count + 1))
      fi
    done < <(echo "$events" | jq -rc 'select(.event=="task-blocked")' 2>/dev/null)
  fi

  local blocked_median_sess="0.00"
  [[ "$block_count" -gt 0 ]] && blocked_median_sess=$(to_sessions "$((total_blocked_secs / block_count))")
  echo "  BLOCKED TIME"
  echo "    Average  ${blocked_median_sess} sessions/item"
  echo ""
}

# ── SM Pace Recommendation ────────────────────────────────────────────────────
sm_metrics() {
  local events
  events=$(filtered_events)

  echo "================================================================"
  echo "                 PACE RECOMMENDATION                            "
  echo "================================================================"
  echo ""

  local accepted_count=0 regression_count=0
  if [[ -n "$events" ]]; then
    accepted_count=$(echo "$events" | jq -c 'select(.event == "item-accepted")' | grep -c . || true)
    regression_count=$(echo "$events" | jq -c 'select(.event == "bug-found" and .source == "regression")' | grep -c . || true)
  fi
  local cfr=0
  if [[ "$accepted_count" -gt 0 ]]; then
    cfr=$(awk "BEGIN { printf \"%d\", ($regression_count / $accepted_count) * 100 }")
  fi

  local total_sends=0 total_accepted=0
  if [[ -n "$events" ]]; then
    while IFS= read -r send_line; do
      local s_item s_from s_to s_ts
      s_item=$(echo "$send_line" | jq -r '.item')
      s_from=$(echo "$send_line" | jq -r '.from')
      s_to=$(echo "$send_line" | jq -r '.to')
      s_ts=$(echo "$send_line" | jq -r '.ts')
      local rejected=0
      rejected=$(echo "$events" | jq -r \
        --arg item "$s_item" --arg from "$s_from" --arg to "$s_to" --arg since "$s_ts" \
        'select(.event=="handoff-rejected" and .item==$item and .from==$from and .to==$to and .ts>$since) | 1' \
        2>/dev/null | wc -l | tr -d ' ')
      total_sends=$((total_sends + 1))
      if [[ "$rejected" -eq 0 ]]; then
        total_accepted=$((total_accepted + 1))
      fi
    done < <(echo "$events" | jq -rc 'select(.event=="handoff-sent")' 2>/dev/null)
  fi
  local fleet_fpy=0
  if [[ "$total_sends" -gt 0 ]]; then
    fleet_fpy=$(awk "BEGIN { printf \"%d\", ($total_accepted / $total_sends) * 100 }")
  fi

  local has_dora_data=false has_flow_data=false
  [[ "$accepted_count" -gt 0 ]] && has_dora_data=true
  [[ "$total_sends" -gt 0 ]] && has_flow_data=true

  local pace="Crawl"
  local recommendation="Remain at Crawl"

  if [[ "$has_dora_data" == "false" ]]; then
    recommendation="Remain at Crawl -- insufficient data to evaluate"
  elif [[ "$cfr" -gt 10 ]]; then
    recommendation="Remain at Crawl"
  elif [[ "$cfr" -le 5 && "$has_flow_data" == "true" && "$fleet_fpy" -ge 80 ]]; then
    pace="Run"
    recommendation="Advance to Run"
  elif [[ "$cfr" -le 10 ]]; then
    pace="Walk"
    recommendation="Advance to Walk"
  fi

  echo "  PACE RECOMMENDATION"
  echo "    Current pace: $pace"
  echo ""
  echo "  DORA signals"
  if [[ "$has_dora_data" == "true" ]]; then
    echo "    CFR: ${cfr}% (Walk threshold: <=10%)"
  else
    echo "    CFR: -- (no items accepted yet)"
  fi
  echo ""
  echo "  Flow signals"
  if [[ "$has_flow_data" == "true" ]]; then
    echo "    FPY: ${fleet_fpy}%"
  else
    echo "    FPY: -- (no handoffs logged yet)"
  fi
  echo ""
  echo "  Recommendation: $recommendation"
  echo ""
}

# ── Item Detail ───────────────────────────────────────────────────────────────
item_detail() {
  local events
  events=$(filtered_events)

  echo "================================================================"
  echo "                   ITEM DETAIL: $ITEM_FILTER"
  echo "================================================================"
  echo ""

  local item_events=""
  if [[ -n "$events" ]]; then
    item_events=$(echo "$events" | jq -c --arg id "$ITEM_FILTER" 'select(.item == $id)' 2>/dev/null || true)
  fi

  if [[ -z "$item_events" ]]; then
    echo "  No events found for item $ITEM_FILTER"
    echo ""
    return 0
  fi

  local promoted_ts accepted_ts
  promoted_ts=$(echo "$item_events" | jq -r 'select(.event=="item-promoted") | .ts' | head -1)
  accepted_ts=$(echo "$item_events" | jq -r 'select(.event=="item-accepted") | .ts' | head -1)

  echo "  LIFECYCLE"
  if [[ -n "$promoted_ts" && "$promoted_ts" != "null" ]]; then
    echo "    Promoted:  $promoted_ts"
  else
    echo "    Promoted:  --"
  fi
  if [[ -n "$accepted_ts" && "$accepted_ts" != "null" ]]; then
    echo "    Accepted:  $accepted_ts"
  else
    echo "    Accepted:  --"
  fi

  if [[ -n "$promoted_ts" && "$promoted_ts" != "null" && -n "$accepted_ts" && "$accepted_ts" != "null" ]]; then
    local p_epoch a_epoch
    p_epoch=$(date -u -d "$promoted_ts" +%s 2>/dev/null || echo 0)
    a_epoch=$(date -u -d "$accepted_ts" +%s 2>/dev/null || echo 0)
    local diff=$(( a_epoch - p_epoch ))
    local sessions; sessions=$(to_sessions "$diff")
    echo "    Lead time: ${sessions} sessions (${diff}s)"
  fi
  echo ""

  local bug_count=0
  bug_count=$(echo "$item_events" | jq -c 'select(.event=="bug-found")' | grep -c . || true)
  echo "  BUGS: $bug_count found"
  echo ""

  local rejection_count=0
  rejection_count=$(echo "$item_events" | jq -c 'select(.event=="handoff-rejected")' | grep -c . || true)
  echo "  HANDOFF REJECTIONS: $rejection_count"
  echo ""
}

# ── Agent Cost ────────────────────────────────────────────────────────────────
cost_metrics() {
  local events
  events=$(filtered_events)

  echo "================================================================"
  echo "                 AGENT COST ANALYSIS                            "
  echo "================================================================"
  echo ""

  local invocations=""
  if [[ -n "$events" ]]; then
    invocations=$(echo "$events" | jq -c 'select(.event == "agent-invoked")' 2>/dev/null || true)
  fi

  if [[ -z "$invocations" ]]; then
    echo "  No agent-invoked events found in the selected time window."
    echo "  Log usage: ops/metrics-log.sh agent-invoked <agent> --tokens N [--turns N] [--model M]"
    echo ""
    return 0
  fi

  local total_invocations total_tokens
  total_invocations=$(echo "$invocations" | grep -c . || true)
  total_tokens=$(echo "$invocations" | jq -s '[.[].tokens // 0] | add' 2>/dev/null || echo 0)

  echo "  SUMMARY"
  echo "    Total invocations: $total_invocations"
  echo "    Total tokens:      $total_tokens"
  echo ""

  echo "  MODEL SPLIT"
  echo "$invocations" | jq -s '
    group_by(.model) |
    .[] |
    "    \(.[0].model // "unknown"): \(length) calls, \([.[].tokens // 0] | add) tokens"
  ' -r 2>/dev/null || echo "    (no model data)"
  echo ""
}

# ── Main ──────────────────────────────────────────────────────────────────────
case "$MODE" in
  dora) dora_metrics ;;
  flow) flow_quality ;;
  sm)   sm_metrics ;;
  cost) cost_metrics ;;
  pathways) exec "$SCRIPT_DIR/pathways.sh" ${SINCE:+--since "$SINCE"} ;;
  all)
    dora_metrics
    flow_quality
    ;;
esac

if [[ -n "$ITEM_FILTER" ]]; then
  item_detail
fi
