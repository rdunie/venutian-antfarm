# Compiler Simplification Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the 1558-line `compile-floor.sh` with a gomplate-based compiler using template files for artifact generation and a YAML schema for block validation.

**Architecture:** The compiler stays as a single entry point but becomes an orchestrator that calls gomplate for generation and a separate `validate.sh` for schema-driven validation. Heavy lifting moves to template files in `ops/compiler/templates/` and a schema definition in `ops/compiler/schema.yaml`. Migration is incremental — each task must pass all 111 existing tests before proceeding.

**Tech Stack:** Bash, gomplate v4+, yq, jq

**Spec:** `docs/superpowers/specs/2026-03-26-compiler-simplification-design.md`

---

## Prerequisites

**Install gomplate before starting:**
```bash
# macOS/Linux
brew install gomplate

# Or via Go
go install github.com/hairyhenderson/gomplate/v4@latest

# Or download binary from https://github.com/hairyhenderson/gomplate/releases
```

Verify: `gomplate --version` should show v4.x.

---

## File Structure

### New Files

| File | Responsibility |
|------|---------------|
| `ops/compiler/schema.yaml` | Declarative enforcement block schema (required fields, forbidden fields, type constraints) |
| `ops/compiler/validate.sh` | Schema-driven validation script — reads schema.yaml + relational constraints |
| `ops/compiler/templates/prose.md.tmpl` | Gomplate template for prose floor output |
| `ops/compiler/templates/coverage.md.tmpl` | Gomplate template for coverage report |
| `ops/compiler/templates/manifest.sha256.tmpl` | Gomplate template for manifest |
| `ops/compiler/templates/semgrep-rules.yaml.tmpl` | Gomplate template for semgrep config |
| `ops/compiler/templates/eslint-rules.json.tmpl` | Gomplate template for eslint config |
| `ops/compiler/templates/enforce.sh.tmpl` | Gomplate template for enforce.sh dispatcher (riskiest — last) |

### Modified Files

| File | Change |
|------|--------|
| `ops/compile-floor.sh` | Replace inline generators with gomplate calls, add `prepare_context`, add gomplate dep check |
| `CLAUDE.md` | Document gomplate dependency |

### Not Changed

| File | Reason |
|------|--------|
| `ops/tests/test-compile-floor.sh` | Tests verify behavior — must pass unchanged |
| `ops/tests/fixtures/*` | Test inputs unchanged |

---

## Task 1: Install Gomplate and Add Dependency Check

**Files:**
- Modify: `ops/compile-floor.sh:97-101` (dependency check section)

- [ ] **Step 1: Install gomplate**

```bash
brew install gomplate || go install github.com/hairyhenderson/gomplate/v4@latest
```

Verify: `gomplate --version`

- [ ] **Step 2: Add gomplate dep check to compiler**

In `ops/compile-floor.sh`, after the existing yq dependency check (around line 101), add:

```bash
if ! command -v gomplate &>/dev/null; then
  echo "ERROR: gomplate v4+ is required but not installed." >&2
  echo "Install with: brew install gomplate  OR  go install github.com/hairyhenderson/gomplate/v4@latest" >&2
  exit 2
fi
```

- [ ] **Step 3: Run tests to verify nothing breaks**

```bash
bash ops/tests/test-compile-floor.sh
```

Expected: 111/111 pass.

- [ ] **Step 4: Commit**

```bash
git add ops/compile-floor.sh
git commit -m "feat(#22): add gomplate dependency check to compiler"
```

---

## Task 2: Extract Validation to `ops/compiler/validate.sh`

**Files:**
- Create: `ops/compiler/validate.sh`
- Modify: `ops/compile-floor.sh` (replace `validate_block` calls with `validate.sh` calls)

This task moves the existing `validate_block` function to a standalone script with the same behavior. No schema yet — just extraction.

- [ ] **Step 1: Create the `ops/compiler/` directory**

```bash
mkdir -p ops/compiler/templates
```

- [ ] **Step 2: Extract `validate_block` to `ops/compiler/validate.sh`**

