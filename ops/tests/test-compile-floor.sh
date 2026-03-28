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

assert_output_contains() {
  local label="$1"
  local output="$2"
  local expected="$3"
  TOTAL=$((TOTAL + 1))
  if echo "${output}" | grep -qi "${expected}"; then
    echo -e "  ${GREEN}PASS${NC} ${label}"
    PASS=$((PASS + 1))
  else
    echo -e "  ${RED}FAIL${NC} ${label} — expected output to contain '${expected}'"
    FAIL=$((FAIL + 1))
  fi
}

# ---------------------------------------------------------------------------
# Drift test helpers
# ---------------------------------------------------------------------------

setup_drift_env() {
  local base_dir="$1"
  DRIFT_DIR="$(mktemp -d "${base_dir}/drift-XXXXXX")"
  mkdir -p "${DRIFT_DIR}/floors"
  cp "${FIXTURES}/floor-valid.md" "${DRIFT_DIR}/floors/compliance.md"
  cat > "${DRIFT_DIR}/fleet-config.json" <<DEOF
{
  "floors": {
    "compliance": {
      "file": "floors/compliance.md",
      "compiled_dir": ".claude/floors/compliance/compiled"
    }
  }
}
DEOF
  pushd "${DRIFT_DIR}" >/dev/null
  "${COMPILER}" >/dev/null 2>&1
  popd >/dev/null
}

