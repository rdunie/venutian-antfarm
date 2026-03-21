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

  dry-run|verify|proposal)
    echo "ERROR: Mode '${MODE}' is not yet implemented." >&2
    exit 2
    ;;

  *)
    echo "ERROR: Unknown mode: ${MODE}" >&2
    exit 1
    ;;
esac
