#!/usr/bin/env bash
set -euo pipefail

# ---------------------------------------------------------------------------
# validate.sh — validate a single enforcement block YAML file
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

block_file="$1"
block_name="$(basename "${block_file}")"
valid=1

# Read source line number for error context
source_line="$(yq '._source_line' "${block_file}" 2>/dev/null)"
source_line="${source_line//\"/}"
loc=""
if [[ "${source_line}" != "null" && -n "${source_line}" ]]; then
  loc=" (line ${source_line})"
fi

# Read id early for error context
id="$(yq '.id' "${block_file}")"
id="${id//\"/}"
id_label=""
if [[ "${id}" != "null" && -n "${id}" && "${id}" != '""' ]]; then
  id_label=" [${id}]"
fi

# Check: version exists and equals 1
version="$(yq '.version' "${block_file}")"
if [[ "${version}" == "null" || -z "${version}" ]]; then
  echo "INVALID${id_label}${loc}: missing required field 'version'" >&2
  valid=0
elif [[ "${version}" != "1" ]]; then
  echo "INVALID${id_label}${loc}: 'version' must be 1, got ${version}" >&2
  valid=0
fi

# Check: id exists and is non-empty (already read above for error context)
if [[ "${id}" == "null" || -z "${id}" || "${id}" == '""' ]]; then
  echo "INVALID${id_label}${loc}: missing or empty 'id' field" >&2
  valid=0
fi

# Check: severity is 'blocking' or 'warning'
severity="$(yq '.severity' "${block_file}")"
# Remove surrounding quotes if present
severity="${severity//\"/}"
if [[ "${severity}" != "blocking" && "${severity}" != "warning" ]]; then
  echo "INVALID${id_label}${loc}: 'severity' must be 'blocking' or 'warning', got '${severity}'" >&2
  valid=0
fi

# Check: no forbidden top-level keys (bypass, skip, override)
bypass="$(yq '.bypass' "${block_file}")"
skip="$(yq '.skip' "${block_file}")"
override="$(yq '.override' "${block_file}")"
if [[ "${bypass}" != "null" ]]; then
  echo "INVALID${id_label}${loc}: forbidden top-level field 'bypass' is present" >&2
  valid=0
fi
if [[ "${skip}" != "null" ]]; then
  echo "INVALID${id_label}${loc}: forbidden top-level field 'skip' is present" >&2
  valid=0
fi
if [[ "${override}" != "null" ]]; then
  echo "INVALID${id_label}${loc}: forbidden top-level field 'override' is present" >&2
  valid=0
fi

# Check: at least one pre-tool-use or post-tool-use enforcement point under enforce
pre_hook="$(yq '.enforce."pre-tool-use"' "${block_file}")"
post_hook="$(yq '.enforce."post-tool-use"' "${block_file}")"
if [[ "${pre_hook}" == "null" && "${post_hook}" == "null" ]]; then
  echo "INVALID${id_label}${loc}: 'enforce' must contain at least one 'pre-tool-use' or 'post-tool-use' point" >&2
  valid=0
fi

# Check: check type is valid for its enforcement point
# file-pattern: pre-tool-use only
# content-pattern: pre-tool-use, post-tool-use
# semgrep: post-tool-use, ci
# eslint: post-tool-use, ci
# custom-script: any
enforce_keys_ct="$(yq '.enforce | keys | .[]' "${block_file}" 2>/dev/null || true)"
while IFS= read -r ct_ekey; do
  ct_ekey="${ct_ekey//\"/}"
  [[ -z "${ct_ekey}" ]] && continue
  ct_type="$(yq ".enforce.\"${ct_ekey}\".type" "${block_file}" 2>/dev/null)"
  ct_type="${ct_type//\"/}"
  [[ "${ct_type}" == "null" || -z "${ct_type}" ]] && continue
  case "${ct_type}" in
    file-pattern)
      if [[ "${ct_ekey}" != "pre-tool-use" ]]; then
        echo "INVALID${id_label}${loc}: 'file-pattern' is only valid at 'pre-tool-use', found at '${ct_ekey}'" >&2
        valid=0
      fi
      ;;
    content-pattern)
      if [[ "${ct_ekey}" != "pre-tool-use" && "${ct_ekey}" != "post-tool-use" ]]; then
        echo "INVALID${id_label}${loc}: 'content-pattern' is only valid at 'pre-tool-use' or 'post-tool-use', found at '${ct_ekey}'" >&2
        valid=0
      fi
      ;;
    semgrep)
      if [[ "${ct_ekey}" != "post-tool-use" && "${ct_ekey}" != "ci" ]]; then
        echo "INVALID${id_label}${loc}: 'semgrep' is only valid at 'post-tool-use' or 'ci', found at '${ct_ekey}'" >&2
        valid=0
      fi
      ;;
    eslint)
      if [[ "${ct_ekey}" != "post-tool-use" && "${ct_ekey}" != "ci" ]]; then
        echo "INVALID${id_label}${loc}: 'eslint' is only valid at 'post-tool-use' or 'ci', found at '${ct_ekey}'" >&2
        valid=0
      fi
      ;;
    custom-script)
      ;; # valid at any enforcement point
    *)
      echo "INVALID${id_label}${loc}: unknown check type '${ct_type}' at '${ct_ekey}'" >&2
      valid=0
      ;;
  esac
done <<< "${enforce_keys_ct}"

# Check: severity/action contradiction
# warning + block -> reject; blocking + warn -> reject
severity_clean="${severity}"
enforce_keys="$(yq '.enforce | keys | .[]' "${block_file}" 2>/dev/null || true)"
while IFS= read -r ekey; do
  # Strip surrounding quotes
  ekey="${ekey//\"/}"
  action="$(yq ".enforce.\"${ekey}\".action" "${block_file}")"
  action="${action//\"/}"
  if [[ "${action}" == "null" || -z "${action}" ]]; then
    continue
  fi
  if [[ "${severity_clean}" == "warning" && "${action}" == "block" ]]; then
    echo "INVALID${id_label}${loc}: contradiction — severity 'warning' with action 'block' at enforcement point '${ekey}'" >&2
    valid=0
  fi
  if [[ "${severity_clean}" == "blocking" && "${action}" == "warn" ]]; then
    echo "INVALID${id_label}${loc}: contradiction — severity 'blocking' with action 'warn' at enforcement point '${ekey}'" >&2
    valid=0
  fi
done <<< "${enforce_keys}"

# Check: rule-path inside enforcement points (required for semgrep/eslint, must exist)
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

# Check: custom-script enforcement points must have script that exists and is executable
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