Create `ops/compiler/validate.sh` with:
- Shebang and `set -euo pipefail`
- The entire `validate_block` function body (lines 232-446 of current `compile-floor.sh`)
- Accept a single argument: the block YAML file path
- Call the validation logic on the argument
- Exit 0 on valid, exit 2 on invalid (same as current behavior)

The script structure:

```bash
#!/usr/bin/env bash
set -euo pipefail

# ---------------------------------------------------------------------------
# validate.sh — Enforcement block validator
#
# Usage: validate.sh <block-file>
# Exits 0 on valid, 2 on invalid (errors to stderr).
# ---------------------------------------------------------------------------

if [[ $# -ne 1 ]]; then
  echo "Usage: validate.sh <block-file>" >&2
  exit 1
fi

BLOCK_FILE="$1"

if [[ ! -f "${BLOCK_FILE}" ]]; then
  echo "ERROR: Block file not found: ${BLOCK_FILE}" >&2
  exit 2
fi

# --- paste the entire body of validate_block() here, replacing
#     references to $1 with ${BLOCK_FILE} and $block_file with ${BLOCK_FILE} ---
```

Make executable: `chmod +x ops/compiler/validate.sh`

- [ ] **Step 3: Update `compile-floor.sh` to call `validate.sh` instead of `validate_block`**

Find all calls to `validate_block` in the mode dispatch section. They look like:

```bash
validate_block "${block_file}"
```

Replace each with:

```bash
"${SCRIPT_DIR}/compiler/validate.sh" "${block_file}"
```

Where `SCRIPT_DIR` is `$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)` — add this variable near the top of the script if not already present.

- [ ] **Step 4: Remove the `validate_block` function from `compile-floor.sh`**

Delete lines 232-446 (the entire `validate_block` function).

- [ ] **Step 5: Run tests**

```bash
bash ops/tests/test-compile-floor.sh
```

Expected: 111/111 pass.

- [ ] **Step 6: Commit**

```bash
git add ops/compiler/validate.sh ops/compile-floor.sh
git commit -m "refactor(#22): extract validation to ops/compiler/validate.sh"
```

---

## Task 3: Add Schema and Schema-Driven Validation

**Files:**
- Create: `ops/compiler/schema.yaml`
- Modify: `ops/compiler/validate.sh`

Replace hardcoded field checks with schema-driven loops where possible. Relational constraints stay as code.

- [ ] **Step 1: Create `ops/compiler/schema.yaml`**

```yaml
# Enforcement block schema — used by validate.sh
required_fields:
  version:
    type: integer
    value: 1
  id:
    type: string
    non_empty: true
  severity:
    type: enum
    values: ["blocking", "warning"]

forbidden_fields:
  - bypass
  - skip
  - override

enforce:
  # At least one of these must be present
  valid_points: ["pre-tool-use", "post-tool-use", "ci"]
  required_points: ["pre-tool-use", "post-tool-use"]  # at least one

  # Check type validity per enforcement point
  type_constraints:
    file-pattern: ["pre-tool-use"]
    content-pattern: ["pre-tool-use", "post-tool-use"]
    semgrep: ["post-tool-use", "ci"]
    eslint: ["post-tool-use", "ci"]
    custom-script: ["pre-tool-use", "post-tool-use", "ci"]
```

- [ ] **Step 2: Refactor `validate.sh` to read schema**

Update `validate.sh` to:
1. Determine its own directory: `SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"`
2. Read `schema.yaml` from `${SCRIPT_DIR}/schema.yaml`
3. Replace hardcoded required field checks with a loop over `required_fields` from schema
4. Replace hardcoded forbidden field checks with a loop over `forbidden_fields` from schema
5. Replace hardcoded type constraint checks with a loop reading `enforce.type_constraints` from schema
6. Keep relational constraints as explicit code: severity/action contradiction, rule-path/rule-id existence, custom-script file checks

The script should be ~80-100 lines now (down from 214).

- [ ] **Step 3: Run tests**

```bash
bash ops/tests/test-compile-floor.sh
```

Expected: 111/111 pass. The validation behavior is identical — only the implementation changed.

