# Multi-Floor Governance Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Generalize the compliance floor into a multi-floor governance pattern where any Cx officer can own a behavioral floor with the same enforcement machinery.

**Architecture:** The single `compliance-floor.md` at repo root becomes one instance of a general floor pattern. Floors live in `floors/`, compiled artifacts in `.claude/floors/<name>/compiled/`. The compiler reads `fleet-config.json` for floor declarations and compiles any floor with the same extraction→validation→generation pipeline. The Compliance Officer becomes the Chief Risk Officer (CRO), gaining cross-floor risk facilitation.

**Tech Stack:** Bash (compiler, hooks, tests), Markdown (agent definitions, skills, docs), JSON (fleet-config)

**Spec:** `docs/superpowers/specs/2026-03-25-behavioral-floor-design.md`

---

## File Structure

### New Files

| File                                 | Responsibility                                                            |
| ------------------------------------ | ------------------------------------------------------------------------- |
| `floors/compliance.md`               | Compliance floor (migrated from `compliance-floor.md` at root)            |
| `templates/floors/compliance.md`     | Compliance floor template (migrated from `templates/compliance-floor.md`) |
| `templates/floors/behavioral.md`     | Behavioral floor template (new)                                           |
| `.claude/agents/cro.md`              | CRO agent (replaces `compliance-officer.md`)                              |
| `.claude/skills/behavioral/SKILL.md` | `/behavioral` skill — routes to COO as behavioral floor guardian          |
| `.claude/skills/floor/SKILL.md`      | `/floor propose <name>` — generic floor proposal skill                    |

### Modified Files

| File                                 | Change                                                                         |
| ------------------------------------ | ------------------------------------------------------------------------------ |
| `ops/compile-floor.sh`               | Read defaults from fleet-config, add `--all` flag, floor-agnostic output names |
| `ops/tests/test-compile-floor.sh`    | Update tests for multi-floor compiler                                          |
| `templates/fleet-config.json`        | Add `floors` section, rename `compliance-officer` → `cro`                      |
| `.claude/agents/coo.md`              | Add behavioral floor guardianship                                              |
| `.claude/skills/compliance/SKILL.md` | Update CO → CRO references, floor file path                                    |
| `.claude/skills/onboard/SKILL.md`    | Create `floors/` directory, per-floor scaffolding                              |
| `.claude/settings.json`              | Generalize hooks from `compliance-floor.md` to `floors/*.md`                   |
| `CLAUDE.md`                          | Document multi-floor model, rename CO → CRO, update directory structure        |
| `.claude/COLLABORATION.md`           | Update Compliance Hierarchy → Governance Floors, CO → CRO                      |

### Deleted Files

| File                                   | Reason                                    |
| -------------------------------------- | ----------------------------------------- |
| `compliance-floor.md` (root)           | Moved to `floors/compliance.md`           |
| `templates/compliance-floor.md`        | Moved to `templates/floors/compliance.md` |
| `.claude/agents/compliance-officer.md` | Renamed to `.claude/agents/cro.md`        |

---

## Task 1: Directory Structure and Floor Migration

**Files:**

- Create: `floors/` directory
- Create: `templates/floors/` directory
- Move: `templates/compliance-floor.md` → `templates/floors/compliance.md`
- Delete: `templates/compliance-floor.md`

This task sets up the physical directory structure the rest of the plan depends on.

