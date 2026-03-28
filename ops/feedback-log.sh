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
#   ops/feedback-log.sh tensions [--item <id>]
#
# Env vars (for testing — defaults to repo paths):
#   FEEDBACK_LEDGER    Override ledger path (also accepts REWARDS_LEDGER for backward compat)
#   FEEDBACK_CHECKSUM  Override checksum path (also accepts REWARDS_CHECKSUM for backward compat)
#   FINDINGS_REGISTER  Override findings register path
#   METRICS_LOG_FILE   Override metrics log path
# ---------------------------------------------------------------------------

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

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
ISSUER="" SUBJECT="" DOMAIN="" SEVERITY="" ITEM="" DESCRIPTION="" EVIDENCE=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --issuer)      ISSUER="$2";      shift 2 ;;
    --subject)     SUBJECT="$2";     shift 2 ;;
    --domain)      DOMAIN="$2";      shift 2 ;;
    --severity)    SEVERITY="$2";    shift 2 ;;
    --item)        ITEM="$2";        shift 2 ;;
    --description) DESCRIPTION="$2"; shift 2 ;;
    --evidence)    EVIDENCE="$2";    shift 2 ;;
    *) # Positional (used by profile/tensions)
       if [[ -z "$SUBJECT" ]]; then SUBJECT="$1"; fi
       shift ;;
  esac
done

# ── Helpers ──────────────────────────────────────────────────────────────

update_checksum() {
  sha256sum "$LEDGER" > "$CHECKSUM"
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
  "$SCRIPT_DIR/metrics-log.sh" tension-detected \
    --description "${first_id},${second_id}" \
    --item "$new_item" --subject "$new_subject" 2>/dev/null || true

  update_checksum
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
    } >> "$LEDGER"

    # Emit metric event
    "$SCRIPT_DIR/metrics-log.sh" reward-issued \
      --type reprimand --from "$ISSUER" --subject "$SUBJECT" \
      --scope "$DOMAIN" --severity "$SEVERITY" \
      ${ITEM:+--item "$ITEM"} --reward-id "$local_id" 2>/dev/null || true

    update_checksum

    # Check for tension
    check_tension "reprimand" "$SUBJECT" "$ITEM" "$local_id"

    echo "reward_id=$local_id"
    ;;

  kudo)
    [[ -z "$ISSUER" ]]      && echo "ERROR: --issuer required" >&2 && exit 1
    [[ -z "$SUBJECT" ]]     && echo "ERROR: --subject required" >&2 && exit 1
    [[ -z "$DOMAIN" ]]      && echo "ERROR: --domain required" >&2 && exit 1
    [[ -z "$DESCRIPTION" ]] && echo "ERROR: --description required" >&2 && exit 1
    [[ -z "$EVIDENCE" ]]    && echo "ERROR: --evidence required" >&2 && exit 1

    local_id=$(next_id "K")
    ts="$(date -u +%Y-%m-%d)"

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
    } >> "$LEDGER"

    "$SCRIPT_DIR/metrics-log.sh" reward-issued \
      --type kudo --from "$ISSUER" --subject "$SUBJECT" \
      --scope "$DOMAIN" \
      ${ITEM:+--item "$ITEM"} --reward-id "$local_id" 2>/dev/null || true

    update_checksum

    check_tension "kudo" "$SUBJECT" "$ITEM" "$local_id"

    echo "reward_id=$local_id"
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

  *)
    echo "ERROR: Unknown subcommand '$SUBCOMMAND'" >&2
    echo "Valid: reprimand, kudo, recommend, formalize, reject, check-escalations, profile, tensions" >&2
    exit 1
    ;;
esac
