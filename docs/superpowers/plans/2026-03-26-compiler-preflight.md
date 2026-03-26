# Compiler Pre-Flight Validation Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add pre-flight environment checks to the compiler's `compile` mode that distinguish expected remediation (first compile) from unexpected remediation (artifacts deleted/corrupted), using the manifest as the signal.

**Architecture:** A single `preflight_check` function (~50-60 lines) added to `compile-floor.sh`, called before extraction in `compile` mode. A new `preflight-remediation` event type added to `metrics-log.sh`. The `compile-all` mode inherits pre-flight via subprocess invocation.

**Tech Stack:** Bash

**Spec:** `docs/superpowers/specs/2026-03-26-compiler-preflight-design.md`

---

## File Structure

### Modified Files

| File                              | Change                                                                    |
| --------------------------------- | ------------------------------------------------------------------------- |
| `ops/compile-floor.sh`            | Add `preflight_check` function, call before extraction in `compile)` mode |
| `ops/metrics-log.sh`              | Add `--floor` and `--detail` args, add `preflight-remediation` event type |
| `ops/tests/test-compile-floor.sh` | Add pre-flight tests                                                      |
| `docs/COMPILER-GUIDE.md`          | Document pre-flight behavior                                              |

---

## Task 1: Add `preflight-remediation` Event to metrics-log.sh

**Files:**

- Modify: `ops/metrics-log.sh`

- [ ] **Step 1: Add `--floor` and `--detail` arg parsing**

In `ops/metrics-log.sh`, add two new args to the `while` loop (around line 84, before the `*)` catch-all):

```bash
    --floor) FLOOR_ARG="$2"; shift 2 ;;
    --detail) DETAIL_ARG="$2"; shift 2 ;;
```

Also add the variable declarations near line 44 (with the other arg vars):

```bash
FLOOR_ARG="" DETAIL_ARG=""
```

- [ ] **Step 2: Add the `preflight-remediation` event handler**

In the event type `case` block (before the error/usage `*` case, around line 360), add:

```bash
  preflight-remediation)
    if [[ -z "${FLOOR_ARG}" ]]; then
      echo "ERROR: preflight-remediation requires --floor" >&2
      exit 1
    fi
    if [[ -z "${DEPLOY_TYPE}" ]]; then
      echo "ERROR: preflight-remediation requires --type (expected|unexpected)" >&2
      exit 1
    fi
    if [[ -z "${DETAIL_ARG}" ]]; then
      echo "ERROR: preflight-remediation requires --detail" >&2
      exit 1
    fi
    emit_event "$(jq -cn --arg ts "$TS" --arg event "$EVENT_TYPE" \
       --arg floor "$FLOOR_ARG" --arg type "$DEPLOY_TYPE" \
       --arg detail "$DETAIL_ARG" --arg agent "$AGENT" \
       '{"ts":$ts,"event":$event,"floor":$floor,"type":$type,"detail":$detail,"agent":$agent} | with_entries(select(.value != ""))')"
    ;;
```

Note: `--type` is already parsed into `DEPLOY_TYPE` (line 57). We reuse it for expected/unexpected.

- [ ] **Step 3: Update the usage/error message**

In the error message that lists valid event types (around line 364), add `preflight-remediation` to the list.

- [ ] **Step 4: Test the new event**

```bash
TMPLOG=$(mktemp) && METRICS_LOG_FILE="$TMPLOG" bash ops/metrics-log.sh preflight-remediation --floor compliance --type unexpected --detail "enforce.sh missing but manifest exists" && cat "$TMPLOG" && rm "$TMPLOG"
```

Expected: JSON line with `event`, `floor`, `type`, `detail` fields.

- [ ] **Step 5: Test validation — missing required args**

```bash
TMPLOG=$(mktemp) && METRICS_LOG_FILE="$TMPLOG" bash ops/metrics-log.sh preflight-remediation --type expected --detail "test" 2>&1; echo "exit: $?"
```

Expected: error about missing `--floor`, exit 1.

- [ ] **Step 6: Commit**

```bash
git add ops/metrics-log.sh
git commit -m "feat(#31): add preflight-remediation event to metrics-log.sh"
```

