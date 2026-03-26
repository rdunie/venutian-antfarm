# Compliance Floor Compiler Guide

The compliance floor compiler (`ops/compile-floor.sh`) transforms governance floor files into enforcement artifacts. It extracts enforcement blocks from Markdown, validates them against a schema, and generates hook scripts, coverage reports, and integrity manifests.

## Prerequisites

- **bash** (4.0+)
- **yq** — YAML processor
- **gomplate** (v4+) — template engine for artifact generation
- **jq** (optional) — for fleet-config.json reading and context preparation

Install gomplate:

```bash
brew install gomplate
# or: go install github.com/hairyhenderson/gomplate/v4@latest
# or: download from https://github.com/hairyhenderson/gomplate/releases
```

## Quick Reference

```bash
# Compile the default floor (reads fleet-config.json for paths)
ops/compile-floor.sh

# Compile all active floors declared in fleet-config.json
ops/compile-floor.sh --all

# Compile a specific floor by name
ops/compile-floor.sh --floor behavioral

# Compile with explicit paths
ops/compile-floor.sh floors/compliance.md .claude/floors/compliance/compiled

# Validate enforcement blocks without writing files
ops/compile-floor.sh --dry-run

# Verify compiled artifacts haven't drifted from source
ops/compile-floor.sh --verify

# Extract enforcement blocks only (no generation)
ops/compile-floor.sh --extract-only

# Generate only prose output
ops/compile-floor.sh --prose-only

# Generate only enforce.sh + semgrep/eslint configs
ops/compile-floor.sh --generate-enforce

# Tag artifacts with a proposal ID
ops/compile-floor.sh --proposal 003
```

## Architecture

```
ops/compile-floor.sh          Orchestrator — parsing, mode dispatch, context prep
ops/compiler/
├── schema.yaml              Declarative enforcement block schema
├── validate.sh              Schema-driven block validation
└── templates/
    ├── enforce.sh.tmpl      Hook enforcement dispatcher
    ├── prose.md.tmpl        Floor without enforcement fences
    ├── coverage.md.tmpl     Coverage report table
    ├── manifest.sha256.tmpl Integrity manifest
    ├── semgrep-rules.yaml.tmpl
    └── eslint-rules.json.tmpl
```

### Pipeline

````
Floor file (Markdown)
    │
    ▼
┌──────────────────┐
│ preflight_check  │ ── Verify environment (manifest, artifacts, source hash)
└──────┬───────────┘
       │
       ▼
┌──────────────┐
│ extract_blocks│ ── Parse ```enforcement fences → block-NNN.yaml files
└──────┬───────┘
       │
       ▼
┌──────────────┐
│ validate.sh  │ ── Validate each block against schema.yaml
└──────┬───────┘
       │
       ▼
┌────────────────┐
│ prepare_context│ ── Build JSON context from all blocks
└──────┬─────────┘
       │
       ▼
┌──────────────┐
│  gomplate    │ ── Generate artifacts from templates
└──────┬───────┘
       │
       ├── enforce.sh          Hook dispatcher script
       ├── <floor>.prose.md    Floor without enforcement blocks
       ├── coverage report     Rule coverage table
       ├── manifest.sha256     Integrity checksums
       ├── semgrep-rules.yaml  Merged semgrep configs
       └── eslint-rules.json   Merged eslint configs
````

### Pre-Flight Checks

Before extraction begins, the compiler runs `preflight_check` to inspect the compilation environment. This step is diagnostic only -- it never blocks compilation, but it logs warnings and emits `preflight-remediation` metrics events to provide visibility into unexpected state.

**What it checks:**

1. Whether the compiled output directory exists (creates it if missing)
2. Whether `manifest.sha256` is present
3. Whether compiled artifacts (`enforce.sh`, `<floor>.prose.md`) are present
4. Whether the source floor file hash matches the manifest's recorded hash
5. Whether this is a first-time compile (no manifest and no artifacts)

**Classification:**

| Scenario                                     | Classification | Detail                                  |
| -------------------------------------------- | -------------- | --------------------------------------- |
| First compile (no manifest, no artifacts)    | expected       | `first compile`                         |
| Source floor file changed since last compile | expected       | `source has changed since last compile` |
| Manifest missing but artifacts exist         | unexpected     | `manifest missing but artifacts exist`  |
| Artifacts missing but manifest exists        | unexpected     | `missing artifacts: <list>`             |

**Output format:**

Pre-flight messages are written to stderr with the prefix `[preflight]`. Warnings use the format:

```
[preflight] WARNING: Floor '<name>': <description>
[preflight] Floor '<name>': <description>
```

**When it runs:**

Pre-flight checks run in `compile` mode and `compile-all` mode (via subprocess invocation) only. Other modes (`dry-run`, `verify`, `extract-only`, `validate-only`, `prose-only`, `generate-enforce`) skip pre-flight checks because they do not produce a full artifact set.

**Metrics:**

Each pre-flight finding emits a `preflight-remediation` event via `ops/metrics-log.sh`:

```bash
ops/metrics-log.sh preflight-remediation --floor <name> --type <expected|unexpected> --detail "<description>"
```

## Enforcement Block Format

Enforcement blocks are YAML embedded in Markdown floor files using fenced code blocks with the `enforcement` language tag:

````markdown
### Rule 1

**We MUST NEVER** store secrets in code.

```enforcement
version: 1
id: no-secrets-in-code
severity: blocking
enforce:
  pre-tool-use:
    type: file-pattern
    action: block
    patterns:
      - '\.env$'
      - 'secrets?\.yaml$'
