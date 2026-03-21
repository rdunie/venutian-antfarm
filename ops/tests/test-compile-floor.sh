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
# Section: Manifest + Verify
# ---------------------------------------------------------------------------

echo ""
echo "=== Manifest + Verify ==="

MANIFESTDIR="${TMPDIR_ROOT}/manifest"
mkdir -p "${MANIFESTDIR}"

# Run full compile with --proposal test-001 on valid fixture
manifest_compile_exit=0
"${COMPILER}" --proposal test-001 "${FIXTURES}/floor-valid.md" "${MANIFESTDIR}" >/dev/null 2>&1 || manifest_compile_exit=$?
assert_exit "full compile with --proposal exits 0" 0 "${manifest_compile_exit}"

# Assert: manifest.sha256 exists
assert_file_exists "manifest.sha256 exists" "${MANIFESTDIR}/manifest.sha256"

# Assert: manifest contains "source:" line
assert_contains "manifest contains source: line" "${MANIFESTDIR}/manifest.sha256" "^source:"

# Assert: manifest contains proposal ID "test-001"
assert_contains "manifest contains test-001 proposal ID" "${MANIFESTDIR}/manifest.sha256" "test-001"

# Assert: manifest contains enforce.sh artifact hash
assert_contains "manifest contains enforce.sh artifact hash" "${MANIFESTDIR}/manifest.sha256" "enforce\.sh:"

# Verify mode: run --verify against same floor + output dir → exit 0
verify_pass_exit=0
"${COMPILER}" --verify "${FIXTURES}/floor-valid.md" "${MANIFESTDIR}" >/dev/null 2>&1 || verify_pass_exit=$?
assert_exit "--verify on unmodified artifacts exits 0" 0 "${verify_pass_exit}"

# Tamper: append "# tampered" to enforce.sh, run --verify again → exit 1
printf '\n# tampered\n' >> "${MANIFESTDIR}/enforce.sh"
verify_fail_exit=0
"${COMPILER}" --verify "${FIXTURES}/floor-valid.md" "${MANIFESTDIR}" >/dev/null 2>&1 || verify_fail_exit=$?
assert_exit "--verify on tampered artifacts exits 1" 1 "${verify_fail_exit}"

# ---------------------------------------------------------------------------
# Section: Coverage Report
# ---------------------------------------------------------------------------

echo ""
echo "=== Coverage Report ==="

COVERAGEDIR="${TMPDIR_ROOT}/coverage"
mkdir -p "${COVERAGEDIR}"
COVERAGE_PATH="${COVERAGEDIR}/compliance-coverage.md"

# Run full compile with COVERAGE_PATH env var set
coverage_exit=0
COVERAGE_PATH="${COVERAGE_PATH}" "${COMPILER}" "${FIXTURES}/floor-valid.md" "${COVERAGEDIR}" >/dev/null 2>&1 || coverage_exit=$?
assert_exit "full compile with COVERAGE_PATH exits 0" 0 "${coverage_exit}"

# Assert: coverage report file exists at COVERAGE_PATH
assert_file_exists "coverage report file exists at COVERAGE_PATH" "${COVERAGE_PATH}"

# Assert: contains "no-hardcoded-secrets" rule ID
assert_contains "coverage report contains no-hardcoded-secrets" "${COVERAGE_PATH}" "no-hardcoded-secrets"

# Assert: contains "pre-tool-use" enforcement point
assert_contains "coverage report contains pre-tool-use" "${COVERAGE_PATH}" "pre-tool-use"

# Assert: contains "What Each Layer Guarantees" trust summary
assert_contains "coverage report contains What Each Layer Guarantees" "${COVERAGE_PATH}" "What Each Layer Guarantees"

# Assert: contains "judgment-only" (for rule 3 which has no enforcement block)
assert_contains "coverage report contains judgment-only" "${COVERAGE_PATH}" "judgment-only"

# ---------------------------------------------------------------------------
# Section: Dry Run
# ---------------------------------------------------------------------------

echo ""
echo "=== Dry Run ==="

DRYRUNDIR="${TMPDIR_ROOT}/dryrun"
mkdir -p "${DRYRUNDIR}"

# Run --dry-run on valid fixture → exit 0
dryrun_valid_exit=0
dryrun_output=$("${COMPILER}" --dry-run "${FIXTURES}/floor-valid.md" "${DRYRUNDIR}" 2>/dev/null) || dryrun_valid_exit=$?
assert_exit "--dry-run on valid fixture exits 0" 0 "${dryrun_valid_exit}"

# Capture stdout, assert it contains "no-hardcoded-secrets"
TOTAL=$((TOTAL + 1))
if echo "${dryrun_output}" | grep -q "no-hardcoded-secrets"; then
  echo -e "  ${GREEN}PASS${NC} --dry-run stdout contains no-hardcoded-secrets"
  PASS=$((PASS + 1))
else
  echo -e "  ${RED}FAIL${NC} --dry-run stdout contains no-hardcoded-secrets — not found in output"
  FAIL=$((FAIL + 1))
fi

# Assert: --dry-run writes no files
assert_file_not_exists "--dry-run writes no block YAML files" "${DRYRUNDIR}/block-001.yaml"
assert_file_not_exists "--dry-run writes no enforce.sh" "${DRYRUNDIR}/enforce.sh"
assert_file_not_exists "--dry-run writes no manifest.sha256" "${DRYRUNDIR}/manifest.sha256"

