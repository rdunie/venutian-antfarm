# Compliance Floor Compiler Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build `ops/compile-floor.sh` — a compiler that reads annotated `compliance-floor.md`, extracts enforcement blocks, validates them, and produces compiled artifacts (enforce.sh, prose floor, linter configs, coverage report, staleness manifest).

**Architecture:** Single shell script with three modes (compile, --dry-run, --verify). Reads enforcement blocks from fenced Markdown, parses YAML with `yq`, generates a dispatcher script (`enforce.sh`) that `settings.json` hooks call. Signal emission via `ops/metrics-log.sh`.

**Tech Stack:** Bash, `yq` (YAML parsing), `sha256sum` (integrity), existing `ops/metrics-log.sh` (structured events).

**Spec:** `docs/superpowers/specs/2026-03-21-compliance-compiler-design.md`

---

## File Structure

| File                                                    | Responsibility                                                                                           |
| ------------------------------------------------------- | -------------------------------------------------------------------------------------------------------- |
| `ops/compile-floor.sh`                                  | Main compiler script — extract, validate, generate                                                       |
| `ops/tests/test-compile-floor.sh`                       | Test suite for the compiler                                                                              |
| `.claude/compliance/compiled/enforce.sh`                | Generated: dispatcher script called by hooks                                                             |
| `.claude/compliance/compiled/compliance-floor.prose.md` | Generated: prose-only floor for agent consumption                                                        |
| `.claude/compliance/compiled/semgrep-rules.yaml`        | Generated: batched semgrep ruleset                                                                       |
| `.claude/compliance/compiled/eslint-rules.json`         | Generated: batched eslint config                                                                         |
| `.claude/compliance/compiled/manifest.sha256`           | Generated: staleness manifest                                                                            |
| `docs/compliance-coverage.md`                           | Generated: coverage report + trust summary                                                               |
| `templates/compliance-floor.md`                         | Modified: add enforcement block examples                                                                 |
| `.claude/skills/compliance/SKILL.md`                    | Modified: add compiler step to apply workflow                                                            |
| `ops/metrics-log.sh`                                    | Modified: add `compliance-pass` event type and update `compliance-violation` to accept structured fields |
| `.claude/settings.json`                                 | Modified: add SessionStart staleness check (use Write tool per CLAUDE.md gotchas)                        |

**Testing pattern:** The test harness uses `setup_tmpdir` (defined in Task 1) to create temp directories with centralized cleanup. When test code blocks below show `TMPDIR=$(mktemp -d)` with `trap`, replace with `TMPDIR=$(setup_tmpdir)` and omit the `trap`/`rm -rf` cleanup — `cleanup_all` handles it at exit.

**Fixture note:** Fixture files contain nested Markdown fencing (enforcement blocks inside Markdown files). Write fixtures with the Write tool rather than copy-pasting from this plan — the nested backtick fencing is unreliable in plan rendering.

---

## Task 1: Scaffold Test Infrastructure + Dependency Check

**Files:**

- Create: `ops/tests/test-compile-floor.sh`
- Create: `ops/tests/fixtures/floor-valid.md`
- Create: `ops/tests/fixtures/floor-invalid-no-realtime.md`
- Create: `ops/tests/fixtures/floor-invalid-bypass.md`
- Create: `ops/tests/fixtures/floor-invalid-severity-action.md`
- Create: `ops/tests/fixtures/floor-invalid-no-version.md`

This task creates the test harness and fixture files used by all subsequent tasks. The fixtures are small Markdown files with enforcement blocks — valid and invalid variants.

- [ ] **Step 1: Create test directory**

```bash
mkdir -p ops/tests/fixtures
```

- [ ] **Step 2: Write the valid floor fixture**

Create `ops/tests/fixtures/floor-valid.md`:

The fixture file `ops/tests/fixtures/floor-valid.md` should contain exactly this content (write with the Write tool, not copy-paste from this plan — the nested fencing is tricky in Markdown):

- A `# Compliance Floor` heading, then `## Rules`
- Rule 1: `**No hardcoded secrets.**` prose, followed by a ` ```enforcement ` block with `id: no-hardcoded-secrets`, `severity: blocking`, `pre-tool-use` file-pattern check for `['\.env$', '\.pem$', '\.key$']`, action `block`
- Rule 2: `**No console.log in production.**` prose, followed by a ` ```enforcement ` block with `id: no-console-log`, `severity: warning`, `post-tool-use` content-pattern check for `['console\.log\(']`, action `warn`
- Rule 3: `**All data changes are auditable.**` prose with NO enforcement block (judgment-only rule for coverage report testing)

- [ ] **Step 3: Write the invalid fixture — CI-only rule (no real-time enforcement)**

Create `ops/tests/fixtures/floor-invalid-no-realtime.md`:

````markdown
# Compliance Floor

1. **Bad rule.** Only CI enforcement.

```enforcement
version: 1
id: ci-only-rule
severity: blocking
enforce:
  ci:
    type: semgrep
    rule-id: bad-rule
    rule-path: rules/bad.yaml
```
````

````

- [ ] **Step 4: Write the invalid fixtures**

Write each fixture with the Write tool. All follow the same pattern: `# Compliance Floor` heading, one rule with prose, one enforcement block. Specific invalid content:

`ops/tests/fixtures/floor-invalid-bypass.md`: id: `bypass-rule`, severity: `blocking`, has `bypass: true` at top level (forbidden field), valid `pre-tool-use` file-pattern.

`ops/tests/fixtures/floor-invalid-severity-action.md`: id: `contradictory-rule`, severity: `warning`, `pre-tool-use` file-pattern with `action: block` (contradicts warning severity).

`ops/tests/fixtures/floor-invalid-no-version.md`: id: `no-version-rule`, severity: `blocking`, valid `pre-tool-use` file-pattern, but NO `version` field.

- [ ] **Step 7: Write the test harness shell script**

Create `ops/tests/test-compile-floor.sh`:

```bash
#!/usr/bin/env bash
# Test suite for ops/compile-floor.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
COMPILER="$REPO_ROOT/ops/compile-floor.sh"
FIXTURES="$SCRIPT_DIR/fixtures"

PASS=0
FAIL=0
TOTAL=0

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

assert_exit() {
  local desc="$1" expected="$2" actual="$3"
  TOTAL=$((TOTAL + 1))
  if [[ "$expected" == "$actual" ]]; then
    echo -e "  ${GREEN}PASS${NC}: $desc"
    PASS=$((PASS + 1))
  else
    echo -e "  ${RED}FAIL${NC}: $desc (expected exit $expected, got $actual)"
    FAIL=$((FAIL + 1))
  fi
}

assert_file_exists() {
  local desc="$1" path="$2"
  TOTAL=$((TOTAL + 1))
  if [[ -f "$path" ]]; then
    echo -e "  ${GREEN}PASS${NC}: $desc"
    PASS=$((PASS + 1))
  else
    echo -e "  ${RED}FAIL${NC}: $desc (file not found: $path)"
    FAIL=$((FAIL + 1))
  fi
}

assert_file_not_exists() {
  local desc="$1" path="$2"
  TOTAL=$((TOTAL + 1))
  if [[ ! -f "$path" ]]; then
    echo -e "  ${GREEN}PASS${NC}: $desc"
    PASS=$((PASS + 1))
  else
    echo -e "  ${RED}FAIL${NC}: $desc (file should not exist: $path)"
    FAIL=$((FAIL + 1))
  fi
}

assert_contains() {
  local desc="$1" file="$2" pattern="$3"
  TOTAL=$((TOTAL + 1))
  if grep -qE "$pattern" "$file" 2>/dev/null; then
    echo -e "  ${GREEN}PASS${NC}: $desc"
    PASS=$((PASS + 1))
  else
    echo -e "  ${RED}FAIL${NC}: $desc (pattern '$pattern' not found in $file)"
    FAIL=$((FAIL + 1))
  fi
}

assert_not_contains() {
  local desc="$1" file="$2" pattern="$3"
  TOTAL=$((TOTAL + 1))
  if ! grep -qE "$pattern" "$file" 2>/dev/null; then
    echo -e "  ${GREEN}PASS${NC}: $desc"
    PASS=$((PASS + 1))
  else
    echo -e "  ${RED}FAIL${NC}: $desc (pattern '$pattern' should not be in $file)"
    FAIL=$((FAIL + 1))
  fi
}

# Check yq dependency
if ! command -v yq &>/dev/null; then
  echo "ERROR: yq is required to run tests. Install: https://github.com/mikefarah/yq" >&2
  exit 1
fi

echo "=== Compliance Floor Compiler Tests ==="
echo ""

# Each test section uses its own TMPDIR with explicit cleanup.
# Use setup_tmpdir/cleanup_tmpdir helpers to avoid trap collisions:
TMPDIRS=()
setup_tmpdir() { local d; d=$(mktemp -d); TMPDIRS+=("$d"); echo "$d"; }
cleanup_all() { for d in "${TMPDIRS[@]}"; do rm -rf "$d"; done; }
trap cleanup_all EXIT

# Tests will be added in subsequent tasks

echo ""
echo "=== Results: $PASS/$TOTAL passed, $FAIL failed ==="
[[ $FAIL -eq 0 ]] && exit 0 || exit 1
````

- [ ] **Step 8: Make test script executable and verify it runs**

```bash
chmod +x ops/tests/test-compile-floor.sh
ops/tests/test-compile-floor.sh
```

Expected: 0/0 passed, 0 failed (empty test suite runs clean)

- [ ] **Step 9: Commit**

```bash
git add ops/tests/
git commit -m "test: scaffold compliance compiler test infrastructure

Test harness with assert helpers and fixture files for valid/invalid
enforcement blocks. Fixtures cover: valid rules, CI-only (no real-time),
bypass field, severity/action contradiction, missing version."
```

---

## Task 2: Enforcement Block Extraction

**Files:**

- Create: `ops/compile-floor.sh` (initial — extraction + dependency check only)
- Modify: `ops/tests/test-compile-floor.sh` (add extraction tests)

The compiler's first responsibility: extract ` ```enforcement ` blocks from Markdown, outputting each as standalone YAML. This task builds only extraction — no validation or code generation.

- [ ] **Step 1: Write the extraction tests**

Add to `ops/tests/test-compile-floor.sh` before the results line:

```bash
echo "--- Extraction ---"

# Test: extracts correct number of blocks from valid fixture
TMPDIR=$(mktemp -d)
trap "rm -rf $TMPDIR" EXIT

"$COMPILER" --extract-only "$FIXTURES/floor-valid.md" "$TMPDIR" 2>/dev/null
BLOCK_COUNT=$(ls "$TMPDIR"/block-*.yaml 2>/dev/null | wc -l)
TOTAL=$((TOTAL + 1))
if [[ "$BLOCK_COUNT" -eq 2 ]]; then
  echo -e "  ${GREEN}PASS${NC}: extracts 2 blocks from valid fixture"
  PASS=$((PASS + 1))
else
  echo -e "  ${RED}FAIL${NC}: expected 2 blocks, got $BLOCK_COUNT"
  FAIL=$((FAIL + 1))
fi

# Test: extracted YAML is parseable by yq
for block in "$TMPDIR"/block-*.yaml; do
  yq '.' "$block" >/dev/null 2>&1
  assert_exit "block $(basename $block) is valid YAML" 0 $?
done

# Test: block IDs are correct
BLOCK1_ID=$(yq '.id' "$TMPDIR/block-001.yaml" 2>/dev/null)
assert_exit "block 1 has id=no-hardcoded-secrets" 0 $([[ "$BLOCK1_ID" == "no-hardcoded-secrets" ]] && echo 0 || echo 1)

BLOCK2_ID=$(yq '.id' "$TMPDIR/block-002.yaml" 2>/dev/null)
assert_exit "block 2 has id=no-console-log" 0 $([[ "$BLOCK2_ID" == "no-console-log" ]] && echo 0 || echo 1)

rm -rf "$TMPDIR"
trap - EXIT
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
ops/tests/test-compile-floor.sh
```

Expected: FAIL (compiler doesn't exist yet)

- [ ] **Step 3: Write the compiler with extraction logic**

Create `ops/compile-floor.sh`:

````bash
#!/usr/bin/env bash
# Compliance floor compiler.
# Reads compliance-floor.md, extracts enforcement blocks, validates,
# and generates compiled artifacts.
#
# Usage:
#   ops/compile-floor.sh [options] [floor-file] [output-dir]
#   ops/compile-floor.sh --dry-run [floor-file]
#   ops/compile-floor.sh --verify [floor-file] [compiled-dir]
#   ops/compile-floor.sh --extract-only <floor-file> <output-dir>
#
# Options:
#   --dry-run        Print what would be generated without writing files
#   --verify         Check if compiled artifacts match source (for CI)
#   --extract-only   Extract enforcement blocks only (for testing)
#   --proposal <id>  Proposal ID for generated artifact headers
#
# Exit codes:
#   0 = success
#   1 = validation warnings (non-fatal) / drift detected (--verify)
#   2 = validation errors (fatal)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# ── Defaults ──────────────────────────────────────────────────────────────
MODE="compile"
FLOOR_FILE=""
OUTPUT_DIR=""
PROPOSAL_ID="none"

# ── Parse args ────────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)      MODE="dry-run";       shift ;;
    --verify)       MODE="verify";        shift ;;
    --extract-only) MODE="extract-only";  shift ;;
    --proposal)     PROPOSAL_ID="$2";     shift 2 ;;
    *)
      if [[ -z "$FLOOR_FILE" ]]; then
        FLOOR_FILE="$1"
      elif [[ -z "$OUTPUT_DIR" ]]; then
        OUTPUT_DIR="$1"
      fi
      shift ;;
  esac
