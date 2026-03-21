#!/usr/bin/env bash
set -euo pipefail

# ---------------------------------------------------------------------------
# test-compile-floor.sh — Test suite for the compliance floor compiler
# ---------------------------------------------------------------------------

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
COMPILER="${REPO_ROOT}/ops/compile-floor.sh"
FIXTURES="${SCRIPT_DIR}/fixtures"

PASS=0
FAIL=0
TOTAL=0

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

# ---------------------------------------------------------------------------
# Assert helpers
# ---------------------------------------------------------------------------

assert_exit() {
  local label="$1"
  local expected_exit="$2"
  local actual_exit="$3"
  TOTAL=$((TOTAL + 1))
  if [[ "$actual_exit" -eq "$expected_exit" ]]; then
    echo -e "  ${GREEN}PASS${NC} ${label}"
    PASS=$((PASS + 1))
  else
    echo -e "  ${RED}FAIL${NC} ${label} — expected exit ${expected_exit}, got ${actual_exit}"
    FAIL=$((FAIL + 1))
  fi
}

assert_file_exists() {
  local label="$1"
  local path="$2"
  TOTAL=$((TOTAL + 1))
  if [[ -f "$path" ]]; then
    echo -e "  ${GREEN}PASS${NC} ${label}"
    PASS=$((PASS + 1))
  else
    echo -e "  ${RED}FAIL${NC} ${label} — file not found: ${path}"
    FAIL=$((FAIL + 1))
  fi
}

assert_file_not_exists() {
  local label="$1"
  local path="$2"
  TOTAL=$((TOTAL + 1))
  if [[ ! -f "$path" ]]; then
    echo -e "  ${GREEN}PASS${NC} ${label}"
    PASS=$((PASS + 1))
  else
    echo -e "  ${RED}FAIL${NC} ${label} — file should not exist: ${path}"
    FAIL=$((FAIL + 1))
  fi
}

assert_contains() {
  local label="$1"
  local file="$2"
  local pattern="$3"
  TOTAL=$((TOTAL + 1))
  if grep -qE "$pattern" "$file" 2>/dev/null; then
    echo -e "  ${GREEN}PASS${NC} ${label}"
    PASS=$((PASS + 1))
  else
    echo -e "  ${RED}FAIL${NC} ${label} — pattern not found in ${file}: ${pattern}"
    FAIL=$((FAIL + 1))
  fi
}

assert_not_contains() {
  local label="$1"
  local file="$2"
  local pattern="$3"
  TOTAL=$((TOTAL + 1))
  if ! grep -qE "$pattern" "$file" 2>/dev/null; then
    echo -e "  ${GREEN}PASS${NC} ${label}"
    PASS=$((PASS + 1))
  else
    echo -e "  ${RED}FAIL${NC} ${label} — pattern should not be found in ${file}: ${pattern}"
    FAIL=$((FAIL + 1))
  fi
}

# ---------------------------------------------------------------------------
# Dependency check
# ---------------------------------------------------------------------------

if ! command -v yq &>/dev/null; then
  echo "ERROR: yq is required but not installed." >&2
  echo "Install with: brew install yq  OR  snap install yq" >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# TMPDIR management
# ---------------------------------------------------------------------------

TMPDIR_ROOT=""

setup_tmpdir() {
  TMPDIR_ROOT="$(mktemp -d)"
}

cleanup_all() {
  if [[ -n "${TMPDIR_ROOT:-}" && -d "${TMPDIR_ROOT}" ]]; then
    rm -rf "${TMPDIR_ROOT}"
  fi
}

trap cleanup_all EXIT

setup_tmpdir

# ---------------------------------------------------------------------------
# Section: Extraction tests
# ---------------------------------------------------------------------------

echo ""
echo "=== Extraction ==="

EXTRACT_DIR="${TMPDIR_ROOT}/extraction"
mkdir -p "${EXTRACT_DIR}"

# Run compiler in extract-only mode against the valid fixture
"${COMPILER}" --extract-only "${FIXTURES}/floor-valid.md" "${EXTRACT_DIR}" 2>/dev/null
extract_exit=$?

assert_exit "extract-only exits 0 on valid fixture" 0 "${extract_exit}"

# Count extracted blocks (expect 2 — rule 3 has no enforcement block)
block_count=$(ls "${EXTRACT_DIR}"/block-*.yaml 2>/dev/null | wc -l | tr -d ' ')
TOTAL=$((TOTAL + 1))
if [[ "${block_count}" -eq 2 ]]; then
  echo -e "  ${GREEN}PASS${NC} extracted block count is 2"
  PASS=$((PASS + 1))
else
  echo -e "  ${RED}FAIL${NC} extracted block count is 2 — got ${block_count}"
  FAIL=$((FAIL + 1))
fi

# Verify each extracted block is valid YAML (parseable by yq)
for block_file in "${EXTRACT_DIR}"/block-*.yaml; do
  if [[ -f "${block_file}" ]]; then
    yq '.' "${block_file}" >/dev/null 2>&1
    yq_exit=$?
    assert_exit "block $(basename "${block_file}") is valid YAML" 0 "${yq_exit}"
  fi
done

# Verify block 1 has id=no-hardcoded-secrets
assert_contains "block-001.yaml has id=no-hardcoded-secrets" \
  "${EXTRACT_DIR}/block-001.yaml" \
  "no-hardcoded-secrets"

# Verify block 2 has id=no-console-log
assert_contains "block-002.yaml has id=no-console-log" \
  "${EXTRACT_DIR}/block-002.yaml" \
  "no-console-log"

# ---------------------------------------------------------------------------
# Results summary
# ---------------------------------------------------------------------------

echo ""
echo "Results: ${PASS}/${TOTAL} passed, ${FAIL} failed"

if [[ "${FAIL}" -gt 0 ]]; then
  exit 1
fi
exit 0
