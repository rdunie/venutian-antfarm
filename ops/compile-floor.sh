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

  dry-run|verify|proposal)
    echo "ERROR: Mode '${MODE}' is not yet implemented." >&2
    exit 2
    ;;

  *)
    echo "ERROR: Unknown mode: ${MODE}" >&2
    exit 1
    ;;
esac
