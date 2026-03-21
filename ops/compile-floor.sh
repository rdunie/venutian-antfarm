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
#   --dry-run       Show what would be done without writing files (planned)
#   --verify        Validate extracted blocks without generating output (planned)
#   --extract-only  Extract blocks and write YAML files, then stop
#   --proposal      Emit a compliance proposal instead of hooks (planned)
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
      MODE="proposal"
      shift
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
  MODE="extract-only"
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
# Mode dispatch
# ---------------------------------------------------------------------------

case "${MODE}" in
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

  dry-run|verify|proposal)
    echo "ERROR: Mode '${MODE}' is not yet implemented." >&2
    exit 2
    ;;

  *)
    echo "ERROR: Unknown mode: ${MODE}" >&2
    exit 1
    ;;
esac