**Note:** `compliance-floor.md` at repo root does not exist on this branch (it's created per-project by implementers). We only migrate the template. The root-level `compliance-floor.md` migration is an implementer concern documented in release notes.

- [ ] **Step 1: Create the `floors/` directory with a README placeholder**

```bash
mkdir -p floors
```

Create `floors/.gitkeep` so the directory is tracked:

```bash
touch floors/.gitkeep
```

- [ ] **Step 2: Create `templates/floors/` and move the compliance template**

```bash
mkdir -p templates/floors
git mv templates/compliance-floor.md templates/floors/compliance.md
```

- [ ] **Step 3: Create the behavioral floor template**

Write `templates/floors/behavioral.md`:

```markdown
# Behavioral Floor

> This file is guarded by the COO. Changes go through `/floor propose behavioral` or `/behavioral propose`.
> Unauthorized edits are blocked by hooks and will be reverted.

## Process Quality

<!-- Define non-negotiable process rules here. Examples: -->
<!-- ### Rule 1 -->
<!-- **We MUST ALWAYS** run the full validation cycle before handoff. -->

## Delivery Standards

<!-- Define non-negotiable delivery standards here. Examples: -->
<!-- ### Rule 1 -->
<!-- **We MUST ALWAYS** include test coverage for new functionality. -->

## Collaboration Norms

<!-- Define non-negotiable collaboration rules here. Examples: -->
<!-- ### Rule 1 -->
<!-- **We MUST NEVER** skip the findings loop for notable events. -->
```

- [ ] **Step 4: Commit**

```bash
git add floors/.gitkeep templates/floors/compliance.md templates/floors/behavioral.md
git commit -m "feat(#29): set up floors directory structure and migrate compliance template"
```

---

## Task 2: Fleet Config Template — Add Floors Section

**Files:**

- Modify: `templates/fleet-config.json`

- [ ] **Step 1: Add `floors` section to `templates/fleet-config.json`**

Add after the `pace` section:

```json
"floors": {
  "compliance": {
    "file": "floors/compliance.md",
    "guardian": "cro",
    "compiled_dir": ".claude/floors/compliance/compiled"
  },
  "behavioral": {
    "file": "floors/behavioral.md",
    "guardian": "coo",
    "compiled_dir": ".claude/floors/behavioral/compiled"
  }
},
```

Also rename `"compliance-officer"` to `"cro"` in the `agents.governance` array.

- [ ] **Step 2: Validate the JSON is well-formed**

```bash
jq . templates/fleet-config.json > /dev/null
```

Expected: exits 0, no output.

- [ ] **Step 3: Commit**

```bash
git add templates/fleet-config.json
git commit -m "feat(#29): add floors section to fleet-config template, rename CO to CRO"
```

---

## Task 3: CRO Agent — Rename and Update Role

**Files:**

- Create: `.claude/agents/cro.md` (from `compliance-officer.md`)
- Delete: `.claude/agents/compliance-officer.md`

- [ ] **Step 1: Copy compliance-officer.md to cro.md**

```bash
git mv .claude/agents/compliance-officer.md .claude/agents/cro.md
```

- [ ] **Step 2: Update cro.md frontmatter and content**

Update the frontmatter:

```yaml
---
name: cro
description: "Chief Risk Officer. Guards the compliance floor, facilitates cross-floor risk assessment, manages change control across all governance floors, and ensures the fleet conforms to floor requirements."
model: opus
color: crimson
memory: project
maxTurns: 50
---
```

Update the opening paragraph to reference the new role:

```markdown
**Read `.claude/COLLABORATION.md` § Governance Floors and § Governance Collaboration Pattern first** -- they define the multi-floor governance model (floor/targets/guidance) and the Cx consultation process you lead.

You are the **Chief Risk Officer (CRO)** for this project. You guard the compliance floor and facilitate cross-floor risk assessment when any floor change is proposed. This is your reason for being.
```

Update "What You Own":

```markdown
## What You Own

- **`floors/compliance.md`** -- sole write authority. No other agent may modify this file. Changes go through `/compliance propose` or `/floor propose compliance` → your review → user approval.
- **`.claude/compliance/targets.md`** -- compliance targets (SHOULD tier). Risk-reducing changes you may approve autonomously; all others require user approval.
- **`.claude/compliance/change-log.md`** -- append-only audit trail for every change.
- **`.claude/compliance/proposals/`** -- change proposal storage.
- **Cross-floor risk facilitation** -- when any floor guardian receives a change proposal, they dispatch you as a subagent to facilitate multi-round Cx consultation. You synthesize domain positions into a consolidated risk assessment.
```

Update Floor Guardianship section to reference `floors/compliance.md` instead of `compliance-floor.md`:

```markdown
### 1. Floor Guardianship

Monitor `floors/compliance.md` integrity. A PreToolUse hook blocks unauthorized edits to any `floors/*.md` file. On SessionStart, verify the checksum in `.claude/floors/compliance/floor-checksum.sha256`. If a mismatch is detected:

1. Restore via `git checkout <commit> -- floors/compliance.md` using the commit ref in the checksum file
2. Issue a reprimand -- log a critical finding in `.claude/findings/register.md` with category "compliance-violation"
3. Log `compliance-violation` and `compliance-reverted` events via `ops/metrics-log.sh`
```

Add a new section after Floor Guardianship:

```markdown
### 2. Cross-Floor Risk Facilitation

When a floor guardian (including yourself for compliance) receives a change proposal:

1. The guardian dispatches you as a subagent with the proposal
2. You distribute the proposal to all Cx agents
3. Round 1: Each Cx agent advocates their domain impact (impacted / not impacted / concerns)
4. You synthesize — identify conflicts, cross-domain interactions, open questions
5. Round N: If unresolved concerns, facilitate further rounds until positions stabilize
6. Return: consolidated risk assessment, each Cx position, recommendation

**Special case (compliance floor):** You are both guardian and risk facilitator. Dispatch the consultation as a generic consultation subagent — provide your compliance position as input alongside the proposal.

**Context efficiency:** The entire consultation is a single subagent dispatch. The main context sees only one dispatch + one result.
```

Renumber remaining sections (Change Control → 3, Conformance Reporting → 4, etc.).

Update the autonomy model table to add cross-floor facilitation:

```markdown
| Cross-floor risk facilitation | Autonomous (subagent) |
```

- [ ] **Step 3: Commit**

```bash
git add .claude/agents/cro.md
git commit -m "feat(#29): rename Compliance Officer to CRO with cross-floor risk facilitation"
```

---

## Task 4: COO Agent — Add Behavioral Floor Guardianship

**Files:**

- Modify: `.claude/agents/coo.md`

- [ ] **Step 1: Update coo.md description in frontmatter**

```yaml
description: "Operational efficiency authority and behavioral floor guardian. Sets process standards, SLAs, and quality benchmarks. Guards floors/behavioral.md. Monitors agent performance and recommends retraining when needed."
```

- [ ] **Step 2: Add behavioral floor guardianship to the opening**

After the "Position" section, add:

```markdown
## What You Guard

- **`floors/behavioral.md`** -- sole write authority. No other agent may modify this file. Changes go through `/behavioral propose` or `/floor propose behavioral` → CRO risk facilitation → your review → user approval.

### Behavioral Floor Guardianship

Monitor `floors/behavioral.md` integrity. The PreToolUse hook blocks unauthorized edits to `floors/*.md`. On SessionStart, verify the checksum in `.claude/floors/behavioral/floor-checksum.sha256`. If a mismatch is detected:

1. Restore via `git checkout <commit> -- floors/behavioral.md` using the commit ref in the checksum file
2. Issue a reprimand -- log a critical finding in `.claude/findings/register.md` with category "behavioral-floor-violation"
3. Log `behavioral-floor-violation` and `behavioral-floor-reverted` events via `ops/metrics-log.sh`

### Change Proposals

When you receive a proposal to change the behavioral floor:

1. Classify: Type 1 (risk-reducing) / Type 2 (other) / Type 3 (new rule)
2. Dispatch CRO as subagent for cross-floor risk consultation
3. Review the CRO's consolidated risk assessment
4. Decision gate: Type 1 with consensus → approve autonomously, notify user. Type 2-3 or no consensus → present to user with full Cx input.
5. Apply via sentinel file bypass mechanism
6. Log everything: who, what, why, Cx positions, consensus, before/after diff
```

- [ ] **Step 3: Update the "Floor and Targets" section**

Replace the existing "Floor and Targets" section:

```markdown
## Floor and Targets

- **Floor rules (MUST):** As behavioral floor guardian, you own these directly in `floors/behavioral.md`. Process changes go through `/behavioral propose`.
- **Targets (SHOULD):** Aspirational operational objectives. Published via change control.
- **Guidance (NICE TO HAVE):** Operational standards, quality benchmarks, SLAs, readiness criteria -- published to the guidance registry.
```

- [ ] **Step 4: Add guardianship to autonomy table**

Add these rows to the COO autonomy table:

```markdown
| Monitoring behavioral floor integrity | Autonomous |
| Reverting unauthorized behavioral floor changes | Autonomous |
| Approving Type 1 behavioral floor changes (with consensus) | Autonomous, notify user |
| Processing Type 2-3 behavioral floor changes | Escalate to user (always) |
```

- [ ] **Step 5: Commit**

```bash
git add .claude/agents/coo.md
git commit -m "feat(#29): add behavioral floor guardianship to COO agent"
```

---

## Task 5: Compiler Generalization — Fleet-Config Defaults

**Files:**

- Modify: `ops/compile-floor.sh`

This task updates the compiler's default resolution logic. Currently it hardcodes `compliance-floor.md` and `.claude/compliance/compiled`. After this change, it reads from `fleet-config.json` when available.

- [ ] **Step 1: Write the failing test — fleet-config default resolution**

Add to `ops/tests/test-compile-floor.sh` a new test group:

```bash
# ---------------------------------------------------------------------------
# Test: Fleet-config default resolution
# ---------------------------------------------------------------------------

echo ""
echo "=== Fleet-config default resolution ==="

# Create a temp dir with fleet-config.json and a floor file
FC_DIR="$(mktemp -d)"
trap_add "rm -rf '${FC_DIR}'" EXIT

mkdir -p "${FC_DIR}/floors"
cp "${FIXTURES}/floor-valid.md" "${FC_DIR}/floors/compliance.md"

cat > "${FC_DIR}/fleet-config.json" <<'FCEOF'
{
  "floors": {
    "compliance": {
      "file": "floors/compliance.md",
      "guardian": "cro",
      "compiled_dir": ".claude/floors/compliance/compiled"
    }
  }
}
FCEOF

# Run compiler with no positional args from the fleet-config dir
pushd "${FC_DIR}" > /dev/null
OUTPUT=$(${COMPILER} --dry-run 2>&1) || true
ACTUAL_EXIT=$?
popd > /dev/null

assert_exit "fleet-config defaults: dry-run exits 0" 0 "${ACTUAL_EXIT}"
assert_output_contains "fleet-config defaults: output mentions rule" "${OUTPUT}" "rule"
```

- [ ] **Step 2: Run the test to verify it fails**

```bash
bash ops/tests/test-compile-floor.sh 2>&1 | tail -20
```

Expected: FAIL — the compiler still uses hardcoded defaults and won't find `floors/compliance.md` in that temp dir.

- [ ] **Step 3: Update compiler defaults section to read fleet-config.json**

Replace the "Defaults" section (lines 28-31) with:

```bash
# ---------------------------------------------------------------------------
# Defaults — read from fleet-config.json if available, fall back to legacy paths
# ---------------------------------------------------------------------------

resolve_defaults() {
  local config="fleet-config.json"
  local floor_name="${1:-compliance}"

  if [[ -f "${config}" ]] && command -v jq &>/dev/null; then
    local fc_file fc_dir
    fc_file="$(jq -r ".floors.\"${floor_name}\".file // empty" "${config}" 2>/dev/null)"
    fc_dir="$(jq -r ".floors.\"${floor_name}\".compiled_dir // empty" "${config}" 2>/dev/null)"

    if [[ -n "${fc_file}" ]]; then
      FLOOR_FILE="${fc_file}"
    fi
    if [[ -n "${fc_dir}" ]]; then
      OUTPUT_DIR="${fc_dir}"
    fi
  fi
}

# Legacy fallback: if fleet-config.json is absent, use floors/compliance.md
# (backward compat: if floors/compliance.md doesn't exist but compliance-floor.md does, use that)
FLOOR_FILE="floors/compliance.md"
OUTPUT_DIR=".claude/floors/compliance/compiled"
if [[ ! -f "floors/compliance.md" && -f "compliance-floor.md" ]]; then
  FLOOR_FILE="compliance-floor.md"
  OUTPUT_DIR=".claude/compliance/compiled"
fi
MODE=""
PROPOSAL_ID=""
FLOOR_NAME=""
COMPILE_ALL=0
```

- [ ] **Step 4: Add `--all` and `--floor` flags to arg parsing**

Add these cases to the `while` loop:

```bash
    --all)
      COMPILE_ALL=1
      shift
      ;;
    --floor)
      FLOOR_NAME="$2"
      shift 2
      ;;
```

- [ ] **Step 5: Add default resolution after arg parsing**

After the positional args handling (after line 86), add:

```bash
# Resolve defaults from fleet-config.json if no positional args given
if [[ ${#POSITIONAL[@]} -eq 0 ]]; then
  if [[ -n "${FLOOR_NAME}" ]]; then
    resolve_defaults "${FLOOR_NAME}"
  else
    resolve_defaults "compliance"
  fi
fi

# Default mode if none specified
if [[ -z "${MODE}" ]]; then
  MODE="compile"
fi
```

- [ ] **Step 6: Run the test to verify it passes**

```bash
bash ops/tests/test-compile-floor.sh 2>&1 | tail -20
```

Expected: PASS

- [ ] **Step 7: Commit**

```bash
git add ops/compile-floor.sh ops/tests/test-compile-floor.sh
git commit -m "feat(#29): compiler reads floor defaults from fleet-config.json"
```

---

## Task 6: Compiler Generalization — Floor-Agnostic Output Names

**Files:**

- Modify: `ops/compile-floor.sh`

The `generate_prose` function hardcodes `compliance-floor.prose.md`. The enforce.sh dispatcher hardcodes `compliance-floor.md` sentinel paths. These need to become floor-agnostic.

- [ ] **Step 1: Write the failing test — floor-agnostic prose output name**

Add to test file:

```bash
echo ""
echo "=== Floor-agnostic output names ==="

FA_DIR="$(mktemp -d)"
trap_add "rm -rf '${FA_DIR}'" EXIT

mkdir -p "${FA_DIR}/floors"
cp "${FIXTURES}/floor-valid.md" "${FA_DIR}/floors/behavioral.md"

# Compile with explicit paths
OUTPUT=$(${COMPILER} "${FA_DIR}/floors/behavioral.md" "${FA_DIR}/compiled" 2>&1)
ACTUAL_EXIT=$?

assert_exit "floor-agnostic: compiles behavioral floor" 0 "${ACTUAL_EXIT}"
assert_file_exists "floor-agnostic: prose file uses floor name" "${FA_DIR}/compiled/behavioral.prose.md"
```

- [ ] **Step 2: Run the test to verify it fails**

```bash
bash ops/tests/test-compile-floor.sh 2>&1 | grep -A1 "floor-agnostic"
```

Expected: FAIL — prose file is still named `compliance-floor.prose.md`.

- [ ] **Step 3: Update `generate_prose` to derive filename from floor input**

Replace the hardcoded filename in `generate_prose`:

```bash
generate_prose() {
  local input_file="$1"
  local out_dir="$2"

  # Derive prose filename from input: floors/behavioral.md → behavioral.prose.md
  local base_name
  base_name="$(basename "${input_file}" .md)"
  local out_file="${out_dir}/${base_name}.prose.md"

  local in_block=0

  {
    printf '# GENERATED by ops/compile-floor.sh from %s\n' "$(basename "${input_file}")"
    printf '# Do not edit — changes will be overwritten. Proposal: %s\n' "${PROPOSAL_ID:-<none>}"
```

- [ ] **Step 4: Update `generate_manifest` to use floor-agnostic prose filename**

In `generate_manifest`, replace the hardcoded `compliance-floor.prose.md` references:

```bash
generate_manifest() {
  local floor_file="$1"
  local out_dir="$2"
  local proposal_id="${3:-}"

  local base_name
  base_name="$(basename "${floor_file}" .md)"

  local source_hash
  source_hash="$(sha256sum "${floor_file}" | cut -d' ' -f1)"

  local prose_hash=""
  if [[ -f "${out_dir}/${base_name}.prose.md" ]]; then
    prose_hash="$(sha256sum "${out_dir}/${base_name}.prose.md" | cut -d' ' -f1)"
  fi
```

Update the artifact line in the manifest output:

```bash
    printf '  %s.prose.md: %s\n' "${base_name}" "${prose_hash}"
```

- [ ] **Step 5: Update `verify_manifest` to use floor-agnostic prose filename**

In `verify_manifest`, derive the base name and use it:

```bash
verify_manifest() {
  local floor_file="$1"
  local out_dir="$2"
  local manifest_file="${out_dir}/manifest.sha256"

  local base_name
  base_name="$(basename "${floor_file}" .md)"
```

Replace the hardcoded prose grep:

```bash
  # Compare prose artifact
  if grep -q "${base_name}\\.prose\\.md:" "${manifest_file}"; then
    local recorded_prose
    recorded_prose="$(grep "${base_name}\\.prose\\.md:" "${manifest_file}" | awk '{print $2}')"
    if [[ -n "${recorded_prose}" ]]; then
      local current_prose=""
      if [[ -f "${out_dir}/${base_name}.prose.md" ]]; then
        current_prose="$(sha256sum "${out_dir}/${base_name}.prose.md" | cut -d' ' -f1)"
      fi
```

- [ ] **Step 6: Update `generate_coverage` header to reference the floor file name**

In `generate_coverage`, replace the hardcoded compliance reference in the header:

```bash
    printf '# GENERATED by ops/compile-floor.sh from %s\n' "$(basename "${floor_file}")"
```

- [ ] **Step 7: Update enforce.sh dispatcher sentinel paths to be floor-agnostic**

In `generate_enforce`, the hardcoded `compliance-floor.md` and `.claude/compliance/` paths in the dispatcher `case` block need to become parameterized. Add a `FLOOR_BASE_NAME` variable at the top of the generated script and use it in the dispatcher:

Replace the hardcoded dispatcher case block. After the `ENFORCE_HEADER` heredoc write, insert the floor name:

```bash
  # Write floor identity
  local base_name
  base_name="$(basename "${FLOOR_FILE}" .md)"
  printf '\nFLOOR_NAME="%s"\n' "${base_name}" >> "${out_file}"
  printf 'FLOOR_FILE="%s"\n\n' "${FLOOR_FILE}" >> "${out_file}"
```

Update the dispatcher case to use `FLOOR_FILE` and compute sentinel paths from it:

```bash
  cat >> "${out_file}" <<'ENFORCE_DISPATCH'
# ---------------------------------------------------------------------------
# Dispatcher
# ---------------------------------------------------------------------------

dispatch() {
  local point="$1"
  local file_path="$2"
  local max_exit=0
  local rc=0

  case "${point}" in
    pre-tool-use)
      # Intent declaration — governance surface area
      FILE_PATH="${file_path}"

      # Block edits to any floor file without sentinel
      case "${FILE_PATH}" in
        floors/*.md|*/floors/*.md)
          local floor_base
          floor_base="$(basename "${FILE_PATH}" .md)"
          local sentinel=".claude/floors/${floor_base}/.applying"
          if [ -f "${sentinel}" ]; then
            echo "WARN: Floor modification: ${FILE_PATH} (sentinel active)"
            exit 1
          else
            echo "BLOCKED: Floor file protected. Use /floor propose ${floor_base}."
            exit 2
          fi
          ;;
        .claude/floors/*/compiled/*|*/.claude/floors/*/compiled/*)
          echo "WARN: This is generated by ops/compile-floor.sh. Manual edits will be overwritten."
          exit 1
          ;;
        ops/compile-floor.sh|*/ops/compile-floor.sh)
          echo "WARN: This modifies the floor compiler. Changes affect all rule enforcement."
          exit 1
          ;;
        .claude/agents/cro.md|*/.claude/agents/cro.md|\
