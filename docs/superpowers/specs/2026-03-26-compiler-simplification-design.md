# Compiler Simplification — Gomplate Templates + Schema Validation

**Issue:** [#22](https://github.com/rdunie/venutian-antfarm/issues/22)
**Date:** 2026-03-26
**Status:** Draft

## Problem

The compliance floor compiler (`ops/compile-floor.sh`) is 1558 lines of bash. The generation functions build bash scripts via string concatenation and heredocs (~400 lines of bash-generating-bash in `generate_enforce` alone). The validation function (`validate_block`) is 214 lines of field-by-field yq calls. The script is correct and well-tested (111 tests), but hard to read, modify, and extend.

## Goals

1. **Replace artifact generation with gomplate templates** — move enforce.sh, prose, coverage, manifest, semgrep, and eslint generation to template files.
2. **Replace field-by-field validation with a declarative schema** — define enforcement block structure in a YAML schema, validate against it.
3. **Preserve the entire test suite** — all 111 tests pass without modification.
4. **Preserve the CLI interface** — same flags, same arguments, same exit codes.

## Non-Goals

- Changing the generated output format (enforce.sh, prose, etc. remain identical)
- Adding new features to the compiler (this is purely simplification)
- Supporting multiple templating engines (gomplate only)
- Maintaining a fallback to inline generation (gomplate is required)

## Design

### New Directory Structure

```
ops/compile-floor.sh          (~300-400 lines — parsing, orchestration, mode dispatch)
ops/compiler/
├── schema.yaml              # Declarative enforcement block schema
├── validate.sh              # Schema validation using yq
├── templates/
│   ├── enforce.sh.tmpl      # Gomplate template for enforce.sh dispatcher
│   ├── prose.md.tmpl        # Gomplate template for prose floor
│   ├── coverage.md.tmpl     # Gomplate template for coverage report
│   ├── manifest.sha256.tmpl # Gomplate template for manifest
│   ├── semgrep-rules.yaml.tmpl
│   └── eslint-rules.json.tmpl
```

### 1. Schema Validation

**File:** `ops/compiler/schema.yaml`
**Script:** `ops/compiler/validate.sh` (~80-100 lines)

The schema defines:

- **Required fields:** `version` (must equal 1), `id` (non-empty string), `severity` (enum: `blocking` | `warning`)
- **Forbidden top-level fields:** `bypass`, `skip`, `override`
- **Enforcement structure:** At least one of `pre-tool-use` or `post-tool-use` under `enforce` (a block with only `ci` enforcement is intentionally invalid — `ci` is a supplementary point, not a standalone one)
- **Check type validity per enforcement point:**
  - `file-pattern` → `pre-tool-use` only
  - `content-pattern` → `pre-tool-use` or `post-tool-use`
  - `semgrep` → `post-tool-use` or `ci`
  - `eslint` → `post-tool-use` or `ci`
  - `custom-script` → any enforcement point
- **Relational constraints (code, not schema):**
  - Severity/action contradiction: `warning` + `block` → reject; `blocking` + `warn` → reject
  - `semgrep`/`eslint` types require `rule-path` (must exist as file) and `rule-id`
  - `custom-script` requires `script` (must be relative path, must exist, must be executable)

The schema file defines the structural rules declaratively. `validate.sh` reads the schema and iterates over fields using yq. Relational constraints that don't fit a pure schema (severity/action contradiction, file existence checks) remain as explicit code in `validate.sh`.

**Interface:** `ops/compiler/validate.sh <block-file>` — exits 0 on valid, exits 2 on invalid with error messages to stderr. Same behavior as current `validate_block` function.

### 2. Context Preparation

Between extraction and generation, the orchestrator builds a single JSON context from the extracted YAML blocks. This is passed to all gomplate templates as a datasource, eliminating the current pattern where each generator re-reads block files independently via yq.

```json
{
  "floor": {
    "file": "floors/compliance.md",
    "name": "compliance",
    "base_name": "compliance",
    "proposal_id": "003"
  },
  "blocks": [
    {
      "id": "no-secrets-in-code",
      "severity": "blocking",
      "source_line": 42,
      "enforce": {
        "pre-tool-use": {
          "type": "file-pattern",
          "action": "block",
          "exit_code": 2,
          "patterns": ["\\.env$", "secrets?\\.yaml$"],
          "patterns_joined": "\\.env$|secrets?\\.yaml$"
        },
        "post-tool-use": {
          "type": "content-pattern",
          "action": "warn",
          "exit_code": 1,
          "patterns": ["TODO|FIXME"],
          "patterns_joined": "TODO|FIXME"
        }
      },
      "func_name": "check_no_secrets_in_code"
    }
  ],
  "stats": {
    "total_rules": 5,
    "block_count": 3,
    "judgment_count": 2
  },
  "coverage_path": "docs/compliance-coverage.md",
  "hashes": {
    "source": "abc123...",
    "prose": "def456...",
    "enforce": "ghi789...",
    "coverage": "jkl012..."
  }
}
```

The context is built by a `prepare_context` function in the orchestrator (~40-50 lines) that reads all block files once and emits JSON via yq/jq.

### 3. Gomplate Templates

Each generator function is replaced by a gomplate template. The orchestrator invokes gomplate with the context JSON as a datasource.

**Invocation pattern:**

```bash
gomplate -d ctx="file://${context_file}?type=application/json" \
  -f "ops/compiler/templates/enforce.sh.tmpl" \
  -o "${OUTPUT_DIR}/enforce.sh"
```

#### `enforce.sh.tmpl` (~140-160 lines)

The biggest win. Replaces ~400 lines of bash string concatenation. The template:

1. Emits the static header (shebang, helpers: `log_violation`, `log_pass`)
2. Emits floor identity variables (`FLOOR_NAME`, `FLOOR_FILE`)
3. Iterates over blocks to emit per-rule check functions:
   - For each block with `pre-tool-use`: emit a check function based on type (file-pattern, content-pattern, custom-script)
   - For each block with `post-tool-use`: emit a check function based on type (semgrep, eslint, content-pattern, custom-script)
   - Each function uses pre-computed `exit_code` (2 for block, 1 for warn) and `patterns_joined` from context
4. Emits the dispatcher `case` block:
   - `pre-tool-use)`: **floor file protection logic (~70 lines of static-but-interpolated bash)** — this is the most complex part of the template. It emits case arms for:
     - `floors/*.md` / `*/floors/*.md` — sentinel-gated blocking (`.claude/floors/<name>/.applying`)
     - Legacy `compliance-floor.md` / `*/compliance-floor.md` — sentinel-gated blocking
     - `.claude/floors/*/compiled/*` — warn about generated files
     - `.claude/compliance/*` — sentinel-gated blocking (legacy)
     - `ops/compile-floor.sh` — warn about compiler modification
     - `.claude/agents/cro.md`, `.claude/agents/compliance-auditor.md` — warn about compliance agent modification
   - After protection logic: calls to pre check functions
   - `post-tool-use)`: calls to post check functions

The `FLOOR_NAME` and `FLOOR_FILE` variables from the context are interpolated into the protection logic. The generated bash must be identical to current output — test against the existing enforce.sh generation tests.

**This is the riskiest template.** The protection logic is the most fragile part because it mixes static bash with template interpolation. Implement this template last (migration step 9) and diff the generated output against the old generator's output to verify byte-for-byte equivalence.

#### `prose.md.tmpl` (~10 lines)

Reads the floor file, strips enforcement fences, adds a generated header referencing the floor filename and proposal ID.

**Note:** The prose generation still needs to process the source markdown (stripping fences). This can be done either by preprocessing in bash (passing the stripped content as a context field) or using gomplate's file functions to read and filter. Preprocessing in bash is simpler and keeps the template logic-free.

#### `coverage.md.tmpl` (~30 lines)

Emits the coverage table from block metadata (id, severity, enforcement points, check types, status). Uses gomplate `range` over blocks. Emits summary stats from context.

**Note:** Coverage is the one artifact that writes to a configurable external path (`COVERAGE_PATH` env var, default: `docs/compliance-coverage.md`) rather than inside the output directory. The orchestrator passes this path to gomplate's `-o` flag instead of `${OUTPUT_DIR}/...`. The context includes `coverage_path` so the manifest template can conditionally include the coverage hash (only when the path resolves inside the output directory — matching current behavior).

#### `manifest.sha256.tmpl` (~15 lines)

Emits source hash, proposal ID, and per-artifact hashes from the context `hashes` object. Conditionally includes the coverage hash only when `coverage_path` resolves inside the output directory (matching current `generate_manifest` behavior).

#### `semgrep-rules.yaml.tmpl` (~20 lines)

Iterates over blocks, finds semgrep-typed enforcement points, merges their rule-path files into a combined `rules:` YAML document.

#### `eslint-rules.json.tmpl` (~15 lines)

Iterates over blocks, finds eslint-typed enforcement points, emits a JSON object with rule IDs.

### 4. Orchestrator (`ops/compile-floor.sh`)

Retains:

- Argument parsing and mode dispatch (~150 lines)
- `resolve_defaults` function (~20 lines)
- `extract_blocks` function (~50 lines — markdown fence parsing, not a templating concern)
- `prepare_context` function (NEW, ~40-50 lines — builds JSON from extracted blocks)
- Mode dispatch logic (compile, verify, dry-run, extract-only, validate-only, prose-only, generate-enforce, compile-all)

Delegates to:

- `ops/compiler/validate.sh` for block validation
- `gomplate` with templates for all artifact generation

Also retains (not templated):

- **Orphan rule-file warning** — after compilation, scans `.claude/compliance/semgrep` and `.claude/compliance/eslint` for unreferenced rule files. Stays as inline orchestrator code.
- **`dry-run` mode formatting** — iterates blocks and prints a summary without writing files. Not a template candidate since it produces terminal output, not file artifacts.

**Dependency check:** At startup, verify gomplate v4+ is installed (v4 changed datasource syntax from v3). If not:

```
ERROR: gomplate is required but not installed.
Install with: brew install gomplate  OR  go install github.com/hairyhenderson/gomplate/v4@latest
```

Exit 2. No fallback — gomplate is required.

### 5. `verify_manifest` Function

This function compares current hashes against recorded manifest values. It stays in the orchestrator (not a template — it reads files and compares, doesn't generate). Simplified to use the same `base_name` derivation pattern. ~50 lines.

### Migration Strategy

Incremental, test-driven. Each step must pass all 111 tests before proceeding.

1. **Extract validation** — move `validate_block` to `ops/compiler/validate.sh`, call it from orchestrator. Tests pass.
2. **Add schema.yaml** — define the declarative schema. Update `validate.sh` to read from schema for structural checks. Tests pass.
3. **Add context preparation** — write `prepare_context` function. No behavior change yet. Tests pass.
4. **Template prose** — replace `generate_prose` with gomplate + `prose.md.tmpl`. Tests pass.
5. **Template coverage** — replace `generate_coverage` with gomplate + `coverage.md.tmpl`. Tests pass.
6. **Template manifest** — replace `generate_manifest` with gomplate + `manifest.sha256.tmpl`. Tests pass.
7. **Template semgrep** — replace `generate_semgrep` with gomplate + template. Tests pass.
8. **Template eslint** — replace `generate_eslint` with gomplate + template. Tests pass.
9. **Template enforce.sh** — replace `generate_enforce` with gomplate + `enforce.sh.tmpl`. Tests pass. This is the biggest and riskiest step.
10. **Clean up** — remove dead code (old inline generator functions). Final test pass.

### Line Count Estimate

| Component           | Current  | After        |
| ------------------- | -------- | ------------ |
| `compile-floor.sh`  | 1558     | ~300-400     |
| `validate.sh`       | (inline) | ~80-100      |
| `schema.yaml`       | —        | ~40          |
| Templates (6 files) | (inline) | ~200 total   |
| **Total**           | **1558** | **~620-740** |

~55% reduction in total lines. The remaining code is more readable (templates look like their output, schema is declarative, orchestrator is flow control only).

### Dependency Story

**New required dependency:** `gomplate` (single static binary, ~15MB, no runtime dependencies)

Installation options:

- `brew install gomplate` (macOS/Linux)
- `go install github.com/hairyhenderson/gomplate/v4@latest` (requires Go)
- Download binary from GitHub releases

**Existing dependencies:** `bash`, `yq` (required), `jq` (optional, for fleet-config reading)

### What Doesn't Change

- The 111-test suite — all tests pass without modification
- The CLI interface (`compile-floor.sh [options] [floor-file] [output-dir]`)
- The generated artifacts (enforce.sh, prose, coverage, manifest, semgrep, eslint configs)
- All modes (compile, verify, dry-run, extract-only, validate-only, prose-only, generate-enforce, compile-all)
- `extract_blocks` function — markdown fence parsing stays in bash
- Exit codes (0 = success, 1 = error, 2 = validation failure / missing dependency)

## File Inventory

### New Files

| File                                             | Purpose                               |
| ------------------------------------------------ | ------------------------------------- |
| `ops/compiler/schema.yaml`                       | Declarative enforcement block schema  |
| `ops/compiler/validate.sh`                       | Schema-driven block validation        |
| `ops/compiler/templates/enforce.sh.tmpl`         | Gomplate template for enforce.sh      |
| `ops/compiler/templates/prose.md.tmpl`           | Gomplate template for prose floor     |
| `ops/compiler/templates/coverage.md.tmpl`        | Gomplate template for coverage report |
| `ops/compiler/templates/manifest.sha256.tmpl`    | Gomplate template for manifest        |
| `ops/compiler/templates/semgrep-rules.yaml.tmpl` | Gomplate template for semgrep config  |
| `ops/compiler/templates/eslint-rules.json.tmpl`  | Gomplate template for eslint config   |

### Modified Files

| File                   | Change                                                                                       |
| ---------------------- | -------------------------------------------------------------------------------------------- |
| `ops/compile-floor.sh` | Replace inline generators with gomplate calls, add `prepare_context`, add gomplate dep check |
| `CLAUDE.md`            | Document gomplate dependency in Prerequisites, update compiler section                       |

### Not Changed

| File                              | Reason                                                     |
| --------------------------------- | ---------------------------------------------------------- |
| `ops/tests/test-compile-floor.sh` | Tests verify behavior, not internals — must pass unchanged |
| `ops/tests/fixtures/*`            | Test inputs unchanged                                      |

## Related Issues

- [#29](https://github.com/rdunie/venutian-antfarm/issues/29) — Multi-floor governance (compiler was generalized, this simplifies the generalized version)
- [#31](https://github.com/rdunie/venutian-antfarm/issues/31) — Compiler pre-flight validation (should build on the simplified compiler)
