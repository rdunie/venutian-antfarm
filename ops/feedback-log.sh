#!/usr/bin/env bash
set -euo pipefail

# ---------------------------------------------------------------------------
# feedback-log.sh — Behavioral feedback helper
#
# Single entry point for all ledger writes and queries.
# Agents never edit the ledger directly — always use this script.
#
# Usage:
#   ops/feedback-log.sh reprimand --issuer <agent> --subject <agent> ...
#   ops/feedback-log.sh kudo --issuer <agent> --subject <agent> ...
#   ops/feedback-log.sh recommend --issuer <agent> --subject <agent> ...
#   ops/feedback-log.sh formalize --issuer <agent> --subject <agent> ...
#   ops/feedback-log.sh reject --issuer <agent> --subject <agent> ...
#   ops/feedback-log.sh check-escalations
#   ops/feedback-log.sh profile <agent>
#   ops/feedback-log.sh score <agent>
#   ops/feedback-log.sh tensions [--item <id>]
#
# Env vars (for testing — defaults to repo paths):
#   FEEDBACK_LEDGER    Override ledger path (also accepts REWARDS_LEDGER for backward compat)
#   FEEDBACK_CHECKSUM  Override checksum path (also accepts REWARDS_CHECKSUM for backward compat)
#   FINDINGS_REGISTER  Override findings register path
#   METRICS_LOG_FILE   Override metrics log path
# ---------------------------------------------------------------------------

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/.." && pwd)}"

LEDGER="${FEEDBACK_LEDGER:-${REWARDS_LEDGER:-$REPO_ROOT/.claude/rewards/ledger.md}}"
CHECKSUM="${FEEDBACK_CHECKSUM:-${REWARDS_CHECKSUM:-$REPO_ROOT/.claude/rewards/ledger-checksum.sha256}}"
FINDINGS="${FINDINGS_REGISTER:-$REPO_ROOT/.claude/findings/register.md}"
export METRICS_LOG_FILE="${METRICS_LOG_FILE:-$REPO_ROOT/.claude/metrics/events.jsonl}"

if [[ $# -eq 0 ]]; then
  echo "Usage: ops/feedback-log.sh <reprimand|kudo|recommend|formalize|reject|check-escalations|profile|tensions> [args...]" >&2
  exit 1
fi

SUBCOMMAND="$1"; shift

# ── Parse flags ──────────────────────────────────────────────────────────
ISSUER="" SUBJECT="" DOMAIN="" SEVERITY="" ITEM="" DESCRIPTION="" EVIDENCE="" TYPE="" REASON=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --issuer)      ISSUER="$2";      shift 2 ;;
    --subject)     SUBJECT="$2";     shift 2 ;;
    --domain)      DOMAIN="$2";      shift 2 ;;
    --severity)    SEVERITY="$2";    shift 2 ;;
    --item)        ITEM="$2";        shift 2 ;;
    --description) DESCRIPTION="$2"; shift 2 ;;
    --evidence)    EVIDENCE="$2";    shift 2 ;;
    --type)        TYPE="$2";        shift 2 ;;
    --reason)      REASON="$2";      shift 2 ;;
    *) # Positional (used by profile/tensions)
       if [[ -z "$SUBJECT" ]]; then SUBJECT="$1"; fi
       shift ;;
  esac
done

# ── Version check ────────────────────────────────────────────────────────
if ((BASH_VERSINFO[0] < 4)); then
  echo "ERROR: feedback-log.sh requires bash 4+. macOS users: brew install bash" >&2
  exit 1
fi

# ── Helpers ──────────────────────────────────────────────────────────────

# Emit a metric event (non-fatal — errors visible on stderr but don't block primary operation)
emit_metric() {
  "$SCRIPT_DIR/metrics-log.sh" "$@" 2>&1 || echo "WARNING: metric emission failed: $1" >&2
}

update_checksum() {
  if ! sha256sum "$LEDGER" > "$CHECKSUM" 2>/dev/null; then
    echo "WARNING: checksum update failed for $LEDGER" >&2
  fi
}

resolve_tier() {
  local agent="$1"
  local config="$REPO_ROOT/fleet-config.json"
  if [[ ! -f "$config" ]] || ! command -v jq &>/dev/null; then
    echo "unknown"
    return
  fi
  if jq -e --arg a "$agent" '.agents.governance | index($a)' "$config" &>/dev/null; then
    echo "governance"; return
  fi
  if jq -e --arg a "$agent" '.agents.core | index($a)' "$config" &>/dev/null; then
    echo "core"; return
  fi
  echo "specialist"
}

resolve_supervisor() {
  local issuer="$1"
  local config="$REPO_ROOT/fleet-config.json"
  if [[ ! -f "$config" ]] || ! command -v jq &>/dev/null; then
    echo ""; return
  fi
  local feedback_target
  feedback_target=$(jq -r --arg i "$issuer" \
    '.pathways.declared.feedback[]? | select(startswith($i + " -> ")) | split(" -> ")[1]' \
    "$config" 2>/dev/null | head -1)
  if [[ -n "$feedback_target" ]]; then echo "$feedback_target"; return; fi
  local escalation_target
  escalation_target=$(jq -r \
    '.pathways.declared.escalation[]? | select(startswith("* -> ")) | split(" -> ")[1]' \
    "$config" 2>/dev/null | head -1)
  if [[ -n "$escalation_target" ]]; then echo "$escalation_target"; return; fi
  echo ""
}