---

## Task 2: Add `preflight_check` Function to Compiler

**Files:**

- Modify: `ops/compile-floor.sh`
- Modify: `ops/tests/test-compile-floor.sh`

- [ ] **Step 1: Write pre-flight tests**

Add a new test section to `ops/tests/test-compile-floor.sh`:

```bash
# ---------------------------------------------------------------------------
# Test: Pre-flight checks
# ---------------------------------------------------------------------------

echo ""
echo "=== Pre-flight checks ==="

# Test: First compile (expected) — no compiled dir, no manifest
PF_DIR="$(mktemp -d)"
trap_dirs+=("${PF_DIR}")
mkdir -p "${PF_DIR}/floors"
cp "${FIXTURES}/floor-valid.md" "${PF_DIR}/floors/compliance.md"

cat > "${PF_DIR}/fleet-config.json" <<'PFEOF'
{
  "floors": {
    "compliance": {
      "file": "floors/compliance.md",
      "guardian": "cro",
      "compiled_dir": ".claude/floors/compliance/compiled"
    }
  }
}
PFEOF

pushd "${PF_DIR}" > /dev/null
OUTPUT=$(PATH="$HOME/.local/bin:$PATH" METRICS_LOG_FILE=/dev/null ${COMPILER} 2>&1)
ACTUAL_EXIT=$?
popd > /dev/null

assert_exit "preflight: first compile succeeds" 0 "${ACTUAL_EXIT}"
assert_output_contains "preflight: logs first compile info" "${OUTPUT}" "first compile"
assert_file_exists "preflight: creates compiled dir" "${PF_DIR}/.claude/floors/compliance/compiled/manifest.sha256"

# Test: Unexpected — delete enforce.sh after first compile, recompile
rm -f "${PF_DIR}/.claude/floors/compliance/compiled/enforce.sh"

pushd "${PF_DIR}" > /dev/null
OUTPUT=$(PATH="$HOME/.local/bin:$PATH" METRICS_LOG_FILE=/dev/null ${COMPILER} 2>&1)
ACTUAL_EXIT=$?
popd > /dev/null

assert_exit "preflight: recompile after artifact deletion succeeds" 0 "${ACTUAL_EXIT}"
assert_output_contains "preflight: warns about missing artifact" "${OUTPUT}" "WARNING"

# Test: Unexpected — delete manifest but leave artifacts
rm -f "${PF_DIR}/.claude/floors/compliance/compiled/manifest.sha256"

pushd "${PF_DIR}" > /dev/null
OUTPUT=$(PATH="$HOME/.local/bin:$PATH" METRICS_LOG_FILE=/dev/null ${COMPILER} 2>&1)
ACTUAL_EXIT=$?
popd > /dev/null

assert_exit "preflight: recompile after manifest deletion succeeds" 0 "${ACTUAL_EXIT}"
assert_output_contains "preflight: warns about missing manifest with artifacts" "${OUTPUT}" "WARNING"

# Test: Expected — source hash mismatch (floor edited)
echo "# Extra rule added" >> "${PF_DIR}/floors/compliance.md"

pushd "${PF_DIR}" > /dev/null
OUTPUT=$(PATH="$HOME/.local/bin:$PATH" METRICS_LOG_FILE=/dev/null ${COMPILER} 2>&1)
ACTUAL_EXIT=$?
popd > /dev/null

assert_exit "preflight: recompile after floor edit succeeds" 0 "${ACTUAL_EXIT}"
assert_output_contains "preflight: logs source changed" "${OUTPUT}" "source has changed"
```

Note: You'll need to check if `assert_output_contains` exists in the test file. If not, add it:

```bash
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
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
PATH="$HOME/.local/bin:$PATH" bash ops/tests/test-compile-floor.sh 2>&1 | tail -20
```

Expected: new pre-flight tests fail (no `preflight_check` function yet).

- [ ] **Step 3: Write the `preflight_check` function**

Add to `ops/compile-floor.sh` after the `prepare_context` function (before the mode dispatch):

