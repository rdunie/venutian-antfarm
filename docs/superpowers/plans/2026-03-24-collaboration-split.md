# COLLABORATION.md Split Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Split the 792-line monolithic `.claude/COLLABORATION.md` into `.claude/protocol/` with a three-tier loading model (base + profiles + sub-files), build a protocol compiler, and update all 33 cross-references.

**Architecture:** Extract content from COLLABORATION.md into 15 Tier 2 sub-files, condense universal rules into a Tier 0 base file, compose 4 Tier 1 role profiles, then build `ops/compile-protocol.sh` that reads agent frontmatter and assembles per-agent compiled protocol contexts. Extract shared utilities from the existing compliance compiler into `ops/lib/compiler-utils.sh`.

**Tech Stack:** Bash, yq (existing dependency), sha256sum

**Spec:** `docs/superpowers/specs/2026-03-22-collaboration-split-design.md`

---

## File Map

### Created

| File                                         | Responsibility                                               |
| -------------------------------------------- | ------------------------------------------------------------ |
| `.claude/protocol/base.md`                   | Tier 0: universal behavioral floor (~70-80 lines)            |
| `.claude/protocol/ethos.md`                  | Full guiding ethos                                           |
| `.claude/protocol/resource-stewardship.md`   | Resource stewardship + budget table                          |
| `.claude/protocol/fleet-structure.md`        | Agent tiers + triad dynamics                                 |
| `.claude/protocol/pace-control.md`           | Pace definitions, rules, info needs                          |
| `.claude/protocol/principles.md`             | Core Principles 1-11 (full)                                  |
| `.claude/protocol/metrics.md`                | DORA + flow quality + event table                            |
| `.claude/protocol/handoffs.md`               | Handoff protocol + completion format                         |
| `.claude/protocol/coordination.md`           | Coordination architecture (working state vs published view)  |
| `.claude/protocol/lifecycle.md`              | 10-phase lifecycle + milestone release                       |
| `.claude/protocol/deployment.md`             | Deployment progression + failures                            |
| `.claude/protocol/regression.md`             | Periodic regression testing                                  |
| `.claude/protocol/branching.md`              | Branch lifecycle, PRs, env discipline                        |
| `.claude/protocol/compliance-governance.md`  | Compliance floor, hierarchy, governance, CEO pace, Cx memory |
| `.claude/protocol/learning.md`               | Findings, learning collective, memory integration            |
| `.claude/protocol/escalation.md`             | Conflict resolution, escalation, success criteria            |
| `.claude/protocol/profiles/triad.md`         | Tier 1: PO, SA, SM profile                                   |
| `.claude/protocol/profiles/governance.md`    | Tier 1: Cx roles profile                                     |
| `.claude/protocol/profiles/specialist.md`    | Tier 1: domain specialists profile                           |
| `.claude/protocol/profiles/cross-cutting.md` | Tier 1: platform-ops, knowledge-ops, auditor profile         |
| `ops/lib/compiler-utils.sh`                  | Shared compiler utility API                                  |
| `ops/compile-protocol.sh`                    | Protocol compiler                                            |
| `ops/tests/test-compile-protocol.sh`         | Protocol compiler tests                                      |
| `ops/tests/fixtures/agent-triad.md`          | Test fixture: triad agent frontmatter                        |
| `ops/tests/fixtures/agent-governance.md`     | Test fixture: governance agent frontmatter                   |
| `ops/tests/fixtures/agent-specialist.md`     | Test fixture: specialist agent frontmatter                   |

### Modified

| File                                  | Change                                                |
| ------------------------------------- | ----------------------------------------------------- |
| `.claude/COLLABORATION.md`            | Replace 792 lines with ~50-line hub index             |
| `ops/compile-floor.sh`                | Refactor to source `ops/lib/compiler-utils.sh`        |
| `ops/hooks/collab-sync-check.sh`      | Rewrite for protocol/ directory structure             |
| `.claude/agents/*.md` (13 files)      | Add `protocol.profile` frontmatter, update prose refs |
| `.claude/skills/*/SKILL.md` (7 files) | Update cross-references                               |
| `CLAUDE.md`                           | Update directory structure, refs, commands            |
| `docs/GETTING-STARTED.md`             | Update cross-references                               |
| `docs/AGENT-FLEET-PATTERN.md`         | Update cross-references                               |
| `docs/COLLABORATION-MODEL.md`         | Update cross-references                               |
| `templates/agents/*.md` (6 files)     | Add default `protocol.profile` frontmatter            |
| `.claude/compliance/targets.md`       | Update cross-references                               |
| `.claude/DOCUMENTATION-STYLE.md`      | Update cross-references                               |
| `.claude/settings.json`               | Add SessionStart hook for protocol drift check        |

---

## Task 1: Extract Tier 2 Sub-Files from COLLABORATION.md

**Files:**

- Read: `.claude/COLLABORATION.md`
- Create: `.claude/protocol/ethos.md`
- Create: `.claude/protocol/resource-stewardship.md`
- Create: `.claude/protocol/fleet-structure.md`
- Create: `.claude/protocol/pace-control.md`
- Create: `.claude/protocol/principles.md`
- Create: `.claude/protocol/metrics.md`
- Create: `.claude/protocol/handoffs.md`
- Create: `.claude/protocol/coordination.md`
- Create: `.claude/protocol/lifecycle.md`
- Create: `.claude/protocol/deployment.md`
- Create: `.claude/protocol/regression.md`
- Create: `.claude/protocol/branching.md`
- Create: `.claude/protocol/compliance-governance.md`
- Create: `.claude/protocol/learning.md`
- Create: `.claude/protocol/escalation.md`

This is the largest task — extracting all 15 sub-files from the monolith. Each sub-file gets the content from its corresponding section(s) in COLLABORATION.md, verbatim. No rewording yet — that happens in Task 2 (base) and Task 3 (profiles).

**Section-to-file mapping (line ranges from current COLLABORATION.md):**