resolve_escalation_target() {
  local current_supervisor="$1"
  local config="$REPO_ROOT/fleet-config.json"
  if [[ ! -f "$config" ]] || ! command -v jq &>/dev/null; then
    echo "ceo"; return
  fi
  local target
  target=$(jq -r --arg s "$current_supervisor" \
    '.pathways.declared.governance[]? | select(startswith($s + " -> ")) | split(" -> ")[1]' \
    "$config" 2>/dev/null | head -1)
  if [[ -n "$target" ]]; then echo "$target"; return; fi
  echo "ceo"
}

read_proposal_field() {
  local pid="$1"
  local field="$2"
  sed -n "/^### ${pid} /,/^### /p" "$LEDGER" | grep "^\*\*${field}:\*\*" | head -1 | sed "s/.*\*\*${field}:\*\* //"
}

update_proposal_status() {
  local pid="$1"
  local new_status="$2"
  local tmpfile
  tmpfile=$(mktemp)
  awk -v pid="### ${pid} " -v new_status="$new_status" '
    $0 ~ pid { in_entry=1 }
    in_entry && /^\*\*Status:\*\*/ { print "**Status:** " new_status; in_entry=0; next }
    in_entry && /^### / && !($0 ~ pid) { in_entry=0 }
    { print }
  ' "$LEDGER" > "$tmpfile" && mv "$tmpfile" "$LEDGER"
}

# Get the next ID for a given prefix (R, K, or T)
next_id() {
  local prefix="$1"
  local count=0
  if [[ -f "$LEDGER" ]]; then
    count=$(grep -cE "^### ${prefix}-[0-9]+" "$LEDGER" 2>/dev/null || true)
    count="${count:-0}"
  fi
  printf "%s-%03d" "$prefix" "$((count + 1))"
}