.claude/agents/compliance-auditor.md|*/.claude/agents/compliance-auditor.md)
          echo "WARN: This modifies a compliance agent's instructions."
          exit 1
          ;;
      esac
ENFORCE_DISPATCH
```

- [ ] **Step 8: Run all tests**

```bash
bash ops/tests/test-compile-floor.sh
```

Expected: all existing + new tests pass.

- [ ] **Step 9: Commit**

```bash
git add ops/compile-floor.sh ops/tests/test-compile-floor.sh
git commit -m "feat(#29): make compiler output names and dispatcher floor-agnostic"
```

---

## Task 7: Compiler Generalization — `--all` Flag

**Files:**

- Modify: `ops/compile-floor.sh`

- [ ] **Step 1: Write the failing test — `--all` compiles multiple floors**

Add to test file:

```bash
echo ""
echo "=== --all flag ==="

ALL_DIR="$(mktemp -d)"
trap_add "rm -rf '${ALL_DIR}'" EXIT

mkdir -p "${ALL_DIR}/floors"
cp "${FIXTURES}/floor-valid.md" "${ALL_DIR}/floors/compliance.md"
cp "${FIXTURES}/floor-valid.md" "${ALL_DIR}/floors/behavioral.md"

cat > "${ALL_DIR}/fleet-config.json" <<'ALLEOF'
{
  "floors": {
    "compliance": {
      "file": "floors/compliance.md",
      "guardian": "cro",
      "compiled_dir": ".claude/floors/compliance/compiled"
    },
    "behavioral": {
      "file": "floors/behavioral.md",
      "guardian": "coo",
      "compiled_dir": ".claude/floors/behavioral/compiled"
    }
  }
}
ALLEOF