setup_multifloor_env() {
  local base_dir="$1"
  DRIFT_DIR="$(mktemp -d "${base_dir}/multifloor-XXXXXX")"
  mkdir -p "${DRIFT_DIR}/floors"
  cp "${FIXTURES}/floor-valid.md" "${DRIFT_DIR}/floors/compliance.md"
  cat > "${DRIFT_DIR}/floors/behavioral.md" <<BEOF
# Behavioral Floor

We MUST ALWAYS run full validation before handoff.
We MUST NEVER skip the findings loop on notable events.
BEOF
  cat > "${DRIFT_DIR}/fleet-config.json" <<MEOF
{
  "floors": {
    "compliance": {
      "file": "floors/compliance.md",
      "compiled_dir": ".claude/floors/compliance/compiled"
    },
    "behavioral": {
      "file": "floors/behavioral.md",
      "compiled_dir": ".claude/floors/behavioral/compiled"
    }
  }
}
MEOF
  pushd "${DRIFT_DIR}" >/dev/null
  "${COMPILER}" --all >/dev/null 2>&1
  popd >/dev/null
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

assert_file_exists "prose file generated" "$PROSEDIR/floor-valid.prose.md"
assert_not_contains "prose has no enforcement blocks" "$PROSEDIR/floor-valid.prose.md" '```enforcement'
assert_contains "prose retains rule 1 text" "$PROSEDIR/floor-valid.prose.md" "No hardcoded secrets"
assert_contains "prose retains rule 2 text" "$PROSEDIR/floor-valid.prose.md" "No console.log"
assert_contains "prose retains rule 3 text" "$PROSEDIR/floor-valid.prose.md" "All data changes are auditable"

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
# Section: Semgrep/ESLint
# ---------------------------------------------------------------------------

echo ""
echo "=== Semgrep/ESLint ==="

SEMGREP_DIR="${TMPDIR_ROOT}/semgrep"
mkdir -p "${SEMGREP_DIR}"

# Create stub rule-path files so validation passes (the compiler checks file existence)
mkdir -p "${SEMGREP_DIR}/.claude/compliance/semgrep" "${SEMGREP_DIR}/.claude/compliance/eslint"
touch "${SEMGREP_DIR}/.claude/compliance/semgrep/no-hardcoded-secrets.yaml"
touch "${SEMGREP_DIR}/.claude/compliance/eslint/no-eval.json"

# Compile the semgrep fixture → exit 0
semgrep_compile_exit=0
pushd "${SEMGREP_DIR}" >/dev/null
"${COMPILER}" "${FIXTURES}/floor-with-semgrep.md" "${SEMGREP_DIR}" >/dev/null 2>&1 || semgrep_compile_exit=$?
popd >/dev/null
assert_exit "semgrep fixture compiles exit 0" 0 "${semgrep_compile_exit}"

# Assert: semgrep-rules.yaml exists and contains "no-hardcoded-secrets"
assert_file_exists "semgrep-rules.yaml exists" "${SEMGREP_DIR}/semgrep-rules.yaml"
assert_contains "semgrep-rules.yaml contains no-hardcoded-secrets" \
  "${SEMGREP_DIR}/semgrep-rules.yaml" "no-hardcoded-secrets"

# Assert: eslint-rules.json exists and contains "no-eval"
assert_file_exists "eslint-rules.json exists" "${SEMGREP_DIR}/eslint-rules.json"
assert_contains "eslint-rules.json contains no-eval" \
  "${SEMGREP_DIR}/eslint-rules.json" "no-eval"

# Assert: semgrep-rules.yaml has GENERATED header
assert_contains "semgrep-rules.yaml has GENERATED header" \
  "${SEMGREP_DIR}/semgrep-rules.yaml" "GENERATED by ops/compile-floor.sh"

# Assert: enforce.sh contains semgrep check (graceful skip if not installed)
assert_contains "enforce.sh contains semgrep invocation" \
  "${SEMGREP_DIR}/enforce.sh" "semgrep"

# ---------------------------------------------------------------------------
# Section: Custom Script
# ---------------------------------------------------------------------------

echo ""
echo "=== Custom Script ==="

CUSTOM_DIR="${TMPDIR_ROOT}/custom"
mkdir -p "${CUSTOM_DIR}"

# Compile the custom-script fixture → exit 0
custom_compile_exit=0
"${COMPILER}" "${FIXTURES}/floor-with-custom-script.md" "${CUSTOM_DIR}" >/dev/null 2>&1 || custom_compile_exit=$?
assert_exit "custom-script fixture compiles exit 0" 0 "${custom_compile_exit}"

# Assert: enforce.sh contains "timeout 10" wrapper
assert_contains "enforce.sh contains timeout 10" \
  "${CUSTOM_DIR}/enforce.sh" "timeout 10"

# Functional: file with FIXME → exit 2 (blocked)
chmod +x "${CUSTOM_DIR}/enforce.sh"
FIXME_FILE="${CUSTOM_DIR}/bad-file.txt"
printf 'FIXME: this needs fixing\n' > "${FIXME_FILE}"
custom_fixme_exit=0
"${CUSTOM_DIR}/enforce.sh" pre-tool-use "${FIXME_FILE}" || custom_fixme_exit=$?
assert_exit "custom-script: file with FIXME → exit 2 (blocked)" 2 "${custom_fixme_exit}"

# Functional: clean file → exit 0 (passes)
CLEAN_FILE="${CUSTOM_DIR}/clean-file.txt"
printf 'all good here\n' > "${CLEAN_FILE}"
custom_clean_exit=0
"${CUSTOM_DIR}/enforce.sh" pre-tool-use "${CLEAN_FILE}" || custom_clean_exit=$?
assert_exit "custom-script: clean file → exit 0 (passes)" 0 "${custom_clean_exit}"

# ---------------------------------------------------------------------------
# Section: New Validation Gaps (C1, C2, X6)
# ---------------------------------------------------------------------------

echo ""
echo "=== New Validation ==="

# C1: Check type at wrong enforcement point (file-pattern at post-tool-use)
val_wrongpoint_exit=0
"${COMPILER}" --validate-only "${FIXTURES}/floor-invalid-wrong-point.md" >/dev/null 2>&1 || val_wrongpoint_exit=$?
assert_exit "file-pattern at post-tool-use rejected (exit 2)" 2 "${val_wrongpoint_exit}"

# X6: skip field rejected
val_skip_exit=0
"${COMPILER}" --validate-only "${FIXTURES}/floor-invalid-skip.md" >/dev/null 2>&1 || val_skip_exit=$?
assert_exit "skip field rejected (exit 2)" 2 "${val_skip_exit}"

# X6: override field rejected
val_override_exit=0
"${COMPILER}" --validate-only "${FIXTURES}/floor-invalid-override.md" >/dev/null 2>&1 || val_override_exit=$?
assert_exit "override field rejected (exit 2)" 2 "${val_override_exit}"

# C2: rule-path inside enforcement point validated (missing file)
val_missingrp_exit=0
"${COMPILER}" --validate-only "${FIXTURES}/floor-invalid-missing-rulepath.md" >/dev/null 2>&1 || val_missingrp_exit=$?
assert_exit "missing rule-path file rejected (exit 2)" 2 "${val_missingrp_exit}"

# ---------------------------------------------------------------------------
# Section: ESLint Enforcement
# ---------------------------------------------------------------------------

echo ""
echo "=== ESLint Enforcement ==="

ESLINT_DIR="${TMPDIR_ROOT}/eslint"
mkdir -p "${ESLINT_DIR}"

# Create stub rule-path files so validation passes
mkdir -p "${ESLINT_DIR}/.claude/compliance/eslint"
touch "${ESLINT_DIR}/.claude/compliance/eslint/no-eval.json"

eslint_compile_exit=0
pushd "${ESLINT_DIR}" >/dev/null
"${COMPILER}" "${FIXTURES}/floor-with-eslint.md" "${ESLINT_DIR}" >/dev/null 2>&1 || eslint_compile_exit=$?
popd >/dev/null
assert_exit "eslint fixture compiles exit 0" 0 "${eslint_compile_exit}"

assert_file_exists "eslint enforce.sh exists" "${ESLINT_DIR}/enforce.sh"
assert_contains "enforce.sh contains eslint invocation" \
  "${ESLINT_DIR}/enforce.sh" "eslint"
assert_contains "enforce.sh contains no-eval eslint rule" \
  "${ESLINT_DIR}/enforce.sh" "no.eval"

# ---------------------------------------------------------------------------
# Section: Per-rule Pass Logging (C9)
# ---------------------------------------------------------------------------

echo ""
echo "=== Per-rule Pass Logging ==="

PASSLOG_DIR="${TMPDIR_ROOT}/passlog"
mkdir -p "${PASSLOG_DIR}"

passlog_compile_exit=0
"${COMPILER}" --generate-enforce "${FIXTURES}/floor-valid.md" "${PASSLOG_DIR}" >/dev/null 2>&1 || passlog_compile_exit=$?
assert_exit "generate-enforce for pass logging exits 0" 0 "${passlog_compile_exit}"

# enforce.sh should contain per-rule log_pass calls (not just "all")
assert_contains "enforce.sh has per-rule log_pass for no-hardcoded-secrets" \
  "${PASSLOG_DIR}/enforce.sh" 'log_pass "no-hardcoded-secrets"'
assert_contains "enforce.sh has per-rule log_pass for no-console-log" \
  "${PASSLOG_DIR}/enforce.sh" 'log_pass "no-console-log"'
assert_not_contains "enforce.sh does not have aggregate log_pass all" \
  "${PASSLOG_DIR}/enforce.sh" 'log_pass "all"'

# ---------------------------------------------------------------------------
# Section: Network Isolation (C6)
# ---------------------------------------------------------------------------

echo ""
echo "=== Network Isolation ==="

NETISO_DIR="${TMPDIR_ROOT}/netiso"
mkdir -p "${NETISO_DIR}"

netiso_compile_exit=0
"${COMPILER}" "${FIXTURES}/floor-with-custom-script.md" "${NETISO_DIR}" >/dev/null 2>&1 || netiso_compile_exit=$?
assert_exit "custom-script with network isolation compiles exit 0" 0 "${netiso_compile_exit}"

assert_contains "enforce.sh contains unshare --net" \
  "${NETISO_DIR}/enforce.sh" "unshare --net"

# ---------------------------------------------------------------------------
# Section: Line Numbers in Errors (C4)
# ---------------------------------------------------------------------------

echo ""
echo "=== Error Context ==="

# Validation errors should include line numbers
val_errctx_output=""
val_errctx_output=$("${COMPILER}" --validate-only "${FIXTURES}/floor-invalid-wrong-point.md" 2>&1 || true)
TOTAL=$((TOTAL + 1))
if echo "${val_errctx_output}" | grep -q "line"; then
  echo -e "  ${GREEN}PASS${NC} validation error includes line number"
  PASS=$((PASS + 1))
else
  echo -e "  ${RED}FAIL${NC} validation error should include line number, got: ${val_errctx_output}"
  FAIL=$((FAIL + 1))
fi

# Validation errors should include rule id
TOTAL=$((TOTAL + 1))
if echo "${val_errctx_output}" | grep -q "wrong-point-test"; then
  echo -e "  ${GREEN}PASS${NC} validation error includes rule id"
  PASS=$((PASS + 1))
else
  echo -e "  ${RED}FAIL${NC} validation error should include rule id, got: ${val_errctx_output}"
  FAIL=$((FAIL + 1))
fi

# ---------------------------------------------------------------------------
# Section: End-to-End
# ---------------------------------------------------------------------------

echo ""
echo "=== End-to-End ==="

E2E_DIR="${TMPDIR_ROOT}/e2e"
mkdir -p "${E2E_DIR}"

# Step 1: Full compile with --proposal e2e-001 on valid fixture
e2e_compile_exit=0
"${COMPILER}" --proposal e2e-001 "${FIXTURES}/floor-valid.md" "${E2E_DIR}" >/dev/null 2>&1 || e2e_compile_exit=$?
assert_exit "e2e: full compile with --proposal e2e-001 exits 0" 0 "${e2e_compile_exit}"

# Step 2: Assert all artifacts exist
assert_file_exists "e2e: prose file exists" "${E2E_DIR}/floor-valid.prose.md"
assert_file_exists "e2e: enforce.sh exists" "${E2E_DIR}/enforce.sh"
assert_file_exists "e2e: manifest.sha256 exists" "${E2E_DIR}/manifest.sha256"
assert_file_exists "e2e: semgrep-rules.yaml exists" "${E2E_DIR}/semgrep-rules.yaml"
assert_file_exists "e2e: eslint-rules.json exists" "${E2E_DIR}/eslint-rules.json"

# Step 3: Verify mode passes (exit 0) on freshly compiled artifacts
e2e_verify_pass_exit=0
"${COMPILER}" --verify "${FIXTURES}/floor-valid.md" "${E2E_DIR}" >/dev/null 2>&1 || e2e_verify_pass_exit=$?
assert_exit "e2e: --verify on fresh artifacts exits 0" 0 "${e2e_verify_pass_exit}"

# Step 4: Tamper with enforce.sh
printf '\n# e2e tamper\n' >> "${E2E_DIR}/enforce.sh"

# Step 5: Verify mode catches tampering (exit 1)
e2e_verify_tamper_exit=0
"${COMPILER}" --verify "${FIXTURES}/floor-valid.md" "${E2E_DIR}" >/dev/null 2>&1 || e2e_verify_tamper_exit=$?
assert_exit "e2e: --verify on tampered enforce.sh exits 1" 1 "${e2e_verify_tamper_exit}"

# Step 6: Recompile with --proposal e2e-002 (fixes tampered artifacts)
e2e_recompile_exit=0
"${COMPILER}" --proposal e2e-002 "${FIXTURES}/floor-valid.md" "${E2E_DIR}" >/dev/null 2>&1 || e2e_recompile_exit=$?
assert_exit "e2e: recompile with --proposal e2e-002 exits 0" 0 "${e2e_recompile_exit}"

# Step 7: Verify mode passes again after recompile (exit 0)
e2e_verify_final_exit=0
"${COMPILER}" --verify "${FIXTURES}/floor-valid.md" "${E2E_DIR}" >/dev/null 2>&1 || e2e_verify_final_exit=$?
assert_exit "e2e: --verify after recompile exits 0" 0 "${e2e_verify_final_exit}"

# ---------------------------------------------------------------------------
# Section: Fleet-Config Default Resolution
# ---------------------------------------------------------------------------

echo ""
echo "=== Fleet-Config Default Resolution ==="

FCDIR="${TMPDIR_ROOT}/fleet-config-test"
mkdir -p "${FCDIR}/floors"

# Create a minimal fleet-config.json
cat > "${FCDIR}/fleet-config.json" <<'FCEOF'
{
  "floors": {
    "compliance": {
      "file": "floors/compliance.md",
      "compiled_dir": ".claude/floors/compliance/compiled"
    }
  }
}
FCEOF

# Copy valid fixture as the floor file
cp "${FIXTURES}/floor-valid.md" "${FCDIR}/floors/compliance.md"

# Run compiler from inside the FCDIR (so it finds fleet-config.json)
pushd "${FCDIR}" >/dev/null
fc_compile_exit=0
"${COMPILER}" >/dev/null 2>&1 || fc_compile_exit=$?
popd >/dev/null
assert_exit "fleet-config: compile with fleet-config.json exits 0" 0 "${fc_compile_exit}"

# Check that the output went to the fleet-config-specified directory
assert_file_exists "fleet-config: enforce.sh in fleet-config dir" "${FCDIR}/.claude/floors/compliance/compiled/enforce.sh"
assert_file_exists "fleet-config: prose in fleet-config dir" "${FCDIR}/.claude/floors/compliance/compiled/compliance.prose.md"

# ---------------------------------------------------------------------------
# Section: Floor-Agnostic Prose Naming
# ---------------------------------------------------------------------------

echo ""
echo "=== Floor-Agnostic Prose Naming ==="

AGNOSTIC_DIR="${TMPDIR_ROOT}/agnostic"
mkdir -p "${AGNOSTIC_DIR}"

# Compile with a non-standard floor file name
agnostic_exit=0
"${COMPILER}" "${FIXTURES}/floor-valid.md" "${AGNOSTIC_DIR}" >/dev/null 2>&1 || agnostic_exit=$?
assert_exit "agnostic: compile exits 0" 0 "${agnostic_exit}"

# Prose file should be named after the input file, not hardcoded
assert_file_exists "agnostic: floor-valid.prose.md exists" "${AGNOSTIC_DIR}/floor-valid.prose.md"
assert_file_not_exists "agnostic: no compliance-floor.prose.md" "${AGNOSTIC_DIR}/compliance-floor.prose.md"

# Manifest should reference floor-valid.prose.md
assert_contains "agnostic: manifest references floor-valid.prose.md" \
  "${AGNOSTIC_DIR}/manifest.sha256" "floor-valid\\.prose\\.md:"

# ---------------------------------------------------------------------------
# Section: --all Flag (compile-all)
# ---------------------------------------------------------------------------

echo ""
echo "=== --all Flag ==="

ALLDIR="${TMPDIR_ROOT}/all-test"
mkdir -p "${ALLDIR}/floors"

# Create fleet-config.json with two floors
cat > "${ALLDIR}/fleet-config.json" <<'ALLEOF'
{
  "floors": {
    "compliance": {
      "file": "floors/compliance.md",
      "compiled_dir": ".claude/floors/compliance/compiled"
    },
    "behavioral": {
      "file": "floors/behavioral.md",
      "compiled_dir": ".claude/floors/behavioral/compiled"
    }
  }
}
ALLEOF

# Copy valid fixture as both floor files
cp "${FIXTURES}/floor-valid.md" "${ALLDIR}/floors/compliance.md"
cp "${FIXTURES}/floor-valid.md" "${ALLDIR}/floors/behavioral.md"

# Run --all from inside the test dir
pushd "${ALLDIR}" >/dev/null
all_compile_exit=0
"${COMPILER}" --all >/dev/null 2>&1 || all_compile_exit=$?
popd >/dev/null
assert_exit "--all: compile exits 0" 0 "${all_compile_exit}"

# Check artifacts exist for both floors
assert_file_exists "--all: compliance enforce.sh" "${ALLDIR}/.claude/floors/compliance/compiled/enforce.sh"
assert_file_exists "--all: compliance prose" "${ALLDIR}/.claude/floors/compliance/compiled/compliance.prose.md"
assert_file_exists "--all: behavioral enforce.sh" "${ALLDIR}/.claude/floors/behavioral/compiled/enforce.sh"
assert_file_exists "--all: behavioral prose" "${ALLDIR}/.claude/floors/behavioral/compiled/behavioral.prose.md"

# Test --all with missing floor file (should warn and skip, not fail)
rm "${ALLDIR}/floors/behavioral.md"
pushd "${ALLDIR}" >/dev/null
all_skip_exit=0
all_skip_output=$("${COMPILER}" --all 2>&1) || all_skip_exit=$?
popd >/dev/null
assert_exit "--all: skips missing floor without failing" 0 "${all_skip_exit}"

TOTAL=$((TOTAL + 1))
if echo "${all_skip_output}" | grep -q "WARNING.*behavioral"; then
  echo -e "  ${GREEN}PASS${NC} --all: warns about missing behavioral floor"
  PASS=$((PASS + 1))
else
  echo -e "  ${RED}FAIL${NC} --all: should warn about missing behavioral floor"
  FAIL=$((FAIL + 1))
fi

# ---------------------------------------------------------------------------
# Section: Pre-Flight Checks
# ---------------------------------------------------------------------------

echo ""
echo "=== Pre-Flight Checks ==="

# Test A: First compile (expected) — no compiled dir exists yet
PFDIR_A="${TMPDIR_ROOT}/preflight-a"
mkdir -p "${PFDIR_A}/floors"
cat > "${PFDIR_A}/fleet-config.json" <<'PFAEOF'
{
  "floors": {
    "compliance": {
      "file": "floors/compliance.md",
      "compiled_dir": ".claude/floors/compliance/compiled"
    }
  }
}
PFAEOF
cp "${FIXTURES}/floor-valid.md" "${PFDIR_A}/floors/compliance.md"

pushd "${PFDIR_A}" >/dev/null
pfa_output=$("${COMPILER}" 2>&1) || true
pfa_exit=$?
popd >/dev/null
assert_exit "preflight-a: first compile exits 0" 0 "${pfa_exit}"
assert_output_contains "preflight-a: output mentions first compile" "${pfa_output}" "first compile"
assert_file_exists "preflight-a: manifest created" "${PFDIR_A}/.claude/floors/compliance/compiled/manifest.sha256"

# Test B: Unexpected — delete enforce.sh, recompile
rm -f "${PFDIR_A}/.claude/floors/compliance/compiled/enforce.sh"
pushd "${PFDIR_A}" >/dev/null
pfb_output=$("${COMPILER}" 2>&1) || true
pfb_exit=$?
popd >/dev/null
assert_exit "preflight-b: recompile after deleting enforce.sh exits 0" 0 "${pfb_exit}"
assert_output_contains "preflight-b: output mentions WARNING" "${pfb_output}" "WARNING"

# Test C: Unexpected — delete manifest, leave artifacts
rm -f "${PFDIR_A}/.claude/floors/compliance/compiled/manifest.sha256"
pushd "${PFDIR_A}" >/dev/null
pfc_output=$("${COMPILER}" 2>&1) || true
pfc_exit=$?
popd >/dev/null
assert_exit "preflight-c: recompile after deleting manifest exits 0" 0 "${pfc_exit}"
assert_output_contains "preflight-c: output mentions WARNING" "${pfc_output}" "WARNING"

# Test D: Expected — edit floor file (source hash mismatch)
# First do a clean compile
pushd "${PFDIR_A}" >/dev/null
"${COMPILER}" >/dev/null 2>&1 || true
popd >/dev/null
# Now modify the floor file
echo "# additional rule" >> "${PFDIR_A}/floors/compliance.md"
pushd "${PFDIR_A}" >/dev/null
pfd_output=$("${COMPILER}" 2>&1) || true
pfd_exit=$?
popd >/dev/null
assert_exit "preflight-d: recompile after editing floor exits 0" 0 "${pfd_exit}"
assert_output_contains "preflight-d: output mentions source has changed" "${pfd_output}" "source has changed"

# ===========================================================================
# Drift Detection Tests (#32)
# ===========================================================================

echo ""
echo "=== Drift Detection Tests ==="
DRIFT_TMP="$(mktemp -d)"

# --- Test: Clean first compile (no prior artifacts) ---
echo "--- clean first compile ---"
CLEAN_DIR="$(mktemp -d "${DRIFT_TMP}/clean-XXXXXX")"
mkdir -p "${CLEAN_DIR}/floors"
cp "${FIXTURES}/floor-valid.md" "${CLEAN_DIR}/floors/compliance.md"
cat > "${CLEAN_DIR}/fleet-config.json" <<CFEOF
{
  "floors": {
    "compliance": {
      "file": "floors/compliance.md",
      "compiled_dir": ".claude/floors/compliance/compiled"
    }
  }
}
CFEOF

pushd "${CLEAN_DIR}" >/dev/null
clean_output=$("${COMPILER}" 2>&1) || true
clean_exit=$?
popd >/dev/null
assert_exit "drift: clean first compile exits 0" 0 "${clean_exit}"
assert_output_contains "drift: first compile message" "${clean_output}" "first compile"
assert_file_exists "drift: manifest created on first compile" "${CLEAN_DIR}/.claude/floors/compliance/compiled/manifest.sha256"
assert_file_exists "drift: enforce.sh created on first compile" "${CLEAN_DIR}/.claude/floors/compliance/compiled/enforce.sh"

# --- Test: All artifacts present and valid (re-compile is idempotent) ---
echo "--- all artifacts valid (idempotent re-compile) ---"
pushd "${CLEAN_DIR}" >/dev/null
valid_output=$("${COMPILER}" 2>&1) || true
valid_exit=$?
popd >/dev/null
assert_exit "drift: idempotent re-compile exits 0" 0 "${valid_exit}"

# --- Test: Artifacts deleted after successful compile ---
echo "--- artifacts deleted after compile ---"
setup_drift_env "${DRIFT_TMP}"
rm -f "${DRIFT_DIR}/.claude/floors/compliance/compiled/enforce.sh"
pushd "${DRIFT_DIR}" >/dev/null
del_output=$("${COMPILER}" 2>&1) || true
del_exit=$?
popd >/dev/null
assert_exit "drift: recompile after artifact deletion exits 0" 0 "${del_exit}"
assert_output_contains "drift: WARNING on missing artifact" "${del_output}" "WARNING"
assert_file_exists "drift: enforce.sh restored after deletion" "${DRIFT_DIR}/.claude/floors/compliance/compiled/enforce.sh"

# --- Test: Manifest deleted, artifacts remain ---
echo "--- manifest deleted, artifacts remain ---"
setup_drift_env "${DRIFT_TMP}"
rm -f "${DRIFT_DIR}/.claude/floors/compliance/compiled/manifest.sha256"
pushd "${DRIFT_DIR}" >/dev/null
mani_output=$("${COMPILER}" 2>&1) || true
mani_exit=$?
popd >/dev/null
assert_exit "drift: recompile after manifest deletion exits 0" 0 "${mani_exit}"
assert_output_contains "drift: WARNING on missing manifest" "${mani_output}" "WARNING"
assert_file_exists "drift: manifest restored" "${DRIFT_DIR}/.claude/floors/compliance/compiled/manifest.sha256"

# --- Test: Partial compilation (prose exists, enforce.sh missing) ---
echo "--- partial compilation state ---"
setup_drift_env "${DRIFT_TMP}"
rm -f "${DRIFT_DIR}/.claude/floors/compliance/compiled/enforce.sh"
pushd "${DRIFT_DIR}" >/dev/null
partial_output=$("${COMPILER}" 2>&1) || true
partial_exit=$?
popd >/dev/null
assert_exit "drift: partial state recompile exits 0" 0 "${partial_exit}"
assert_file_exists "drift: enforce.sh restored from partial state" "${DRIFT_DIR}/.claude/floors/compliance/compiled/enforce.sh"

# --- Test: Checksum mismatch (artifact hand-edited) ---
echo "--- checksum mismatch (hand-edited artifact) ---"
setup_drift_env "${DRIFT_TMP}"
echo "# hand-edited" >> "${DRIFT_DIR}/.claude/floors/compliance/compiled/enforce.sh"
pushd "${DRIFT_DIR}" >/dev/null
tamper_exit=0
tamper_output=$("${COMPILER}" --verify 2>&1) || tamper_exit=$?
popd >/dev/null
assert_exit "drift: --verify detects tampered artifact (exit 1)" 1 "${tamper_exit}"
assert_output_contains "drift: DRIFT message on tampered artifact" "${tamper_output}" "DRIFT"

# --- Test: Floor source changed, artifacts stale ---
echo "--- floor source changed, artifacts stale ---"
setup_drift_env "${DRIFT_TMP}"
echo "# new rule added" >> "${DRIFT_DIR}/floors/compliance.md"
pushd "${DRIFT_DIR}" >/dev/null
src_exit=0
src_output=$("${COMPILER}" --verify 2>&1) || src_exit=$?
popd >/dev/null
assert_exit "drift: --verify detects source change (exit 1)" 1 "${src_exit}"
assert_output_contains "drift: DRIFT message on source change" "${src_output}" "DRIFT"

# --- Test: Source changed, recompile updates artifacts ---
echo "--- source changed, recompile updates ---"
pushd "${DRIFT_DIR}" >/dev/null
recomp_output=$("${COMPILER}" 2>&1) || true
recomp_exit=$?
popd >/dev/null
assert_exit "drift: recompile after source change exits 0" 0 "${recomp_exit}"
assert_output_contains "drift: source has changed message" "${recomp_output}" "source has changed"
# Verify is now clean
pushd "${DRIFT_DIR}" >/dev/null
reverify_exit=0
reverify_output=$("${COMPILER}" --verify 2>&1) || reverify_exit=$?
popd >/dev/null
assert_exit "drift: --verify clean after recompile" 0 "${reverify_exit}"

# --- Test: --all with one floor drifted, one clean ---
echo "--- multi-floor: one drifted, one clean ---"
setup_multifloor_env "${DRIFT_TMP}"
echo "# drift injection" >> "${DRIFT_DIR}/floors/compliance.md"
pushd "${DRIFT_DIR}" >/dev/null
multi_output=$("${COMPILER}" --all 2>&1) || true
multi_exit=$?
popd >/dev/null
assert_exit "drift: --all with partial drift exits 0" 0 "${multi_exit}"
assert_output_contains "drift: --all mentions compliance" "${multi_output}" "compliance"
assert_output_contains "drift: --all mentions behavioral" "${multi_output}" "behavioral"

# --- Test: --verify on clean multi-floor environment ---
echo "--- multi-floor: --verify on clean state ---"
setup_multifloor_env "${DRIFT_TMP}"
pushd "${DRIFT_DIR}" >/dev/null
mverify_exit=0
mverify_output=$("${COMPILER}" --floor compliance --verify 2>&1) || mverify_exit=$?
popd >/dev/null
assert_exit "drift: --verify clean on multi-floor exits 0" 0 "${mverify_exit}"

# --- Test: --verify detects drift in one floor of multi-floor ---
echo "--- multi-floor: --verify detects single-floor drift ---"
echo "# drift" >> "${DRIFT_DIR}/floors/compliance.md"
pushd "${DRIFT_DIR}" >/dev/null
mverify_drift_exit=0
mverify_drift_output=$("${COMPILER}" --floor compliance --verify 2>&1) || mverify_drift_exit=$?
popd >/dev/null
assert_exit "drift: --verify detects drift in one floor (exit 1)" 1 "${mverify_drift_exit}"
assert_output_contains "drift: DRIFT in compliance floor" "${mverify_drift_output}" "DRIFT"

# Cleanup drift temp
rm -rf "${DRIFT_TMP}"

# ---------------------------------------------------------------------------
# Results summary
# ---------------------------------------------------------------------------

echo ""
echo "Results: ${PASS}/${TOTAL} passed, ${FAIL} failed"

if [[ "${FAIL}" -gt 0 ]]; then
  exit 1
fi
exit 0
