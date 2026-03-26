#!/usr/bin/env bash
set -euo pipefail

# ---------------------------------------------------------------------------
# validate.sh — validate a single enforcement block YAML file
#
# Reads validation rules from schema.yaml where possible; keeps relational
# constraints (severity/action, file existence, custom-script) as code.
#
# Usage:
#   validate.sh <block-file>
#
# Returns 0 on valid.
# Prints error to stderr and exits 2 on invalid.
# ---------------------------------------------------------------------------

if [[ $# -lt 1 ]]; then
  echo "Usage: validate.sh <block-file>" >&2
  exit 1
fi

VALIDATE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCHEMA="${VALIDATE_DIR}/schema.yaml"

block_file="$1"
valid=1

# --- Error context helpers -------------------------------------------------
source_line="$(yq '._source_line' "${block_file}" 2>/dev/null)"
source_line="${source_line//\"/}"
loc=""
if [[ "${source_line}" != "null" && -n "${source_line}" ]]; then
  loc=" (line ${source_line})"
fi

id="$(yq '.id' "${block_file}")"
id="${id//\"/}"
id_label=""
if [[ "${id}" != "null" && -n "${id}" && "${id}" != '""' ]]; then
  id_label=" [${id}]"
fi

# --- Required fields: version ----------------------------------------------
version="$(yq '.version' "${block_file}")"
if [[ "${version}" == "null" || -z "${version}" ]]; then
  echo "INVALID${id_label}${loc}: missing required field 'version'" >&2
  valid=0
elif [[ "${version}" != "1" ]]; then
  echo "INVALID${id_label}${loc}: 'version' must be 1, got ${version}" >&2
  valid=0
fi

# --- Required fields: id ---------------------------------------------------
if [[ "${id}" == "null" || -z "${id}" || "${id}" == '""' ]]; then
  echo "INVALID${id_label}${loc}: missing or empty 'id' field" >&2
  valid=0
fi

# --- Required fields: severity (enum from schema) --------------------------
severity="$(yq '.severity' "${block_file}")"
severity="${severity//\"/}"
if [[ "${severity}" != "blocking" && "${severity}" != "warning" ]]; then
  echo "INVALID${id_label}${loc}: 'severity' must be 'blocking' or 'warning', got '${severity}'" >&2
  valid=0
fi

# --- Forbidden fields (driven by schema.yaml) ------------------------------
while IFS= read -r ff; do
  ff="${ff//\"/}"
  [[ -z "${ff}" ]] && continue
  val="$(yq ".${ff}" "${block_file}")"
  if [[ "${val}" != "null" ]]; then
    echo "INVALID${id_label}${loc}: forbidden top-level field '${ff}' is present" >&2
    valid=0
  fi
done <<< "$(yq '.forbidden_fields[]' "${SCHEMA}")"

# --- Required enforcement points -------------------------------------------
pre_hook="$(yq '.enforce."pre-tool-use"' "${block_file}")"
post_hook="$(yq '.enforce."post-tool-use"' "${block_file}")"
if [[ "${pre_hook}" == "null" && "${post_hook}" == "null" ]]; then
  echo "INVALID${id_label}${loc}: 'enforce' must contain at least one 'pre-tool-use' or 'post-tool-use' point" >&2
  valid=0
fi

# --- Type constraints (driven by schema.yaml) ------------------------------
enforce_keys_ct="$(yq '.enforce | keys | .[]' "${block_file}" 2>/dev/null || true)"
while IFS= read -r ct_ekey; do
  ct_ekey="${ct_ekey//\"/}"
  [[ -z "${ct_ekey}" ]] && continue
  ct_type="$(yq ".enforce.\"${ct_ekey}\".type" "${block_file}" 2>/dev/null)"
  ct_type="${ct_type//\"/}"
  [[ "${ct_type}" == "null" || -z "${ct_type}" ]] && continue

  # Read allowed points for this type from schema
  allowed="$(yq ".enforce.type_constraints.\"${ct_type}\"" "${SCHEMA}" 2>/dev/null)"
  if [[ "${allowed}" == "null" || -z "${allowed}" ]]; then
    echo "INVALID${id_label}${loc}: unknown check type '${ct_type}' at '${ct_ekey}'" >&2
    valid=0
    continue
  fi

  # Check if current enforcement point is in the allowed list
  match="$(yq ".enforce.type_constraints.\"${ct_type}\" | .[] | select(. == \"${ct_ekey}\")" "${SCHEMA}" 2>/dev/null)"
  if [[ -z "${match}" ]]; then
    # Build human-readable allowed-points string (e.g. "'pre-tool-use' or 'post-tool-use'")
    points_list="$(yq -r ".enforce.type_constraints.\"${ct_type}\" | .[]" "${SCHEMA}" 2>/dev/null)"
    readable=""
    while IFS= read -r pt; do
      if [[ -z "${readable}" ]]; then
        readable="'${pt}'"
      else
        readable="${readable} or '${pt}'"
      fi
    done <<< "${points_list}"
    echo "INVALID${id_label}${loc}: '${ct_type}' is only valid at ${readable}, found at '${ct_ekey}'" >&2
    valid=0
  fi