```bash
# ---------------------------------------------------------------------------
# preflight_check — verify floor environment health before compilation
#
# Arguments:
#   $1  floor name (e.g., "compliance")
#   $2  floor file path
#   $3  compiled directory path
#
# Returns 0 (healthy or remediated), 1 (fatal).
# Prints info/warnings to stderr. Logs unexpected events via metrics-log.sh.
# ---------------------------------------------------------------------------

preflight_check() {
  local floor_name="$1"
  local floor_file="$2"
  local compiled_dir="$3"
  local manifest="${compiled_dir}/manifest.sha256"
  local has_manifest=0
  local has_artifacts=0

  # Check compiled directory
  if [[ ! -d "${compiled_dir}" ]]; then
    if [[ -f "${manifest}" ]]; then
      # Impossible state — manifest without dir
      echo "[preflight] WARNING: Floor '${floor_name}': compiled directory missing" >&2
    else
      echo "[preflight] Floor '${floor_name}': first compile — creating ${compiled_dir}/" >&2
    fi
    mkdir -p "${compiled_dir}"
  fi

  # Check manifest existence
  if [[ -f "${manifest}" ]]; then
    has_manifest=1
  fi

  # Check for existing artifacts (any .sh or .md in compiled dir)
  if ls "${compiled_dir}"/*.sh "${compiled_dir}"/*.md 2>/dev/null | grep -q .; then
    has_artifacts=1
  fi

  # Manifest missing but artifacts exist — unexpected
  if [[ "${has_manifest}" -eq 0 && "${has_artifacts}" -eq 1 ]]; then
    echo "[preflight] WARNING: Floor '${floor_name}': manifest.sha256 missing but artifacts exist — manifest may have been deleted" >&2
    if [[ -x "${SCRIPT_DIR}/metrics-log.sh" ]]; then
      "${SCRIPT_DIR}/metrics-log.sh" preflight-remediation \
        --floor "${floor_name}" --type unexpected \
        --detail "manifest missing but artifacts exist" 2>/dev/null || true
    fi
  fi

  # Manifest exists — check source hash and artifacts
  if [[ "${has_manifest}" -eq 1 ]]; then
    # Check source hash
    local recorded_source
    recorded_source="$(grep '^source:' "${manifest}" | awk '{print $2}')"
    local current_source
    current_source="$(sha256sum "${floor_file}" | cut -d' ' -f1)"
    if [[ "${current_source}" != "${recorded_source}" ]]; then
      echo "[preflight] Floor '${floor_name}': source has changed since last compile — will recompile" >&2
    fi

    # Check key artifacts exist
    local base_name
    base_name="$(basename "${floor_file}" .md)"
    local missing_artifacts=""
    if [[ ! -f "${compiled_dir}/enforce.sh" ]]; then
      missing_artifacts="${missing_artifacts} enforce.sh"
    fi
    if [[ ! -f "${compiled_dir}/${base_name}.prose.md" ]]; then
      missing_artifacts="${missing_artifacts} ${base_name}.prose.md"
    fi

    if [[ -n "${missing_artifacts}" ]]; then
      echo "[preflight] WARNING: Floor '${floor_name}':${missing_artifacts} missing but manifest exists — artifacts may have been deleted" >&2
      if [[ -x "${SCRIPT_DIR}/metrics-log.sh" ]]; then
        "${SCRIPT_DIR}/metrics-log.sh" preflight-remediation \
          --floor "${floor_name}" --type unexpected \
          --detail "missing artifacts:${missing_artifacts}" 2>/dev/null || true
      fi
    fi
  fi

  # First compile info (no manifest, no artifacts)
  if [[ "${has_manifest}" -eq 0 && "${has_artifacts}" -eq 0 ]]; then
    echo "[preflight] Floor '${floor_name}': first compile" >&2
    if [[ -x "${SCRIPT_DIR}/metrics-log.sh" ]]; then
      "${SCRIPT_DIR}/metrics-log.sh" preflight-remediation \
        --floor "${floor_name}" --type expected \
        --detail "first compile" 2>/dev/null || true
    fi
  fi

  return 0
}
```