pushd "${ALL_DIR}" > /dev/null
OUTPUT=$(${COMPILER} --all 2>&1)
ACTUAL_EXIT=$?
popd > /dev/null

assert_exit "--all: exits 0" 0 "${ACTUAL_EXIT}"
assert_file_exists "--all: compliance compiled" "${ALL_DIR}/.claude/floors/compliance/compiled/compliance.prose.md"
assert_file_exists "--all: behavioral compiled" "${ALL_DIR}/.claude/floors/behavioral/compiled/behavioral.prose.md"
```

- [ ] **Step 2: Run test to verify it fails**

```bash
bash ops/tests/test-compile-floor.sh 2>&1 | grep -A3 "\-\-all"
```

Expected: FAIL

- [ ] **Step 3: Implement `--all` mode dispatch**

Add a new case at the top of the mode dispatch `case` block (before `compile)`):

```bash
  compile-all)
    if ! command -v jq &>/dev/null; then
      echo "ERROR: --all requires jq to read fleet-config.json" >&2
      exit 2
    fi

    local config="fleet-config.json"
    if [[ ! -f "${config}" ]]; then
      echo "ERROR: fleet-config.json not found (required for --all)" >&2
      exit 1
    fi

    local floor_names
    floor_names="$(jq -r '.floors | keys[]' "${config}" 2>/dev/null)"
    if [[ -z "${floor_names}" ]]; then
      echo "ERROR: No floors declared in fleet-config.json" >&2
      exit 1
    fi

    local all_exit=0
    while IFS= read -r fname; do
      local f_file f_dir
      f_file="$(jq -r ".floors.\"${fname}\".file" "${config}")"
      f_dir="$(jq -r ".floors.\"${fname}\".compiled_dir" "${config}")"

      if [[ ! -f "${f_file}" ]]; then
        echo "WARNING: Floor file not found for '${fname}': ${f_file} — skipping" >&2
        continue
      fi

      echo "--- Compiling floor: ${fname} (${f_file} → ${f_dir}) ---"
      FLOOR_FILE="${f_file}" OUTPUT_DIR="${f_dir}" FLOOR_NAME="${fname}" \
        "${BASH_SOURCE[0]}" "${f_file}" "${f_dir}" ${PROPOSAL_ID:+--proposal "${PROPOSAL_ID}"} || {
        echo "ERROR: Compilation failed for floor '${fname}'" >&2
        all_exit=1
      }
    done <<< "${floor_names}"

    exit "${all_exit}"
    ;;
