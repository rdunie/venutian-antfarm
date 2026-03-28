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

# ── Source shared emit library ────────────────────────────────────────────
source "$SCRIPT_DIR/lib/signal-emit.sh"

# Backward compat: alias for internal references
emit_event() { signal_emit "$@"; }

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
ITEMS_REVIEWED="" ITEMS_ADDED="" ITEMS_DROPPED="" ITEMS_REORDERED=""
RULE_ID="" ENFORCEMENT_POINT="" FILE_PATH_ARG=""
REWARD_ID_ARG="" SUBJECT="" DESCRIPTION=""
FLOOR_ARG="" DETAIL_ARG=""
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
    --rule-id) RULE_ID="$2"; shift 2 ;;
    --enforcement-point) ENFORCEMENT_POINT="$2"; shift 2 ;;
    --file) FILE_PATH_ARG="$2"; shift 2 ;;
    --items-reviewed) ITEMS_REVIEWED="$2"; shift 2 ;;
    --items-added) ITEMS_ADDED="$2"; shift 2 ;;
    --items-dropped) ITEMS_DROPPED="$2"; shift 2 ;;
    --items-reordered) ITEMS_REORDERED="$2"; shift 2 ;;
    --reward-id) REWARD_ID_ARG="$2"; shift 2 ;;
    --subject) SUBJECT="$2"; shift 2 ;;
    --description) DESCRIPTION="$2"; shift 2 ;;
    --floor) FLOOR_ARG="$2"; shift 2 ;;
    --detail) DETAIL_ARG="$2"; shift 2 ;;
    *) POSITIONAL+=("$1"); shift ;;
  esac
done