```
````

### Required Fields

| Field      | Type    | Description                                                                 |
| ---------- | ------- | --------------------------------------------------------------------------- |
| `version`  | integer | Must be `1`                                                                 |
| `id`       | string  | Unique rule identifier (used in function names and logging)                 |
| `severity` | enum    | `blocking` (violations are errors) or `warning` (violations are advisories) |
| `enforce`  | object  | Must contain at least one of `pre-tool-use` or `post-tool-use`              |

### Forbidden Fields

These fields are rejected by the validator to prevent bypass mechanisms: `bypass`, `skip`, `override`.

### Enforcement Points

| Point           | When It Runs             | Purpose                                                     |
| --------------- | ------------------------ | ----------------------------------------------------------- |
| `pre-tool-use`  | Before a file edit/write | Block or warn before changes are made                       |
| `post-tool-use` | After a file edit/write  | Check content after changes                                 |
| `ci`            | Supplementary            | Additional CI-only checks (must be paired with pre or post) |

### Check Types

| Type              | Valid Points                    | How It Works                                           |
| ----------------- | ------------------------------- | ------------------------------------------------------ |
| `file-pattern`    | `pre-tool-use` only             | Matches file path against regex patterns               |
| `content-pattern` | `pre-tool-use`, `post-tool-use` | Greps file content for regex patterns                  |
| `custom-script`   | Any                             | Runs an external script with the file path as argument |
| `semgrep`         | `post-tool-use`, `ci`           | Runs semgrep with a rule config file                   |
| `eslint`          | `post-tool-use`, `ci`           | Runs eslint with a rule config file                    |

### Check Type Details

#### file-pattern

Matches the file path being edited against one or more regex patterns.

```yaml
enforce:
  pre-tool-use:
    type: file-pattern
    action: block
    patterns:
      - '\.env$'
      - 'secrets?\.yaml$'
```

#### content-pattern

Greps the file content for regex patterns after an edit.

```yaml
enforce:
  post-tool-use:
    type: content-pattern
    action: block
    patterns:
      - 'SSN[:=]\s*\d{3}-\d{2}-\d{4}'
      - 'api[_-]?key\s*[:=]\s*["\x27][A-Za-z0-9]{20,}'
```

#### custom-script

Runs an external script. The script receives the file path as its first argument. Exit 0 = pass, non-zero = fail. Scripts run with a 10-second timeout and network isolation (via `unshare --net` if available).

```yaml
enforce:
  post-tool-use:
    type: custom-script
    action: warn
    script: ops/checks/verify-audit-log.sh
```

Requirements:

- `script` must be a relative path within the repo
- The script file must exist and be executable

#### semgrep

Runs semgrep with a rule configuration file. Requires `rule-path` (must exist) and `rule-id`.

```yaml
enforce:
  post-tool-use:
    type: semgrep
    action: block
    rule-path: .claude/compliance/semgrep/no-eval.yaml
    rule-id: no-eval-calls
```

Gracefully skips if semgrep is not installed.

#### eslint

Runs eslint with a config file. Only checks JS/TS files. Requires `rule-path` and `rule-id`.

```yaml
enforce:
  post-tool-use:
    type: eslint
    action: block
    rule-path: .claude/compliance/eslint/no-any.json
    rule-id: no-explicit-any