- [ ] **Step 4: Call `preflight_check` in `compile)` mode**

In the `compile)` case (around line 717), add the pre-flight call after the floor file existence check but before extraction:

```bash
  compile)
    if [[ ! -f "${FLOOR_FILE}" ]]; then
      echo "ERROR: Floor file not found: ${FLOOR_FILE}" >&2
      exit 1
    fi

    # Pre-flight environment check
    local pf_base_name
    pf_base_name="$(basename "${FLOOR_FILE}" .md)"
    preflight_check "${FLOOR_NAME:-${pf_base_name}}" "${FLOOR_FILE}" "${OUTPUT_DIR}"

    mkdir -p "${OUTPUT_DIR}"
    ...
```

Note: Move the `mkdir -p "${OUTPUT_DIR}"` AFTER the preflight call (preflight creates the dir if needed).

Note: The `compile-all` mode already handles missing floor files with warn+skip (line 951-953) before invoking the subprocess. The pre-flight call in `compile)` only runs for floors that compile-all has already verified exist. No changes needed to compile-all.

- [ ] **Step 5: Run tests**

```bash
PATH="$HOME/.local/bin:$PATH" bash ops/tests/test-compile-floor.sh 2>&1 | tail -20
```

Expected: all tests pass (existing 111 + new pre-flight tests).

- [ ] **Step 6: Syntax check**

```bash
bash -n ops/compile-floor.sh
```

- [ ] **Step 7: Commit**

```bash
git add ops/compile-floor.sh ops/tests/test-compile-floor.sh
git commit -m "feat(#31): add pre-flight environment checks to compiler"
```

---

## Task 3: Update Compiler Guide

**Files:**

- Modify: `docs/COMPILER-GUIDE.md`

- [ ] **Step 1: Add Pre-Flight section**

After the "Pipeline" section in `docs/COMPILER-GUIDE.md`, add:

```markdown
## Pre-Flight Checks

Before compilation, the compiler verifies the floor environment is healthy. Pre-flight runs in `compile` and `compile-all` modes only — diagnostic modes skip it.

### What It Checks

1. **Compiled directory exists** — creates if missing
2. **Manifest exists** — determines expected vs unexpected classification
3. **Source hash matches** — detects floor edits since last compile
4. **Key artifacts present** — detects deleted enforce.sh or prose files

### Expected vs Unexpected

The manifest (`manifest.sha256`) is the signal. If it exists, the floor has been compiled before — missing infrastructure is unexpected.

| Condition                           | Classification                | Action                     |
| ----------------------------------- | ----------------------------- | -------------------------- |
| No manifest, no artifacts           | Expected (first compile)      | Create dir, log info       |
| No manifest, artifacts exist        | Unexpected (manifest deleted) | Log warning, metrics event |
| Source hash mismatch                | Expected (floor edited)       | Log info, recompile        |
| Artifacts missing, manifest present | Unexpected (files deleted)    | Log warning, metrics event |

### Output

Expected remediation logs as `[preflight]` info. Unexpected remediation logs as `[preflight] WARNING` and emits a `preflight-remediation` metrics event.
```

- [ ] **Step 2: Update the Pipeline diagram**

Add `preflight_check` as the first step:

````
```
preflight_check  ← Verify environment
    │
    ▼
extract_blocks   ── Parse enforcement fences
...
```
````

- [ ] **Step 3: Commit**

```bash
git add docs/COMPILER-GUIDE.md
git commit -m "docs(#31): document pre-flight checks in Compiler Guide"
```

---

## Key Files Reference

| File                                                             | Why                                               |
| ---------------------------------------------------------------- | ------------------------------------------------- |
| `docs/superpowers/specs/2026-03-26-compiler-preflight-design.md` | The spec                                          |
| `ops/compile-floor.sh`                                           | Compiler getting pre-flight function (~971 lines) |
| `ops/metrics-log.sh`                                             | Getting new event type                            |
| `ops/tests/test-compile-floor.sh`                                | Test suite (111 tests + new pre-flight tests)     |
| `docs/COMPILER-GUIDE.md`                                         | Guide to update                                   |