- [ ] **Step 4: Commit**

```bash
git add ops/compiler/schema.yaml ops/compiler/validate.sh
git commit -m "feat(#22): add declarative schema for enforcement block validation"
```

---

## Task 4: Add Context Preparation Function

**Files:**
- Modify: `ops/compile-floor.sh`

Add `prepare_context` that builds a JSON context from extracted blocks. This function doesn't change any behavior yet — it's preparation for the template tasks.

- [ ] **Step 1: Write `prepare_context` function**

Add to `compile-floor.sh` after `extract_blocks`:

```bash
# ---------------------------------------------------------------------------
# prepare_context — build JSON context from extracted blocks for gomplate
#
# Arguments:
#   $1  floor file path
#   $2  output directory containing block-NNN.yaml files
#   $3  proposal ID (may be empty)
#
# Writes context.json to $2 and prints its path to stdout.
# ---------------------------------------------------------------------------

prepare_context() {
  local floor_file="$1"
  local out_dir="$2"
  local proposal_id="${3:-}"
  local context_file="${out_dir}/context.json"

  local base_name
  base_name="$(basename "${floor_file}" .md)"

  local floor_name="${base_name}"

  # Count total prose rules
  local total_rules=0
  total_rules=$(grep -cE '^### Rule [0-9]+' "${floor_file}" 2>/dev/null) || true
  if [[ "${total_rules}" -eq 0 ]]; then
    total_rules=$(grep -cE '^[0-9]+\. \*\*' "${floor_file}" 2>/dev/null) || true
  fi

  # Build blocks array
  local blocks_json="[]"
  for block_file in "${out_dir}"/block-*.yaml; do
    [[ -f "${block_file}" ]] || continue

    local id severity source_line
    id="$(yq -r '.id // ""' "${block_file}")"
    severity="$(yq -r '.severity // ""' "${block_file}")"
    source_line="$(yq -r '._source_line // ""' "${block_file}")"

    local func_name="check_${id//-/_}"

    # Build enforce object with computed fields
    local enforce_json
    enforce_json="$(yq -o=json '.enforce' "${block_file}")"

    # Add exit_code and patterns_joined to each enforcement point
    local enriched_enforce="{}"
    local ekeys
    ekeys="$(yq -r '.enforce | keys | .[]' "${block_file}" 2>/dev/null || true)"
    while IFS= read -r ekey; do
      [[ -z "${ekey}" ]] && continue
      local etype eaction eexit patterns_joined
      etype="$(yq -r ".enforce.\"${ekey}\".type // \"\"" "${block_file}")"
      eaction="$(yq -r ".enforce.\"${ekey}\".action // \"\"" "${block_file}")"
      eexit=1
      [[ "${eaction}" == "block" ]] && eexit=2

      # Join patterns
      patterns_joined=""
      local pats
      pats="$(yq -r ".enforce.\"${ekey}\".patterns[]?" "${block_file}" 2>/dev/null || true)"
      while IFS= read -r pat; do
        [[ -z "${pat}" ]] && continue
        if [[ -n "${patterns_joined}" ]]; then
          patterns_joined="${patterns_joined}|${pat}"
        else
          patterns_joined="${pat}"
        fi
      done <<< "${pats}"

      enriched_enforce="$(echo "${enriched_enforce}" | jq \
        --arg key "${ekey}" \
        --arg type "${etype}" \
        --arg action "${eaction}" \
        --argjson exit_code "${eexit}" \
        --arg patterns_joined "${patterns_joined}" \
        --argjson original "$(yq -o=json ".enforce.\"${ekey}\"" "${block_file}")" \
        '.[$key] = ($original + {"exit_code": $exit_code, "patterns_joined": $patterns_joined})'
      )"
    done <<< "${ekeys}"

    blocks_json="$(echo "${blocks_json}" | jq \
      --arg id "${id}" \
      --arg severity "${severity}" \
      --arg source_line "${source_line}" \
      --arg func_name "${func_name}" \
      --argjson enforce "${enriched_enforce}" \
      '. + [{"id": $id, "severity": $severity, "source_line": $source_line, "func_name": $func_name, "enforce": $enforce}]'
    )"
  done

  local block_count
  block_count="$(echo "${blocks_json}" | jq 'length')"
  local judgment_count=$(( total_rules - block_count ))
  [[ "${judgment_count}" -lt 0 ]] && judgment_count=0

  # Build full context
  jq -n \
    --arg file "${floor_file}" \
    --arg name "${floor_name}" \
    --arg base_name "${base_name}" \
    --arg proposal_id "${proposal_id}" \
    --argjson blocks "${blocks_json}" \
    --argjson total_rules "${total_rules}" \
    --argjson block_count "${block_count}" \
    --argjson judgment_count "${judgment_count}" \
    --arg coverage_path "${COVERAGE_PATH:-docs/compliance-coverage.md}" \
    '{
      floor: {file: $file, name: $name, base_name: $base_name, proposal_id: $proposal_id},
      blocks: $blocks,
      stats: {total_rules: $total_rules, block_count: $block_count, judgment_count: $judgment_count},
      coverage_path: $coverage_path
    }' > "${context_file}"

  echo "${context_file}"
}
```