# Assign positional args by event type
if [[ "$EVENT_TYPE" == "ext-deployed" ]]; then
  [[ ${#POSITIONAL[@]} -gt 0 ]] && EXT="${POSITIONAL[0]}"
else
  [[ ${#POSITIONAL[@]} -gt 0 ]] && [[ -z "$ITEM" ]] && ITEM="${POSITIONAL[0]}"
fi

TS="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

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
       --arg rule_id "$RULE_ID" --arg severity "$SEVERITY" \
       --arg enforcement_point "$ENFORCEMENT_POINT" --arg file "$FILE_PATH_ARG" \
       --arg action "$ACTION" --arg source "$SOURCE" --arg agent "$AGENT" \
       '{"ts":$ts,"event":$event,"rule_id":$rule_id,"severity":$severity,"enforcement_point":$enforcement_point,"file":$file,"action":$action,"source":$source,"agent":$agent} | with_entries(select(.value != ""))')"
    ;;

  compliance-pass)
    emit_event "$(jq -cn --arg ts "$TS" --arg event "$EVENT_TYPE" \
       --arg rule_id "$RULE_ID" --arg enforcement_point "$ENFORCEMENT_POINT" \
       --arg file "$FILE_PATH_ARG" --arg agent "$AGENT" \
       '{"ts":$ts,"event":$event,"rule_id":$rule_id,"enforcement_point":$enforcement_point,"file":$file,"agent":$agent} | with_entries(select(.value != ""))')"
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

  backlog-triaged)
    emit_event "$(jq -cn --arg ts "$TS" --arg event "$EVENT_TYPE" \
       --arg items_reviewed "$ITEMS_REVIEWED" --arg items_added "$ITEMS_ADDED" \
       --arg items_dropped "$ITEMS_DROPPED" --arg items_reordered "$ITEMS_REORDERED" \
       --arg agent "$AGENT" \
       '{"ts":$ts,"event":$event,"items_reviewed":$items_reviewed,"items_added":$items_added,"items_dropped":$items_dropped,"items_reordered":$items_reordered,"agent":$agent} | with_entries(select(.value != ""))')"
    ;;

  reward-issued)
    if [[ -z "$DEPLOY_TYPE" ]]; then
      echo "ERROR: reward-issued requires --type (kudo|reprimand)" >&2
      exit 1
    fi
    emit_event "$(jq -cn --arg ts "$TS" --arg event "$EVENT_TYPE" \
       --arg type "$DEPLOY_TYPE" --arg issuer "$FROM" --arg subject "$SUBJECT" \
       --arg domain "$SCOPE" --arg severity "$SEVERITY" \
       --arg item "$ITEM" --arg reward_id "$REWARD_ID_ARG" --arg agent "$AGENT" \
       '{"ts":$ts,"event":$event,"type":$type,"issuer":$issuer,"subject":$subject,"domain":$domain,"severity":$severity,"item":$item,"reward_id":$reward_id,"agent":$agent} | with_entries(select(.value != ""))')"
    ;;

  tension-detected)
    emit_event "$(jq -cn --arg ts "$TS" --arg event "$EVENT_TYPE" \
       --arg reward_ids "$DESCRIPTION" --arg item "$ITEM" \
       --arg subject "$SUBJECT" --arg agent "$AGENT" \
       '{"ts":$ts,"event":$event,"reward_ids":$reward_ids,"item":$item,"subject":$subject,"agent":$agent} | with_entries(select(.value != ""))')"
    ;;

  preflight-remediation)
    if [[ -z "${FLOOR_ARG}" ]]; then
      echo "ERROR: preflight-remediation requires --floor" >&2
      exit 1
    fi
    if [[ -z "${DEPLOY_TYPE}" ]]; then
      echo "ERROR: preflight-remediation requires --type (expected|unexpected)" >&2
      exit 1
    fi
    if [[ -z "${DETAIL_ARG}" ]]; then
      echo "ERROR: preflight-remediation requires --detail" >&2
      exit 1
    fi
    emit_event "$(jq -cn --arg ts "$TS" --arg event "$EVENT_TYPE" \
       --arg floor "$FLOOR_ARG" --arg type "$DEPLOY_TYPE" \
       --arg detail "$DETAIL_ARG" --arg agent "$AGENT" \
       '{"ts":$ts,"event":$event,"floor":$floor,"type":$type,"detail":$detail,"agent":$agent} | with_entries(select(.value != ""))')"
    ;;

  feedback-proposed)
    emit_event "$(jq -cn --arg ts "$TS" --arg event "$EVENT_TYPE" \
       --arg issuer "$FROM" --arg subject "$SUBJECT" --arg type "$DEPLOY_TYPE" \
       --arg domain "$SCOPE" --arg severity "$SEVERITY" \
       --arg item "$ITEM" --arg proposal_id "$PROPOSAL" --arg supervisor "$TO" \
       --arg agent "$AGENT" \
       '{"ts":$ts,"event":$event,"issuer":$issuer,"subject":$subject,"type":$type,"domain":$domain,"severity":$severity,"item":$item,"proposal_id":$proposal_id,"supervisor":$supervisor,"agent":$agent} | with_entries(select(.value != ""))')"
    ;;

  feedback-formalized)
    emit_event "$(jq -cn --arg ts "$TS" --arg event "$EVENT_TYPE" \
       --arg proposal_id "$PROPOSAL" --arg reward_id "$REWARD_ID_ARG" \
       --arg formalizer "$FROM" --arg agent "$AGENT" \
       '{"ts":$ts,"event":$event,"proposal_id":$proposal_id,"reward_id":$reward_id,"formalizer":$formalizer,"agent":$agent} | with_entries(select(.value != ""))')"
    ;;

  feedback-rejected)
    emit_event "$(jq -cn --arg ts "$TS" --arg event "$EVENT_TYPE" \
       --arg proposal_id "$PROPOSAL" --arg rejector "$FROM" \
       --arg reason "$REASON" --arg agent "$AGENT" \
       '{"ts":$ts,"event":$event,"proposal_id":$proposal_id,"rejector":$rejector,"reason":$reason,"agent":$agent} | with_entries(select(.value != ""))')"
    ;;

  feedback-escalated)
    emit_event "$(jq -cn --arg ts "$TS" --arg event "$EVENT_TYPE" \
       --arg proposal_id "$PROPOSAL" --arg from_supervisor "$FROM" \
       --arg to_supervisor "$TO" --arg agent "$AGENT" \
       '{"ts":$ts,"event":$event,"proposal_id":$proposal_id,"from_supervisor":$from_supervisor,"to_supervisor":$to_supervisor,"agent":$agent} | with_entries(select(.value != ""))')"
    ;;

  *)
    echo "ERROR: unknown event type '$EVENT_TYPE'" >&2
    echo "Valid types: item-promoted item-accepted ext-deployed bug-found bug-fixed" >&2
    echo "             handoff-sent handoff-rejected item-rejected-at-build item-rejected-at-acceptance" >&2
    echo "             task-restarted task-discarded task-blocked task-unblocked" >&2
    echo "             agent-invoked regression-run" >&2
    echo "             compliance-proposed compliance-approved compliance-rejected" >&2
    echo "             compliance-applied compliance-violation compliance-pass compliance-reverted" >&2
    echo "             branch-created pr-opened pr-merged" >&2
    echo "             guidance-published ceo-autonomy-granted ceo-autonomy-violation knowledge-distributed backlog-triaged" >&2
    echo "             reward-issued tension-detected preflight-remediation" >&2
    echo "             feedback-proposed feedback-formalized feedback-rejected feedback-escalated" >&2
    exit 1
    ;;
esac