# Check for tension: opposing signal types on same item + subject
check_tension() {
  local new_type="$1" new_subject="$2" new_item="$3" new_id="$4"

  [[ -z "$new_item" ]] && return 0  # No item = no conflict possible

  local opposing_type
  if [[ "$new_type" == "kudo" ]]; then
    opposing_type="reprimand"
  else
    opposing_type="kudo"
  fi

  # Search ledger for opposing signal on same item + subject
  # Look within the subject's section for entries with the same item
  local in_section=0
  local opposing_id=""
  while IFS= read -r line; do
    if [[ "$line" =~ ^##\  ]] && [[ ! "$line" =~ ^###\  ]]; then
      if [[ "$line" == "## $new_subject" ]]; then
        in_section=1
      else
        in_section=0
      fi
    fi
    if [[ "$in_section" -eq 1 ]] && [[ "$line" =~ ^###\ ([RK]-[0-9]+)\ \[${opposing_type}\] ]]; then
      local candidate_id="${BASH_REMATCH[1]}"
      # Check if this entry has the same item
      local next_lines
      next_lines=$(sed -n "/^### ${candidate_id} /,/^### /p" "$LEDGER" | head -10)
      if echo "$next_lines" | grep -q "^\*\*Item:\*\* ${new_item}$"; then
        opposing_id="$candidate_id"
        break
      fi
    fi
  done < "$LEDGER"

  [[ -z "$opposing_id" ]] && return 0

  # Generate tension entry
  local tension_id
  tension_id=$(next_id "T")
  local ts
  ts="$(date -u +%Y-%m-%d)"

  # Determine order: earlier ID first
  local first_id="$opposing_id"
  local second_id="$new_id"

  cat >> "$LEDGER" <<EOF

### ${tension_id} [tension] ${ts} — auto / item-${new_item}

**Signals:** ${first_id} vs ${second_id}
**Description:** Opposing feedback on item ${new_item} for ${new_subject}
**Status:** open
**Referred to:** SM for retro
EOF

  # Add finding to register
  if [[ -f "$FINDINGS" ]]; then
    local finding_entry
    finding_entry="### [${ts}] normal -- Behavioral tension on item ${new_item}

**Found by:** rewards-system (auto)
**Category:** boundary-tension
**Description:** ${first_id} and ${second_id} are opposing feedback for ${new_subject} on item ${new_item}. SM should surface in retro.
**Proposed action:** Review during next retro (Phase 8)
**Status:** open"

    # Insert before "(none yet)" or append
    if grep -q "^(none yet)" "$FINDINGS"; then
      # Replace (none yet) with finding entry
      local tmpfile
      tmpfile=$(mktemp)
      awk -v entry="$finding_entry" '{
        if ($0 == "(none yet)") {
          print entry
        } else {
          print
        }
      }' "$FINDINGS" > "$tmpfile" && mv "$tmpfile" "$FINDINGS"
    elif grep -q "^## Resolved Findings" "$FINDINGS"; then
      # Insert before Resolved section
      local tmpfile
      tmpfile=$(mktemp)
      awk -v entry="$finding_entry" '{
        if ($0 == "## Resolved Findings") {
          print ""
          print entry
          print ""
        }
        print
      }' "$FINDINGS" > "$tmpfile" && mv "$tmpfile" "$FINDINGS"
    else
      echo "" >> "$FINDINGS"
      echo "$finding_entry" >> "$FINDINGS"
    fi
  fi

  # Emit tension-detected metric
  emit_metric tension-detected \
    --description "${first_id},${second_id}" \
    --item "$new_item" --subject "$new_subject"

  update_checksum
}

compute_weighted_score() {
  local agent="$1"
  local config="$REPO_ROOT/fleet-config.json"

  local tier_gov=1.0 tier_core=0.8 tier_spec=0.5
  local type_reprimand=1.5 type_kudo=1.0
  local decay_cliff=10 decay_post=0.25

  if [[ -f "$config" ]] && command -v jq &>/dev/null; then
    local w
    w=$(jq -r '.rewards.weighting // empty' "$config" 2>/dev/null)
    if [[ -n "$w" ]]; then
      tier_gov=$(jq -r '.rewards.weighting.tier_multipliers.governance // 1.0' "$config" 2>/dev/null)
      tier_core=$(jq -r '.rewards.weighting.tier_multipliers.core // 0.8' "$config" 2>/dev/null)
      tier_spec=$(jq -r '.rewards.weighting.tier_multipliers.specialist // 0.5' "$config" 2>/dev/null)
      type_reprimand=$(jq -r '.rewards.weighting.type_multipliers.reprimand // 1.5' "$config" 2>/dev/null)
      type_kudo=$(jq -r '.rewards.weighting.type_multipliers.kudo // 1.0' "$config" 2>/dev/null)
      decay_cliff=$(jq -r '.rewards.weighting.decay.cliff_items // 10' "$config" 2>/dev/null)
      decay_post=$(jq -r '.rewards.weighting.decay.post_cliff_multiplier // 0.25' "$config" 2>/dev/null)
    fi
  fi

  if [[ "$decay_cliff" -lt 1 ]] 2>/dev/null; then
    echo "WARNING: cliff_items must be >= 1, got ${decay_cliff}. Using 1." >&2
    decay_cliff=1
  fi

  declare -A accepted_by_date
  local total_accepted=0
  if [[ -f "$METRICS_LOG_FILE" ]] && command -v jq &>/dev/null; then
    while IFS= read -r evt_date; do
      [[ -z "$evt_date" ]] && continue
      total_accepted=$((total_accepted + 1))
      accepted_by_date["$evt_date"]=$total_accepted
    done < <(jq -r -R 'fromjson? | select(.event == "item-accepted") | .ts[:10]' "$METRICS_LOG_FILE" 2>/dev/null)
  fi

  local sorted_dates
  sorted_dates=$(printf '%s\n' "${!accepted_by_date[@]}" | sort)

  lookup_accepted_at() {
    local signal_date="$1"
    local result=0
    local d
    while IFS= read -r d; do
      [[ -z "$d" ]] && continue
      if [[ "$d" < "$signal_date" || "$d" == "$signal_date" ]]; then
        result=${accepted_by_date["$d"]}
      else
        break
      fi
    done <<< "$sorted_dates"
    echo "$result"
  }

  local kudos_sum=0 reprimands_sum=0 signal_count=0 recent_count=0

  if grep -q "^## ${agent}$" "$LEDGER" 2>/dev/null; then
    local section
    section=$(sed -n "/^## ${agent}$/,/^## [^#]/p" "$LEDGER")

    while IFS= read -r header; do
      [[ -z "$header" ]] && continue

      local entry_type entry_date entry_domain entry_tier
      local re_type='\[(kudo|reprimand)\]'
      local re_date='\] ([0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]) '
      local re_domain='/ ([a-zA-Z_-]+)$'
      local re_id='^### ([RK]-[0-9]+)'
      if [[ "$header" =~ $re_type ]]; then
        entry_type="${BASH_REMATCH[1]}"
      else
        continue
      fi
      if [[ "$header" =~ $re_date ]]; then
        entry_date="${BASH_REMATCH[1]}"
      else
        continue
      fi
      if [[ "$header" =~ $re_domain ]]; then
        entry_domain="${BASH_REMATCH[1]}"
      else
        entry_domain="unknown"
      fi

      local entry_id=""
      if [[ "$header" =~ $re_id ]]; then
        entry_id="${BASH_REMATCH[1]}"
      fi
      [[ -z "$entry_id" ]] && continue
      entry_tier=$(sed -n "/^### ${entry_id} /,/^### /p" "$LEDGER" | grep '^\*\*Origin tier:\*\*' | head -1 | sed 's/.*\*\* //')
      [[ -z "$entry_tier" ]] && entry_tier="unknown"

      local tm=1.0
      case "$entry_tier" in
        governance) tm=$tier_gov ;;
        core) tm=$tier_core ;;
        specialist) tm=$tier_spec ;;
      esac

      local tpm=1.0
      case "$entry_type" in
        reprimand) tpm=$type_reprimand ;;
        kudo) tpm=$type_kudo ;;
      esac

      local dm=1.0
      if [[ -f "$config" ]] && command -v jq &>/dev/null; then
        local dm_lookup
        dm_lookup=$(jq -r --arg d "$entry_domain" --arg a "$agent" \
          '.rewards.weighting.domain_multipliers[$d] | if type == "object" then .[$a] // ._default // null else . // null end // null' \
          "$config" 2>/dev/null)
        if [[ "$dm_lookup" != "null" && -n "$dm_lookup" ]]; then
          dm=$dm_lookup
        else
          dm_lookup=$(jq -r '.rewards.weighting.domain_multipliers._default // 1.0' "$config" 2>/dev/null)
          dm=$dm_lookup
        fi
      fi

      local decay=1.0
      local accepted_at
      accepted_at=$(lookup_accepted_at "$entry_date")
      local signal_age=$((total_accepted - accepted_at))
      if [[ "$signal_age" -gt "$decay_cliff" ]]; then
        decay=$decay_post
      fi

      local weight
      weight=$(awk -v tm="$tm" -v tpm="$tpm" -v dm="$dm" -v decay="$decay" \
        'BEGIN { printf "%.1f", tm * tpm * dm * decay }')

      signal_count=$((signal_count + 1))
      if [[ "$signal_age" -le "$decay_cliff" ]]; then
        recent_count=$((recent_count + 1))
      fi

      if [[ "$entry_type" == "kudo" ]]; then
        kudos_sum=$(awk -v s="$kudos_sum" -v w="$weight" 'BEGIN { printf "%.1f", s + w }')
      else
        reprimands_sum=$(awk -v s="$reprimands_sum" -v w="$weight" 'BEGIN { printf "%.1f", s - w }')
      fi

    done <<< "$(echo "$section" | grep '^### [RK]-')"
  fi

  local net
  net=$(awk -v k="$kudos_sum" -v r="$reprimands_sum" 'BEGIN { printf "%.1f", k + r }')

  echo "net=${net}"
  echo "kudos=${kudos_sum}"
  echo "reprimands=${reprimands_sum}"
  echo "signals=${signal_count}"
  echo "recent=${recent_count}"
}