- [ ] **Step 2: Run tests — no behavior change yet**

```bash
bash ops/tests/test-compile-floor.sh
```

Expected: 111/111 pass (function exists but isn't called yet).

- [ ] **Step 3: Commit**

```bash
git add ops/compile-floor.sh
git commit -m "feat(#22): add prepare_context function for gomplate datasource"
```

---

## Task 5: Template Prose Generation

**Files:**
- Create: `ops/compiler/templates/prose.md.tmpl`
- Modify: `ops/compile-floor.sh` (replace `generate_prose` call with gomplate)

- [ ] **Step 1: Create `ops/compiler/templates/prose.md.tmpl`**

The prose template is simple — it just emits a header. The actual fence stripping is done in bash (preprocessing) because gomplate can't easily parse markdown fences. The orchestrator passes the stripped content as a context field.

```
# GENERATED by ops/compile-floor.sh from {{ (ds "ctx").floor.base_name }}.md
# Do not edit — changes will be overwritten. Proposal: {{ (ds "ctx").floor.proposal_id | default "<none>" }}
{{ (ds "ctx").prose_content }}
```

- [ ] **Step 2: Add `strip_enforcement_fences` helper to `compile-floor.sh`**

Add a small function that strips enforcement fences from markdown and returns the result:

```bash
strip_enforcement_fences() {
  local input_file="$1"
  local in_block=0
  while IFS= read -r line || [[ -n "${line}" ]]; do
    if [[ "${in_block}" -eq 0 ]]; then
      if [[ "${line}" == '```enforcement' ]]; then
        in_block=1
      else
        printf '%s\n' "${line}"
      fi
    else
      if [[ "${line}" == '```' ]]; then
        in_block=0
      fi
    fi
  done < "${input_file}"
}
```

- [ ] **Step 3: Update the compile mode to use gomplate for prose**

In the `compile)` case, replace the `generate_prose` call:

```bash
# Generate prose via template
local prose_content
prose_content="$(strip_enforcement_fences "${FLOOR_FILE}")"
local prose_ctx
prose_ctx="$(mktemp)"
jq --arg content "${prose_content}" '. + {prose_content: $content}' "${context_file}" > "${prose_ctx}"
gomplate -d ctx="file://${prose_ctx}?type=application/json" \
  -f "${SCRIPT_DIR}/compiler/templates/prose.md.tmpl" \
  -o "${OUTPUT_DIR}/${base_name}.prose.md"
rm -f "${prose_ctx}"
```

Also update the `prose-only)` mode similarly.

- [ ] **Step 4: Remove the old `generate_prose` function**

Delete the `generate_prose` function (lines ~458-496).

- [ ] **Step 5: Run tests**

```bash
bash ops/tests/test-compile-floor.sh
```

Expected: 111/111 pass.

- [ ] **Step 6: Commit**

```bash
git add ops/compiler/templates/prose.md.tmpl ops/compile-floor.sh
git commit -m "refactor(#22): replace generate_prose with gomplate template"
```

---

## Task 6: Template Coverage Report

**Files:**
- Create: `ops/compiler/templates/coverage.md.tmpl`
- Modify: `ops/compile-floor.sh`

- [ ] **Step 1: Create `ops/compiler/templates/coverage.md.tmpl`**

```
# GENERATED by ops/compile-floor.sh from {{ (ds "ctx").floor.base_name }}.md
# Do not edit — changes will be overwritten.