| File                       | Source Lines                       | Source Sections                                                                                    |
| -------------------------- | ---------------------------------- | -------------------------------------------------------------------------------------------------- |
| `ethos.md`                 | 5-18                               | Guiding Ethos                                                                                      |
| `resource-stewardship.md`  | 19-45                              | Resource Stewardship                                                                               |
| `fleet-structure.md`       | 46-114                             | Agent Fleet Structure (all 4 tiers + triad)                                                        |
| `pace-control.md`          | 115-151, 340-353                   | Pace Control (definitions, rules, info needs) + Autonomy Model (full version; condensed in base)   |
| `principles.md`            | 178-294                            | Core Principles 1-10 (Principle 11 is in metrics.md)                                               |
| `metrics.md`               | 295-338                            | Principle 11 (Measure Delivery Performance) + DORA + flow quality + event logging table            |
| `handoffs.md`              | 376-399                            | Handoff Protocol + Completion                                                                      |
| `coordination.md`          | 152-177, 401-410                   | Coordination Architecture + Parallel vs. Sequential Work                                           |
| `lifecycle.md`             | 452-470, 526-534, 538-598, 599-611 | Lifecycle table, Team Retro, Periodic Regression intro, Milestone Release                          |
| `deployment.md`            | 471-525                            | Deployment Progression, Deployment Failures, Acceptance Failure                                    |
| `regression.md`            | 535-598                            | Periodic Regression Testing (full)                                                                 |
| `branching.md`             | 411-450                            | Branching, PR-Native Review, Environment Discipline, Fix Ownership, Branch Health                  |
| `compliance-governance.md` | 625-710                            | Compliance Floor, Hierarchy, Governance Collaboration, CEO Pace, Cx Memory, Knowledge Distribution |
| `learning.md`              | 241-260, 712-756                   | Findings (from Principles), Learning Collective, Memory Integration                                |
| `escalation.md`            | 613-624, 757-793                   | Conflict Resolution, Escalation Rules, Success Criteria, Deferred Concerns                         |

**Content that moves directly to profiles (not extracted to sub-files):**

- Lines 354-374 (Model Tiering + Thinking-Time Caps) → inlined in `profiles/triad.md` in Task 3. Excluded from Task 1 coverage check.

Note: Some content appears in multiple mappings (e.g., findings urgency table). During extraction, assign each block to exactly one file. The `lifecycle.md` file gets the lifecycle table + milestone release dispatch. `regression.md` gets the full regression testing section. `learning.md` gets the findings section from Core Principles (§7 Learning Through Findings) plus the Learning Collective and Memory Integration sections.

- [ ] **Step 1: Create the protocol directory**

Run: `mkdir -p .claude/protocol/profiles`

- [ ] **Step 2: Extract each sub-file**

For each file in the mapping above, extract the corresponding lines from COLLABORATION.md. Each sub-file should:

- Start with a level-1 heading matching its topic
- Contain the verbatim content from the source sections
- NOT include frontmatter (sub-files are plain markdown)
- End with a blank line

Use the Read tool on COLLABORATION.md for each line range, then Write each sub-file. Work through the mapping in order.

**Validation:** After each file is written, verify line count is within ~20% of the estimate in the spec's Tier 2 table.

- [ ] **Step 3: Verify content coverage**

Run a line-count comparison:

```bash
# Count non-blank, non-heading lines in original
original=$(grep -cvE '^\s*$|^#|^---' .claude/COLLABORATION.md)
# Count non-blank, non-heading lines across all sub-files
split=$(cat .claude/protocol/*.md | grep -cvE '^\s*$|^#|^---')
echo "Original: $original  Split: $split"
```

Expected: `split` should be close to `original` minus ~20 lines (Model Tiering, lines 354-374, moves to profiles in Task 3). Some lines may appear in multiple files due to the lifecycle/regression/learning overlap. If `split` is significantly less than `original - 20`, content was missed.

- [ ] **Step 4: Commit**

```bash
git add .claude/protocol/*.md
git commit -m "feat: extract 15 protocol sub-files from COLLABORATION.md

Content extracted verbatim from .claude/COLLABORATION.md into individual
topic files under .claude/protocol/. No content changes — this is a
mechanical extraction."
```

---

## Task 2: Write the Base File (Tier 0)

**Files:**

- Create: `.claude/protocol/base.md`
- Read: `.claude/protocol/ethos.md` (source for condensed ethos)
- Read: `.claude/protocol/principles.md` (source for condensed principles)
- Read: `.claude/protocol/resource-stewardship.md` (source for condensed stewardship)

The base file is NOT a copy — it's a condensed version of universal rules. Target: ~70-80 lines.

- [ ] **Step 1: Write base.md**

```markdown
# Agent Protocol — Universal Base

Every agent loads this file. It is not optional and cannot be overridden.

## Guiding Ethos

- **Own your work.** See a problem, raise it, propose a fix, or flag it.
- **Act ethically.** The compliance floor is respected because real consequences follow from violations.
- **Value transparency.** Show reasoning, document decisions, make work observable.
- **Pursue quality.** Genuine quality — work you would be proud to hand to a colleague.
- **Deliver value.** Every action connects to a user need.

Full ethos: `.claude/protocol/ethos.md`

## Core Principles

1. **Non-Blocking Escalation** — escalate clearly, continue unblocked work
2. **Documentation Currency** — update docs as part of completing work
3. **DRY Documentation** — cross-link to source of truth, don't duplicate
4. **Transparency and Observability** — log decisions, explicit handoffs, record findings
5. **Separation of Duties** — request, don't reach; never bypass compliance floor
6. **Shift-Left Validation** — the building agent owns the full validation cycle
7. **Learning Through Findings** — record notable findings, refine over time
8. **No Bugs Left Behind** — fix immediately or track explicitly
9. **Stop and Reassess When Scope Expands** — rolling back is always valid
10. **Risk-Proportional Recovery** — verify at depth proportional to risk
11. **Measure Delivery Performance** — DORA + flow quality metrics

Full principles: `.claude/protocol/principles.md`

## Autonomy Model

| Tier           | Behavior                     | Examples                                                                  |
| -------------- | ---------------------------- | ------------------------------------------------------------------------- |
| **Autonomous** | Act, inform after            | Reading code, running tests, writing within own domain, diagnosing issues |
| **Propose**    | Recommend, wait for approval | Cross-domain changes, priority changes, new dependencies, architecture    |
| **Escalate**   | Surface, user decides        | Compliance implications, strategic decisions, destructive operations      |

**Default when uncertain: Propose.**

Pace modifies autonomy: at Crawl, most actions shift toward Propose. At Fly, more toward Autonomous. The three tiers exist at every pace.

## Compliance Floor

The compliance floor is **non-negotiable** across all agents. These rules override autonomy tiers, pace settings, and all other protocol elements — even autonomous actions at Fly pace.

The compliance-officer is the sole guardian. Changes go through `/compliance propose` with user approval.

## Resource Stewardship

Choose the cheapest effective approach. Tokens, thinking time, context window, and human attention are all finite. Start cheap, escalate if quality is insufficient.

Full stewardship model: `.claude/protocol/resource-stewardship.md`

## Separation of Duties

Each agent owns a specific domain. Do not modify code or artifacts outside your domain without involving the domain owner. Request, don't reach.

## Documentation Currency

Every agent updates documentation within its domain as part of completing work. No agent marks work as done while docs are stale.
```

- [ ] **Step 2: Verify line count**

Run: `wc -l .claude/protocol/base.md`
Expected: 70-85 lines.

- [ ] **Step 3: Commit**

```bash
git add .claude/protocol/base.md
git commit -m "feat: add protocol base file (Tier 0 universal floor)

Condensed universal rules that every agent loads unconditionally.
~75 lines covering ethos, principles, autonomy, compliance, stewardship,
separation of duties, and documentation currency."
```