# Run --dry-run on invalid fixture → exit 2
dryrun_invalid_exit=0
"${COMPILER}" --dry-run "${FIXTURES}/floor-invalid-no-version.md" "${DRYRUNDIR}" >/dev/null 2>&1 || dryrun_invalid_exit=$?
assert_exit "--dry-run on invalid fixture exits 2" 2 "${dryrun_invalid_exit}"

# ---------------------------------------------------------------------------
# Section: Metrics Events
# ---------------------------------------------------------------------------

echo ""
echo "=== Metrics Events ==="

METRICSDIR="$TMPDIR_ROOT/metrics"
mkdir -p "$METRICSDIR"

metrics_exit=0
METRICS_LOG_FILE="$METRICSDIR/events.jsonl" \
  "$REPO_ROOT/ops/metrics-log.sh" compliance-violation \
    --rule-id no-hardcoded-secrets --severity blocking \
    --enforcement-point pre-tool-use --file "secrets.env" \
    --action block >/dev/null 2>&1 || metrics_exit=$?
assert_exit "compliance-violation with structured fields" 0 $metrics_exit

assert_contains "violation event has rule-id" "$METRICSDIR/events.jsonl" '"rule_id"'

metrics_exit=0
METRICS_LOG_FILE="$METRICSDIR/events.jsonl" \
  "$REPO_ROOT/ops/metrics-log.sh" compliance-pass \
    --rule-id no-hardcoded-secrets \
    --enforcement-point pre-tool-use --file "app.js" >/dev/null 2>&1 || metrics_exit=$?
assert_exit "compliance-pass event accepted" 0 $metrics_exit

assert_contains "pass event has rule-id" "$METRICSDIR/events.jsonl" '"rule_id"'

# ---------------------------------------------------------------------------
# Section: Intent Declaration
# ---------------------------------------------------------------------------

echo ""
echo "=== Intent Declaration ==="

INTENT_DIR="${TMPDIR_ROOT}/intent"
mkdir -p "${INTENT_DIR}"

# Generate enforce.sh from valid fixture
intent_gen_exit=0
"${COMPILER}" --generate-enforce "${FIXTURES}/floor-valid.md" "${INTENT_DIR}" >/dev/null 2>&1 || intent_gen_exit=$?
assert_exit "intent: generate-enforce exits 0" 0 "${intent_gen_exit}"
chmod +x "${INTENT_DIR}/enforce.sh"

# Test: compiled artifact path → exit 1 (warn)
intent_compiled_exit=0
"${INTENT_DIR}/enforce.sh" pre-tool-use ".claude/compliance/compiled/enforce.sh" || intent_compiled_exit=$?
assert_exit "intent: compiled artifact → exit 1 (warn)" 1 "${intent_compiled_exit}"

# Test: compiler script → exit 1 (warn)
intent_compiler_exit=0
"${INTENT_DIR}/enforce.sh" pre-tool-use "ops/compile-floor.sh" || intent_compiler_exit=$?
assert_exit "intent: compiler script → exit 1 (warn)" 1 "${intent_compiler_exit}"

# Test: compliance agent def → exit 1 (warn)
intent_agent_exit=0
"${INTENT_DIR}/enforce.sh" pre-tool-use ".claude/agents/compliance-officer.md" || intent_agent_exit=$?
assert_exit "intent: compliance agent def → exit 1 (warn)" 1 "${intent_agent_exit}"

# Test: normal source file → exit 0 (pass through to rule checks)
intent_normal_exit=0
"${INTENT_DIR}/enforce.sh" pre-tool-use "src/app.js" || intent_normal_exit=$?
assert_exit "intent: normal file → exit 0 (pass through)" 0 "${intent_normal_exit}"

# Test: compliance-floor.md with no sentinel → exit 2 (block)
intent_floor_nosent_exit=0
"${INTENT_DIR}/enforce.sh" pre-tool-use "compliance-floor.md" || intent_floor_nosent_exit=$?
assert_exit "intent: compliance-floor.md no sentinel → exit 2 (block)" 2 "${intent_floor_nosent_exit}"

# Test: compliance targets.md with no sentinel → exit 2 (block)
intent_targets_nosent_exit=0
"${INTENT_DIR}/enforce.sh" pre-tool-use ".claude/compliance/targets.md" || intent_targets_nosent_exit=$?
assert_exit "intent: .claude/compliance/targets.md no sentinel → exit 2 (block)" 2 "${intent_targets_nosent_exit}"

# Test: compliance-floor.md with sentinel → exit 1 (warn instead of block)
mkdir -p "${INTENT_DIR}/.claude/compliance"
touch "${INTENT_DIR}/.claude/compliance/.applying"
# Run enforce.sh from inside INTENT_DIR so sentinel path is relative to cwd
pushd "${INTENT_DIR}" >/dev/null
intent_floor_sent_exit=0
"${INTENT_DIR}/enforce.sh" pre-tool-use "compliance-floor.md" || intent_floor_sent_exit=$?
popd >/dev/null
rm -f "${INTENT_DIR}/.claude/compliance/.applying"
assert_exit "intent: compliance-floor.md with sentinel → exit 1 (warn)" 1 "${intent_floor_sent_exit}"

# ---------------------------------------------------------------------------
# Results summary
# ---------------------------------------------------------------------------

echo ""
echo "Results: ${PASS}/${TOTAL} passed, ${FAIL} failed"

if [[ "${FAIL}" -gt 0 ]]; then
  exit 1
fi
exit 0