# Compliance Coverage Report

| Rule ID | Severity | Enforcement Points | Check Types | Status |
|---------|----------|--------------------|-------------|--------|
{{- range (ds "ctx").blocks }}
| {{ .id }} | {{ .severity }} | {{ $points := slice }}{{ if has .enforce "pre-tool-use" }}{{ $points = append $points "pre-tool-use" }}{{ end }}{{ if has .enforce "post-tool-use" }}{{ $points = append $points "post-tool-use" }}{{ end }}{{ join $points ", " }} | {{ $types := slice }}{{ if has .enforce "pre-tool-use" }}{{ $types = append $types (index .enforce "pre-tool-use").type }}{{ end }}{{ if has .enforce "post-tool-use" }}{{ $types = append $types (index .enforce "post-tool-use").type }}{{ end }}{{ join $types ", " }} | covered |
{{- end }}
{{- $jcount := (ds "ctx").stats.judgment_count }}{{ range $i := seq 1 $jcount }}
| (prose-only-{{ $i }}) | — | — | — | judgment-only |
{{- end }}

## What Each Layer Guarantees

- **covered**: Rule has automated enforcement via hook checks at one or more enforcement points.
- **judgment-only**: Rule is enforced through human review and design judgment only — no automated check exists.

## Summary

- Total rules: {{ (ds "ctx").stats.total_rules }}
- Covered by automation: {{ (ds "ctx").stats.block_count }}
- judgment-only (human review): {{ (ds "ctx").stats.judgment_count }}
```

- [ ] **Step 2: Update compile mode to use gomplate for coverage**

Replace the `generate_coverage` call with:

```bash
local coverage_path="${COVERAGE_PATH:-docs/compliance-coverage.md}"
mkdir -p "$(dirname "${coverage_path}")"
gomplate -d ctx="file://${context_file}?type=application/json" \
  -f "${SCRIPT_DIR}/compiler/templates/coverage.md.tmpl" \
  -o "${coverage_path}"
```

- [ ] **Step 3: Remove the old `generate_coverage` function**

Delete lines ~1072-1168.

- [ ] **Step 4: Run tests**

```bash
bash ops/tests/test-compile-floor.sh
```

Expected: 111/111 pass. If coverage output differs slightly (whitespace), adjust the template to match exactly.

- [ ] **Step 5: Commit**

```bash
git add ops/compiler/templates/coverage.md.tmpl ops/compile-floor.sh
git commit -m "refactor(#22): replace generate_coverage with gomplate template"
```

---

## Task 7: Template Manifest

**Files:**
- Create: `ops/compiler/templates/manifest.sha256.tmpl`
- Modify: `ops/compile-floor.sh`

- [ ] **Step 1: Create `ops/compiler/templates/manifest.sha256.tmpl`**

```
source: {{ (ds "ctx").hashes.source }}
compiled-from: {{ (ds "ctx").floor.proposal_id }}
artifacts:
  {{ (ds "ctx").floor.base_name }}.prose.md: {{ (ds "ctx").hashes.prose }}
  enforce.sh: {{ (ds "ctx").hashes.enforce }}
{{- if (ds "ctx").hashes.coverage }}
  {{ (ds "ctx").floor.base_name }}-coverage.md: {{ (ds "ctx").hashes.coverage }}
{{- end }}
```

- [ ] **Step 2: Add hash computation to context**

Before calling the manifest template, compute hashes and add them to the context:

```bash
# Compute artifact hashes for manifest
local source_hash prose_hash enforce_hash coverage_hash
source_hash="$(sha256sum "${FLOOR_FILE}" | cut -d' ' -f1)"
prose_hash=""
[[ -f "${OUTPUT_DIR}/${base_name}.prose.md" ]] && prose_hash="$(sha256sum "${OUTPUT_DIR}/${base_name}.prose.md" | cut -d' ' -f1)"
enforce_hash=""
[[ -f "${OUTPUT_DIR}/enforce.sh" ]] && enforce_hash="$(sha256sum "${OUTPUT_DIR}/enforce.sh" | cut -d' ' -f1)"
coverage_hash=""
# Only include if coverage path is inside output dir
local out_dir_abs coverage_abs
out_dir_abs="$(cd "${OUTPUT_DIR}" && pwd)"
local cov_path="${COVERAGE_PATH:-}"
if [[ -n "${cov_path}" && -f "${cov_path}" ]]; then
  coverage_abs="$(cd "$(dirname "${cov_path}")" && pwd)/$(basename "${cov_path}")"
  if [[ "${coverage_abs}" == "${out_dir_abs}/"* ]]; then
    coverage_hash="$(sha256sum "${cov_path}" | cut -d' ' -f1)"
  fi
