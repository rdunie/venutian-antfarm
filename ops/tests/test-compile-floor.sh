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
# Tests will be added in subsequent tasks
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# Results summary
# ---------------------------------------------------------------------------

echo ""
echo "Results: ${PASS}/${TOTAL} passed, ${FAIL} failed"

if [[ "${FAIL}" -gt 0 ]]; then
  exit 1
fi
exit 0
