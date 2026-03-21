#!/usr/bin/env bash
set -euo pipefail

# ---------------------------------------------------------------------------
# compile-floor.sh — Compliance floor compiler
#
# Extracts ```enforcement blocks from a Markdown compliance floor file,
# validates them, and (in future tasks) generates hook configuration.
#
# Usage:
#   compile-floor.sh [options] [floor-file] [output-dir]
#
# Options:
#   --dry-run         Show what would be done without writing files (planned)
#   --verify          Verify artifacts against manifest.sha256 (exit 0=clean, 1=drift)
#   --extract-only    Extract blocks and write YAML files, then stop
#   --proposal <id>   Set proposal ID embedded in manifest (full compile mode)
#
# Defaults:
#   floor-file  compliance-floor.md
#   output-dir  .claude/compliance/compiled
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# Defaults
# ---------------------------------------------------------------------------

FLOOR_FILE="compliance-floor.md"
OUTPUT_DIR=".claude/compliance/compiled"
MODE=""
PROPOSAL_ID=""

# ---------------------------------------------------------------------------
# Arg parsing
# ---------------------------------------------------------------------------

POSITIONAL=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)
      MODE="dry-run"
      shift
      ;;
    --verify)
      MODE="verify"
      shift
      ;;
    --extract-only)
      MODE="extract-only"
      shift
      ;;
    --proposal)
      PROPOSAL_ID="$2"
      shift 2
      ;;
    --validate-only)
      MODE="validate-only"
      shift
      ;;
    --prose-only)
      MODE="prose-only"
      shift
      ;;
    --generate-enforce)
      MODE="generate-enforce"
      shift
      ;;
    --*)
      echo "ERROR: Unknown option: $1" >&2
      exit 1
      ;;
    *)
      POSITIONAL+=("$1")
      shift
      ;;
  esac
done