fi

# Update context with hashes
local manifest_ctx
manifest_ctx="$(mktemp)"
jq --arg source "${source_hash}" --arg prose "${prose_hash}" \
   --arg enforce "${enforce_hash}" --arg coverage "${coverage_hash}" \
   '.hashes = {source: $source, prose: $prose, enforce: $enforce, coverage: $coverage}' \
   "${context_file}" > "${manifest_ctx}"

gomplate -d ctx="file://${manifest_ctx}?type=application/json" \
  -f "${SCRIPT_DIR}/compiler/templates/manifest.sha256.tmpl" \
  -o "${OUTPUT_DIR}/manifest.sha256"
rm -f "${manifest_ctx}"
```

- [ ] **Step 3: Remove old `generate_manifest` function**

- [ ] **Step 4: Run tests**

```bash
bash ops/tests/test-compile-floor.sh
```

Expected: 111/111 pass. Manifest format must match exactly.

- [ ] **Step 5: Commit**

```bash
git add ops/compiler/templates/manifest.sha256.tmpl ops/compile-floor.sh
git commit -m "refactor(#22): replace generate_manifest with gomplate template"
```

---

## Task 8: Template Semgrep Config

**Files:**
- Create: `ops/compiler/templates/semgrep-rules.yaml.tmpl`
- Modify: `ops/compile-floor.sh`

- [ ] **Step 1: Create `ops/compiler/templates/semgrep-rules.yaml.tmpl`**

```
# GENERATED by ops/compile-floor.sh — do not edit manually.
# Re-generate with: ops/compile-floor.sh --generate-enforce
{{ $found := 0 }}
{{- range (ds "ctx").blocks }}
{{- range $point, $cfg := .enforce }}
{{- if eq $cfg.type "semgrep" }}{{ $found = add $found 1 }}{{ end }}
{{- end }}
{{- end }}
{{- if gt $found 0 }}
rules:
{{- range (ds "ctx").blocks }}
{{- range $point, $cfg := .enforce }}
{{- if eq $cfg.type "semgrep" }}
  # rule-id: {{ $cfg.rule_id }}
{{- end }}
{{- end }}
{{- end }}
{{- else }}
# No semgrep rules defined in compliance floor.
rules: []
{{- end }}
```

**Note:** The current generator also reads rule-path files and merges their content. Since the test fixtures don't have real semgrep rule files, and the merger is complex, keep the rule-path file reading in the orchestrator and pass merged content via context. If test fixtures only produce the stub output (just rule-id comments), the simple template above is sufficient. Verify by checking what the tests expect.

- [ ] **Step 2: Replace `generate_semgrep` call with gomplate**

- [ ] **Step 3: Remove old `generate_semgrep` function**

- [ ] **Step 4: Run tests**

```bash
bash ops/tests/test-compile-floor.sh
```

Expected: 111/111 pass.

- [ ] **Step 5: Commit**

```bash
git add ops/compiler/templates/semgrep-rules.yaml.tmpl ops/compile-floor.sh
git commit -m "refactor(#22): replace generate_semgrep with gomplate template"
```

---

## Task 9: Template ESLint Config

**Files:**
- Create: `ops/compiler/templates/eslint-rules.json.tmpl`
- Modify: `ops/compile-floor.sh`

- [ ] **Step 1: Create `ops/compiler/templates/eslint-rules.json.tmpl`**

```
// GENERATED by ops/compile-floor.sh — do not edit manually.
// Re-generate with: ops/compile-floor.sh --generate-enforce
{{ $ruleIds := slice }}
{{- range (ds "ctx").blocks }}
{{- range $point, $cfg := .enforce }}
{{- if eq $cfg.type "eslint" }}{{ $ruleIds = append $ruleIds $cfg.rule_id }}{{ end }}
{{- end }}
{{- end }}
{{- if gt (len $ruleIds) 0 }}
// ESLint rules from compliance floor: {{ join $ruleIds "," }}
{
  "_rules": [{{ range $i, $id := $ruleIds }}{{ if $i }},{{ end }}"{{ $id }}"{{ end }}],
  "_generated": true
}
{{- else }}
// No eslint rules defined in compliance floor.
{}
{{- end }}
```

- [ ] **Step 2: Replace `generate_eslint` call with gomplate**

- [ ] **Step 3: Remove old `generate_eslint` function**

- [ ] **Step 4: Run tests**

```bash
bash ops/tests/test-compile-floor.sh
```

Expected: 111/111 pass.

- [ ] **Step 5: Commit**

```bash
git add ops/compiler/templates/eslint-rules.json.tmpl ops/compile-floor.sh
git commit -m "refactor(#22): replace generate_eslint with gomplate template"
```

---

## Task 10: Template Enforce.sh (Riskiest)

**Files:**
- Create: `ops/compiler/templates/enforce.sh.tmpl`
- Modify: `ops/compile-floor.sh`

This is the biggest and riskiest task. The enforce.sh template must produce output **byte-for-byte identical** to the current `generate_enforce` function. Use diff to verify.

**Strategy:** Before replacing the function, generate output from both the old function and the new template, diff them, and fix discrepancies.

- [ ] **Step 1: Capture reference output from the old generator**

For each test fixture that produces an enforce.sh, capture the current output:

```bash
cd /path/to/worktree
# Compile the valid fixture and save reference enforce.sh
mkdir -p /tmp/enforce-ref
bash ops/compile-floor.sh ops/tests/fixtures/floor-valid.md /tmp/enforce-ref
cp /tmp/enforce-ref/enforce.sh /tmp/enforce-ref-output.sh
```

- [ ] **Step 2: Create `ops/compiler/templates/enforce.sh.tmpl`**

The template must emit:
1. Static header (shebang, `set -euo pipefail`, GENERATED comment)
2. `SCRIPT_DIR`, `log_violation`, `log_pass` helper functions
3. Floor identity: `FLOOR_NAME` and `FLOOR_FILE` variables
4. Per-block pre-tool-use check functions (iterated from context)
5. Per-block post-tool-use check functions (iterated from context)
6. The `dispatch()` function with:
   - `pre-tool-use)` case: floor protection logic + per-rule calls
   - `post-tool-use)` case: per-rule calls
   - Main entry point

The floor protection logic is static bash with `FLOOR_NAME` and `FLOOR_FILE` interpolated. It handles:
- `floors/*.md` sentinel-gated blocking
- Legacy `compliance-floor.md` sentinel-gated blocking
- `.claude/floors/*/compiled/*` warn
- `.claude/compliance/*` sentinel-gated blocking
- `ops/compile-floor.sh` warn
- Agent file modification warn

This is ~140-160 lines of gomplate template. Each check function type (file-pattern, content-pattern, custom-script, semgrep, eslint) has its own template block.

**IMPORTANT:** Match the exact output format — including comments, spacing, and variable quoting. The tests compare output behavior, not string equality, but some tests may check file contents.

- [ ] **Step 3: Add parallel generation for comparison**

Temporarily add a second code path that generates enforce.sh via gomplate alongside the old generator:

```bash
# Generate via template (parallel comparison)
gomplate -d ctx="file://${context_file}?type=application/json" \
  -f "${SCRIPT_DIR}/compiler/templates/enforce.sh.tmpl" \
  -o "${OUTPUT_DIR}/enforce.sh.new"

# Diff against old output
diff "${OUTPUT_DIR}/enforce.sh" "${OUTPUT_DIR}/enforce.sh.new" || {
  echo "WARNING: Template output differs from old generator" >&2
}
rm -f "${OUTPUT_DIR}/enforce.sh.new"
```

Run tests and fix template until diff is clean.

- [ ] **Step 4: Switch to template-only generation**

Once diff is clean, remove the old `generate_enforce` function and the parallel comparison. Use only gomplate.

- [ ] **Step 5: Run tests**

```bash
bash ops/tests/test-compile-floor.sh
```

Expected: 111/111 pass.

- [ ] **Step 6: Commit**

```bash
git add ops/compiler/templates/enforce.sh.tmpl ops/compile-floor.sh
git commit -m "refactor(#22): replace generate_enforce with gomplate template"
```

---

## Task 11: Clean Up Dead Code

**Files:**
- Modify: `ops/compile-floor.sh`

- [ ] **Step 1: Verify all old generator functions are removed**

Grep for old function names that should no longer exist in `compile-floor.sh`:

```bash
grep -n 'generate_prose\|generate_enforce\|generate_semgrep\|generate_eslint\|generate_coverage\|generate_manifest\|validate_block' ops/compile-floor.sh
```

Expected: Only references to the new gomplate calls and `validate.sh`.

- [ ] **Step 2: Remove any leftover dead code**

If any old functions or dead variables remain, remove them.

- [ ] **Step 3: Verify orchestrator line count**

```bash
wc -l ops/compile-floor.sh
```

Expected: ~300-400 lines (down from 1558).

- [ ] **Step 4: Run full test suite one final time**

```bash
bash ops/tests/test-compile-floor.sh
```

Expected: 111/111 pass.

- [ ] **Step 5: Syntax check**

```bash
bash -n ops/compile-floor.sh
bash -n ops/compiler/validate.sh
```

Both should pass.

- [ ] **Step 6: Commit**

```bash
git add ops/compile-floor.sh
git commit -m "refactor(#22): remove dead code from compiler after template migration"
```

---

## Task 12: Update CLAUDE.md

**Files:**
- Modify: `CLAUDE.md`

- [ ] **Step 1: Add gomplate to Prerequisites**

In the Quick Start section, after "**Prerequisites:** Claude Code CLI, Git, Bash, jq (optional).", update to:

```markdown
**Prerequisites:** Claude Code CLI, Git, Bash, gomplate v4+, jq (optional).
```

- [ ] **Step 2: Add note about compiler architecture**

In the Gotchas section, add:

```markdown
- **Compiler uses gomplate templates**: `ops/compile-floor.sh` orchestrates, `ops/compiler/templates/` contains gomplate templates for artifact generation, `ops/compiler/validate.sh` handles schema-driven validation. If gomplate is not installed, the compiler exits with install instructions.
```

- [ ] **Step 3: Update Directory Structure**

Add to the `ops/` subtree:

```
│   ├── compiler/                  # Compiler templates and schema
│   │   ├── schema.yaml
│   │   ├── validate.sh
│   │   └── templates/             # Gomplate templates for artifacts
```

- [ ] **Step 4: Commit**

```bash
git add CLAUDE.md
git commit -m "docs(#22): document gomplate dependency and compiler architecture"
```

---

## Key Files Reference

| File | Why |
|------|-----|
| `docs/superpowers/specs/2026-03-26-compiler-simplification-design.md` | The spec this plan implements |
| `ops/compile-floor.sh` | The compiler being simplified (1558 lines → ~300-400) |
| `ops/tests/test-compile-floor.sh` | Test suite (833 lines, 111 tests — must pass unchanged) |
| `ops/tests/fixtures/*` | Test fixture files |
| `ops/compiler/` | New directory for schema, validator, and templates |