```

Gracefully skips if eslint is not installed.

### Severity and Action

| Severity   | Action  | Exit Code | Meaning                               |
| ---------- | ------- | --------- | ------------------------------------- |
| `blocking` | `block` | 2         | Hard stop — edit is rejected          |
| `warning`  | `warn`  | 1         | Advisory — edit proceeds with warning |

**Contradictions are rejected:** `warning` + `block` and `blocking` + `warn` fail validation.

## Generated Artifacts

### enforce.sh

The main enforcement dispatcher. Called by Claude Code hooks with:

```bash
enforce.sh <enforcement-point> <file-path>
```

Contains:

- Per-rule check functions (one per enforcement block per point)
- Floor file protection logic (sentinel-gated blocking for `floors/*.md`)
- Metric logging (`compliance-violation` and `compliance-pass` events)

### \<floor\>.prose.md

The floor file with enforcement blocks stripped — human-readable prose only. Used for context loading (agents read the prose, not the YAML).

### Coverage Report

A Markdown table showing which rules have automated enforcement and which are judgment-only. Written to `COVERAGE_PATH` env var (default: `docs/compliance-coverage.md`).

### manifest.sha256

Checksums for the source floor file and all generated artifacts. Used by `--verify` mode and the SessionStart hook to detect drift.

### semgrep-rules.yaml / eslint-rules.json

Merged config files for semgrep and eslint rules referenced by enforcement blocks.

## Modes

| Mode             | Flag                 | Description                                                         |
| ---------------- | -------------------- | ------------------------------------------------------------------- |
| Compile          | _(default)_          | Full pipeline: extract → validate → generate all artifacts          |
| Compile All      | `--all`              | Compile every floor declared in `fleet-config.json`                 |
| Dry Run          | `--dry-run`          | Validate and show summary without writing files                     |
| Verify           | `--verify`           | Compare current hashes against manifest (exit 0 = clean, 1 = drift) |
| Extract Only     | `--extract-only`     | Parse enforcement blocks to YAML files, stop                        |
| Validate Only    | `--validate-only`    | Extract and validate blocks, don't generate                         |
| Prose Only       | `--prose-only`       | Generate only the prose output                                      |
| Generate Enforce | `--generate-enforce` | Generate enforce.sh + semgrep/eslint configs only                   |

## Default Resolution

When called without positional arguments, the compiler resolves defaults:

1. **`fleet-config.json` present + jq available:** reads `.floors.compliance.file` and `.floors.compliance.compiled_dir`
2. **`floors/compliance.md` exists:** uses it with output to `.claude/floors/compliance/compiled`
3. **`compliance-floor.md` exists (legacy):** uses it with output to `.claude/compliance/compiled`

Use `--floor <name>` to target a specific floor from fleet-config: `--floor behavioral`.

## Schema

The validation schema at `ops/compiler/schema.yaml` defines structural rules declaratively. The validator (`ops/compiler/validate.sh`) reads it to check required fields, forbidden fields, and type-per-enforcement-point constraints. Relational constraints (severity/action contradictions, file existence) are code.

To add a new forbidden field: edit `forbidden_fields` in `schema.yaml`.
To add a new check type: add an entry to `enforce.type_constraints` with its valid enforcement points.

## Templates

Each artifact is generated by a gomplate template in `ops/compiler/templates/`. The orchestrator builds a JSON context from the extracted blocks and passes it to gomplate as a datasource.

To modify an artifact's format: edit the corresponding `.tmpl` file. The template has access to the full context (floor metadata, blocks with enforcement points, stats, hashes).

Template syntax: [gomplate documentation](https://docs.gomplate.ca/).

## Testing

```bash
# Run the full test suite (120 tests)
bash ops/tests/test-compile-floor.sh

# Syntax check
bash -n ops/compile-floor.sh
bash -n ops/compiler/validate.sh
```

Test fixtures are in `ops/tests/fixtures/`. To add a test for a new check type, create a fixture floor file and add assertions to `test-compile-floor.sh`.

## Exit Codes

| Code | Meaning                                                             |
| ---- | ------------------------------------------------------------------- |
| 0    | Success                                                             |
| 1    | Runtime error (file not found, unknown mode, verify drift detected) |
| 2    | Validation failure or missing dependency (yq, gomplate)             |