```

Also update the `COMPILE_ALL` handling — after arg parsing, convert `--all` to `compile-all` mode:

```bash
# Handle --all flag
if [[ "${COMPILE_ALL}" -eq 1 ]]; then
  MODE="compile-all"
fi
```

- [ ] **Step 4: Run the tests**

```bash
bash ops/tests/test-compile-floor.sh
```

Expected: all tests pass.

- [ ] **Step 5: Commit**

```bash
git add ops/compile-floor.sh ops/tests/test-compile-floor.sh
git commit -m "feat(#29): add --all flag to compile all floors from fleet-config"
```

---

## Task 8: Update Existing Tests for New Defaults

**Files:**

- Modify: `ops/tests/test-compile-floor.sh`

Existing tests use `compliance-floor.md` as input and expect `compliance-floor.prose.md` as output. Some may break because prose file naming changed. Review and fix any regressions.

- [ ] **Step 1: Run full test suite and capture output**

```bash
bash ops/tests/test-compile-floor.sh 2>&1
```

- [ ] **Step 2: Fix any tests that reference hardcoded `compliance-floor.prose.md`**

For each failing test, update the expected prose filename from `compliance-floor.prose.md` to the floor-name-derived filename. For fixtures named `floor-valid.md`, the prose output will be `floor-valid.prose.md`.

Look for assertions like:

```bash
assert_file_exists "..." "${OUTPUT_DIR}/compliance-floor.prose.md"
```

Replace with:

```bash
assert_file_exists "..." "${OUTPUT_DIR}/floor-valid.prose.md"
```

(The exact filename depends on the input file basename — trace each test's input.)

- [ ] **Step 3: Run tests again to verify all pass**

```bash
bash ops/tests/test-compile-floor.sh
```

Expected: 0 failures.

- [ ] **Step 4: Commit**

```bash
git add ops/tests/test-compile-floor.sh
git commit -m "test(#29): fix existing tests for floor-agnostic output naming"
```

---

## Task 9: Hook Generalization

**Files:**

- Modify: `.claude/settings.json`

Generalize hooks from hardcoded `compliance-floor.md` to `floors/*.md` pattern. Also update the SessionStart checksum verification to check all active floors.

**Note:** Per CLAUDE.md gotcha — use Write (full rewrite) for `settings.json`, not Edit.

- [ ] **Step 1: Update PreToolUse Edit|Write hook**

Replace the compliance-floor.md protection hook:

Old:

```bash
echo \"$CLAUDE_FILE_PATH\" | grep -qE '(compliance-floor\\.md|compliance/targets\\.md)$' && { [ -f .claude/compliance/.applying ] ...
```

New:

```bash
echo \"$CLAUDE_FILE_PATH\" | grep -qE '(floors/[^/]+\\.md)$' && { FLOOR_BASE=$(echo \"$CLAUDE_FILE_PATH\" | grep -oP 'floors/\\K[^/]+(?=\\.md)'); [ -f \".claude/floors/${FLOOR_BASE}/.applying\" ] && find \".claude/floors/${FLOOR_BASE}/.applying\" -mmin -1 -print -quit 2>/dev/null | grep -q . && exit 0 || echo \"BLOCKED: Floor file protected. Use /floor propose ${FLOOR_BASE}.\" && exit 2; } || echo \"$CLAUDE_FILE_PATH\" | grep -qE '(compliance/targets\\.md)$' && { [ -f .claude/compliance/.applying ] && find .claude/compliance/.applying -mmin -1 -print -quit 2>/dev/null | grep -q . && exit 0 || echo 'BLOCKED: Compliance targets protected. Use /compliance propose.' && exit 2; } || exit 0
```

- [ ] **Step 2: Update SessionStart checksum hook**

Replace the single-floor checksum check with a loop that checks all floors declared in fleet-config.json:

Old:

```bash
[ -f .claude/compliance/compiled/manifest.sha256 ] && [ -f compliance-floor.md ] && { ... }
```

New:

```bash
[ -f fleet-config.json ] && command -v jq &>/dev/null && { for FLOOR in $(jq -r '.floors | keys[]' fleet-config.json 2>/dev/null); do FFILE=$(jq -r \".floors.\\\"${FLOOR}\\\".file\" fleet-config.json 2>/dev/null); FDIR=$(jq -r \".floors.\\\"${FLOOR}\\\".compiled_dir\" fleet-config.json 2>/dev/null); [ -f \"${FDIR}/manifest.sha256\" ] && [ -f \"${FFILE}\" ] && { EXPECTED=$(grep '^source:' \"${FDIR}/manifest.sha256\" | cut -d' ' -f2); ACTUAL=$(sha256sum \"${FFILE}\" | cut -d' ' -f1); [ \"$EXPECTED\" = \"$ACTUAL\" ] && echo \"[CRO] Floor '${FLOOR}' artifacts in sync.\" || echo \"[CRO] WARNING: Floor '${FLOOR}' changed but artifacts not recompiled. Run ops/compile-floor.sh --all.\"; }; done; } || true
```

- [ ] **Step 3: Update PreCompact hook to reference CRO instead of CO**

Replace `CO` references with `CRO` in the PreCompact context string:

```
7 governance agents (CRO, CISO, CEO, CTO, CFO, COO, CKO)
```

And:

```
Multi-floor governance: floors guarded by Cx officers (CRO for compliance, COO for behavioral) with hook enforcement.
```

- [ ] **Step 4: Write the full updated settings.json**

Use `Write` tool to output the complete updated `settings.json`.

- [ ] **Step 5: Validate JSON**

```bash
jq . .claude/settings.json > /dev/null
```

Expected: exits 0.

- [ ] **Step 6: Commit**

```bash
git add .claude/settings.json
git commit -m "feat(#29): generalize hooks for multi-floor governance"
```

---

## Task 10: New `/behavioral` Skill

**Files:**

- Create: `.claude/skills/behavioral/SKILL.md`

- [ ] **Step 1: Write the `/behavioral` skill**

Create `.claude/skills/behavioral/SKILL.md`:

```markdown
---
name: behavioral
description: "Behavioral floor management. Propose changes, review proposals, apply approved changes, view status. Routes to COO as behavioral floor guardian."
argument-hint: "[status|propose <change>|review <id>|apply <id>|log]"
---

# Behavioral Floor

Manage the behavioral floor through the COO (behavioral floor guardian). All changes to the behavioral floor go through this skill.

## Usage

- `/behavioral` or `/behavioral status` -- Behavioral floor posture report
- `/behavioral propose "We MUST ALWAYS run full validation before handoff"` -- Submit a change proposal
- `/behavioral review 001` -- COO reviews and classifies a proposal
- `/behavioral apply 001` -- COO applies an approved change (only path through the hook)
- `/behavioral log` -- View the behavioral floor change log

## Workflow: Status (default)

1. Read behavioral floor state: `floors/behavioral.md` (count rules), `.claude/floors/behavioral/compiled/` (compilation status).
2. Compile report: floor rule count, last compile date, violations since last retro.
3. Present structured report to user.

## Workflow: Propose

1. Parse the proposed change text from argument.
2. Assign next sequential ID (zero-padded 3 digits) in `.claude/floors/behavioral/proposals/`.
3. Create proposal file with frontmatter (`id`, `status: pending`, `type: TBD`, `requested-by`, `date`) and body.
4. Dispatch COO agent. COO classifies as Type 1/2/3.
5. COO dispatches CRO subagent for cross-floor risk consultation.
6. CRO facilitates multi-round Cx consultation, returns consolidated assessment.
7. COO presents to user with risk assessment, Cx positions, recommendation.
8. Log `behavioral-floor-proposed` event via `ops/metrics-log.sh`.

## Workflow: Review

1. Load the proposal file.
2. Dispatch COO agent (Sonnet). COO classifies, dispatches CRO for Cx consultation.
3. Decision gate: Type 1 with consensus → COO approves, notifies user. Type 2-3 or no consensus → present to user.
4. Update proposal status. Log event.

## Workflow: Apply

1. Verify proposal status is "approved".
2. Create sentinel: `.claude/floors/behavioral/.applying` with proposal ID and timestamp.
3. Apply the change to `floors/behavioral.md`.
4. Run `ops/compile-floor.sh floors/behavioral.md .claude/floors/behavioral/compiled --proposal <id>` — if compilation fails, revert via `git checkout -- floors/behavioral.md`, remove sentinel, report error.
5. Update checksum in `.claude/floors/behavioral/floor-checksum.sha256`.
6. Remove sentinel. Log `behavioral-floor-applied` event.

## Workflow: Log

1. Read `.claude/floors/behavioral/change-log.md`.
2. Present recent entries.

## Model Tiering

| Subcommand            | Model  | Rationale                                      |
| --------------------- | ------ | ---------------------------------------------- |
| `/behavioral status`  | Sonnet | Data aggregation                               |
| `/behavioral propose` | Opus   | Judgment: risk classification, Cx consultation |
| `/behavioral review`  | Opus   | Judgment: risk assessment                      |
| `/behavioral apply`   | Sonnet | Controlled file modification                   |
| `/behavioral log`     | Sonnet | Data lookup                                    |
```

- [ ] **Step 2: Commit**

```bash
git add .claude/skills/behavioral/SKILL.md
git commit -m "feat(#29): add /behavioral skill for behavioral floor management"
```

---

## Task 11: New `/floor` Generic Skill

**Files:**

- Create: `.claude/skills/floor/SKILL.md`

- [ ] **Step 1: Write the `/floor` skill**

Create `.claude/skills/floor/SKILL.md`:

````markdown
---
name: floor
description: "Generic floor management. Routes to the declared guardian for any governance floor. Use /floor propose <floor-name> <change> to propose changes to any active floor."
argument-hint: "[list|propose <floor-name> <change>|status <floor-name>]"
---

# Floor Management

Generic skill for managing any governance floor. Routes proposals to the declared guardian in `fleet-config.json`.

## Usage

- `/floor list` -- List all active floors and their guardians
- `/floor status <name>` -- Status report for a specific floor
- `/floor propose <name> "<change>"` -- Submit a change proposal to a floor's guardian

## Workflow: List

1. Read `fleet-config.json` floors section.
2. For each floor: name, file path, guardian, compilation status (check if compiled dir exists and manifest is current).
3. Present as a table.

## Workflow: Status

1. Resolve the floor name to its config entry in `fleet-config.json`.
2. Read the floor file, count rules.
3. Check compiled artifacts: last compile, manifest freshness.
4. Present structured report.

## Workflow: Propose

1. Resolve the floor name to its guardian from `fleet-config.json`.
2. If the guardian has a dedicated skill (e.g., `/compliance`, `/behavioral`), route there.
3. Otherwise, dispatch the guardian agent with the proposal.
4. The guardian dispatches CRO for cross-floor risk consultation.
5. Present results to user.

## Floor Discovery

```bash
jq -r '.floors | to_entries[] | "\(.key): \(.value.file) (guardian: \(.value.guardian))"' fleet-config.json
```

## Adding New Floors

Adding a floor is configuration, not code:

1. Create the floor file in `floors/<name>.md`
2. Declare it in `fleet-config.json` under the `floors` section
3. Assign a Cx officer as guardian
4. Run `ops/compile-floor.sh --all` to compile

No code changes needed.
````

- [ ] **Step 2: Commit**

```bash
git add .claude/skills/floor/SKILL.md
git commit -m "feat(#29): add /floor generic skill for multi-floor governance"
```

---

## Task 12: Update `/compliance` Skill — CO → CRO References

**Files:**

- Modify: `.claude/skills/compliance/SKILL.md`

- [ ] **Step 1: Update references from CO to CRO and update file paths**

In `.claude/skills/compliance/SKILL.md`:

- Replace "Compliance Officer" → "CRO" in description and body
- Replace "CO" → "CRO" (when referring to the agent role, not the abbreviation in `/compliance`)
- Update `compliance-floor.md` → `floors/compliance.md` in Workflow: Apply
- Update `.claude/compliance/floor-checksum.sha256` → `.claude/floors/compliance/floor-checksum.sha256` in Workflow: Apply
- Update sentinel path from `.claude/compliance/.applying` → `.claude/floors/compliance/.applying`
- Add note about cross-floor risk consultation in Workflow: Review: "CRO dispatches the consultation as a subagent since CRO is both guardian and risk facilitator for the compliance floor."

- [ ] **Step 2: Commit**

```bash
git add .claude/skills/compliance/SKILL.md
git commit -m "refactor(#29): update /compliance skill for CRO rename and multi-floor paths"
```

---

## Task 13: Update `/onboard` Skill

**Files:**

- Modify: `.claude/skills/onboard/SKILL.md`

- [ ] **Step 1: Update onboard skill for multi-floor setup**

In `.claude/skills/onboard/SKILL.md`:

- Step 2: Replace `compliance-floor.md` references with `floors/compliance.md`
- Replace `templates/compliance-floor.md` with `templates/floors/compliance.md`
- Update `mkdir -p .claude/compliance` to `mkdir -p .claude/floors/compliance`
- Update checksum path: `.claude/compliance/floor-checksum.sha256` → `.claude/floors/compliance/floor-checksum.sha256`
- Add Step 2c: Behavioral Floor Setup — ask the user if they want to define behavioral rules. If yes, copy `templates/floors/behavioral.md` to `floors/behavioral.md` and walk through examples. Generate checksum in `.claude/floors/behavioral/floor-checksum.sha256`.
- Rename "CO" → "CRO" references

- [ ] **Step 2: Commit**

```bash
git add .claude/skills/onboard/SKILL.md
git commit -m "refactor(#29): update /onboard skill for multi-floor setup"
```

---

## Task 14: Update COLLABORATION.md

**Files:**

- Modify: `.claude/COLLABORATION.md`

- [ ] **Step 1: Update § Compliance Hierarchy → § Governance Floors**

Replace the section heading and content (around line 641):

```markdown
### Governance Floors

Governance floors define non-negotiable rules for agent behavior. Each floor is owned by a Cx officer (guardian) with sole write authority. All floors share the same enforcement machinery: compiler-generated hooks, checksum integrity, sentinel-gated writes.

Active floors are declared in `fleet-config.json`. Adding a new floor is configuration, not code.

**V1 floors:**

| Floor      | File                   | Guardian | Domain                                                   |
| ---------- | ---------------------- | -------- | -------------------------------------------------------- |
| Compliance | `floors/compliance.md` | CRO      | Risk, regulatory, data governance                        |
| Behavioral | `floors/behavioral.md` | COO      | Process quality, delivery standards, collaboration norms |

**Three tiers per floor:**

- **Floor (MUST):** Declarative, unconditional statements. "We MUST ALWAYS..." / "We MUST NEVER..." No conditionals. User approval required for all changes. Enforced by hooks and compliance-auditor.
- **Targets (SHOULD):** Objectives exceeding the floor. Violations are findings, not blockers.
- **Guidance (NICE TO HAVE):** Best practices from Cx roles, delegated to triad to operationalize.

Targets must be above or in addition to the floor -- never weaker.
```

- [ ] **Step 2: Update § Governance Collaboration Pattern for multi-floor consultation**

Replace:

```markdown
### Governance Collaboration Pattern

When a change is proposed to any governance floor:

1. Floor guardian receives and classifies (Type 1: risk-reducing / Type 2: other / Type 3: new rule)
2. Guardian dispatches CRO as subagent for cross-floor risk consultation
3. CRO subagent runs multi-round Cx consultation internally:
   - Distributes proposal to all Cx agents
   - Round 1: Each Cx agent advocates domain impact
   - CRO synthesizes, identifies conflicts and open questions
   - Round N: Further rounds until positions stabilize
4. CRO subagent returns: consolidated risk assessment, Cx positions, recommendation
5. Only the compact result enters main context — round-by-round discussion stays in subagent
6. Guardian presents to user with full context

**Special case (compliance floor):** CRO is both guardian and risk facilitator. CRO dispatches a generic consultation subagent with its own compliance position as input.

No Cx role overrides another's domain authority. If consensus cannot be reached, the user resolves it.
```

- [ ] **Step 3: Replace "CO" with "CRO" throughout the file**

Search and replace all instances of "CO " (with space), "CO's", "CO)", "compliance-officer" references that refer to the agent role. Be careful not to replace "COO" or "CKO" or acronyms where "CO" is a substring.

Specific replacements:

- "CO takes guardianship" → "CRO takes guardianship"
- "compliance-officer" (agent name) → "cro"
- "Compliance Officer" → "CRO" or "Chief Risk Officer (CRO)"

- [ ] **Step 4: Commit**

```bash
git add .claude/COLLABORATION.md
git commit -m "docs(#29): update COLLABORATION.md for multi-floor governance and CRO rename"
```

---

## Task 15: Update CLAUDE.md

**Files:**

- Modify: `CLAUDE.md`

- [ ] **Step 1: Update Directory Structure**

Add `floors/` to the tree:

```
├── floors/
│   ├── compliance.md              # Compliance floor (CRO guardian)
│   └── behavioral.md              # Behavioral floor (COO guardian)
```

Update `.claude/` subtree:

```
│   ├── floors/                    # Per-floor compiled artifacts and checksums
```

Update `templates/` subtree:

```
│   ├── floors/                    # Floor templates
│   │   ├── compliance.md
│   │   └── behavioral.md
```

- [ ] **Step 2: Update Key Files section**

Add:

```markdown
- **`floors/*.md`** -- Governance floor files. Each is owned by a guardian Cx officer (declared in `fleet-config.json`). The compliance floor is guarded by the CRO; the behavioral floor by the COO.
```

Update the compliance-floor.md reference to point to the new location.

- [ ] **Step 3: Update agent list — rename compliance-officer to cro**

In the agent listing, replace `compliance-officer` with `cro`:

```markdown
7 governance (cro, ciso, ceo, cto, cfo, coo, cko)
```

- [ ] **Step 4: Update Compliance Floor section → Governance Floors**

Replace "Compliance Floor" section with:

```markdown
## Governance Floors

Governance floors define non-negotiable rules with compiler-generated enforcement. Each floor is guarded by a Cx officer with sole write authority, enforced by hooks, and protected by checksums.

Define floors in `floors/` at the project root. V1 ships two floors:

- **Compliance floor** (`floors/compliance.md`, CRO guardian): Security, data governance, regulatory controls
- **Behavioral floor** (`floors/behavioral.md`, COO guardian): Process quality, delivery standards, collaboration norms

Declare active floors in `fleet-config.json` under the `floors` section. Adding a new floor is configuration, not code.
```

- [ ] **Step 5: Update Compile command docs**

````markdown
### Compliance Compiler

```bash
ops/compile-floor.sh                              # Compile default floor (from fleet-config.json)
ops/compile-floor.sh --all                         # Compile all active floors
ops/compile-floor.sh --floor behavioral            # Compile a specific floor
ops/compile-floor.sh --dry-run                     # Validate without writing
ops/compile-floor.sh --verify                      # Check artifacts match source
ops/compile-floor.sh --proposal 003                # Tag artifacts with proposal ID
ops/compile-floor.sh floors/behavioral.md .claude/floors/behavioral/compiled  # Explicit paths
ops/tests/test-compile-floor.sh                    # Run compiler tests
```
````

- [ ] **Step 6: Update Architecture Constraints**

Replace "Compliance floor is sacred" with:

```markdown
1. **Governance floors are sacred.** No agent deprioritizes, defers, or works around governance floor rules. All floors carry equal enforcement weight.
```

- [ ] **Step 7: Update Gotchas**

Add:

```markdown
- **Multi-floor governance**: Floors are declared in `fleet-config.json`. Each has a guardian (Cx officer) with sole write authority. The CRO facilitates cross-floor risk assessment when any floor changes.
- **CO → CRO rename**: The Compliance Officer is now the Chief Risk Officer (CRO). Agent file is `.claude/agents/cro.md`.
```

- [ ] **Step 8: Commit**

```bash
git add CLAUDE.md
git commit -m "docs(#29): update CLAUDE.md for multi-floor governance"
```

---

## Task 16: Update fleet-config.json pathways — CRO rename

**Files:**

- Modify: `templates/fleet-config.json`

- [ ] **Step 1: Update governance pathways**

In `templates/fleet-config.json`, update the pathways section:

Replace:

```json
"ciso -> compliance-officer",
"compliance-officer -> compliance-auditor",
"* -> compliance-officer",
```

With:

```json
"ciso -> cro",
"cro -> compliance-auditor",
"* -> cro",
```

- [ ] **Step 2: Validate JSON**

```bash
jq . templates/fleet-config.json > /dev/null
```

- [ ] **Step 3: Commit**

```bash
git add templates/fleet-config.json
git commit -m "refactor(#29): update fleet-config pathways for CRO rename"
```

---

## Key Files Reference

For the executing agent — these are the files you'll need to read for context:

| File                                                           | Why                                         |
| -------------------------------------------------------------- | ------------------------------------------- |
| `docs/superpowers/specs/2026-03-25-behavioral-floor-design.md` | The spec this plan implements               |
| `ops/compile-floor.sh`                                         | The compiler being generalized (1430 lines) |
| `ops/tests/test-compile-floor.sh`                              | Test suite (714 lines)                      |
| `.claude/agents/compliance-officer.md`                         | Agent being renamed to CRO                  |
| `.claude/agents/coo.md`                                        | Agent gaining behavioral floor guardianship |
| `.claude/skills/compliance/SKILL.md`                           | Skill being updated for CRO                 |
| `.claude/skills/onboard/SKILL.md`                              | Skill being updated for multi-floor         |
| `.claude/settings.json`                                        | Hooks being generalized                     |
| `templates/fleet-config.json`                                  | Config template gaining floors section      |
| `.claude/COLLABORATION.md`                                     | Collaboration doc being updated             |
| `CLAUDE.md`                                                    | Project docs being updated                  |