done <<< "${enforce_keys_ct}"

# --- Severity/action contradiction -----------------------------------------
enforce_keys="$(yq '.enforce | keys | .[]' "${block_file}" 2>/dev/null || true)"
while IFS= read -r ekey; do
  ekey="${ekey//\"/}"
  action="$(yq ".enforce.\"${ekey}\".action" "${block_file}")"
  action="${action//\"/}"
  [[ "${action}" == "null" || -z "${action}" ]] && continue
  if [[ "${severity}" == "warning" && "${action}" == "block" ]]; then
    echo "INVALID${id_label}${loc}: contradiction — severity 'warning' with action 'block' at enforcement point '${ekey}'" >&2
    valid=0
  fi
  if [[ "${severity}" == "blocking" && "${action}" == "warn" ]]; then
    echo "INVALID${id_label}${loc}: contradiction — severity 'blocking' with action 'warn' at enforcement point '${ekey}'" >&2
    valid=0
  fi
done <<< "${enforce_keys}"

# --- Rule-path checks (semgrep/eslint) -------------------------------------
enforce_keys_rp="$(yq '.enforce | keys | .[]' "${block_file}" 2>/dev/null || true)"
while IFS= read -r rp_ekey; do
  rp_ekey="${rp_ekey//\"/}"
  [[ -z "${rp_ekey}" ]] && continue
  rp_type="$(yq ".enforce.\"${rp_ekey}\".type" "${block_file}" 2>/dev/null)"
  rp_type="${rp_type//\"/}"
  if [[ "${rp_type}" == "semgrep" || "${rp_type}" == "eslint" ]]; then
    rp_rule_path="$(yq ".enforce.\"${rp_ekey}\".\"rule-path\"" "${block_file}" 2>/dev/null)"
    rp_rule_path="${rp_rule_path//\"/}"
    if [[ -z "${rp_rule_path}" || "${rp_rule_path}" == "null" ]]; then
      echo "INVALID${id_label}${loc}: ${rp_type} at '${rp_ekey}' missing required 'rule-path' field" >&2
      valid=0
    elif [[ ! -f "${rp_rule_path}" ]]; then
      echo "INVALID${id_label}${loc}: ${rp_type} at '${rp_ekey}' rule-path does not exist: ${rp_rule_path}" >&2
      valid=0
    fi
    rp_rule_id="$(yq ".enforce.\"${rp_ekey}\".\"rule-id\"" "${block_file}" 2>/dev/null)"
    rp_rule_id="${rp_rule_id//\"/}"
    if [[ -z "${rp_rule_id}" || "${rp_rule_id}" == "null" ]]; then
      echo "INVALID${id_label}${loc}: ${rp_type} at '${rp_ekey}' missing required 'rule-id' field" >&2
      valid=0
    fi
  fi
done <<< "${enforce_keys_rp}"

# --- Custom-script checks --------------------------------------------------
enforce_keys_cs="$(yq '.enforce | keys | .[]' "${block_file}" 2>/dev/null || true)"
while IFS= read -r cs_ekey; do
  cs_ekey="${cs_ekey//\"/}"
  [[ -z "${cs_ekey}" ]] && continue
  cs_type="$(yq ".enforce.\"${cs_ekey}\".type" "${block_file}" 2>/dev/null)"
  cs_type="${cs_type//\"/}"
  [[ "${cs_type}" != "custom-script" ]] && continue
  cs_script="$(yq ".enforce.\"${cs_ekey}\".script" "${block_file}" 2>/dev/null)"
  cs_script="${cs_script//\"/}"
  if [[ -z "${cs_script}" || "${cs_script}" == "null" ]]; then
    echo "INVALID${id_label}${loc}: custom-script at '${cs_ekey}' missing 'script' field" >&2
    valid=0
  elif [[ "${cs_script}" == /* ]]; then
    echo "INVALID${id_label}${loc}: custom-script 'script' must be a relative path within the repo, got: ${cs_script}" >&2
    valid=0
  elif [[ ! -f "${cs_script}" ]]; then
    echo "INVALID${id_label}${loc}: custom-script 'script' does not exist: ${cs_script}" >&2
    valid=0
  elif [[ ! -x "${cs_script}" ]]; then
    echo "INVALID${id_label}${loc}: custom-script 'script' is not executable: ${cs_script}" >&2
    valid=0
  fi
done <<< "${enforce_keys_cs}"

if [[ "${valid}" -eq 0 ]]; then
  exit 2
fi
exit 0