done

FLOOR_FILE="${FLOOR_FILE:-$REPO_ROOT/compliance-floor.md}"
OUTPUT_DIR="${OUTPUT_DIR:-$REPO_ROOT/.claude/compliance/compiled}"

# ── Dependency check ──────────────────────────────────────────────────────
if ! command -v yq &>/dev/null; then
  echo "ERROR: yq is required but not installed." >&2
  echo "Install: https://github.com/mikefarah/yq#install" >&2
  exit 2
fi

# ── Extraction ────────────────────────────────────────────────────────────
# Extracts ```enforcement blocks from Markdown, writes each as block-NNN.yaml
extract_blocks() {
  local input="$1" outdir="$2"
  local in_block=false
  local block_num=0
  local block_file=""

  mkdir -p "$outdir"

  while IFS= read -r line; do
    if [[ "$line" =~ ^\`\`\`enforcement[[:space:]]*$ ]]; then
      in_block=true
      block_num=$((block_num + 1))
      block_file="$outdir/block-$(printf '%03d' $block_num).yaml"
      > "$block_file"
      continue
    fi

    if $in_block && [[ "$line" =~ ^\`\`\`[[:space:]]*$ ]]; then
      in_block=false
      continue
    fi

    if $in_block; then
      echo "$line" >> "$block_file"
    fi
  done < "$input"

  if $in_block; then
    echo "ERROR: unclosed enforcement block at end of file (block $block_num)" >&2
    exit 2
  fi

  echo "$block_num"
}

# ── Mode dispatch ─────────────────────────────────────────────────────────
if [[ ! -f "$FLOOR_FILE" ]]; then
  echo "ERROR: floor file not found: $FLOOR_FILE" >&2
  exit 2
fi

case "$MODE" in
  extract-only)
    if [[ -z "$OUTPUT_DIR" ]]; then
      echo "ERROR: --extract-only requires output directory" >&2
      exit 2
    fi
    extract_blocks "$FLOOR_FILE" "$OUTPUT_DIR"
    ;;
  *)
    echo "ERROR: mode '$MODE' not yet implemented" >&2
    exit 2
    ;;
esac
````

- [ ] **Step 4: Make compiler executable**

```bash
chmod +x ops/compile-floor.sh
```

- [ ] **Step 5: Run tests to verify they pass**

```bash
ops/tests/test-compile-floor.sh
```

Expected: All extraction tests PASS

- [ ] **Step 6: Commit**

```bash
git add ops/compile-floor.sh ops/tests/test-compile-floor.sh
git commit -m "feat: add enforcement block extraction to compile-floor.sh

Extracts fenced enforcement blocks from compliance-floor.md into
standalone YAML files. Positional association (Nth block = Nth rule).
Detects unclosed blocks. Tests verify extraction count, YAML validity,
and rule ID preservation."
```

---

## Task 3: Validation Engine

**Files:**

- Modify: `ops/compile-floor.sh` (add validation function)
- Modify: `ops/tests/test-compile-floor.sh` (add validation tests)

Validates extracted blocks against all spec constraints: required fields, forbidden fields, severity/action consistency, enforcement point requirements, rule-path existence.

- [ ] **Step 1: Write validation tests**

Add to `ops/tests/test-compile-floor.sh`:

```bash
echo "--- Validation ---"

TMPDIR=$(mktemp -d)
trap "rm -rf $TMPDIR" EXIT

# Test: valid fixture passes validation
"$COMPILER" --validate-only "$FIXTURES/floor-valid.md" "$TMPDIR" >/dev/null 2>&1
assert_exit "valid fixture passes validation" 0 $?

# Test: CI-only rule rejected
"$COMPILER" --validate-only "$FIXTURES/floor-invalid-no-realtime.md" "$TMPDIR" >/dev/null 2>&1
assert_exit "CI-only rule rejected (exit 2)" 2 $?

# Test: bypass field rejected
"$COMPILER" --validate-only "$FIXTURES/floor-invalid-bypass.md" "$TMPDIR" >/dev/null 2>&1
assert_exit "bypass field rejected (exit 2)" 2 $?

# Test: severity/action contradiction rejected
"$COMPILER" --validate-only "$FIXTURES/floor-invalid-severity-action.md" "$TMPDIR" >/dev/null 2>&1
assert_exit "severity/action contradiction rejected (exit 2)" 2 $?

# Test: missing version rejected
"$COMPILER" --validate-only "$FIXTURES/floor-invalid-no-version.md" "$TMPDIR" >/dev/null 2>&1
assert_exit "missing version rejected (exit 2)" 2 $?

rm -rf "$TMPDIR"
trap - EXIT
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
ops/tests/test-compile-floor.sh
```

Expected: FAIL (--validate-only not implemented)

- [ ] **Step 3: Implement validation function in compile-floor.sh**

Add `validate_block()` function after the extraction function. It validates:

- `version` field exists and equals `1`
- `id` field exists
- `severity` is `blocking` or `warning`
- No `bypass`, `skip`, or `override` fields
- At least one `pre-tool-use` or `post-tool-use` enforcement point
- `action` does not contradict `severity`
- `rule-path` references exist on disk (when provided)

Add `--validate-only` mode to the case dispatch that calls `extract_blocks` then `validate_block` on each extracted block.

- [ ] **Step 4: Run tests to verify they pass**

```bash
ops/tests/test-compile-floor.sh
```

Expected: All validation tests PASS

- [ ] **Step 5: Commit**

```bash
git add ops/compile-floor.sh ops/tests/test-compile-floor.sh
git commit -m "feat: add validation engine to compliance compiler

Validates: required fields (version, id, severity), forbidden fields
(bypass/skip/override), severity/action consistency, real-time
enforcement requirement, rule-path existence. Exit 2 on fatal errors."
```

---

## Task 4: Prose Floor Generation

**Files:**

- Modify: `ops/compile-floor.sh` (add prose generation)
- Modify: `ops/tests/test-compile-floor.sh` (add prose tests)

Strips enforcement blocks from the source floor, producing a clean prose-only version for agent consumption.

- [ ] **Step 1: Write prose generation tests**

Add to `ops/tests/test-compile-floor.sh`:

````bash
echo "--- Prose Generation ---"

TMPDIR=$(mktemp -d)
trap "rm -rf $TMPDIR" EXIT

"$COMPILER" --prose-only "$FIXTURES/floor-valid.md" "$TMPDIR" >/dev/null 2>&1

assert_file_exists "prose file generated" "$TMPDIR/compliance-floor.prose.md"
assert_not_contains "prose has no enforcement blocks" "$TMPDIR/compliance-floor.prose.md" '```enforcement'
assert_contains "prose retains rule text" "$TMPDIR/compliance-floor.prose.md" "No hardcoded secrets"
assert_contains "prose retains rule 2 text" "$TMPDIR/compliance-floor.prose.md" "No console.log"

rm -rf "$TMPDIR"
trap - EXIT
````

- [ ] **Step 2: Run tests to verify they fail**

```bash
ops/tests/test-compile-floor.sh
```

Expected: FAIL

- [ ] **Step 3: Implement prose generation**

Add `generate_prose()` function that reads the source floor and writes a copy with all ` ```enforcement...``` ` blocks removed. Include the generated artifact header.

Add `--prose-only` mode to the case dispatch.

- [ ] **Step 4: Run tests to verify they pass**

```bash
ops/tests/test-compile-floor.sh
```

Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add ops/compile-floor.sh ops/tests/test-compile-floor.sh
git commit -m "feat: add prose floor generation to compliance compiler

Strips enforcement blocks from compliance-floor.md to produce a clean
prose-only version at .claude/compliance/compiled/compliance-floor.prose.md.
Includes generated artifact header with proposal ID."
```

---

## Task 5: enforce.sh Generation (Hook Script)

**Files:**

- Modify: `ops/compile-floor.sh` (add enforce.sh generation)
- Modify: `ops/tests/test-compile-floor.sh` (add enforce.sh tests)

The core deliverable — generates the dispatcher script that `settings.json` hooks call.

- [ ] **Step 1: Write enforce.sh generation tests**

Add to `ops/tests/test-compile-floor.sh`:

```bash
echo "--- enforce.sh Generation ---"

TMPDIR=$(mktemp -d)
trap "rm -rf $TMPDIR" EXIT

"$COMPILER" --generate-enforce "$FIXTURES/floor-valid.md" "$TMPDIR" >/dev/null 2>&1

assert_file_exists "enforce.sh generated" "$TMPDIR/enforce.sh"
assert_contains "enforce.sh is executable check script" "$TMPDIR/enforce.sh" "#!/usr/bin/env bash"
assert_contains "enforce.sh has pre-tool-use handler" "$TMPDIR/enforce.sh" "pre-tool-use"
assert_contains "enforce.sh has post-tool-use handler" "$TMPDIR/enforce.sh" "post-tool-use"
assert_contains "enforce.sh checks file-pattern rule" "$TMPDIR/enforce.sh" 'no-hardcoded-secrets'
assert_contains "enforce.sh checks content-pattern rule" "$TMPDIR/enforce.sh" 'no-console-log'
assert_contains "enforce.sh has GENERATED header" "$TMPDIR/enforce.sh" "GENERATED by ops/compile-floor.sh"

# Test: enforce.sh actually works — file-pattern check
chmod +x "$TMPDIR/enforce.sh"
"$TMPDIR/enforce.sh" pre-tool-use "app.js" >/dev/null 2>&1
assert_exit "enforce.sh passes non-matching file" 0 $?

"$TMPDIR/enforce.sh" pre-tool-use "secrets.env" >/dev/null 2>&1
assert_exit "enforce.sh blocks .env file" 2 $?

# Test: enforce.sh post-tool-use — content-pattern check
echo 'console.log("debug")' > "$TMPDIR/test-file.js"
"$TMPDIR/enforce.sh" post-tool-use "$TMPDIR/test-file.js" >/dev/null 2>&1
assert_exit "enforce.sh warns on console.log content" 1 $?

echo 'logger.info("debug")' > "$TMPDIR/test-file-clean.js"
"$TMPDIR/enforce.sh" post-tool-use "$TMPDIR/test-file-clean.js" >/dev/null 2>&1
assert_exit "enforce.sh passes clean file content" 0 $?

rm -rf "$TMPDIR"
trap - EXIT
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
ops/tests/test-compile-floor.sh
```

Expected: FAIL

- [ ] **Step 3: Implement enforce.sh generation**

Add `generate_enforce()` function that:

1. Reads all validated blocks
2. Groups checks by enforcement point (`pre-tool-use`, `post-tool-use`)
3. For each enforcement point, generates shell functions per check type:
   - `file-pattern`: `echo "$FILE_PATH" | grep -qE '<pattern>'`
   - `content-pattern`: `grep -qE '<pattern>' "$FILE_PATH"`
4. Generates a dispatcher: takes enforcement point + file path as args, calls all checks for that point
5. Exit code: highest exit code from any check (2 beats 1 beats 0)
6. Includes `log_violation()` and `log_pass()` helpers that call `ops/metrics-log.sh`
7. `log_pass()` checks `fleet-config.json` for `signal-passes` flag (opt-in)
8. Includes generated artifact header

Add `--generate-enforce` mode to the case dispatch.

- [ ] **Step 4: Run tests to verify they pass**

```bash
ops/tests/test-compile-floor.sh
```

Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add ops/compile-floor.sh ops/tests/test-compile-floor.sh
git commit -m "feat: add enforce.sh generation to compliance compiler

Generates dispatcher script from enforcement blocks. Supports
file-pattern (pre-tool-use) and content-pattern (post-tool-use) check
types. Signal emission via ops/metrics-log.sh for violations (always)
and passes (opt-in). Exit code escalation: 2 > 1 > 0."
```

---

## Task 6: Staleness Manifest + Verify Mode

**Files:**

- Modify: `ops/compile-floor.sh` (add manifest generation + --verify mode)
- Modify: `ops/tests/test-compile-floor.sh` (add manifest + verify tests)

- [ ] **Step 1: Write manifest and verify tests**

Add to `ops/tests/test-compile-floor.sh`:

```bash
echo "--- Manifest + Verify ---"

TMPDIR=$(mktemp -d)
trap "rm -rf $TMPDIR" EXIT

# Full compile to get all artifacts
"$COMPILER" --proposal test-001 "$FIXTURES/floor-valid.md" "$TMPDIR" >/dev/null 2>&1

assert_file_exists "manifest generated" "$TMPDIR/manifest.sha256"
assert_contains "manifest has source hash" "$TMPDIR/manifest.sha256" "source:"
assert_contains "manifest has proposal ID" "$TMPDIR/manifest.sha256" "test-001"
assert_contains "manifest has enforce.sh hash" "$TMPDIR/manifest.sha256" "enforce.sh:"

# Verify mode — should pass with matching artifacts
"$COMPILER" --verify "$FIXTURES/floor-valid.md" "$TMPDIR" >/dev/null 2>&1
assert_exit "verify passes with matching artifacts" 0 $?

# Tamper with an artifact and verify again
echo "# tampered" >> "$TMPDIR/enforce.sh"
"$COMPILER" --verify "$FIXTURES/floor-valid.md" "$TMPDIR" >/dev/null 2>&1
assert_exit "verify detects tampered artifact (exit 1)" 1 $?

rm -rf "$TMPDIR"
trap - EXIT
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
ops/tests/test-compile-floor.sh
```

Expected: FAIL

- [ ] **Step 3: Implement manifest generation and verify mode**

Add `generate_manifest()` function that writes `manifest.sha256` with:

- `source:` SHA-256 of the floor file
- `compiled-from:` proposal ID
- `artifacts:` SHA-256 of each generated artifact

Implement `--verify` mode:

1. Read existing manifest
2. Compute current source hash, compare to manifest source hash
3. Compute current artifact hashes, compare to manifest artifact hashes
4. Exit 0 if all match, exit 1 if drift detected (print which files differ)

Wire up the full `compile` mode: extract → validate → generate prose → generate enforce.sh → generate manifest.

- [ ] **Step 4: Run tests to verify they pass**

```bash
ops/tests/test-compile-floor.sh
```

Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add ops/compile-floor.sh ops/tests/test-compile-floor.sh
git commit -m "feat: add staleness manifest and verify mode

Manifest records source + artifact SHA-256 hashes and proposal ID.
--verify mode compares current state against manifest, exits 1 on drift.
Full compile mode now chains: extract → validate → prose → enforce → manifest."
```

---

## Task 7: Coverage Report Generation

**Files:**

- Modify: `ops/compile-floor.sh` (add coverage report generation)
- Modify: `ops/tests/test-compile-floor.sh` (add coverage report tests)

- [ ] **Step 1: Write coverage report tests**

Add to `ops/tests/test-compile-floor.sh`:

```bash
echo "--- Coverage Report ---"

TMPDIR=$(mktemp -d)
DOCS_DIR=$(mktemp -d)
trap "rm -rf $TMPDIR $DOCS_DIR" EXIT

COVERAGE_PATH="$DOCS_DIR/compliance-coverage.md" \
  "$COMPILER" --proposal test-001 "$FIXTURES/floor-valid.md" "$TMPDIR" >/dev/null 2>&1

assert_file_exists "coverage report generated" "$DOCS_DIR/compliance-coverage.md"
assert_contains "coverage lists rule IDs" "$DOCS_DIR/compliance-coverage.md" "no-hardcoded-secrets"
assert_contains "coverage lists enforcement points" "$DOCS_DIR/compliance-coverage.md" "pre-tool-use"
assert_contains "coverage has trust summary" "$DOCS_DIR/compliance-coverage.md" "What Each Layer Guarantees"
assert_contains "coverage flags judgment-only rule" "$DOCS_DIR/compliance-coverage.md" "judgment-only"

rm -rf "$TMPDIR" "$DOCS_DIR"
trap - EXIT
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
ops/tests/test-compile-floor.sh
```

Expected: FAIL

- [ ] **Step 3: Implement coverage report generation**

Add `generate_coverage()` function that writes a Markdown report to `$COVERAGE_PATH` (defaults to `docs/compliance-coverage.md`). Includes:

- Table: rule ID, severity, enforcement points, check types, status (covered / judgment-only)
- Rules with no enforcement blocks are listed as "judgment-only"
- Trust summary section (from spec)
- Generated header

- [ ] **Step 4: Run tests to verify they pass**

```bash
ops/tests/test-compile-floor.sh
```

Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add ops/compile-floor.sh ops/tests/test-compile-floor.sh
git commit -m "feat: add coverage report generation to compliance compiler

Per-rule enforcement breakdown with trust summary. Rules without
enforcement blocks flagged as judgment-only. Written to
docs/compliance-coverage.md for human consumption."
```

---

## Task 8: Dry-Run Mode

**Files:**

- Modify: `ops/compile-floor.sh` (implement --dry-run)
- Modify: `ops/tests/test-compile-floor.sh` (add dry-run tests)

- [ ] **Step 1: Write dry-run tests**

Add to `ops/tests/test-compile-floor.sh`:

```bash
echo "--- Dry Run ---"

TMPDIR=$(mktemp -d)
trap "rm -rf $TMPDIR" EXIT

# Dry run should produce output on stdout but not write files
OUTPUT=$("$COMPILER" --dry-run "$FIXTURES/floor-valid.md" 2>/dev/null)
assert_exit "dry-run exits 0 on valid input" 0 $?

TOTAL=$((TOTAL + 1))
if echo "$OUTPUT" | grep -q "no-hardcoded-secrets"; then
  echo -e "  ${GREEN}PASS${NC}: dry-run outputs rule info to stdout"
  PASS=$((PASS + 1))
else
  echo -e "  ${RED}FAIL${NC}: dry-run should output rule info to stdout"
  FAIL=$((FAIL + 1))
fi

# Dry run with invalid input should exit 2
"$COMPILER" --dry-run "$FIXTURES/floor-invalid-bypass.md" >/dev/null 2>&1
assert_exit "dry-run exits 2 on invalid input" 2 $?

rm -rf "$TMPDIR"
trap - EXIT
```

- [ ] **Step 2: Run tests, verify fail, implement, verify pass**

Implement `--dry-run` in the case dispatch: extract → validate → print summary of what would be generated (rule count, enforcement points, check types) to stdout. No file writes.

- [ ] **Step 3: Commit**

```bash
git add ops/compile-floor.sh ops/tests/test-compile-floor.sh
git commit -m "feat: add dry-run mode to compliance compiler

--dry-run validates rules and prints what would be generated without
writing files. Exits 2 on validation errors, 0 on valid input."
```

---

## Task 9: Update metrics-log.sh for Structured Compliance Events

**Files:**

- Modify: `ops/metrics-log.sh` (update `compliance-violation` handler, add `compliance-pass`)

- [ ] **Step 1: Write tests for new event types**

Add to `ops/tests/test-compile-floor.sh`:

```bash
echo "--- Metrics Events ---"

TMPDIR=$(mktemp -d)
trap "rm -rf $TMPDIR" EXIT

METRICS_LOG_FILE="$TMPDIR/events.jsonl" \
  "$REPO_ROOT/ops/metrics-log.sh" compliance-violation \
    --rule-id no-hardcoded-secrets --severity blocking \
    --enforcement-point pre-tool-use --file "secrets.env" \
    --action block >/dev/null 2>&1
assert_exit "compliance-violation with structured fields" 0 $?

assert_contains "violation event has rule-id" "$TMPDIR/events.jsonl" '"rule_id":"no-hardcoded-secrets"'

METRICS_LOG_FILE="$TMPDIR/events.jsonl" \
  "$REPO_ROOT/ops/metrics-log.sh" compliance-pass \
    --rule-id no-hardcoded-secrets \
    --enforcement-point pre-tool-use --file "app.js" >/dev/null 2>&1
assert_exit "compliance-pass event accepted" 0 $?

assert_contains "pass event has rule-id" "$TMPDIR/events.jsonl" '"rule_id":"no-hardcoded-secrets"'

rm -rf "$TMPDIR"
trap - EXIT
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
ops/tests/test-compile-floor.sh
```

Expected: FAIL (compliance-violation doesn't accept --rule-id, compliance-pass doesn't exist)

- [ ] **Step 3: Update metrics-log.sh**

Add `--rule-id`, `--enforcement-point`, and `--file` flag parsing. Update the `compliance-violation` case to include structured fields (`rule_id`, `severity`, `enforcement_point`, `file`, `action`). Add new `compliance-pass` case with the same structured fields. Update the usage/error help text.

- [ ] **Step 4: Run tests to verify they pass**

```bash
ops/tests/test-compile-floor.sh
```

Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add ops/metrics-log.sh ops/tests/test-compile-floor.sh
git commit -m "feat: add structured compliance events to metrics-log.sh

compliance-violation now accepts --rule-id, --severity, --enforcement-point,
--file, --action for structured downstream consumption. New compliance-pass
event type for opt-in positive signal tracking."
```

---

## Task 10: Update Compliance Floor Template

**Files:**

- Modify: `templates/compliance-floor.md` (add enforcement block examples)

- [ ] **Step 1: Update the template**

Add enforcement blocks to the template rules and update the Enforcement section to reference the compiler instead of hand-written hooks.

The first rule (`No hardcoded secrets`) gets a `file-pattern` enforcement block. The other rules remain without enforcement blocks (they're judgment-only by default — the coverage report will flag them).

Update the `## Enforcement` section to document the compiler workflow:

````markdown
## Enforcement

Rules can include programmatic enforcement via `enforcement` blocks:

    ```enforcement
    version: 1
    id: <unique-id>
    severity: blocking|warning
    enforce:
      pre-tool-use:
        type: file-pattern|content-pattern|custom-script
        patterns: ['regex1', 'regex2']
        action: block|warn
      post-tool-use:
        type: content-pattern|semgrep|eslint|custom-script
        ...
      ci:
        type: semgrep|eslint|custom-script
        ...
    ```

Run `ops/compile-floor.sh` to compile enforcement blocks into hook
scripts and linter configs. See `docs/compliance-coverage.md` for which
rules have programmatic enforcement and which require agent judgment.
````

- [ ] **Step 2: Verify template syntax**

```bash
ops/compile-floor.sh --dry-run templates/compliance-floor.md
```

Expected: exit 0, reports 1 rule with enforcement

- [ ] **Step 3: Commit**

```bash
git add templates/compliance-floor.md
git commit -m "docs: add enforcement block examples to compliance floor template

First rule (no hardcoded secrets) includes a file-pattern enforcement block.
Updated Enforcement section to reference the compiler workflow."
```

---

## Task 11: Update /compliance apply Skill

**Files:**

- Modify: `.claude/skills/compliance/SKILL.md` (add compiler step to apply workflow)

- [ ] **Step 1: Update the apply workflow**

In the `## Workflow: Apply` section, insert compiler step between the floor change and checksum update. The updated sequence:

1. Verify proposal status is "approved"
2. Create sentinel: `.claude/compliance/.applying` with proposal ID and timestamp
3. Apply the change to `compliance-floor.md` or `.claude/compliance/targets.md`
4. **Run `ops/compile-floor.sh --proposal <id>`** — if compilation fails (exit 2), revert via `git checkout -- compliance-floor.md`, remove sentinel, report error
5. Update checksum: regenerate `.claude/compliance/floor-checksum.sha256`
6. Append entry to `.claude/compliance/change-log.md`
7. Remove sentinel. Log `compliance-applied` event. Update proposal to "applied"

- [ ] **Step 2: Commit**

```bash
git add .claude/skills/compliance/SKILL.md
git commit -m "feat: integrate compiler into /compliance apply workflow

Compiler runs after floor change, before checksum update. Atomic:
compilation failure triggers revert + sentinel cleanup. Proposal ID
passed to compiler for generated artifact headers."
```

---

## Task 12: Intent Declaration Hooks

**Files:**

- Modify: `ops/compile-floor.sh` (generate intent declaration hooks in enforce.sh)
- Modify: `ops/tests/test-compile-floor.sh` (add intent declaration tests)

The generated `enforce.sh` must also include the intent declaration logic (Section 6 of the spec): warn on writes to compliance surface area files.

- [ ] **Step 1: Write intent declaration tests**

Add to `ops/tests/test-compile-floor.sh`:

```bash
echo "--- Intent Declaration ---"

TMPDIR=$(mktemp -d)
trap "rm -rf $TMPDIR" EXIT

"$COMPILER" --proposal test-001 "$FIXTURES/floor-valid.md" "$TMPDIR" >/dev/null 2>&1
chmod +x "$TMPDIR/enforce.sh"

# Compiled artifacts should trigger warning
"$TMPDIR/enforce.sh" pre-tool-use "$TMPDIR/enforce.sh" >/dev/null 2>&1
assert_exit "intent declaration warns on compiled artifact edit" 1 $?

# Compiler script should trigger warning
"$TMPDIR/enforce.sh" pre-tool-use "ops/compile-floor.sh" >/dev/null 2>&1
assert_exit "intent declaration warns on compiler edit" 1 $?

# Compliance agent definitions should trigger warning
"$TMPDIR/enforce.sh" pre-tool-use ".claude/agents/compliance-officer.md" >/dev/null 2>&1
assert_exit "intent declaration warns on CO agent edit" 1 $?

# Normal files should pass through
"$TMPDIR/enforce.sh" pre-tool-use "src/app.js" >/dev/null 2>&1
assert_exit "intent declaration passes normal files" 0 $?

rm -rf "$TMPDIR"
trap - EXIT
```

- [ ] **Step 2: Add sentinel-gated BLOCK tests**

Add to the same test section — tests for the sentinel-gated behavior from spec Section 6:

```bash
# compliance-floor.md should BLOCK without sentinel
"$TMPDIR/enforce.sh" pre-tool-use "compliance-floor.md" >/dev/null 2>&1
assert_exit "intent declaration blocks compliance-floor.md edit (no sentinel)" 2 $?

# .claude/compliance/ paths should BLOCK without sentinel
"$TMPDIR/enforce.sh" pre-tool-use ".claude/compliance/targets.md" >/dev/null 2>&1
assert_exit "intent declaration blocks compliance dir edit (no sentinel)" 2 $?

# With sentinel active, should WARN instead of BLOCK
mkdir -p .claude/compliance
touch .claude/compliance/.applying
"$TMPDIR/enforce.sh" pre-tool-use "compliance-floor.md" >/dev/null 2>&1
assert_exit "intent declaration warns on floor edit with sentinel" 1 $?
rm -f .claude/compliance/.applying
```

- [ ] **Step 3: Run tests, verify fail, implement, verify pass**

Add intent declaration checks to the generated `enforce.sh`:

- At the start of the `pre-tool-use` handler, check compliance surface area paths BEFORE rule-specific checks
- For sentinel-gated files (`compliance-floor.md`, `.claude/compliance/**`): BLOCK (exit 2) without sentinel, WARN (exit 1) with sentinel
- For infrastructure files (compiled artifacts, compiler script, agent definitions): always WARN (exit 1)
- Normal files pass through to rule-specific checks

- [ ] **Step 4: Commit**

```bash
git add ops/compile-floor.sh ops/tests/test-compile-floor.sh
git commit -m "feat: add intent declaration to generated enforce.sh

Sentinel-gated: compliance-floor.md and .claude/compliance/ paths BLOCKED
without sentinel, WARNED with sentinel. Infrastructure files (compiled
artifacts, compiler, agent definitions) always WARNED. Cascading check
before rule-specific enforcement."
```

---

## Task 13: Semgrep/ESLint Config Generation

**Files:**

- Modify: `ops/compile-floor.sh` (add semgrep/eslint generation)
- Modify: `ops/tests/test-compile-floor.sh` (add semgrep/eslint tests)
- Create: `ops/tests/fixtures/floor-with-semgrep.md`

Generates batched `semgrep-rules.yaml` and `eslint-rules.json` from enforcement blocks that use those check types.

- [ ] **Step 1: Create a fixture with semgrep/eslint rules**

Create `ops/tests/fixtures/floor-with-semgrep.md` with the Write tool. Contains:

- Rule 1: `**No hardcoded secrets.**` with `pre-tool-use` file-pattern (for real-time enforcement requirement) AND `post-tool-use` semgrep with `rule-id: no-hardcoded-secrets`, `rule-path: .claude/compliance/semgrep/no-hardcoded-secrets.yaml`
- Rule 2: `**No eval usage.**` with `pre-tool-use` content-pattern for `eval\(` AND `ci` eslint with `rule-id: no-eval`, `rule-path: .claude/compliance/eslint/no-eval.json`

Also create stub rule files so `rule-path` validation passes:

```bash
mkdir -p .claude/compliance/semgrep .claude/compliance/eslint
echo "rules: []" > .claude/compliance/semgrep/no-hardcoded-secrets.yaml
echo "{}" > .claude/compliance/eslint/no-eval.json
```

- [ ] **Step 2: Write semgrep/eslint generation tests**

Add to `ops/tests/test-compile-floor.sh`:

```bash
echo "--- Semgrep/ESLint Generation ---"

TMPDIR=$(mktemp -d)
trap "rm -rf $TMPDIR" EXIT

"$COMPILER" --proposal test-001 "$FIXTURES/floor-with-semgrep.md" "$TMPDIR" >/dev/null 2>&1

assert_file_exists "semgrep ruleset generated" "$TMPDIR/semgrep-rules.yaml"
assert_file_exists "eslint config generated" "$TMPDIR/eslint-rules.json"
assert_contains "semgrep includes rule reference" "$TMPDIR/semgrep-rules.yaml" "no-hardcoded-secrets"
assert_contains "eslint includes rule reference" "$TMPDIR/eslint-rules.json" "no-eval"
assert_contains "semgrep has GENERATED header" "$TMPDIR/semgrep-rules.yaml" "GENERATED"

rm -rf "$TMPDIR"
trap - EXIT
```

- [ ] **Step 3: Run tests to verify they fail**

```bash
ops/tests/test-compile-floor.sh
```

Expected: FAIL

- [ ] **Step 4: Implement semgrep/eslint generation**

Add `generate_semgrep()` and `generate_eslint()` functions:

`generate_semgrep()`: Collects all rules with `type: semgrep`, reads each `rule-path` file, merges into a single `semgrep-rules.yaml` with all rules under a top-level `rules:` key. Includes generated header as a YAML comment.

`generate_eslint()`: Collects all rules with `type: eslint`, reads each `rule-path` file, merges into a single `eslint-rules.json` with all rules combined. Includes generated header as a JSON comment field.

Both skip generation (write empty placeholder with header) if no rules use that check type.

Update `enforce.sh` generation: for `post-tool-use` semgrep rules, generate a check function that runs `semgrep --config "$COMPILED_DIR/semgrep-rules.yaml" "$FILE_PATH"`. For eslint, generate `eslint --config "$COMPILED_DIR/eslint-rules.json" "$FILE_PATH"`. Both check if the tool is installed first — if not, print a warning and pass (graceful degradation).

- [ ] **Step 5: Run tests to verify they pass**

```bash
ops/tests/test-compile-floor.sh
```

Expected: PASS

- [ ] **Step 6: Commit**

```bash
git add ops/compile-floor.sh ops/tests/ .claude/compliance/semgrep/ .claude/compliance/eslint/
git commit -m "feat: add semgrep/eslint config generation to compliance compiler

Collects rules by check type, merges referenced rule files into batched
semgrep-rules.yaml and eslint-rules.json. Generated enforce.sh includes
semgrep/eslint check functions with graceful degradation when tools are
not installed."
```

---

## Task 14: Custom-Script Check Type

**Files:**

- Modify: `ops/compile-floor.sh` (add custom-script handling)
- Modify: `ops/tests/test-compile-floor.sh` (add custom-script tests)
- Create: `ops/tests/fixtures/floor-with-custom-script.md`
- Create: `ops/tests/fixtures/test-custom-check.sh`

- [ ] **Step 1: Create fixture and test script**

Create `ops/tests/fixtures/test-custom-check.sh`:

```bash
#!/usr/bin/env bash
# Test custom check script — blocks files with "FIXME" in them
grep -q "FIXME" "$1" && echo "BLOCKED: FIXME found" && exit 2
exit 0
```

Create `ops/tests/fixtures/floor-with-custom-script.md` with the Write tool. Contains:

- Rule 1: `**No FIXME in production.**` with `pre-tool-use` custom-script pointing to `ops/tests/fixtures/test-custom-check.sh`, AND `post-tool-use` content-pattern for `FIXME` (satisfies real-time enforcement requirement)

- [ ] **Step 2: Write custom-script tests**

Add to `ops/tests/test-compile-floor.sh`:

```bash
echo "--- Custom Script ---"

TMPDIR=$(mktemp -d)
trap "rm -rf $TMPDIR" EXIT

chmod +x "$FIXTURES/test-custom-check.sh"
"$COMPILER" --proposal test-001 "$FIXTURES/floor-with-custom-script.md" "$TMPDIR" >/dev/null 2>&1
chmod +x "$TMPDIR/enforce.sh"

# Custom script should be wrapped with timeout
assert_contains "enforce.sh wraps custom script with timeout" "$TMPDIR/enforce.sh" "timeout 10"

# Test execution: file with FIXME should be blocked
echo "FIXME: need to fix this" > "$TMPDIR/test-bad.txt"
"$TMPDIR/enforce.sh" pre-tool-use "$TMPDIR/test-bad.txt" >/dev/null 2>&1
assert_exit "custom script blocks file with FIXME" 2 $?

# Test execution: clean file should pass
echo "all good here" > "$TMPDIR/test-good.txt"
"$TMPDIR/enforce.sh" pre-tool-use "$TMPDIR/test-good.txt" >/dev/null 2>&1
assert_exit "custom script passes clean file" 0 $?

rm -rf "$TMPDIR"
trap - EXIT
```

- [ ] **Step 3: Run tests, verify fail, implement, verify pass**

In `generate_enforce()`, add custom-script handling: generate a check function that wraps the script path with `timeout 10` and calls it with the file path as the first argument. Validate during compilation that the script path exists and is within the repository root.

- [ ] **Step 4: Commit**

```bash
git add ops/compile-floor.sh ops/tests/
git commit -m "feat: add custom-script check type to compliance compiler

Custom scripts wrapped with timeout 10. Script path validated during
compilation (must exist, must be within repo root). Exit codes: 0=pass,
1=warn, 2=block."
```

---

## Task 15: SessionStart Staleness Check

**Files:**

- Modify: `.claude/settings.json` (add staleness check to SessionStart hook — use Write tool per CLAUDE.md gotchas)

- [ ] **Step 1: Add staleness check to SessionStart**

Read the current `.claude/settings.json`. Add a new hook to the `SessionStart` array that runs a lightweight manifest check:

```bash
[ -f .claude/compliance/compiled/manifest.sha256 ] && [ -f compliance-floor.md ] && { EXPECTED=$(grep '^source:' .claude/compliance/compiled/manifest.sha256 | cut -d' ' -f2); ACTUAL=$(sha256sum compliance-floor.md | cut -d' ' -f1); [ "$EXPECTED" = "$ACTUAL" ] && echo '[CO] Compliance artifacts in sync.' || echo '[CO] WARNING: Compliance floor changed but artifacts not recompiled. Run ops/compile-floor.sh or /compliance apply.'; } || true
```

Use the Write tool to rewrite `settings.json` (per CLAUDE.md gotchas about settings.json edits).

- [ ] **Step 2: Verify the hook runs without errors**

```bash
bash -c 'source <(grep "manifest" .claude/settings.json | head -1)' 2>&1 || echo "syntax check only"
```

- [ ] **Step 3: Commit**

```bash
git add .claude/settings.json
git commit -m "feat: add compliance staleness check to SessionStart

Lightweight hash comparison: floor source hash vs manifest source hash.
Warns if floor changed but artifacts not recompiled. No recompilation
on session start — CI handles full verification."
```

---

## Task 16: End-to-End Integration Test

**Files:**

- Modify: `ops/tests/test-compile-floor.sh` (add e2e test)

Full round-trip: compile → verify → tamper → verify fails → recompile → verify passes.

- [ ] **Step 1: Write e2e test**

Add to `ops/tests/test-compile-floor.sh`:

```bash
echo "--- End-to-End ---"

TMPDIR=$(mktemp -d)
DOCS_DIR=$(mktemp -d)
trap "rm -rf $TMPDIR $DOCS_DIR" EXIT

# Full compile
COVERAGE_PATH="$DOCS_DIR/compliance-coverage.md" \
  "$COMPILER" --proposal e2e-001 "$FIXTURES/floor-valid.md" "$TMPDIR" >/dev/null 2>&1
assert_exit "full compile succeeds" 0 $?

# All artifacts exist
assert_file_exists "e2e: prose floor" "$TMPDIR/compliance-floor.prose.md"
assert_file_exists "e2e: enforce.sh" "$TMPDIR/enforce.sh"
assert_file_exists "e2e: manifest" "$TMPDIR/manifest.sha256"
assert_file_exists "e2e: coverage report" "$DOCS_DIR/compliance-coverage.md"

# Verify passes
"$COMPILER" --verify "$FIXTURES/floor-valid.md" "$TMPDIR" >/dev/null 2>&1
assert_exit "e2e: verify passes after compile" 0 $?

# Tamper with enforce.sh
echo "# tampered" >> "$TMPDIR/enforce.sh"

# Verify catches tampering
"$COMPILER" --verify "$FIXTURES/floor-valid.md" "$TMPDIR" >/dev/null 2>&1
assert_exit "e2e: verify catches tampering" 1 $?

# Recompile fixes it
COVERAGE_PATH="$DOCS_DIR/compliance-coverage.md" \
  "$COMPILER" --proposal e2e-002 "$FIXTURES/floor-valid.md" "$TMPDIR" >/dev/null 2>&1
assert_exit "e2e: recompile succeeds" 0 $?

# Verify passes again
"$COMPILER" --verify "$FIXTURES/floor-valid.md" "$TMPDIR" >/dev/null 2>&1
assert_exit "e2e: verify passes after recompile" 0 $?

rm -rf "$TMPDIR" "$DOCS_DIR"
trap - EXIT
```

- [ ] **Step 2: Run full test suite**

```bash
ops/tests/test-compile-floor.sh
```

Expected: All tests PASS

- [ ] **Step 3: Commit**

```bash
git add ops/tests/test-compile-floor.sh
git commit -m "test: add end-to-end integration test for compliance compiler

Full round-trip: compile → verify → tamper → verify fails → recompile →
verify passes. Validates all artifact generation and integrity checking."
```

---

## Task 17: Documentation + Final Cleanup

**Files:**

- Modify: `CLAUDE.md` (add compiler to Commands section)
- Create: `.claude/compliance/compiled/.gitkeep` (ensure directory exists)

- [ ] **Step 1: Add compiler commands to CLAUDE.md**

In the `### Metrics` section or a new `### Compliance Compiler` subsection:

````markdown
### Compliance Compiler

```bash
ops/compile-floor.sh                              # Compile floor → artifacts
ops/compile-floor.sh --dry-run                     # Validate without writing
ops/compile-floor.sh --verify                      # Check artifacts match source
ops/compile-floor.sh --proposal 003                # Tag artifacts with proposal ID
ops/tests/test-compile-floor.sh                    # Run compiler tests
```
````

````

- [ ] **Step 2: Create compiled directory with gitkeep**

```bash
mkdir -p .claude/compliance/compiled
touch .claude/compliance/compiled/.gitkeep
````

- [ ] **Step 3: Run full test suite one final time**

```bash
ops/tests/test-compile-floor.sh
```

Expected: All tests PASS

- [ ] **Step 4: Commit**

```bash
git add CLAUDE.md .claude/compliance/compiled/.gitkeep
git commit -m "docs: add compliance compiler commands to CLAUDE.md

Documents compile, dry-run, verify modes and test command. Creates
.claude/compliance/compiled/ directory for generated artifacts."
```
