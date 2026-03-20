#!/usr/bin/env bash
# Event logging helper for DORA + Flow Quality metrics.
# Agents never write JSON directly -- always use this helper.
#
# Usage: ops/metrics-log.sh <event-type> [positional] [--flags...]
# Env vars:
#   METRICS_LOG_FILE  Override log path (default: .claude/metrics/events.jsonl)
#   AGENT_NAME        Agent identity (default: unknown)
#
# Pluggable backend: reads fleet-config.json for backend type.
# Supported backends: jsonl (default), webhook
# JSONL works out of the box with no configuration.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# ── Read fleet config for backend ──────────────────────────────────────────
FLEET_CONFIG="$REPO_ROOT/fleet-config.json"
BACKEND="jsonl"
WEBHOOK_URL=""
if [[ -f "$FLEET_CONFIG" ]] && command -v jq &>/dev/null; then
  BACKEND=$(jq -r '.metrics.backend // "jsonl"' "$FLEET_CONFIG" 2>/dev/null || echo "jsonl")
  WEBHOOK_URL=$(jq -r '.metrics.webhook // empty' "$FLEET_CONFIG" 2>/dev/null || echo "")
  METRICS_LOG_FILE="${METRICS_LOG_FILE:-$(jq -r '.metrics.file // empty' "$FLEET_CONFIG" 2>/dev/null || echo "")}"
fi

METRICS_LOG_FILE="${METRICS_LOG_FILE:-$REPO_ROOT/.claude/metrics/events.jsonl}"
AGENT="${AGENT_NAME:-unknown}"

if [ $# -eq 0 ]; then
  echo "Usage: ops/metrics-log.sh <event-type> [args...]" >&2
  exit 1
fi

EVENT_TYPE="$1"; shift

# ── Parse positional + named args ────────────────────────────────────────────
ITEM="" FROM="" TO="" REASON="" SEVERITY="" SOURCE="" BUG_ID_ARG="" EXT="" DEPLOY_TYPE="" DEPLOY_ENV=""
TOKENS="" TURNS="" DURATION="" MODEL="" TASK=""
PROPOSAL="" SCOPE="" METHOD="" CHANGE_TYPE=""
BRANCH="" PR=""
TOPIC="" BY="" TRIGGER="" ACTION="" ITEMS=""
POSITIONAL=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --item)     ITEM="$2";     shift 2 ;;
    --from)     FROM="$2";     shift 2 ;;
    --to)       TO="$2";       shift 2 ;;
    --reason)   REASON="$2";   shift 2 ;;
    --severity) SEVERITY="$2"; shift 2 ;;
    --source)   SOURCE="$2";   shift 2 ;;
    --bug-id)   BUG_ID_ARG="$2"; shift 2 ;;
    --type)     DEPLOY_TYPE="$2"; shift 2 ;;
    --env)      DEPLOY_ENV="$2"; shift 2 ;;
    --tokens)   TOKENS="$2";     shift 2 ;;
    --turns)    TURNS="$2";      shift 2 ;;
    --duration) DURATION="$2";   shift 2 ;;
    --model)    MODEL="$2";      shift 2 ;;
    --task)     TASK="$2";       shift 2 ;;
    --proposal) PROPOSAL="$2"; shift 2 ;;
    --scope)    SCOPE="$2";    shift 2 ;;
    --method)   METHOD="$2";   shift 2 ;;
    --change-type) CHANGE_TYPE="$2"; shift 2 ;;
    --branch) BRANCH="$2"; shift 2 ;;
    --pr)     PR="$2";     shift 2 ;;
    --topic) TOPIC="$2"; shift 2 ;;
    --by)    BY="$2";    shift 2 ;;
    --trigger) TRIGGER="$2"; shift 2 ;;
    --action) ACTION="$2"; shift 2 ;;
    --items) ITEMS="$2"; shift 2 ;;
    *) POSITIONAL+=("$1"); shift ;;
  esac
done