# ── Subcommands ──────────────────────────────────────────────────────────

case "$SUBCOMMAND" in

  reprimand)
    # Validate required fields
    [[ -z "$ISSUER" ]]      && echo "ERROR: --issuer required" >&2 && exit 1
    [[ -z "$SUBJECT" ]]     && echo "ERROR: --subject required" >&2 && exit 1
    [[ -z "$DOMAIN" ]]      && echo "ERROR: --domain required" >&2 && exit 1
    [[ -z "$SEVERITY" ]]    && echo "ERROR: --severity required for reprimands" >&2 && exit 1
    [[ -z "$DESCRIPTION" ]] && echo "ERROR: --description required" >&2 && exit 1
    [[ -z "$EVIDENCE" ]]    && echo "ERROR: --evidence required" >&2 && exit 1

    local_id=$(next_id "R")
    ts="$(date -u +%Y-%m-%d)"
    local_tier=$(resolve_tier "$ISSUER")

    # Ensure subject section exists
    if ! grep -q "^## ${SUBJECT}$" "$LEDGER" 2>/dev/null; then
      echo "" >> "$LEDGER"
      echo "## ${SUBJECT}" >> "$LEDGER"
    fi

    # Append reprimand entry
    {
      echo ""
      echo "### ${local_id} [reprimand] ${ts} — ${ISSUER} / ${DOMAIN}"
      echo ""
      echo "**Severity:** ${SEVERITY}"
      [[ -n "$ITEM" ]] && echo "**Item:** ${ITEM}"
      echo "**Description:** ${DESCRIPTION}"
      echo "**Evidence:** ${EVIDENCE}"
      echo "**Origin tier:** ${local_tier}"
    } >> "$LEDGER"

    # Emit metric event
    emit_metric reward-issued \
      --type reprimand --from "$ISSUER" --subject "$SUBJECT" \
      --scope "$DOMAIN" --severity "$SEVERITY" \
      ${ITEM:+--item "$ITEM"} --reward-id "$local_id"

    update_checksum

    # Check for tension
    check_tension "reprimand" "$SUBJECT" "$ITEM" "$local_id"

    echo "reward_id=$local_id"

    # Nudge: check if issuer has pending proposals to review
    if [[ -f "$LEDGER" ]]; then
      pending_for_issuer=$(grep -c "Supervisor.*${ISSUER}" "$LEDGER" 2>/dev/null || true)
      pending_status=$(grep -B5 "Supervisor.*${ISSUER}" "$LEDGER" 2>/dev/null | grep -c "Status.*pending" || true)
      if [[ "$pending_status" -gt 0 ]]; then
        echo "NOTICE: You have ${pending_status} pending proposal(s) awaiting your review. Use 'ops/feedback-log.sh formalize <P-id>' or 'reject <P-id>'." >&2
      fi
    fi
    ;;

  kudo)
    [[ -z "$ISSUER" ]]      && echo "ERROR: --issuer required" >&2 && exit 1
    [[ -z "$SUBJECT" ]]     && echo "ERROR: --subject required" >&2 && exit 1
    [[ -z "$DOMAIN" ]]      && echo "ERROR: --domain required" >&2 && exit 1
    [[ -z "$DESCRIPTION" ]] && echo "ERROR: --description required" >&2 && exit 1
    [[ -z "$EVIDENCE" ]]    && echo "ERROR: --evidence required" >&2 && exit 1

    local_id=$(next_id "K")
    ts="$(date -u +%Y-%m-%d)"
    local_tier=$(resolve_tier "$ISSUER")

    if ! grep -q "^## ${SUBJECT}$" "$LEDGER" 2>/dev/null; then
      echo "" >> "$LEDGER"
      echo "## ${SUBJECT}" >> "$LEDGER"
    fi

    {
      echo ""
      echo "### ${local_id} [kudo] ${ts} — ${ISSUER} / ${DOMAIN}"
      echo ""
      [[ -n "$ITEM" ]] && echo "**Item:** ${ITEM}"
      echo "**Description:** ${DESCRIPTION}"
      echo "**Evidence:** ${EVIDENCE}"
      echo "**Origin tier:** ${local_tier}"
    } >> "$LEDGER"

    emit_metric reward-issued \
      --type kudo --from "$ISSUER" --subject "$SUBJECT" \
      --scope "$DOMAIN" \
      ${ITEM:+--item "$ITEM"} --reward-id "$local_id"

    update_checksum

    check_tension "kudo" "$SUBJECT" "$ITEM" "$local_id"

    echo "reward_id=$local_id"

    # Nudge: check if issuer has pending proposals to review
    if [[ -f "$LEDGER" ]]; then
      pending_for_issuer=$(grep -c "Supervisor.*${ISSUER}" "$LEDGER" 2>/dev/null || true)
      pending_status=$(grep -B5 "Supervisor.*${ISSUER}" "$LEDGER" 2>/dev/null | grep -c "Status.*pending" || true)
      if [[ "$pending_status" -gt 0 ]]; then
        echo "NOTICE: You have ${pending_status} pending proposal(s) awaiting your review. Use 'ops/feedback-log.sh formalize <P-id>' or 'reject <P-id>'." >&2
      fi
    fi
    ;;

  profile)
    # Read-only: display agent behavioral profile
    [[ -z "$SUBJECT" ]] && echo "Usage: ops/feedback-log.sh profile <agent>" >&2 && exit 1

    if ! grep -q "^## ${SUBJECT}$" "$LEDGER" 2>/dev/null; then
      echo "${SUBJECT}: no behavioral signals recorded"
      exit 0
    fi

    # Count signals (no 'local' — we're in a case block, not a function)
    kudos=$(sed -n "/^## ${SUBJECT}$/,/^## [^#]/p" "$LEDGER" | grep -c "\\[kudo\\]" || true)
    reprimands=$(sed -n "/^## ${SUBJECT}$/,/^## [^#]/p" "$LEDGER" | grep -c "\\[reprimand\\]" || true)
    tensions_count=$(grep -c "Opposing feedback on item .* for ${SUBJECT}" "$LEDGER" 2>/dev/null || true)
    open_tensions=$(grep -A2 "Opposing feedback on item .* for ${SUBJECT}" "$LEDGER" 2>/dev/null | grep -c "Status:\\*\\* open" || true)

    echo "${SUBJECT}: ${kudos} kudos, ${reprimands} reprimands, ${tensions_count} tensions (${open_tensions} open)"

    # By domain
    echo "By domain:"
    sed -n "/^## ${SUBJECT}$/,/^## [^#]/p" "$LEDGER" | \
      grep -o '— [a-zA-Z_-]* / [a-zA-Z_-]*' | sed 's/.* \/ //' | sort | uniq -c | sort -rn | \
      while read -r count domain; do
        echo "  ${domain} (${count})"
      done

    # Recent entries (last 5)
    echo "Recent:"
    sed -n "/^## ${SUBJECT}$/,/^## [^#]/p" "$LEDGER" | \
      grep "^### [RKT]-" | tail -5 | \
      while IFS= read -r line; do
        echo "  ${line#\#\#\# }"
      done

    # Pending proposals
    pending_count=$(sed -n "/^## ${SUBJECT}$/,/^## [^#]/p" "$LEDGER" | grep -c "\\[proposal\\]" || true)
    pending_pending=$(sed -n "/^## ${SUBJECT}$/,/^## [^#]/p" "$LEDGER" | grep -c "Status.*pending" || true)
    if [[ "$pending_count" -gt 0 ]]; then
      echo "Proposals: ${pending_count} total (${pending_pending} pending)"
    fi

    # By origin tier
    echo "By tier:"
    for tier in governance core specialist; do
      tier_count=$(sed -n "/^## ${SUBJECT}$/,/^## [^#]/p" "$LEDGER" | grep -c "Origin tier.*${tier}" || true)
      [[ "$tier_count" -gt 0 ]] && echo "  ${tier} (${tier_count})" || true
    done

    # Weighted summary
    weighted_output=$(compute_weighted_score "$SUBJECT")
    w_net=$(echo "$weighted_output" | grep '^net=' | cut -d= -f2)
    w_kudos=$(echo "$weighted_output" | grep '^kudos=' | cut -d= -f2)
    w_reprimands=$(echo "$weighted_output" | grep '^reprimands=' | cut -d= -f2)
    w_recent=$(echo "$weighted_output" | grep '^recent=' | cut -d= -f2)
    w_signals=$(echo "$weighted_output" | grep '^signals=' | cut -d= -f2)
    echo "Weighted: net=${w_net} (kudos=${w_kudos}, reprimands=${w_reprimands}, ${w_recent} of ${w_signals} recent)"
    ;;

  tensions)
    # Show open tensions, optionally filtered by item
    echo "Open tensions:"
    tension_count=0
    # Read the ledger line by line, track tension headers and their status
    current_tension=""
    while IFS= read -r line; do
      if [[ "$line" =~ ^###\ T-[0-9]+\ \[tension\] ]]; then
        current_tension="$line"
      elif [[ -n "$current_tension" ]] && [[ "$line" == "**Status:** open" ]]; then
        # This tension is open — apply item filter if specified
        if [[ -z "$ITEM" ]] || echo "$current_tension" | grep -q "item-${ITEM}"; then
          echo "  ${current_tension#\#\#\# }"
          tension_count=$((tension_count + 1))
        fi
        current_tension=""
      elif [[ -n "$current_tension" ]] && [[ "$line" =~ ^### ]]; then
        # Hit next entry without finding open status — skip
        current_tension=""
      fi
    done < "$LEDGER"
    if [[ "$tension_count" -eq 0 ]]; then echo "  (none)"; fi
    ;;

  recommend)
    [[ -z "$ISSUER" ]]      && echo "ERROR: --issuer required" >&2 && exit 1
    [[ -z "$SUBJECT" ]]     && echo "ERROR: --subject required" >&2 && exit 1
    [[ -z "$TYPE" ]]        && echo "ERROR: --type required (kudo|reprimand)" >&2 && exit 1
    [[ -z "$DOMAIN" ]]      && echo "ERROR: --domain required" >&2 && exit 1
    [[ -z "$DESCRIPTION" ]] && echo "ERROR: --description required" >&2 && exit 1
    [[ -z "$EVIDENCE" ]]    && echo "ERROR: --evidence required" >&2 && exit 1
    if [[ "$TYPE" == "reprimand" && -z "$SEVERITY" ]]; then
      echo "ERROR: --severity required for reprimand recommendations" >&2; exit 1
    fi

    local_supervisor=$(resolve_supervisor "$ISSUER")
    if [[ -z "$local_supervisor" ]]; then
      echo "ERROR: no feedback pathway or escalation fallback found for issuer '$ISSUER'" >&2; exit 1
    fi

    local_id=$(next_id "P")
    ts="$(date -u +%Y-%m-%d)"
    deadline_days=7
    config="$REPO_ROOT/fleet-config.json"
    if [[ -f "$config" ]] && command -v jq &>/dev/null; then
      deadline_days=$(jq -r '.rewards.escalation_deadline_days // 7' "$config" 2>/dev/null || echo 7)
    fi
    deadline=$(date -u -d "+${deadline_days} days" +%Y-%m-%d 2>/dev/null || date -u -v+${deadline_days}d +%Y-%m-%d 2>/dev/null || echo "unknown")

    if ! grep -q "^## ${SUBJECT}$" "$LEDGER" 2>/dev/null; then
      echo "" >> "$LEDGER"; echo "## ${SUBJECT}" >> "$LEDGER"
    fi

    {
      echo ""
      echo "### ${local_id} [proposal] ${ts} — ${ISSUER} / ${DOMAIN}"
      echo ""
      echo "**Type:** ${TYPE}"
      [[ -n "$SEVERITY" ]] && echo "**Severity:** ${SEVERITY}"
      echo "**Subject:** ${SUBJECT}"
      echo "**Domain:** ${DOMAIN}"
      [[ -n "$ITEM" ]] && echo "**Item:** ${ITEM}"
      echo "**Description:** ${DESCRIPTION}"
      echo "**Evidence:** ${EVIDENCE}"
      echo "**Supervisor:** ${local_supervisor}"
      echo "**Origin tier:** specialist"
      echo "**Status:** pending"
      echo "**Escalation deadline:** ${deadline}"
    } >> "$LEDGER"

    emit_metric feedback-proposed \
      --from "$ISSUER" --subject "$SUBJECT" --type "$TYPE" \
      --scope "$DOMAIN" --severity "$SEVERITY" \
      ${ITEM:+--item "$ITEM"} --proposal "$local_id" \
      --to "$local_supervisor"

    update_checksum
    echo "proposal_id=$local_id"
    ;;

  formalize)
    [[ -z "$ISSUER" ]]  && echo "ERROR: --issuer required" >&2 && exit 1

    # Extract P-id from SUBJECT if it looks like a proposal ID
    local_pid=""
    if [[ -n "$SUBJECT" && "$SUBJECT" =~ ^P-[0-9]+ ]]; then
      local_pid="$SUBJECT"
      SUBJECT=""
    fi
    [[ -z "$local_pid" ]] && echo "ERROR: proposal ID (e.g. P-001) required as first positional argument" >&2 && exit 1

    # Validate proposal exists
    if ! grep -q "^### ${local_pid} \[proposal\]" "$LEDGER" 2>/dev/null; then
      echo "ERROR: proposal ${local_pid} not found in ledger" >&2; exit 1
    fi

    # Validate status is pending (prefix match handles "pending (escalated...)")
    prop_status=$(read_proposal_field "$local_pid" "Status")
    if [[ ! "$prop_status" =~ ^pending ]]; then
      echo "ERROR: proposal ${local_pid} is not pending (status: ${prop_status})" >&2; exit 1
    fi

    # Validate issuer matches supervisor
    prop_supervisor=$(read_proposal_field "$local_pid" "Supervisor")
    if [[ "$ISSUER" != "$prop_supervisor" ]]; then
      echo "ERROR: issuer '${ISSUER}' is not the supervisor for ${local_pid} (supervisor: ${prop_supervisor})" >&2; exit 1
    fi

    # Read proposal fields
    prop_type=$(read_proposal_field "$local_pid" "Type")
    prop_subject=$(read_proposal_field "$local_pid" "Subject")
    prop_domain=$(read_proposal_field "$local_pid" "Domain")
    prop_severity=$(read_proposal_field "$local_pid" "Severity")
    prop_item=$(read_proposal_field "$local_pid" "Item")
    prop_description=$(read_proposal_field "$local_pid" "Description")
    prop_evidence=$(read_proposal_field "$local_pid" "Evidence")

    ts="$(date -u +%Y-%m-%d)"
    local_tier=$(resolve_tier "$ISSUER")

    # Determine new entry prefix
    if [[ "$prop_type" == "kudo" ]]; then
      local_id=$(next_id "K")
      entry_type="kudo"
    else
      local_id=$(next_id "R")
      entry_type="reprimand"
    fi

    # Ensure subject section exists
    if ! grep -q "^## ${prop_subject}$" "$LEDGER" 2>/dev/null; then
      echo "" >> "$LEDGER"; echo "## ${prop_subject}" >> "$LEDGER"
    fi

    # Append formalized entry
    {
      echo ""
      echo "### ${local_id} [${entry_type}] ${ts} — ${ISSUER} / ${prop_domain}"
      echo ""
      [[ -n "$prop_severity" ]] && echo "**Severity:** ${prop_severity}"
      [[ -n "$prop_item" ]] && echo "**Item:** ${prop_item}"
      echo "**Description:** ${prop_description}"
      echo "**Evidence:** ${prop_evidence}"
      echo "**Origin:** ${local_pid}"
      echo "**Origin tier:** specialist"
    } >> "$LEDGER"

    # Update proposal status
    update_proposal_status "$local_pid" "formalized (${local_id})"

    emit_metric feedback-formalized \
      --from "$ISSUER" --subject "$prop_subject" --type "$prop_type" \
      --proposal "$local_pid" --reward-id "$local_id"

    update_checksum

    # Check for tension on the new entry
    check_tension "$entry_type" "$prop_subject" "$prop_item" "$local_id"

    echo "reward_id=$local_id"
    ;;

  reject)
    [[ -z "$ISSUER" ]] && echo "ERROR: --issuer required" >&2 && exit 1
    [[ -z "$REASON" ]] && echo "ERROR: --reason required for reject" >&2 && exit 1

    # Extract P-id from SUBJECT if it looks like a proposal ID
    local_pid=""
    if [[ -n "$SUBJECT" && "$SUBJECT" =~ ^P-[0-9]+ ]]; then
      local_pid="$SUBJECT"
      SUBJECT=""
    fi
    [[ -z "$local_pid" ]] && echo "ERROR: proposal ID (e.g. P-001) required as first positional argument" >&2 && exit 1

    # Validate proposal exists
    if ! grep -q "^### ${local_pid} \[proposal\]" "$LEDGER" 2>/dev/null; then
      echo "ERROR: proposal ${local_pid} not found in ledger" >&2; exit 1
    fi

    # Update proposal status
    update_proposal_status "$local_pid" "rejected — ${REASON}"

    emit_metric feedback-rejected \
      --from "$ISSUER" --proposal "$local_pid"

    update_checksum
    echo "proposal_id=$local_pid"
    ;;

  check-escalations)
    today="$(date -u +%Y-%m-%d)"
    current_pid=""
    current_deadline=""
    current_supervisor=""
    current_is_pending=""
    escalated_count=0

    do_escalate() {
      local esc_pid="$1" esc_deadline="$2" esc_supervisor="$3"
      [[ -z "$esc_pid" || -z "$esc_deadline" || -z "$esc_supervisor" ]] && return
      if [[ "$esc_deadline" < "$today" || "$esc_deadline" == "$today" ]]; then
        new_supervisor=$(resolve_escalation_target "$esc_supervisor")
        new_deadline=$(date -u -d "+7 days" +%Y-%m-%d 2>/dev/null || date -u -v+7d +%Y-%m-%d 2>/dev/null || echo "unknown")
        new_status="pending (escalated from ${esc_supervisor})"

        esc_new_sup="$new_supervisor"
        esc_new_deadline="$new_deadline"
        esc_new_status="$new_status"
        tmpfile=$(mktemp)
        awk -v pid="### ${esc_pid} " \
            -v new_sup="$esc_new_sup" \
            -v new_dl="$esc_new_deadline" \
            -v new_st="$esc_new_status" '
          $0 ~ pid { in_entry=1 }
          in_entry && /^\*\*Supervisor:\*\*/ { print "**Supervisor:** " new_sup; next }
          in_entry && /^\*\*Escalation deadline:\*\*/ { print "**Escalation deadline:** " new_dl; next }
          in_entry && /^\*\*Status:\*\*/ { print "**Status:** " new_st; in_entry=0; next }
          in_entry && /^### / && !($0 ~ pid) { in_entry=0 }
          { print }
        ' "$LEDGER" > "$tmpfile" && mv "$tmpfile" "$LEDGER"

        if [[ -f "$FINDINGS" ]]; then
          esc_finding="### [${today}] normal -- Feedback proposal ${esc_pid} escalated to ${esc_new_sup}

**Found by:** feedback-system (auto)
**Category:** escalation
**Description:** Proposal ${esc_pid} deadline passed without action by ${esc_supervisor}. Escalated to ${esc_new_sup}.
**Proposed action:** ${esc_new_sup} to review and formalize or reject within 7 days
**Status:** open"

          if grep -q "^(none yet)" "$FINDINGS"; then
            tmpfile2=$(mktemp)
            awk -v entry="$esc_finding" '{
              if ($0 == "(none yet)") { print entry } else { print }
            }' "$FINDINGS" > "$tmpfile2" && mv "$tmpfile2" "$FINDINGS"
          elif grep -q "^## Resolved Findings" "$FINDINGS"; then
            tmpfile2=$(mktemp)
            awk -v entry="$esc_finding" '{
              if ($0 == "## Resolved Findings") { print ""; print entry; print "" }
              print
            }' "$FINDINGS" > "$tmpfile2" && mv "$tmpfile2" "$FINDINGS"
          else
            echo "" >> "$FINDINGS"
            echo "$esc_finding" >> "$FINDINGS"
          fi
        fi

        emit_metric feedback-escalated \
          --proposal "$esc_pid" --from "$esc_supervisor" --to "$esc_new_sup"

        escalated_count=$((escalated_count + 1))
      fi
    }

    while IFS= read -r line; do
      # Track proposal entry headers
      if [[ "$line" =~ ^###\ (P-[0-9]+)\ \[proposal\] ]]; then
        # Flush previous pending entry if fully collected
        if [[ -n "$current_pid" && -n "$current_is_pending" ]]; then
          do_escalate "$current_pid" "$current_deadline" "$current_supervisor"
        fi
        current_pid="${BASH_REMATCH[1]}"
        current_deadline=""
        current_supervisor=""
        current_is_pending=""
      elif [[ -n "$current_pid" && "$line" =~ ^\*\*Escalation\ deadline:\*\*\ (.*) ]]; then
        current_deadline="${BASH_REMATCH[1]}"
      elif [[ -n "$current_pid" && "$line" =~ ^\*\*Supervisor:\*\*\ (.*) ]]; then
        current_supervisor="${BASH_REMATCH[1]}"
      elif [[ -n "$current_pid" && "$line" =~ ^\*\*Status:\*\*\  ]]; then
        if [[ "$line" =~ ^\*\*Status:\*\*\ pending ]]; then
          current_is_pending="1"
        else
          # Not pending — skip this entry
          current_pid=""
        fi
      fi
    done < "$LEDGER"

    # Flush the last pending entry (no subsequent header to trigger flush)
    if [[ -n "$current_pid" && -n "$current_is_pending" ]]; then
      do_escalate "$current_pid" "$current_deadline" "$current_supervisor"
    fi

    update_checksum
    echo "escalated=${escalated_count}"
    ;;

  score)
    [[ -z "$SUBJECT" ]] && echo "Usage: ops/feedback-log.sh score <agent>" >&2 && exit 1
    compute_weighted_score "$SUBJECT"
    ;;

  *)
    echo "ERROR: Unknown subcommand '$SUBCOMMAND'" >&2
    echo "Valid: reprimand, kudo, recommend, formalize, reject, check-escalations, profile, tensions, score" >&2
    exit 1
    ;;
esac
