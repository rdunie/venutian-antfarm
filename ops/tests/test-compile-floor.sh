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
# Section: Validation tests
# ---------------------------------------------------------------------------

echo ""
echo "=== Validation ==="

VALDIR="$TMPDIR_ROOT/validation"
mkdir -p "$VALDIR"

# Test: valid fixture passes validation
val_valid_exit=0
"$COMPILER" --validate-only "$FIXTURES/floor-valid.md" "$VALDIR" >/dev/null 2>&1 || val_valid_exit=$?
assert_exit "valid fixture passes validation" 0 "${val_valid_exit}"

# Test: CI-only rule rejected
val_norealtime_exit=0
"$COMPILER" --validate-only "$FIXTURES/floor-invalid-no-realtime.md" "$VALDIR" >/dev/null 2>&1 || val_norealtime_exit=$?
assert_exit "CI-only rule rejected (exit 2)" 2 "${val_norealtime_exit}"

# Test: bypass field rejected
val_bypass_exit=0
"$COMPILER" --validate-only "$FIXTURES/floor-invalid-bypass.md" "$VALDIR" >/dev/null 2>&1 || val_bypass_exit=$?
assert_exit "bypass field rejected (exit 2)" 2 "${val_bypass_exit}"

# Test: severity/action contradiction rejected
val_sevact_exit=0
"$COMPILER" --validate-only "$FIXTURES/floor-invalid-severity-action.md" "$VALDIR" >/dev/null 2>&1 || val_sevact_exit=$?
assert_exit "severity/action contradiction rejected (exit 2)" 2 "${val_sevact_exit}"

# Test: missing version rejected
val_noversion_exit=0
"$COMPILER" --validate-only "$FIXTURES/floor-invalid-no-version.md" "$VALDIR" >/dev/null 2>&1 || val_noversion_exit=$?
assert_exit "missing version rejected (exit 2)" 2 "${val_noversion_exit}"

# ---------------------------------------------------------------------------
# Section: Prose Generation
# ---------------------------------------------------------------------------

echo ""
echo "=== Prose Generation ==="

PROSEDIR="$TMPDIR_ROOT/prose"
mkdir -p "$PROSEDIR"

prose_exit=0
"$COMPILER" --prose-only "$FIXTURES/floor-valid.md" "$PROSEDIR" >/dev/null 2>&1 || prose_exit=$?
assert_exit "prose generation exits 0" 0 $prose_exit

assert_file_exists "prose file generated" "$PROSEDIR/compliance-floor.prose.md"
assert_not_contains "prose has no enforcement blocks" "$PROSEDIR/compliance-floor.prose.md" '```enforcement'
assert_contains "prose retains rule 1 text" "$PROSEDIR/compliance-floor.prose.md" "No hardcoded secrets"
assert_contains "prose retains rule 2 text" "$PROSEDIR/compliance-floor.prose.md" "No console.log"
assert_contains "prose retains rule 3 text" "$PROSEDIR/compliance-floor.prose.md" "All data changes are auditable"

# ---------------------------------------------------------------------------
# Section: enforce.sh Generation
# ---------------------------------------------------------------------------

echo ""
echo "=== enforce.sh Generation ==="

ENFDIR="$TMPDIR_ROOT/enforce"
mkdir -p "$ENFDIR"

# Generate enforce.sh from valid fixture
enf_exit=0
"$COMPILER" --generate-enforce "$FIXTURES/floor-valid.md" "$ENFDIR" >/dev/null 2>&1 || enf_exit=$?
assert_exit "generate-enforce exits 0 on valid fixture" 0 "$enf_exit"

# Assert: file exists
assert_file_exists "enforce.sh exists" "$ENFDIR/enforce.sh"

# Assert: has shebang
assert_contains "enforce.sh has bash shebang" "$ENFDIR/enforce.sh" '^#!/usr/bin/env bash'

# Assert: contains pre-tool-use handler
assert_contains "enforce.sh contains pre-tool-use handler" "$ENFDIR/enforce.sh" 'pre-tool-use'

# Assert: contains post-tool-use handler
assert_contains "enforce.sh contains post-tool-use handler" "$ENFDIR/enforce.sh" 'post-tool-use'

# Assert: contains no-hardcoded-secrets check
assert_contains "enforce.sh contains no-hardcoded-secrets check" "$ENFDIR/enforce.sh" 'no.hardcoded.secrets'

# Assert: contains no-console-log check
assert_contains "enforce.sh contains no-console-log check" "$ENFDIR/enforce.sh" 'no.console.log'

# Assert: contains GENERATED header
assert_contains "enforce.sh has GENERATED header" "$ENFDIR/enforce.sh" 'GENERATED by ops/compile-floor.sh'

# Functional test: make enforce.sh executable, run with non-matching file → exit 0
chmod +x "$ENFDIR/enforce.sh"

enf_nomatch_exit=0
"$ENFDIR/enforce.sh" pre-tool-use "app.js" || enf_nomatch_exit=$?
assert_exit "enforce.sh pre-tool-use app.js → exit 0 (no match)" 0 "$enf_nomatch_exit"

# Functional test: run with .env file → exit 2 (blocking rule)
enf_env_exit=0
"$ENFDIR/enforce.sh" pre-tool-use "secrets.env" || enf_env_exit=$?
assert_exit "enforce.sh pre-tool-use secrets.env → exit 2 (blocking)" 2 "$enf_env_exit"

# Functional test: create file with console.log, run post-tool-use → exit 1 (warning)
CONSOLE_FILE="$ENFDIR/test-console.js"
printf 'console.log("debug")\n' > "$CONSOLE_FILE"
enf_console_exit=0
"$ENFDIR/enforce.sh" post-tool-use "$CONSOLE_FILE" || enf_console_exit=$?
assert_exit "enforce.sh post-tool-use console.log file → exit 1 (warning)" 1 "$enf_console_exit"

# Functional test: create file with logger.info, run post-tool-use → exit 0 (no match)
LOGGER_FILE="$ENFDIR/test-logger.js"
printf 'logger.info("debug")\n' > "$LOGGER_FILE"
enf_logger_exit=0
"$ENFDIR/enforce.sh" post-tool-use "$LOGGER_FILE" || enf_logger_exit=$?
assert_exit "enforce.sh post-tool-use logger.info file → exit 0 (no match)" 0 "$enf_logger_exit"

# ---------------------------------------------------------------------------
# Results summary
# ---------------------------------------------------------------------------

echo ""
echo "Results: ${PASS}/${TOTAL} passed, ${FAIL} failed"

if [[ "${FAIL}" -gt 0 ]]; then
  exit 1
fi
exit 0