# Assign positional args by event type
if [[ "$EVENT_TYPE" == "ext-deployed" ]]; then
  [[ ${#POSITIONAL[@]} -gt 0 ]] && EXT="${POSITIONAL[0]}"
else
  [[ ${#POSITIONAL[@]} -gt 0 ]] && [[ -z "$ITEM" ]] && ITEM="${POSITIONAL[0]}"
fi

# ── Ensure log file exists ────────────────────────────────────────────────────
mkdir -p "$(dirname "$METRICS_LOG_FILE")"
touch "$METRICS_LOG_FILE"

TS="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

# ── Backend dispatch ─────────────────────────────────────────────────────────
emit_event() {
  local json_line="$1"
  case "$BACKEND" in
    jsonl)
      echo "$json_line" >> "$METRICS_LOG_FILE"
      ;;
    webhook)
      if [[ -n "$WEBHOOK_URL" ]]; then
        echo "$json_line" >> "$METRICS_LOG_FILE"  # always persist locally
        curl -s -X POST -H "Content-Type: application/json" -d "$json_line" "$WEBHOOK_URL" >/dev/null 2>&1 || true
      else
        echo "$json_line" >> "$METRICS_LOG_FILE"
      fi
      ;;
    statsd|opentelemetry)
      # Future: implement StatsD/OTEL dispatch
      # For now, fall back to JSONL
      echo "$json_line" >> "$METRICS_LOG_FILE"
      echo "WARNING: $BACKEND backend not yet implemented, falling back to JSONL" >&2
      ;;
    *)
      echo "$json_line" >> "$METRICS_LOG_FILE"
      ;;
  esac
}

# ── Event handlers ────────────────────────────────────────────────────────────
case "$EVENT_TYPE" in

  item-promoted|item-accepted)
    emit_event "$(jq -cn --arg ts "$TS" --arg event "$EVENT_TYPE" \
       --arg item "$ITEM" --arg agent "$AGENT" \
       '{"ts":$ts,"event":$event,"item":$item,"agent":$agent}')"
    ;;

  ext-deployed)
    [[ -z "$DEPLOY_TYPE" ]] && DEPLOY_TYPE="planned"
    [[ -z "$DEPLOY_ENV" ]] && DEPLOY_ENV="dev"
    if [[ -n "$ITEM" ]]; then
      emit_event "$(jq -cn --arg ts "$TS" --arg ext "$EXT" \
         --arg item "$ITEM" --arg type "$DEPLOY_TYPE" --arg env "$DEPLOY_ENV" --arg agent "$AGENT" \
         '{"ts":$ts,"event":"ext-deployed","ext":$ext,"item":$item,"type":$type,"env":$env,"agent":$agent}')"
    else
      emit_event "$(jq -cn --arg ts "$TS" --arg ext "$EXT" \
         --arg type "$DEPLOY_TYPE" --arg env "$DEPLOY_ENV" --arg agent "$AGENT" \
         '{"ts":$ts,"event":"ext-deployed","ext":$ext,"type":$type,"env":$env,"agent":$agent}')"
    fi
    ;;

  bug-found)
    [[ -z "$SOURCE" ]] && SOURCE="new-discovery"
    COUNT=$(jq -r --arg item "$ITEM" \
      'select(.event == "bug-found" and .item == $item) | 1' \
      "$METRICS_LOG_FILE" 2>/dev/null | wc -l | tr -d ' ')
    NEW_BUG_ID="b$((COUNT + 1))"
    emit_event "$(jq -cn --arg ts "$TS" --arg item "$ITEM" --arg bug_id "$NEW_BUG_ID" \
       --arg agent "$AGENT" --arg severity "$SEVERITY" --arg source "$SOURCE" \
       '{"ts":$ts,"event":"bug-found","item":$item,"bug_id":$bug_id,"agent":$agent,"severity":$severity,"source":$source}')"
    echo "bug_id=$NEW_BUG_ID"
    ;;

  bug-fixed)
    emit_event "$(jq -cn --arg ts "$TS" --arg item "$ITEM" --arg bug_id "$BUG_ID_ARG" \
       --arg agent "$AGENT" \
       '{"ts":$ts,"event":"bug-fixed","item":$item,"bug_id":$bug_id,"agent":$agent}')"
    ;;

  handoff-sent)
    if [[ "$FROM" != "$AGENT" ]]; then
      echo "WARNING: from='$FROM' does not match AGENT_NAME='$AGENT' -- check attribution" >&2
    fi
    emit_event "$(jq -cn --arg ts "$TS" --arg item "$ITEM" \
       --arg from "$FROM" --arg to "$TO" --arg agent "$AGENT" \
       '{"ts":$ts,"event":"handoff-sent","item":$item,"from":$from,"to":$to,"agent":$agent}')"
    ;;

  handoff-rejected)
    PRIOR=$(jq -r --arg item "$ITEM" --arg from "$FROM" --arg to "$TO" \
      'select(.event == "handoff-sent" and .item == $item and .from == $from and .to == $to) | 1' \
      "$METRICS_LOG_FILE" 2>/dev/null | wc -l | tr -d ' ')
    if [[ "$PRIOR" -eq 0 ]]; then
      echo "WARNING: handoff-rejected logged without prior handoff-sent for item=$ITEM from=$FROM to=$TO" >&2
    fi
    if [[ -n "$REASON" ]]; then
      emit_event "$(jq -cn --arg ts "$TS" --arg item "$ITEM" \
         --arg from "$FROM" --arg to "$TO" --arg reason "$REASON" --arg agent "$AGENT" \
         '{"ts":$ts,"event":"handoff-rejected","item":$item,"from":$from,"to":$to,"reason":$reason,"agent":$agent}')"
    else
      emit_event "$(jq -cn --arg ts "$TS" --arg item "$ITEM" \
         --arg from "$FROM" --arg to "$TO" --arg agent "$AGENT" \
         '{"ts":$ts,"event":"handoff-rejected","item":$item,"from":$from,"to":$to,"agent":$agent}')"
    fi
    ;;

  item-rejected-at-build)
    if [[ -z "$REASON" ]]; then
      echo "ERROR: item-rejected-at-build requires --reason (context-changed|flawed-suggestion|superseded|duplicate)" >&2
      exit 1
    fi
    emit_event "$(jq -cn --arg ts "$TS" --arg item "$ITEM" \
       --arg reason "$REASON" --arg source "$SOURCE" --arg agent "$AGENT" \
       '{"ts":$ts,"event":"item-rejected-at-build","item":$item,"reason":$reason,"source":$source,"agent":$agent} | with_entries(select(.value != ""))')"
    ;;

  task-restarted|task-discarded|task-blocked)
    if [[ -n "$REASON" ]]; then
      emit_event "$(jq -cn --arg ts "$TS" --arg event "$EVENT_TYPE" \
         --arg item "$ITEM" --arg reason "$REASON" --arg agent "$AGENT" \
         '{"ts":$ts,"event":$event,"item":$item,"reason":$reason,"agent":$agent}')"
    else
      emit_event "$(jq -cn --arg ts "$TS" --arg event "$EVENT_TYPE" \
         --arg item "$ITEM" --arg agent "$AGENT" \
         '{"ts":$ts,"event":$event,"item":$item,"agent":$agent}')"
    fi
    ;;

  task-unblocked)
    emit_event "$(jq -cn --arg ts "$TS" --arg item "$ITEM" --arg agent "$AGENT" \
       '{"ts":$ts,"event":"task-unblocked","item":$item,"agent":$agent}')"
    ;;

  agent-invoked)
    [[ ${#POSITIONAL[@]} -gt 0 ]] && [[ "$AGENT" == "unknown" ]] && AGENT="${POSITIONAL[0]}"
    if [[ -z "$TOKENS" ]]; then
      echo "ERROR: agent-invoked requires --tokens <count>" >&2
      exit 1
    fi
    emit_event "$(jq -cn --arg ts "$TS" --arg agent "$AGENT" \
       --argjson tokens "${TOKENS:-0}" \
       --argjson turns "${TURNS:-0}" \
       --argjson duration "${DURATION:-0}" \
       --arg model "${MODEL:-unknown}" \
       --arg item "$ITEM" \
       --arg task "${TASK:-}" \
       '{"ts":$ts,"event":"agent-invoked","agent":$agent,"tokens":$tokens,"turns":$turns,"duration_ms":$duration,"model":$model,"item":$item,"task":$task} | with_entries(select(.value != "" and .value != 0 and .value != "unknown"))')"
    ;;

  regression-run)
    # Log a regression test run completion
    emit_event "$(jq -cn --arg ts "$TS" --arg item "$ITEM" --arg agent "$AGENT" \
       '{"ts":$ts,"event":"regression-run","item":$item,"agent":$agent}')"
    ;;

  compliance-proposed)
    emit_event "$(jq -cn --arg ts "$TS" --arg event "$EVENT_TYPE" \
       --arg proposal "$PROPOSAL" --arg type "$CHANGE_TYPE" --arg agent "$AGENT" \
       '{"ts":$ts,"event":$event,"proposal":$proposal,"type":$type,"agent":$agent}')"
    ;;

  compliance-approved|compliance-rejected)
    emit_event "$(jq -cn --arg ts "$TS" --arg event "$EVENT_TYPE" \
       --arg proposal "$PROPOSAL" --arg by "$AGENT" --arg reason "$REASON" \
       '{"ts":$ts,"event":$event,"proposal":$proposal,"by":$by,"reason":$reason}')"
    ;;

  compliance-applied)
    emit_event "$(jq -cn --arg ts "$TS" --arg event "$EVENT_TYPE" \
       --arg proposal "$PROPOSAL" --arg scope "$SCOPE" --arg agent "$AGENT" \
       '{"ts":$ts,"event":$event,"proposal":$proposal,"scope":$scope,"agent":$agent}')"
    ;;

  compliance-violation)
    emit_event "$(jq -cn --arg ts "$TS" --arg event "$EVENT_TYPE" \
       --arg source "$SOURCE" --arg agent "$AGENT" \
       '{"ts":$ts,"event":$event,"source":$source,"agent":$agent}')"
    ;;

  compliance-reverted)
    emit_event "$(jq -cn --arg ts "$TS" --arg event "$EVENT_TYPE" \
       --arg method "$METHOD" --arg agent "$AGENT" \
       '{"ts":$ts,"event":$event,"method":$method,"agent":$agent}')"
    ;;

  branch-created)
    emit_event "$(jq -cn --arg ts "$TS" --arg event "$EVENT_TYPE" \
       --arg item "$ITEM" --arg branch "$BRANCH" --arg agent "$AGENT" \
       '{"ts":$ts,"event":$event,"item":$item,"branch":$branch,"agent":$agent}')"
    ;;

  pr-opened|pr-merged)
    emit_event "$(jq -cn --arg ts "$TS" --arg event "$EVENT_TYPE" \
       --arg item "$ITEM" --arg pr "$PR" --arg agent "$AGENT" \
       '{"ts":$ts,"event":$event,"item":$item,"pr":$pr,"agent":$agent}')"
    ;;

  guidance-published)
    emit_event "$(jq -cn --arg ts "$TS" --arg event "$EVENT_TYPE" \
       --arg by "$BY" --arg topic "$TOPIC" --arg agent "$AGENT" \
       '{"ts":$ts,"event":$event,"by":$by,"topic":$topic,"agent":$agent}')"
    ;;

  ceo-autonomy-granted)
    emit_event "$(jq -cn --arg ts "$TS" --arg event "$EVENT_TYPE" \
       --arg scope "$SCOPE" --arg agent "$AGENT" \
       '{"ts":$ts,"event":$event,"scope":$scope,"agent":$agent}')"
    ;;

  ceo-autonomy-violation)
    emit_event "$(jq -cn --arg ts "$TS" --arg event "$EVENT_TYPE" \
       --arg action "$ACTION" --arg agent "$AGENT" \
       '{"ts":$ts,"event":$event,"action":$action,"agent":$agent}')"
    ;;

  knowledge-distributed)
    emit_event "$(jq -cn --arg ts "$TS" --arg event "$EVENT_TYPE" \
       --arg trigger "$TRIGGER" --arg items "$ITEMS" --arg agent "$AGENT" \
       '{"ts":$ts,"event":$event,"trigger":$trigger,"items":$items,"agent":$agent}')"
    ;;

  item-rejected-at-acceptance)
    if [[ -z "$REASON" ]]; then
      echo "ERROR: item-rejected-at-acceptance requires --reason" >&2
      exit 1
    fi
    emit_event "$(jq -cn --arg ts "$TS" --arg item "$ITEM" --arg reason "$REASON" --arg agent "$AGENT" \
       '{"ts":$ts,"event":"item-rejected-at-acceptance","item":$item,"reason":$reason,"agent":$agent} | with_entries(select(.value != ""))')"
    ;;

  *)
    echo "ERROR: unknown event type '$EVENT_TYPE'" >&2
    echo "Valid types: item-promoted item-accepted ext-deployed bug-found bug-fixed" >&2
    echo "             handoff-sent handoff-rejected item-rejected-at-build item-rejected-at-acceptance" >&2
    echo "             task-restarted task-discarded task-blocked task-unblocked" >&2
    echo "             agent-invoked regression-run" >&2
    echo "             compliance-proposed compliance-approved compliance-rejected" >&2
    echo "             compliance-applied compliance-violation compliance-reverted" >&2
    echo "             branch-created pr-opened pr-merged" >&2
    echo "             guidance-published ceo-autonomy-granted ceo-autonomy-violation knowledge-distributed" >&2
    exit 1
    ;;
esac