---

## Task 3: Write Role Profiles (Tier 1)

**Files:**

- Create: `.claude/protocol/profiles/triad.md`
- Create: `.claude/protocol/profiles/governance.md`
- Create: `.claude/protocol/profiles/specialist.md`
- Create: `.claude/protocol/profiles/cross-cutting.md`
- Read: `.claude/protocol/handoffs.md` (source for inlined handoff format)
- Read: `.claude/protocol/metrics.md` (source for model tiering table)
- Read: `.claude/protocol/escalation.md` (source for escalation table)
- Read: `.claude/protocol/compliance-governance.md` (source for governance summary)
- Read: `.claude/protocol/branching.md` (source for branching conventions)

Each profile inlines small content and references larger sub-files via markdown links.

- [ ] **Step 1: Write profiles/triad.md**

The triad profile inlines:

- Handoff format + completion format (~25 lines, copied from `handoffs.md`)
- Model tiering table (~15 lines, from COLLABORATION.md lines 354-374)

References (as markdown links):

- lifecycle, deployment, metrics, pace-control, branching, regression, fleet-structure, learning, coordination

```markdown
# Triad Protocol Profile

Loaded by: product-owner, solution-architect, scrum-master

This profile is compiled into your context by the protocol compiler. The base protocol (`base.md`) is always included.

## Handoff Protocol

When handing work to another agent:

[inline the full handoff format from handoffs.md]

### Handoff Completion

[inline the full completion format from handoffs.md]

## Model Tiering

[inline the model tiering table and thinking-time caps from COLLABORATION.md lines 354-374]

## Referenced Sections

Load these when your current task requires them:

- [Work Item Lifecycle](../lifecycle.md) — 10-phase lifecycle, ad-hoc item rule, milestone release
- [Deployment](../deployment.md) — deployment progression, failures, acceptance failure
- [Metrics](../metrics.md) — DORA, flow quality, event logging table
- [Pace Control](../pace-control.md) — pace definitions, rules, promotion thresholds
- [Branching](../branching.md) — branch lifecycle, PRs, environment discipline
- [Regression Testing](../regression.md) — periodic regression testing, screenshot evidence
- [Fleet Structure](../fleet-structure.md) — agent tiers, triad collaboration dynamics
- [Learning](../learning.md) — findings, learning collective, memory integration
- [Coordination](../coordination.md) — working state vs published view, write-lock awareness
```

- [ ] **Step 2: Write profiles/governance.md**

Inlines:

- Escalation rules table (~10 lines, from `escalation.md`)
- Governance collaboration pattern summary (~15 lines, from `compliance-governance.md`)

References: compliance-governance, metrics, pace-control, fleet-structure, learning, escalation

Follow the same structure as triad.md.

- [ ] **Step 3: Write profiles/specialist.md**

Inlines:

- Handoff format + completion format (~25 lines, from `handoffs.md`)
- Branching conventions (~15 lines, from `branching.md` — branch naming, PR title format)

References: lifecycle, deployment, regression, metrics

- [ ] **Step 4: Write profiles/cross-cutting.md**

Inlines:

- Handoff format + completion format (~25 lines, from `handoffs.md`)

References: metrics, compliance-governance, learning, lifecycle

- [ ] **Step 5: Verify line counts**

```bash
for f in .claude/protocol/profiles/*.md; do
  echo "$(wc -l < "$f") $f"
done
```

Expected ranges: triad 60-80, governance 40-60, specialist 40-60, cross-cutting 40-60.

- [ ] **Step 6: Commit**

```bash
git add .claude/protocol/profiles/
git commit -m "feat: add 4 role profiles (Tier 1 protocol loading)

Triad, governance, specialist, and cross-cutting profiles.
Each inlines critical small content and references larger sub-files."
```

---

## Task 4: Extract Shared Compiler Utilities

**Files:**

- Create: `ops/lib/compiler-utils.sh`
- Modify: `ops/compile-floor.sh` (refactor to source shared lib)
- Test: `ops/tests/test-compile-floor.sh` (verify no regression)

Extract `generate_manifest` and `verify_manifest` from the compliance compiler into a shared library, then refactor the compiler to source it. No functional changes.

- [ ] **Step 1: Create ops/lib/ directory**

Run: `mkdir -p ops/lib`

- [ ] **Step 2: Write compiler-utils.sh**