# Positional: floor-file then output-dir
if [[ ${#POSITIONAL[@]} -ge 1 ]]; then
  FLOOR_FILE="${POSITIONAL[0]}"
fi
if [[ ${#POSITIONAL[@]} -ge 2 ]]; then
  OUTPUT_DIR="${POSITIONAL[1]}"
fi

# Default mode if none specified
if [[ -z "${MODE}" ]]; then
  MODE="compile"
fi

# ---------------------------------------------------------------------------
# Dependency check
# ---------------------------------------------------------------------------

if ! command -v yq &>/dev/null; then
  echo "ERROR: yq is required but not installed." >&2
  echo "Install with: brew install yq  OR  snap install yq" >&2
  exit 2
fi

# ---------------------------------------------------------------------------
# extract_blocks — parse enforcement fences from a Markdown file
#
# Arguments:
#   $1  input Markdown file
#   $2  output directory (must exist)
#
# Writes block-NNN.yaml files (zero-padded 3 digits) to $2.
# Prints the number of blocks extracted on stdout.
# Exits 2 on unclosed fence.
# ---------------------------------------------------------------------------

extract_blocks() {
  local input_file="$1"
  local out_dir="$2"

  local in_block=0
  local block_num=0
  local current_block=""

  while IFS= read -r line || [[ -n "${line}" ]]; do
    if [[ "${in_block}" -eq 0 ]]; then
      # Look for opening enforcement fence
      if [[ "${line}" == '```enforcement' ]]; then
        in_block=1
        current_block=""
      fi
    else
      # Inside a block — look for closing fence
      if [[ "${line}" == '```' ]]; then
        # Close the block
        in_block=0
        block_num=$((block_num + 1))
        local padded
        padded=$(printf "%03d" "${block_num}")
        printf '%s\n' "${current_block}" > "${out_dir}/block-${padded}.yaml"
      else
        # Accumulate block content
        if [[ -n "${current_block}" ]]; then
          current_block="${current_block}"$'\n'"${line}"
        else
          current_block="${line}"
        fi
      fi
    fi
  done < "${input_file}"

  # Detect unclosed block
  if [[ "${in_block}" -eq 1 ]]; then
    echo "ERROR: Unclosed enforcement block in ${input_file}" >&2
    exit 2
  fi

  echo "${block_num}"
}

# ---------------------------------------------------------------------------
# validate_block — validate a single enforcement block YAML file
#
# Arguments:
#   $1  path to block YAML file
#
# Returns 0 on valid.
# Prints error to stderr and exits 2 on invalid.
# ---------------------------------------------------------------------------

validate_block() {
  local block_file="$1"
  local block_name
  block_name="$(basename "${block_file}")"
  local valid=1

  # Check: version exists and equals 1
  local version
  version="$(yq '.version' "${block_file}")"
  if [[ "${version}" == "null" || -z "${version}" ]]; then
    echo "INVALID ${block_name}: missing required field 'version'" >&2
    valid=0
  elif [[ "${version}" != "1" ]]; then
    echo "INVALID ${block_name}: 'version' must be 1, got ${version}" >&2
    valid=0
  fi

  # Check: id exists and is non-empty
  local id
  id="$(yq '.id' "${block_file}")"
  if [[ "${id}" == "null" || -z "${id}" || "${id}" == '""' ]]; then
    echo "INVALID ${block_name}: missing or empty 'id' field" >&2
    valid=0
  fi

  # Check: severity is 'blocking' or 'warning'
  local severity
  severity="$(yq '.severity' "${block_file}")"
  # Remove surrounding quotes if present
  severity="${severity//\"/}"
  if [[ "${severity}" != "blocking" && "${severity}" != "warning" ]]; then
    echo "INVALID ${block_name}: 'severity' must be 'blocking' or 'warning', got '${severity}'" >&2
    valid=0
  fi

  # Check: no forbidden top-level keys (bypass, skip, override)
  local bypass skip override
  bypass="$(yq '.bypass' "${block_file}")"
  skip="$(yq '.skip' "${block_file}")"
  override="$(yq '.override' "${block_file}")"
  if [[ "${bypass}" != "null" ]]; then
    echo "INVALID ${block_name}: forbidden top-level field 'bypass' is present" >&2
    valid=0
  fi
  if [[ "${skip}" != "null" ]]; then
    echo "INVALID ${block_name}: forbidden top-level field 'skip' is present" >&2
    valid=0
  fi
  if [[ "${override}" != "null" ]]; then
    echo "INVALID ${block_name}: forbidden top-level field 'override' is present" >&2
    valid=0
  fi

  # Check: at least one pre-tool-use or post-tool-use enforcement point under enforce
  local pre_hook post_hook
  pre_hook="$(yq '.enforce."pre-tool-use"' "${block_file}")"
  post_hook="$(yq '.enforce."post-tool-use"' "${block_file}")"
  if [[ "${pre_hook}" == "null" && "${post_hook}" == "null" ]]; then
    echo "INVALID ${block_name}: 'enforce' must contain at least one 'pre-tool-use' or 'post-tool-use' point" >&2
    valid=0
  fi

  # Check: severity/action contradiction
  # warning + block → reject; blocking + warn → reject
  local severity_clean="${severity}"
  local enforce_keys
  enforce_keys="$(yq '.enforce | keys | .[]' "${block_file}" 2>/dev/null || true)"
  while IFS= read -r ekey; do
    # Strip surrounding quotes
    ekey="${ekey//\"/}"
    local action
    action="$(yq ".enforce.\"${ekey}\".action" "${block_file}")"
    action="${action//\"/}"
    if [[ "${action}" == "null" || -z "${action}" ]]; then
      continue
    fi
    if [[ "${severity_clean}" == "warning" && "${action}" == "block" ]]; then
      echo "INVALID ${block_name}: contradiction — severity 'warning' with action 'block' at enforcement point '${ekey}'" >&2
      valid=0
    fi
    if [[ "${severity_clean}" == "blocking" && "${action}" == "warn" ]]; then
      echo "INVALID ${block_name}: contradiction — severity 'blocking' with action 'warn' at enforcement point '${ekey}'" >&2
      valid=0
    fi
  done <<< "${enforce_keys}"

  # Check: if rule-path is specified, the file must exist
  local rule_path
  rule_path="$(yq '.["rule-path"]' "${block_file}" 2>/dev/null || echo "null")"
  rule_path="${rule_path//\"/}"
  if [[ "${rule_path}" != "null" && -n "${rule_path}" ]]; then
    if [[ ! -f "${rule_path}" ]]; then
      echo "INVALID ${block_name}: 'rule-path' file does not exist: ${rule_path}" >&2
      valid=0
    fi
  fi

  if [[ "${valid}" -eq 0 ]]; then
    exit 2
  fi
  return 0
}

# ---------------------------------------------------------------------------
# generate_prose — strip enforcement blocks and write a prose-only floor file
#
# Arguments:
#   $1  input Markdown file
#   $2  output directory (must exist)
#
# Writes compliance-floor.prose.md to $2 with a generated artifact header.
# Enforcement fences (```enforcement ... ```) are removed entirely.
# ---------------------------------------------------------------------------

generate_prose() {
  local input_file="$1"
  local out_dir="$2"
  local out_file="${out_dir}/compliance-floor.prose.md"

  local in_block=0

  {
    printf '# GENERATED by ops/compile-floor.sh from compliance-floor.md\n'
    printf '# Do not edit — changes will be overwritten. Proposal: <id>\n'

    while IFS= read -r line || [[ -n "${line}" ]]; do
      if [[ "${in_block}" -eq 0 ]]; then
        if [[ "${line}" == '```enforcement' ]]; then
          in_block=1
        else
          printf '%s\n' "${line}"
        fi
      else
        if [[ "${line}" == '```' ]]; then
          in_block=0
        fi
        # Skip all content inside enforcement blocks (including fence lines)
      fi
    done < "${input_file}"
  } > "${out_file}"
}

# ---------------------------------------------------------------------------
# generate_enforce — generate enforce.sh dispatcher script from validated blocks
#
# Arguments:
#   $1  output directory (must exist, contains block-NNN.yaml files)
#
# Writes enforce.sh to $1 and makes it executable.
# ---------------------------------------------------------------------------

generate_enforce() {
  local out_dir="$1"
  local out_file="${out_dir}/enforce.sh"

  # Collect rules by enforcement point
  local pre_rules=""
  local post_rules=""

  for block_file in "${out_dir}"/block-*.yaml; do
    [[ -f "${block_file}" ]] || continue

    local rule_id
    rule_id="$(yq '.id' "${block_file}")"
    rule_id="${rule_id//\"/}"

    local severity
    severity="$(yq '.severity' "${block_file}")"
    severity="${severity//\"/}"

    # Check pre-tool-use
    local pre_type
    pre_type="$(yq '.enforce."pre-tool-use".type' "${block_file}")"
    pre_type="${pre_type//\"/}"
    if [[ "${pre_type}" != "null" && -n "${pre_type}" ]]; then
      local pre_action
      pre_action="$(yq '.enforce."pre-tool-use".action' "${block_file}")"
      pre_action="${pre_action//\"/}"

      # Collect patterns (unescape yq's double-backslash output)
      local pre_patterns=""
      while IFS= read -r pat; do
        pat="${pat//\"/}"
        pat="${pat//\'/}"
        pat="${pat//\\\\/\\}"
        if [[ -n "${pre_patterns}" ]]; then
          pre_patterns="${pre_patterns}|${pat}"
        else
          pre_patterns="${pat}"
        fi
      done < <(yq '.enforce."pre-tool-use".patterns[]' "${block_file}")

      local exit_code=1
      if [[ "${pre_action}" == "block" ]]; then
        exit_code=2
      fi

      local func_name="check_${rule_id//-/_}"
      pre_rules="${pre_rules}
# Rule: ${rule_id} (${severity}, ${pre_action})
${func_name}() {
  local file_path=\"\$1\"
  if echo \"\${file_path}\" | grep -qE '${pre_patterns}'; then
    log_violation \"${rule_id}\" \"${pre_action}\" \"pre-tool-use\" \"\${file_path}\"
    return ${exit_code}
  fi
  return 0
}
"
    fi

    # Check post-tool-use
    local post_type
    post_type="$(yq '.enforce."post-tool-use".type' "${block_file}")"
    post_type="${post_type//\"/}"
    if [[ "${post_type}" != "null" && -n "${post_type}" ]]; then
      local post_action
      post_action="$(yq '.enforce."post-tool-use".action' "${block_file}")"
      post_action="${post_action//\"/}"

      # Collect patterns (unescape yq's double-backslash output)
      local post_patterns=""
      while IFS= read -r pat; do
        pat="${pat//\"/}"
        pat="${pat//\'/}"
        pat="${pat//\\\\/\\}"
        if [[ -n "${post_patterns}" ]]; then
          post_patterns="${post_patterns}|${pat}"
        else
          post_patterns="${pat}"
        fi
      done < <(yq '.enforce."post-tool-use".patterns[]' "${block_file}")

      local exit_code=1
      if [[ "${post_action}" == "block" ]]; then
        exit_code=2
      fi

      local func_name="check_${rule_id//-/_}"
      post_rules="${post_rules}
# Rule: ${rule_id} (${severity}, ${post_action})
${func_name}() {
  local file_path=\"\$1\"
  if [[ -f \"\${file_path}\" ]] && grep -qE '${post_patterns}' \"\${file_path}\"; then
    log_violation \"${rule_id}\" \"${post_action}\" \"post-tool-use\" \"\${file_path}\"
    return ${exit_code}
  fi
  return 0
}
"
    fi
  done

  # Write the enforce.sh script
  cat > "${out_file}" <<'ENFORCE_HEADER'
#!/usr/bin/env bash
set -euo pipefail

# GENERATED by ops/compile-floor.sh — do not edit manually.
# Re-generate with: ops/compile-floor.sh --generate-enforce

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

log_violation() {
  local rule_id="$1"
  local action="$2"
  local point="$3"
  local file_path="$4"
  # Graceful no-op if metrics-log.sh doesn't support compliance-violation yet
  if [[ -x "${SCRIPT_DIR}/../../ops/metrics-log.sh" ]]; then
    "${SCRIPT_DIR}/../../ops/metrics-log.sh" compliance-violation \
      --rule "${rule_id}" --action "${action}" --point "${point}" \
      --file "${file_path}" 2>/dev/null || true
  fi
}

log_pass() {
  local rule_id="$1"
  local point="$2"
  local file_path="$3"
  # Check fleet-config.json for signal-passes flag
  local config="${SCRIPT_DIR}/../../fleet-config.json"
  local signal_passes="false"
  if [[ -f "${config}" ]] && command -v jq &>/dev/null; then
    signal_passes="$(jq -r '.compliance."signal-passes" // false' "${config}" 2>/dev/null || echo "false")"
  fi
  if [[ "${signal_passes}" == "true" ]]; then
    if [[ -x "${SCRIPT_DIR}/../../ops/metrics-log.sh" ]]; then
      "${SCRIPT_DIR}/../../ops/metrics-log.sh" compliance-pass \
        --rule "${rule_id}" --point "${point}" \
        --file "${file_path}" 2>/dev/null || true
    fi
  fi
}

ENFORCE_HEADER

  # Write pre-tool-use checks
  cat >> "${out_file}" <<ENFORCE_PRE
# ---------------------------------------------------------------------------
# pre-tool-use checks
# ---------------------------------------------------------------------------
${pre_rules}
ENFORCE_PRE

  # Write post-tool-use checks
  cat >> "${out_file}" <<ENFORCE_POST
# ---------------------------------------------------------------------------
# post-tool-use checks
# ---------------------------------------------------------------------------
${post_rules}
ENFORCE_POST

  # Write dispatcher
  cat >> "${out_file}" <<'ENFORCE_DISPATCH'
# ---------------------------------------------------------------------------
# Dispatcher
# ---------------------------------------------------------------------------

dispatch() {
  local point="$1"
  local file_path="$2"
  local max_exit=0
  local rc=0

  case "${point}" in
    pre-tool-use)
      # Intent declaration — compliance surface area
      FILE_PATH="${file_path}"
      case "${FILE_PATH}" in
        compliance-floor.md|*/compliance-floor.md)
          # Sentinel-gated: BLOCK without sentinel, WARN with sentinel
          if [ -f .claude/compliance/.applying ]; then
            echo "WARN: Compliance modification: ${FILE_PATH} (sentinel active)"
            exit 1
          else
            echo "BLOCKED: Compliance floor protected. Use /compliance propose."
            exit 2
          fi
          ;;
        .claude/compliance/compiled/*|*/.claude/compliance/compiled/*)
          echo "WARN: This is generated by ops/compile-floor.sh. Manual edits will be overwritten."
          exit 1
          ;;
        .claude/compliance/*|*/.claude/compliance/*)
          # Sentinel-gated
          if [ -f .claude/compliance/.applying ]; then
            echo "WARN: Compliance modification: ${FILE_PATH} (sentinel active)"
            exit 1
          else
            echo "BLOCKED: Compliance file protected. Use /compliance propose."
            exit 2
          fi
          ;;
        ops/compile-floor.sh|*/ops/compile-floor.sh)
          echo "WARN: This modifies the compliance compiler. Changes affect all rule enforcement."
          exit 1
          ;;
        .claude/agents/compliance-officer.md|*/.claude/agents/compliance-officer.md|\
.claude/agents/compliance-auditor.md|*/.claude/agents/compliance-auditor.md)
          echo "WARN: This modifies a compliance agent's instructions."
          exit 1
          ;;
      esac
ENFORCE_DISPATCH

  # Add pre-tool-use function calls
  for block_file in "${out_dir}"/block-*.yaml; do
    [[ -f "${block_file}" ]] || continue
    local pre_type
    pre_type="$(yq '.enforce."pre-tool-use".type' "${block_file}")"
    pre_type="${pre_type//\"/}"
    if [[ "${pre_type}" != "null" && -n "${pre_type}" ]]; then
      local rule_id
      rule_id="$(yq '.id' "${block_file}")"
      rule_id="${rule_id//\"/}"
      local func_name="check_${rule_id//-/_}"
      printf '      rc=0; %s "${file_path}" || rc=$?\n' "${func_name}" >> "${out_file}"
      printf '      [[ ${rc} -gt ${max_exit} ]] && max_exit=${rc}\n' >> "${out_file}"
    fi
  done

  cat >> "${out_file}" <<'ENFORCE_MID'
      ;;
    post-tool-use)
ENFORCE_MID

  # Add post-tool-use function calls
  for block_file in "${out_dir}"/block-*.yaml; do
    [[ -f "${block_file}" ]] || continue
    local post_type
    post_type="$(yq '.enforce."post-tool-use".type' "${block_file}")"
    post_type="${post_type//\"/}"
    if [[ "${post_type}" != "null" && -n "${post_type}" ]]; then
      local rule_id
      rule_id="$(yq '.id' "${block_file}")"
      rule_id="${rule_id//\"/}"
      local func_name="check_${rule_id//-/_}"
      printf '      rc=0; %s "${file_path}" || rc=$?\n' "${func_name}" >> "${out_file}"
      printf '      [[ ${rc} -gt ${max_exit} ]] && max_exit=${rc}\n' >> "${out_file}"
    fi
  done

  cat >> "${out_file}" <<'ENFORCE_TAIL'
      ;;
    *)
      echo "ERROR: Unknown enforcement point: ${point}" >&2
      exit 1
      ;;
  esac

  # Log pass if no violations
  if [[ ${max_exit} -eq 0 ]]; then
    log_pass "all" "${point}" "${file_path}"
  fi

  exit ${max_exit}
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

if [[ $# -lt 2 ]]; then
  echo "Usage: enforce.sh <enforcement-point> <file-path>" >&2
  exit 1
fi

dispatch "$1" "$2"
ENFORCE_TAIL

  chmod +x "${out_file}"
}

# ---------------------------------------------------------------------------
# generate_coverage — write a Markdown coverage report
#
# Arguments:
#   $1  input floor file (to count prose rules)
#   $2  output directory (contains block-NNN.yaml files)
#
# Reads COVERAGE_PATH env var (default: docs/compliance-coverage.md).
# Writes the coverage report to COVERAGE_PATH.
# ---------------------------------------------------------------------------

generate_coverage() {
  local floor_file="$1"
  local out_dir="$2"
  local coverage_path="${COVERAGE_PATH:-docs/compliance-coverage.md}"

  # Count total rules in prose by counting numbered rule headings: "N. **..." or "### Rule N"
  # We look for lines like "### Rule N" or "**No ..." preceded by a number in the heading
  # The fixture uses "### Rule N" headings — count those
  local total_rules
  total_rules=$(grep -cE '^### Rule [0-9]+' "${floor_file}" 2>/dev/null || echo "0")
  # Fallback: also try "^[0-9]+\. \*\*" numbered list style
  if [[ "${total_rules}" -eq 0 ]]; then
    total_rules=$(grep -cE '^[0-9]+\. \*\*' "${floor_file}" 2>/dev/null || echo "0")
  fi

  # Count enforcement blocks
  local block_count=0
  for block_file in "${out_dir}"/block-*.yaml; do
    [[ -f "${block_file}" ]] || continue
    block_count=$((block_count + 1))
  done

  local judgment_count=$(( total_rules - block_count ))
  if [[ "${judgment_count}" -lt 0 ]]; then
    judgment_count=0
  fi

  # Ensure parent directory exists
  mkdir -p "$(dirname "${coverage_path}")"

  {
    printf '# GENERATED by ops/compile-floor.sh from compliance-floor.md\n'
    printf '# Do not edit — changes will be overwritten.\n'
    printf '\n'
    printf '# Compliance Coverage Report\n'
    printf '\n'
    printf '| Rule ID | Severity | Enforcement Points | Check Types | Status |\n'
    printf '|---------|----------|--------------------|-------------|--------|\n'

    # Rows for enforced blocks
    for block_file in "${out_dir}"/block-*.yaml; do
      [[ -f "${block_file}" ]] || continue

      local rule_id
      rule_id="$(yq '.id' "${block_file}")"
      rule_id="${rule_id//\"/}"

      local severity
      severity="$(yq '.severity' "${block_file}")"
      severity="${severity//\"/}"

      # Collect enforcement points and check types
      local enf_points=""
      local check_types=""

      local pre_type
      pre_type="$(yq '.enforce."pre-tool-use".type' "${block_file}")"
      pre_type="${pre_type//\"/}"
      if [[ "${pre_type}" != "null" && -n "${pre_type}" ]]; then
        enf_points="${enf_points:+${enf_points}, }pre-tool-use"
        check_types="${check_types:+${check_types}, }${pre_type}"
      fi

      local post_type
      post_type="$(yq '.enforce."post-tool-use".type' "${block_file}")"
      post_type="${post_type//\"/}"
      if [[ "${post_type}" != "null" && -n "${post_type}" ]]; then
        enf_points="${enf_points:+${enf_points}, }post-tool-use"
        check_types="${check_types:+${check_types}, }${post_type}"
      fi

      printf '| %s | %s | %s | %s | covered |\n' \
        "${rule_id}" "${severity}" "${enf_points}" "${check_types}"
    done

    # Rows for judgment-only rules (rules without enforcement blocks)
    # We identify them by scanning the floor file for rule IDs not present in blocks
    # Since we don't have IDs for prose-only rules, we emit placeholder rows
    local i
    for (( i = 1; i <= judgment_count; i++ )); do
      printf '| (prose-only-%d) | — | — | — | judgment-only |\n' "${i}"
    done

    printf '\n'
    printf '## What Each Layer Guarantees\n'
    printf '\n'
    printf '%s\n' "- **covered**: Rule has automated enforcement via hook checks at one or more enforcement points."
    printf '%s\n' "- **judgment-only**: Rule is enforced through human review and design judgment only — no automated check exists."
    printf '\n'
    printf '## Summary\n'
    printf '\n'
    printf '%s\n' "- Total rules: ${total_rules}"
    printf '%s\n' "- Covered by automation: ${block_count}"
    printf '%s\n' "- judgment-only (human review): ${judgment_count}"
  } > "${coverage_path}"
}

# ---------------------------------------------------------------------------
# generate_manifest — write manifest.sha256 for staleness detection
#
# Arguments:
#   $1  input floor file (source)
#   $2  output directory (must contain compiled artifacts)
#   $3  proposal ID (may be empty)
#
# Writes manifest.sha256 to $2.
# ---------------------------------------------------------------------------

generate_manifest() {
  local floor_file="$1"
  local out_dir="$2"
  local proposal_id="${3:-}"

  local source_hash
  source_hash="$(sha256sum "${floor_file}" | cut -d' ' -f1)"

  local prose_hash=""
  if [[ -f "${out_dir}/compliance-floor.prose.md" ]]; then
    prose_hash="$(sha256sum "${out_dir}/compliance-floor.prose.md" | cut -d' ' -f1)"
  fi

  local enforce_hash=""
  if [[ -f "${out_dir}/enforce.sh" ]]; then
    enforce_hash="$(sha256sum "${out_dir}/enforce.sh" | cut -d' ' -f1)"
  fi

  # Include coverage report hash only when COVERAGE_PATH is within the output dir
  local coverage_hash=""
  local coverage_path_resolved="${COVERAGE_PATH:-}"
  if [[ -n "${coverage_path_resolved}" && -f "${coverage_path_resolved}" ]]; then
    local out_dir_abs
    out_dir_abs="$(cd "${out_dir}" && pwd)"
    local coverage_abs
    coverage_abs="$(cd "$(dirname "${coverage_path_resolved}")" && pwd)/$(basename "${coverage_path_resolved}")"
    if [[ "${coverage_abs}" == "${out_dir_abs}/"* ]]; then
      coverage_hash="$(sha256sum "${coverage_path_resolved}" | cut -d' ' -f1)"
    fi
  fi

  {
    printf 'source: %s\n' "${source_hash}"
    printf 'compiled-from: %s\n' "${proposal_id}"
    printf 'artifacts:\n'
    printf '  compliance-floor.prose.md: %s\n' "${prose_hash}"
    printf '  enforce.sh: %s\n' "${enforce_hash}"
    if [[ -n "${coverage_hash}" ]]; then
      printf '  compliance-coverage.md: %s\n' "${coverage_hash}"
    fi
  } > "${out_dir}/manifest.sha256"
}

# ---------------------------------------------------------------------------
# verify_manifest — compare current hashes against manifest.sha256
#
# Arguments:
#   $1  input floor file (source)
#   $2  output directory (must contain manifest.sha256 and artifacts)
#
# Exits 0 if all hashes match, exits 1 if any differ (prints which drifted).
# ---------------------------------------------------------------------------

verify_manifest() {
  local floor_file="$1"
  local out_dir="$2"
  local manifest_file="${out_dir}/manifest.sha256"

  if [[ ! -f "${manifest_file}" ]]; then
    echo "ERROR: manifest.sha256 not found in ${out_dir}" >&2
    exit 1
  fi

  local drift=0

  # Compare source hash
  local recorded_source
  recorded_source="$(grep '^source:' "${manifest_file}" | awk '{print $2}')"
  local current_source
  current_source="$(sha256sum "${floor_file}" | cut -d' ' -f1)"
  if [[ "${current_source}" != "${recorded_source}" ]]; then
    echo "DRIFT: source floor file has changed (${floor_file})"
    drift=1
  fi

  # Compare prose artifact
  if grep -q 'compliance-floor\.prose\.md:' "${manifest_file}"; then
    local recorded_prose
    recorded_prose="$(grep 'compliance-floor\.prose\.md:' "${manifest_file}" | awk '{print $2}')"
    if [[ -n "${recorded_prose}" ]]; then
      local current_prose=""
      if [[ -f "${out_dir}/compliance-floor.prose.md" ]]; then
        current_prose="$(sha256sum "${out_dir}/compliance-floor.prose.md" | cut -d' ' -f1)"
      fi
      if [[ "${current_prose}" != "${recorded_prose}" ]]; then
        echo "DRIFT: compliance-floor.prose.md has changed"
        drift=1
      fi
    fi
  fi

  # Compare enforce.sh artifact
  if grep -q 'enforce\.sh:' "${manifest_file}"; then
    local recorded_enforce
    recorded_enforce="$(grep 'enforce\.sh:' "${manifest_file}" | awk '{print $2}')"
    if [[ -n "${recorded_enforce}" ]]; then
      local current_enforce=""
      if [[ -f "${out_dir}/enforce.sh" ]]; then
        current_enforce="$(sha256sum "${out_dir}/enforce.sh" | cut -d' ' -f1)"
      fi
      if [[ "${current_enforce}" != "${recorded_enforce}" ]]; then
        echo "DRIFT: enforce.sh has changed"
        drift=1
      fi
    fi
  fi

  if [[ "${drift}" -eq 1 ]]; then
    exit 1
  fi
  echo "All artifacts match manifest — no drift detected"
  exit 0
}

# ---------------------------------------------------------------------------
# Mode dispatch
# ---------------------------------------------------------------------------

case "${MODE}" in
  compile)
    if [[ ! -f "${FLOOR_FILE}" ]]; then
      echo "ERROR: Floor file not found: ${FLOOR_FILE}" >&2
      exit 1
    fi

    mkdir -p "${OUTPUT_DIR}"

    # Extract blocks to a temp dir for validation
    local_compile_tmp="$(mktemp -d)"
    trap 'rm -rf "${local_compile_tmp}"' EXIT

    block_count=$(extract_blocks "${FLOOR_FILE}" "${local_compile_tmp}")

    if [[ "${block_count}" -gt 0 ]]; then
      for block_file in "${local_compile_tmp}"/block-*.yaml; do
        validate_block "${block_file}"
      done
    fi

    # Copy validated blocks to output dir
    for block_file in "${local_compile_tmp}"/block-*.yaml; do
      [[ -f "${block_file}" ]] || continue
      cp "${block_file}" "${OUTPUT_DIR}/"
    done

    # Generate prose
    generate_prose "${FLOOR_FILE}" "${OUTPUT_DIR}"

    # Generate enforce.sh (if any blocks)
    if [[ "${block_count}" -gt 0 ]]; then
      generate_enforce "${OUTPUT_DIR}"
    fi

    # Generate coverage report
    generate_coverage "${FLOOR_FILE}" "${OUTPUT_DIR}"

    # Generate manifest
    generate_manifest "${FLOOR_FILE}" "${OUTPUT_DIR}" "${PROPOSAL_ID}"

    echo "Compiled ${block_count} rule(s) to ${OUTPUT_DIR} (proposal: ${PROPOSAL_ID:-<none>})"
    ;;

  extract-only)
    if [[ ! -f "${FLOOR_FILE}" ]]; then
      echo "ERROR: Floor file not found: ${FLOOR_FILE}" >&2
      exit 1
    fi

    mkdir -p "${OUTPUT_DIR}"

    block_count=$(extract_blocks "${FLOOR_FILE}" "${OUTPUT_DIR}")
    echo "Extracted ${block_count} enforcement block(s) to ${OUTPUT_DIR}"
    ;;

  validate-only)
    if [[ ! -f "${FLOOR_FILE}" ]]; then
      echo "ERROR: Floor file not found: ${FLOOR_FILE}" >&2
      exit 1
    fi

    local_validate_dir="$(mktemp -d)"
    trap 'rm -rf "${local_validate_dir}"' EXIT

    block_count=$(extract_blocks "${FLOOR_FILE}" "${local_validate_dir}")

    if [[ "${block_count}" -eq 0 ]]; then
      echo "No enforcement blocks found in ${FLOOR_FILE}"
      exit 0
    fi

    for block_file in "${local_validate_dir}"/block-*.yaml; do
      validate_block "${block_file}"
    done

    echo "Validated ${block_count} enforcement block(s) — all valid"
    ;;

  prose-only)
    if [[ ! -f "${FLOOR_FILE}" ]]; then
      echo "ERROR: Floor file not found: ${FLOOR_FILE}" >&2
      exit 1
    fi

    mkdir -p "${OUTPUT_DIR}"

    generate_prose "${FLOOR_FILE}" "${OUTPUT_DIR}"
    echo "Generated prose floor to ${OUTPUT_DIR}/compliance-floor.prose.md"
    ;;

  generate-enforce)
    if [[ ! -f "${FLOOR_FILE}" ]]; then
      echo "ERROR: Floor file not found: ${FLOOR_FILE}" >&2
      exit 1
    fi

    mkdir -p "${OUTPUT_DIR}"

    block_count=$(extract_blocks "${FLOOR_FILE}" "${OUTPUT_DIR}")

    if [[ "${block_count}" -eq 0 ]]; then
      echo "No enforcement blocks found in ${FLOOR_FILE}"
      exit 0
    fi

    for block_file in "${OUTPUT_DIR}"/block-*.yaml; do
      validate_block "${block_file}"
    done

    generate_enforce "${OUTPUT_DIR}"
    echo "Generated enforce.sh to ${OUTPUT_DIR}/enforce.sh (${block_count} rule(s))"
    ;;

  verify)
    if [[ ! -f "${FLOOR_FILE}" ]]; then
      echo "ERROR: Floor file not found: ${FLOOR_FILE}" >&2
      exit 1
    fi

    verify_manifest "${FLOOR_FILE}" "${OUTPUT_DIR}"
    ;;

  dry-run)
    if [[ ! -f "${FLOOR_FILE}" ]]; then
      echo "ERROR: Floor file not found: ${FLOOR_FILE}" >&2
      exit 1
    fi

    local_dryrun_tmp="$(mktemp -d)"
    trap 'rm -rf "${local_dryrun_tmp}"' EXIT

    # Extract blocks to temp dir
    block_count=$(extract_blocks "${FLOOR_FILE}" "${local_dryrun_tmp}")

    # Validate all blocks
    if [[ "${block_count}" -gt 0 ]]; then
      for block_file in "${local_dryrun_tmp}"/block-*.yaml; do
        validate_block "${block_file}"
      done
    fi

    # Print summary to stdout without writing any files
    echo "Dry run: ${block_count} rule(s) found in ${FLOOR_FILE}"
    echo ""
    if [[ "${block_count}" -gt 0 ]]; then
      for block_file in "${local_dryrun_tmp}"/block-*.yaml; do
        [[ -f "${block_file}" ]] || continue

        dryrun_rule_id="$(yq '.id' "${block_file}")"
        dryrun_rule_id="${dryrun_rule_id//\"/}"

        dryrun_severity="$(yq '.severity' "${block_file}")"
        dryrun_severity="${dryrun_severity//\"/}"

        # Collect enforcement points
        dryrun_enf_points=""
        dryrun_pre_type="$(yq '.enforce."pre-tool-use".type' "${block_file}")"
        dryrun_pre_type="${dryrun_pre_type//\"/}"
        if [[ "${dryrun_pre_type}" != "null" && -n "${dryrun_pre_type}" ]]; then
          dryrun_enf_points="${dryrun_enf_points:+${dryrun_enf_points}, }pre-tool-use"
        fi
        dryrun_post_type="$(yq '.enforce."post-tool-use".type' "${block_file}")"
        dryrun_post_type="${dryrun_post_type//\"/}"
        if [[ "${dryrun_post_type}" != "null" && -n "${dryrun_post_type}" ]]; then
          dryrun_enf_points="${dryrun_enf_points:+${dryrun_enf_points}, }post-tool-use"
        fi

        echo "  rule: ${dryrun_rule_id} | severity: ${dryrun_severity} | enforcement: ${dryrun_enf_points}"
      done
    fi
    echo ""
    echo "No files written (dry-run mode)."
    ;;

  *)
    echo "ERROR: Unknown mode: ${MODE}" >&2
    exit 1
    ;;
esac