```bash
#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# compiler-utils.sh — Shared utilities for harness compilers
#
# Source this file: source ops/lib/compiler-utils.sh
#
# Provides:
#   generate_manifest  — SHA256 manifest for drift detection
#   verify_manifest    — Compare current hashes against manifest
#   parse_frontmatter  — Extract YAML frontmatter field from markdown
#   compile_log        — Structured compiler logging
#   emit_header        — Traceability header for compiled output
# ---------------------------------------------------------------------------

# Guard against double-sourcing
[[ -n "${_COMPILER_UTILS_LOADED:-}" ]] && return 0
_COMPILER_UTILS_LOADED=1

# ---------------------------------------------------------------------------
# parse_frontmatter — extract a YAML frontmatter field from a markdown file
#
# Arguments:
#   $1  markdown file path
#   $2  field name (dot notation supported, e.g., "protocol.profile")
#
# Prints the field value to stdout. Prints empty string if not found.
# Requires yq.
# ---------------------------------------------------------------------------
parse_frontmatter() {
  local file="$1"
  local field="$2"
  local yaml_block

  # Extract YAML between first --- pair
  yaml_block=$(sed -n '/^---$/,/^---$/{ /^---$/d; p; }' "$file" | head -50)
  if [[ -z "$yaml_block" ]]; then
    echo ""
    return 0
  fi

  local value
  value=$(echo "$yaml_block" | yq ".$field" 2>/dev/null)
  # yq returns "null" for missing fields
  if [[ "$value" == "null" ]]; then
    echo ""
  else
    echo "${value//\"/}"
  fi
}

# ---------------------------------------------------------------------------
# compile_log — structured compiler logging
#
# Arguments:
#   $1  level (INFO, WARN, ERROR)
#   $2  message
#   remaining args: key=value pairs
# ---------------------------------------------------------------------------
compile_log() {
  local level="$1"
  local message="$2"
  shift 2
  local timestamp
  timestamp=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
  printf '[%s] %s: %s' "$timestamp" "$level" "$message"
  for kv in "$@"; do
    printf ' %s' "$kv"
  done
  printf '\n'
}

# ---------------------------------------------------------------------------
# emit_header — write traceability header to compiled output
#
# Arguments:
#   $1  compiler name (e.g., "compile-protocol.sh")
#   remaining args: source file paths
#
# Prints header lines to stdout.
# ---------------------------------------------------------------------------
emit_header() {
  local compiler="$1"
  shift
  local timestamp
  timestamp=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
  printf '# GENERATED by ops/%s at %s\n' "$compiler" "$timestamp"
  printf '# Sources:'
  for src in "$@"; do
    printf ' %s' "$src"
  done
  printf '\n'
  printf '# Do not edit — changes will be overwritten on next compile.\n'
  printf '\n'
}

# ---------------------------------------------------------------------------
# generate_manifest — write manifest.sha256 for staleness detection
#
# Arguments:
#   $1  source file or directory path
#   $2  output directory (must contain compiled artifacts)
#   $3  proposal ID or label (may be empty)
# ---------------------------------------------------------------------------
generate_manifest() {
  local source_path="$1"
  local out_dir="$2"
  local label="${3:-}"

  local source_hash
  if [[ -d "$source_path" ]]; then
    source_hash=$(find "$source_path" -name '*.md' -print0 | sort -z | xargs -0 cat | sha256sum | cut -d' ' -f1)
  else
    source_hash=$(sha256sum "$source_path" | cut -d' ' -f1)
  fi

  {
    printf 'source: %s\n' "$source_hash"
    printf 'label: %s\n' "$label"
    printf 'artifacts:\n'
    for artifact in "$out_dir"/*; do
      [[ -f "$artifact" ]] || continue
      [[ "$(basename "$artifact")" == "manifest.sha256" ]] && continue
      local ahash
      ahash=$(sha256sum "$artifact" | cut -d' ' -f1)
      printf '  %s: %s\n' "$(basename "$artifact")" "$ahash"
    done
  } > "$out_dir/manifest.sha256"
}

# ---------------------------------------------------------------------------
# verify_manifest — compare current hashes against manifest.sha256
#
# Arguments:
#   $1  source file or directory path
#   $2  output directory (must contain manifest.sha256)
#
# Exits 0 if clean, prints drifted items and exits 1 if any differ.
# ---------------------------------------------------------------------------
verify_manifest() {
  local source_path="$1"
  local out_dir="$2"
  local manifest_file="$out_dir/manifest.sha256"

  if [[ ! -f "$manifest_file" ]]; then
    echo "ERROR: manifest.sha256 not found in $out_dir" >&2
    return 1
  fi

  local drift=0

  # Compare source hash
  local recorded_source
  recorded_source=$(grep '^source:' "$manifest_file" | awk '{print $2}')
  local current_source
  if [[ -d "$source_path" ]]; then
    current_source=$(find "$source_path" -name '*.md' -print0 | sort -z | xargs -0 cat | sha256sum | cut -d' ' -f1)
  else
    current_source=$(sha256sum "$source_path" | cut -d' ' -f1)
  fi

  if [[ "$current_source" != "$recorded_source" ]]; then
    echo "DRIFT: source has changed ($source_path)"
    drift=1
  fi

  # Compare artifact hashes
  while IFS=': ' read -r artifact_name artifact_hash; do
    [[ -z "$artifact_name" ]] && continue
    local artifact_path="$out_dir/$artifact_name"
    if [[ ! -f "$artifact_path" ]]; then
      echo "DRIFT: artifact missing: $artifact_name"
      drift=1
      continue
    fi
    local current_hash
    current_hash=$(sha256sum "$artifact_path" | cut -d' ' -f1)
    if [[ "$current_hash" != "$artifact_hash" ]]; then
      echo "DRIFT: $artifact_name has changed"
      drift=1
    fi
  done < <(grep '^  ' "$manifest_file" | sed 's/^  //')

  [[ "$drift" -eq 0 ]] && return 0 || return 1
}
```

- [ ] **Step 3: Refactor compile-floor.sh to source shared utils**

In `ops/compile-floor.sh`, add after the dependency check (line ~101):

```bash
# Source shared compiler utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/compiler-utils.sh"
```

Then replace the `generate_manifest` function body (lines 1096-1137) with a call that delegates to the shared version. Similarly for `verify_manifest` (lines 1149-1208).

**Important:** The compliance compiler's `generate_manifest` has floor-specific logic (prose hash, enforce hash, coverage hash, proposal ID). The shared version is more generic. The refactor approach:

1. Keep the compliance compiler's `generate_manifest` and `verify_manifest` functions in place for now
2. Source the shared library for `parse_frontmatter`, `compile_log`, and `emit_header` (which the compliance compiler doesn't have today)
3. Converge manifest functions in a future refactor when both compilers' manifest needs are better understood

This avoids risking the working compliance compiler.

- [ ] **Step 4: Run existing compliance compiler tests**

Run: `bash ops/tests/test-compile-floor.sh`
Expected: All tests pass. Zero regressions.

- [ ] **Step 5: Commit**

```bash
git add ops/lib/compiler-utils.sh ops/compile-floor.sh
git commit -m "feat: add shared compiler utilities library

Add shared compiler utilities (parse_frontmatter, compile_log,
emit_header, generate_manifest, verify_manifest) to ops/lib/.
compile-floor.sh sources the library for new functions only;
manifest function convergence deferred to future refactor."
```

---

## Task 5: Build Protocol Compiler

**Files:**

- Create: `ops/compile-protocol.sh`
- Create: `ops/tests/test-compile-protocol.sh`
- Create: `ops/tests/fixtures/agent-triad.md`
- Create: `ops/tests/fixtures/agent-governance.md`
- Create: `ops/tests/fixtures/agent-specialist.md`

- [ ] **Step 1: Create test fixtures**

`ops/tests/fixtures/agent-triad.md`:

```markdown
---
name: test-po
description: "Test product owner agent"
model: opus
protocol:
  profile: triad
---

Test agent content.
```

`ops/tests/fixtures/agent-governance.md`:

```markdown
---
name: test-ciso
description: "Test CISO agent"
model: opus
protocol:
  profile: governance
---

Test agent content.
```

`ops/tests/fixtures/agent-specialist.md`:

```markdown
---
name: test-backend
description: "Test backend specialist"
model: sonnet
protocol:
  profile: specialist
  additional:
    - regression
---

Test agent content.
```

- [ ] **Step 2: Write the test suite**

`ops/tests/test-compile-protocol.sh` — follow the same pattern as `test-compile-floor.sh` (assert helpers, temp dirs, test functions). Test cases:

1. **Basic compilation** — compile a triad agent, verify output contains base.md content + triad profile inlined content + reference index
2. **Governance compilation** — compile governance agent, verify escalation table inlined, compliance-governance referenced
3. **Additional sub-files** — compile specialist agent with `additional: [regression]`, verify regression.md content included
4. **Base is always present** — compile any agent, verify base.md content appears regardless of profile
5. **Verify mode** — compile, then verify with `--verify`, expect exit 0. Modify a source file, verify again, expect exit 1 with DRIFT message
6. **Dry-run mode** — run with `--dry-run`, verify no files written
7. **Single agent mode** — run with `--agent test-po`, verify only that agent compiled
8. **Missing profile** — agent with `protocol.profile: nonexistent`, expect exit 2 with error
9. **Traceability header** — verify compiled output starts with `# GENERATED by` header

- [ ] **Step 3: Run tests to verify they fail**

Run: `bash ops/tests/test-compile-protocol.sh`
Expected: All tests FAIL (compiler doesn't exist yet).

- [ ] **Step 4: Write compile-protocol.sh**

```bash
#!/usr/bin/env bash
set -euo pipefail

# ---------------------------------------------------------------------------
# compile-protocol.sh — Protocol compiler
#
# Reads agent frontmatter, resolves protocol dependencies, and produces
# compiled protocol blocks for each agent.
#
# Usage:
#   compile-protocol.sh [options] [agents-dir] [protocol-dir] [output-dir]
#
# Options:
#   --dry-run         Show what would be compiled without writing
#   --verify          Verify compiled outputs match sources (exit 0=clean, 1=drift)
#   --agent <name>    Compile for a single agent only
# ---------------------------------------------------------------------------

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/compiler-utils.sh"

AGENTS_DIR=".claude/agents"
PROTOCOL_DIR=".claude/protocol"
OUTPUT_DIR=".claude/protocol/compiled"
MODE=""
SINGLE_AGENT=""

# Arg parsing
POSITIONAL=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) MODE="dry-run"; shift ;;
    --verify) MODE="verify"; shift ;;
    --agent) SINGLE_AGENT="$2"; shift 2 ;;
    --*) echo "ERROR: Unknown option: $1" >&2; exit 1 ;;
    *) POSITIONAL+=("$1"); shift ;;
  esac
done

# Positional overrides
[[ ${#POSITIONAL[@]} -ge 1 ]] && AGENTS_DIR="${POSITIONAL[0]}"
[[ ${#POSITIONAL[@]} -ge 2 ]] && PROTOCOL_DIR="${POSITIONAL[1]}"
[[ ${#POSITIONAL[@]} -ge 3 ]] && OUTPUT_DIR="${POSITIONAL[2]}"

# Dependency check
if ! command -v yq &>/dev/null; then
  echo "ERROR: yq is required but not installed." >&2
  exit 2
fi

# ---------------------------------------------------------------------------
# compile_agent — compile protocol context for one agent
# ---------------------------------------------------------------------------
compile_agent() {
  local agent_file="$1"
  local agent_name
  agent_name=$(parse_frontmatter "$agent_file" "name")

  if [[ -z "$agent_name" ]]; then
    compile_log "WARN" "Skipping $agent_file — no name in frontmatter"
    return 0
  fi

  local profile
  profile=$(parse_frontmatter "$agent_file" "protocol.profile")

  local additional
  additional=$(parse_frontmatter "$agent_file" "protocol.additional")

  # Resolve profile file
  local profile_file=""
  if [[ -n "$profile" ]]; then
    profile_file="${PROTOCOL_DIR}/profiles/${profile}.md"
    if [[ ! -f "$profile_file" ]]; then
      compile_log "ERROR" "Profile not found: $profile_file" "agent=$agent_name"
      return 2
    fi
  fi

  local output_file="${OUTPUT_DIR}/${agent_name}.protocol.md"
  local sources=("${PROTOCOL_DIR}/base.md")

  if [[ "$MODE" == "dry-run" ]]; then
    compile_log "INFO" "Would compile" "agent=$agent_name" "profile=$profile"
    return 0
  fi

  # Assemble compiled output
  {
    emit_header "compile-protocol.sh" "${sources[@]}" ${profile_file:+"$profile_file"}

    # Tier 0: base (always)
    cat "${PROTOCOL_DIR}/base.md"
    printf '\n'

    # Tier 1: profile inlined content (strip references section for compilation)
    if [[ -n "$profile_file" ]]; then
      printf '---\n\n'
      # Include everything from profile up to "## Referenced Sections"
      sed '/^## Referenced Sections/,$d' "$profile_file"
      printf '\n'
    fi

    # Tier 1: additional sub-files compiled into context
    if [[ -n "$additional" && "$additional" != "null" ]]; then
      # Parse YAML list
      local items
      items=$(echo "$additional" | yq '.[]' 2>/dev/null || true)
      while IFS= read -r item; do
        item="${item//\"/}"
        [[ -z "$item" ]] && continue
        local sub_file="${PROTOCOL_DIR}/${item}.md"
        if [[ -f "$sub_file" ]]; then
          printf '---\n\n'
          cat "$sub_file"
          printf '\n'
          sources+=("$sub_file")
        else
          compile_log "WARN" "Additional sub-file not found: $sub_file" "agent=$agent_name"
        fi
      done <<< "$items"
    fi

    # Reference index (from profile)
    if [[ -n "$profile_file" ]]; then
      local ref_section
      ref_section=$(sed -n '/^## Referenced Sections/,$p' "$profile_file")
      if [[ -n "$ref_section" ]]; then
        printf '---\n\n'
        printf '%s\n' "$ref_section"
      fi
    fi
  } > "$output_file"

  compile_log "INFO" "Compiled" "agent=$agent_name" "profile=${profile:-none}" "output=$output_file"
}

# ---------------------------------------------------------------------------
# dispatch
# ---------------------------------------------------------------------------

mkdir -p "$OUTPUT_DIR"

if [[ "$MODE" == "verify" ]]; then
  verify_manifest "$PROTOCOL_DIR" "$OUTPUT_DIR"
  exit $?
fi

# Compile agents
compiled=0
for agent_file in "$AGENTS_DIR"/*.md; do
  [[ -f "$agent_file" ]] || continue
  iter_name=$(parse_frontmatter "$agent_file" "name")

  if [[ -n "$SINGLE_AGENT" && "$iter_name" != "$SINGLE_AGENT" ]]; then
    continue
  fi

  compile_agent "$agent_file"
  compiled=$((compiled + 1))
done

if [[ "$MODE" != "dry-run" ]]; then
  generate_manifest "$PROTOCOL_DIR" "$OUTPUT_DIR" "protocol-compile"
  compile_log "INFO" "Manifest written" "agents=$compiled"
fi

compile_log "INFO" "Done" "agents=$compiled" "mode=${MODE:-compile}"
```

- [ ] **Step 5: Make compiler executable**

Run: `chmod +x ops/compile-protocol.sh`

- [ ] **Step 6: Run tests**

Run: `bash ops/tests/test-compile-protocol.sh`
Expected: All tests PASS.

- [ ] **Step 7: Run compiler against real agents**

Run: `ops/compile-protocol.sh --dry-run`
Expected: Lists all 13 agents with their profiles. No errors.

- [ ] **Step 8: Run full compilation**

Run: `ops/compile-protocol.sh`
Expected: Creates `.claude/protocol/compiled/<agent-name>.protocol.md` for each agent. Verify one file manually (e.g., `head -20 .claude/protocol/compiled/product-owner.protocol.md`).

- [ ] **Step 9: Run verify**

Run: `ops/compile-protocol.sh --verify`
Expected: Exit 0, no drift.

- [ ] **Step 10: Commit**

```bash
git add ops/compile-protocol.sh ops/tests/test-compile-protocol.sh ops/tests/fixtures/agent-*.md .claude/protocol/compiled/
git commit -m "feat: add protocol compiler (ops/compile-protocol.sh)

Reads agent frontmatter, resolves protocol.profile and protocol.additional,
assembles base + profile + additional into per-agent compiled protocol
contexts. Supports --verify, --dry-run, --agent flags."
```

---

## Task 6: Add protocol.profile Frontmatter to All Agents

**Files:**

- Modify: `.claude/agents/product-owner.md`
- Modify: `.claude/agents/solution-architect.md`
- Modify: `.claude/agents/scrum-master.md`
- Modify: `.claude/agents/compliance-officer.md`
- Modify: `.claude/agents/ciso.md`
- Modify: `.claude/agents/ceo.md`
- Modify: `.claude/agents/cto.md`
- Modify: `.claude/agents/cfo.md`
- Modify: `.claude/agents/coo.md`
- Modify: `.claude/agents/cko.md`
- Modify: `.claude/agents/platform-ops.md`
- Modify: `.claude/agents/knowledge-ops.md`
- Modify: `.claude/agents/compliance-auditor.md`
- Modify: `templates/agents/backend-specialist.md`
- Modify: `templates/agents/frontend-specialist.md`
- Modify: `templates/agents/e2e-test-engineer.md`
- Modify: `templates/agents/infrastructure-ops.md`
- Modify: `templates/agents/security-reviewer.md`
- Modify: `templates/agents/cx-role.md`

- [ ] **Step 1: Add protocol frontmatter to triad agents**

For each of `product-owner.md`, `solution-architect.md`, `scrum-master.md`, add to the YAML frontmatter:

```yaml
protocol:
  profile: triad
```

Also remove the line `**Read `.claude/COLLABORATION.md` first**` (or equivalent) from the body — the compiler now handles protocol loading.

- [ ] **Step 2: Add protocol frontmatter to governance agents**

For each of `compliance-officer.md`, `ciso.md`, `ceo.md`, `cto.md`, `cfo.md`, `coo.md`, `cko.md`, add:

```yaml
protocol:
  profile: governance
```

Remove COLLABORATION.md read instructions from the body.

- [ ] **Step 3: Add protocol frontmatter to cross-cutting agents**

For `platform-ops.md`, `knowledge-ops.md`, `compliance-auditor.md`, add:

```yaml
protocol:
  profile: cross-cutting
```

Remove COLLABORATION.md read instructions from the body.

- [ ] **Step 4: Add protocol frontmatter to agent templates**

For specialist templates (`backend-specialist.md`, `frontend-specialist.md`, `e2e-test-engineer.md`, `infrastructure-ops.md`), add:

```yaml
protocol:
  profile: specialist
```

For `security-reviewer.md`, add:

```yaml
protocol:
  profile: cross-cutting
```

For `cx-role.md`, add:

```yaml
protocol:
  profile: governance
```

- [ ] **Step 5: Recompile and verify**

Run: `ops/compile-protocol.sh`
Run: `ops/compile-protocol.sh --verify`
Expected: Exit 0, all agents compile with correct profiles.

- [ ] **Step 6: Commit**

```bash
git add .claude/agents/*.md templates/agents/*.md
git commit -m "feat: add protocol.profile frontmatter to all agents

Triad: product-owner, solution-architect, scrum-master
Governance: compliance-officer, ciso, ceo, cto, cfo, coo, cko
Cross-cutting: platform-ops, knowledge-ops, compliance-auditor
Templates: specialist profile for domain agents, cross-cutting for
security-reviewer, governance for cx-role."
```

---

## Task 7: Add Protocol Change Governance Content

**Files:**

- Modify: `.claude/protocol/compliance-governance.md`
- Modify: `.claude/protocol/base.md`

The spec defines new governance content (SM as Protocol Guardian, Floor-Change Proposals, Pace Governs Escalation Autonomy) that doesn't exist in the current COLLABORATION.md. This must be written into the protocol files.

- [ ] **Step 1: Add Protocol Change Governance section to compliance-governance.md**

Append the following to `.claude/protocol/compliance-governance.md`:

```markdown
## Protocol Change Governance

### SM as Protocol Guardian

The Scrum Master owns protocol profiles and coordinates sub-file changes with these constraints:

- SM must not make or adopt changes that violate the compliance floor
- SM must not permit suggestions from any agent that would violate the floor to be adopted

### Floor-Change Proposals (SM as Filter)

When a suggestion requires a change to the compliance floor:

1. **SM evaluates:** Does this bring value? What risks does it introduce? Would the Cx executive team accept those risks? Are there mitigations that would make it acceptable?
2. **SM seeks triad consensus** (PO + SA + SM) on whether to escalate to the executive team
3. **Triad agrees** → SM checks pace (see below). If pace permits autonomous escalation, SM escalates to Cx executive team via the governance collaboration pattern. If pace requires user approval, SM presents the triad's recommendation to the user first.
4. **Triad disagrees** → User decides whether to escalate (at all paces)

### Pace Governs Escalation Autonomy

All protocol change escalation is subject to the current fleet pace:

| Pace      | Escalation Behavior                                                                                     |
| --------- | ------------------------------------------------------------------------------------------------------- |
| **Crawl** | All escalations require user approval before reaching the executive team. No autonomous escalation.     |
| **Walk**  | Standard flow: triad consensus gates escalation. User decides on triad disagreement.                    |
| **Run**   | Triad may escalate non-floor protocol changes autonomously. Floor changes still require user awareness. |
| **Fly**   | Triad may escalate autonomously. User is informed after the fact for non-floor changes.                 |

The compliance floor is never subject to autonomous change — even at Fly, floor changes require user approval per the existing compliance change control process.

### Non-Floor Protocol Changes

- **Sub-file content changes:** Domain owner makes the change, SM reviews for floor compliance
- **Profile restructuring** (what's inlined vs referenced): SM owns, CO reviews if compliance-relevant content is affected
- **Base.md changes:** CO is guardian, follows `/compliance propose`, user approval required
```

- [ ] **Step 2: Add ownership table to base.md**

Append to `.claude/protocol/base.md`:

```markdown
## Protocol Ownership

| Artifact                 | Owner                        | Change Control                                        |
| ------------------------ | ---------------------------- | ----------------------------------------------------- |
| `base.md`                | Compliance Officer           | `/compliance propose`, user approval required         |
| `profiles/*.md`          | Scrum Master                 | SM owns; CO reviews if compliance content is affected |
| Sub-files                | Domain owner of that content | Domain owner changes; SM reviews for floor compliance |
| `COLLABORATION.md` (hub) | Scrum Master                 | Updated when sub-files are added/removed              |

Full governance model: `.claude/protocol/compliance-governance.md` § Protocol Change Governance
```

- [ ] **Step 3: Recompile and verify**

Run: `ops/compile-protocol.sh`
Expected: All agents recompile with updated content.

- [ ] **Step 4: Commit**

```bash
git add .claude/protocol/compliance-governance.md .claude/protocol/base.md
git commit -m "feat: add protocol change governance and ownership model

New content from the spec: SM as protocol guardian, floor-change
proposal flow, pace-governed escalation autonomy table, ownership
table in base.md."
```

---

## Task 8: Update Cross-References (~33 files)

**Files:**

- Modify: `.claude/skills/deploy/SKILL.md`
- Modify: `.claude/skills/findings/SKILL.md`
- Modify: `.claude/skills/handoff/SKILL.md`
- Modify: `.claude/skills/onboard/SKILL.md`
- Modify: `.claude/skills/pace/SKILL.md`
- Modify: `.claude/skills/po/SKILL.md`
- Modify: `.claude/skills/retro/SKILL.md`
- Modify: `CLAUDE.md`
- Modify: `docs/GETTING-STARTED.md`
- Modify: `docs/AGENT-FLEET-PATTERN.md`
- Modify: `docs/COLLABORATION-MODEL.md`
- Modify: `.claude/compliance/targets.md`
- Modify: `.claude/DOCUMENTATION-STYLE.md`
- Modify: `templates/agents/cx-role.md`
- Modify: `ops/test-example.sh`
- Modify: `docs/plans/roadmap-index.md`
- Modify: `README.md`

Every reference to `.claude/COLLABORATION.md` or `COLLABORATION.md` gets rewritten to the specific sub-file.

- [ ] **Step 1: Find all references**

Run: `grep -rn 'COLLABORATION\.md' --include='*.md' --include='*.sh' --include='*.json' | grep -v 'protocol/\|specs/\|plans/'`

This shows every file that still points to the old monolith (excluding protocol sub-files, specs, and plans).

- [ ] **Step 2: Update skill files (7 files)**

For each skill, find lines referencing `COLLABORATION.md § <section>` and replace with the specific protocol sub-file path. Common patterns:

- `COLLABORATION.md § Work Item Lifecycle` → `.claude/protocol/lifecycle.md`
- `COLLABORATION.md § Pace Control` → `.claude/protocol/pace-control.md`
- `COLLABORATION.md § Compliance Floor` → `.claude/protocol/compliance-governance.md`
- `COLLABORATION.md § Handoff Protocol` → `.claude/protocol/handoffs.md`
- `COLLABORATION.md` (generic) → `.claude/protocol/base.md` or the most relevant sub-file

- [ ] **Step 3: Update CLAUDE.md**

Key changes:

- Directory structure section: add `protocol/` with brief description
- Commands section: add `compile-protocol.sh` commands
- Reference Documents: update COLLABORATION.md description to "Hub index (navigation only)"
- Add `.claude/protocol/base.md` as "Protocol base (universal agent rules)"
- Workflow section: update lifecycle reference

- [ ] **Step 4: Update docs/ files**

Update `GETTING-STARTED.md`, `AGENT-FLEET-PATTERN.md`, `COLLABORATION-MODEL.md` with new paths.

- [ ] **Step 5: Update remaining files**

Update `compliance/targets.md`, `DOCUMENTATION-STYLE.md`, `templates/agents/cx-role.md`, `ops/test-example.sh`, `docs/plans/roadmap-index.md`, `README.md`.

- [ ] **Step 6: Verify no stale references remain**

Run: `grep -rn 'COLLABORATION\.md' --include='*.md' --include='*.sh' --include='*.json' | grep -v 'protocol/\|specs/\|plans/\|COLLABORATION\.md:\|collab-sync-check\|settings\.json'`

Expected: Zero results. Note: `ops/hooks/collab-sync-check.sh` and `.claude/settings.json` are updated in Task 10, so they are excluded from this check.

- [ ] **Step 7: Commit**

```bash
git add .claude/skills/ CLAUDE.md docs/ .claude/compliance/ .claude/DOCUMENTATION-STYLE.md templates/ ops/test-example.sh README.md
git commit -m "refactor: update all cross-references from COLLABORATION.md to protocol/

Rewrite ~33 file references to point to specific protocol sub-files.
No file should reference the hub except for human navigation contexts."
```

---

## Task 9: Rewrite COLLABORATION.md as Hub Index

**Files:**

- Modify: `.claude/COLLABORATION.md`

**Note:** This task runs AFTER cross-reference updates (Task 8) to avoid a window where the monolith is gutted but references still point to it. If interrupted between Task 8 and Task 9, agents see the old monolith (safe) with updated references pointing to protocol/ (also safe since sub-files exist from Task 1).

- [ ] **Step 1: Replace COLLABORATION.md with hub content**

Replace the entire 792-line file with a ~50-line human-readable index:

```markdown
# Agent Collaboration Protocol

Universal rules for all agents in this fleet. This file is the navigation index — each section lives in `.claude/protocol/` for selective loading by the protocol compiler.

**Agents do not load this file.** Protocol content is compiled into agent contexts by `ops/compile-protocol.sh` based on each agent's `protocol.profile` frontmatter.

## Protocol Sections

### Tier 0: Universal Base

| File                        | Content                                            |
| --------------------------- | -------------------------------------------------- |
| [base.md](protocol/base.md) | Universal behavioral floor — loaded by every agent |

### Tier 1: Role Profiles

| File                                                   | Loaded By                                       | Content                                            |
| ------------------------------------------------------ | ----------------------------------------------- | -------------------------------------------------- |
| [triad.md](protocol/profiles/triad.md)                 | PO, SA, SM                                      | Handoff format, model tiering + references         |
| [governance.md](protocol/profiles/governance.md)       | CO, CISO, CEO, CTO, CFO, COO, CKO               | Escalation rules, governance pattern + references  |
| [specialist.md](protocol/profiles/specialist.md)       | App-defined specialists                         | Handoff format, branching conventions + references |
| [cross-cutting.md](protocol/profiles/cross-cutting.md) | Platform-ops, Knowledge-ops, Compliance-auditor | Handoff format + references                        |

### Tier 2: Topic Sub-Files

| File                                                          | Content                                                     |
| ------------------------------------------------------------- | ----------------------------------------------------------- |
| [ethos.md](protocol/ethos.md)                                 | Guiding ethos — 5 behavioral commitments                    |
| [resource-stewardship.md](protocol/resource-stewardship.md)   | Resource stewardship + budget management                    |
| [fleet-structure.md](protocol/fleet-structure.md)             | Agent tiers + triad collaboration dynamics                  |
| [pace-control.md](protocol/pace-control.md)                   | Pace definitions, rules, information needs                  |
| [principles.md](protocol/principles.md)                       | Core Principles 1-11 (full explanations)                    |
| [metrics.md](protocol/metrics.md)                             | DORA + flow quality + event logging table                   |
| [handoffs.md](protocol/handoffs.md)                           | Handoff protocol + completion format                        |
| [coordination.md](protocol/coordination.md)                   | Coordination architecture (working state vs published view) |
| [lifecycle.md](protocol/lifecycle.md)                         | 10-phase work item lifecycle + milestone release            |
| [deployment.md](protocol/deployment.md)                       | Deployment progression + failure handling                   |
| [regression.md](protocol/regression.md)                       | Periodic regression testing + screenshot evidence           |
| [branching.md](protocol/branching.md)                         | Branch lifecycle, PRs, environment discipline               |
| [compliance-governance.md](protocol/compliance-governance.md) | Compliance floor, hierarchy, governance collaboration       |
| [learning.md](protocol/learning.md)                           | Findings, learning collective, memory integration           |
| [escalation.md](protocol/escalation.md)                       | Conflict resolution, escalation rules, success criteria     |

## Ownership

See `.claude/protocol/base.md` § Protocol Ownership for the ownership table, and `.claude/protocol/compliance-governance.md` § Protocol Change Governance for the full governance model.

## Compilation

Run `ops/compile-protocol.sh` after modifying any protocol file. Run `ops/compile-protocol.sh --verify` to check for drift.
```

- [ ] **Step 2: Verify line count**

Run: `wc -l .claude/COLLABORATION.md`
Expected: ~50-55 lines.

- [ ] **Step 3: Commit**

```bash
git add .claude/COLLABORATION.md
git commit -m "feat: replace COLLABORATION.md with hub index

Replaces the 792-line monolithic protocol file with a ~50-line
navigation index. All protocol content now lives in .claude/protocol/
and is compiled into agent contexts by ops/compile-protocol.sh."
```

---

## Task 10: Rewrite collab-sync-check.sh Hook

**Files:**

- Modify: `ops/hooks/collab-sync-check.sh`
- Modify: `.claude/settings.json`

- [ ] **Step 1: Rewrite the hook**

The current hook warns about COLLABORATION.md ↔ COLLABORATION-MODEL.md sync. After the split:

- Protocol changes happen in `.claude/protocol/`
- The hook should warn when protocol files are edited without recompiling
- It should also check if COLLABORATION-MODEL.md needs updating when protocol files change

```bash
#!/usr/bin/env bash
# PostToolUse hook: warns when protocol files are edited without recompiling.
# Advisory only (always exits 0).

FILE="$CLAUDE_FILE_PATH"

# Only fire for protocol-related files
case "$FILE" in
  *.claude/protocol/*.md|*COLLABORATION-MODEL.md)
    ;;
  *)
    exit 0
    ;;
esac

# If a protocol source file was edited, remind to recompile
if echo "$FILE" | grep -q '.claude/protocol/'; then
  echo "[PROTOCOL-SYNC] You edited a protocol file. Run ops/compile-protocol.sh to recompile agent contexts."

  # Also check if COLLABORATION-MODEL.md might need updating
  echo "[PROTOCOL-SYNC] Check if docs/COLLABORATION-MODEL.md needs a matching update."
fi

# If COLLABORATION-MODEL.md was edited, check if protocol files were also touched
if echo "$FILE" | grep -q 'COLLABORATION-MODEL.md'; then
  TOUCHED=$(git diff --name-only 2>/dev/null; git diff --cached --name-only 2>/dev/null)
  if ! echo "$TOUCHED" | grep -q '.claude/protocol/'; then
    echo "[PROTOCOL-SYNC] You edited COLLABORATION-MODEL.md -- check if .claude/protocol/ files need a matching update."
  fi
fi

exit 0
```

- [ ] **Step 2: Add SessionStart drift check to settings.json**

Add a SessionStart hook that runs the protocol compiler verify:

```json
{
  "type": "command",
  "command": "[ -f .claude/protocol/compiled/manifest.sha256 ] && { ops/compile-protocol.sh --verify >/dev/null 2>&1 && echo '[PROTOCOL] Protocol artifacts in sync.' || echo '[PROTOCOL] WARNING: Protocol sources changed but artifacts not recompiled. Run ops/compile-protocol.sh.'; } || true"
}
```

Add this to the existing `SessionStart` hooks array in `settings.json`.

**Important:** Use the Write tool (full rewrite) for settings.json, not Edit — per CLAUDE.md gotchas about JSON validation failures with partial edits.

- [ ] **Step 3: Test the hook**

Run: `echo "test" >> .claude/protocol/base.md && bash ops/hooks/collab-sync-check.sh`
Expected: Warning about recompilation.

Run: `git checkout .claude/protocol/base.md` to undo test change.

- [ ] **Step 4: Commit**

```bash
git add ops/hooks/collab-sync-check.sh .claude/settings.json
git commit -m "feat: update hooks for protocol/ directory structure

Rewrite collab-sync-check.sh to monitor .claude/protocol/ files
and remind to recompile. Add SessionStart drift check for protocol
compiler artifacts."
```

---

## Task 11: Remove Deferred Concern #3 and Final Validation

**Files:**

- Modify: `.claude/protocol/escalation.md` (remove deferred concern #3)

- [ ] **Step 1: Remove deferred concern #3 from escalation.md**

In `.claude/protocol/escalation.md`, find the deferred concerns table and remove row #3 ("COLLABORATION.md length approaching readability limit"). This concern is now resolved.

- [ ] **Step 2: Run full compilation**

```bash
ops/compile-protocol.sh
ops/compile-protocol.sh --verify
```

Expected: Exit 0, all agents compile, no drift.

- [ ] **Step 3: Run compliance compiler to verify no regression**

```bash
bash ops/tests/test-compile-floor.sh
```

Expected: All tests pass.

- [ ] **Step 4: Run protocol compiler tests**

```bash
bash ops/tests/test-compile-protocol.sh
```

Expected: All tests pass.

- [ ] **Step 5: Verify no stale references**

```bash
grep -rn 'COLLABORATION\.md' --include='*.md' --include='*.sh' --include='*.json' | grep -v 'protocol/\|specs/\|plans/\|node_modules\|COLLABORATION\.md:'
```

Expected: Zero results.

- [ ] **Step 6: Verify content coverage**

```bash
# Original non-blank non-heading content lines
wc -l .claude/protocol/*.md .claude/protocol/profiles/*.md .claude/protocol/base.md
```

Verify total is in the ~1050-1100 range per spec.

- [ ] **Step 7: Commit**

```bash
git add .claude/protocol/escalation.md
git commit -m "chore: remove deferred concern #3 (COLLABORATION.md length)

Resolved by the protocol split. The monolithic 792-line file is now
15 sub-files + 4 profiles + base + hub, with ~80-85% context savings
per agent."
```

- [ ] **Step 8: Final syntax check**

```bash
bash -n ops/compile-protocol.sh
bash -n ops/lib/compiler-utils.sh
bash -n ops/hooks/collab-sync-check.sh
```

Expected: All pass (no syntax errors).
