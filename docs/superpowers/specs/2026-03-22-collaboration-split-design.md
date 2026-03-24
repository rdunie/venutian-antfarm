# COLLABORATION.md Split Design

**Date:** 2026-03-22
**Status:** Draft
**Item:** #8 — COLLABORATION.md length

## Problem

COLLABORATION.md is 792 lines. Every agent loads the full file but only needs a fraction of it. The file is referenced by 35 other files across the framework. This creates three problems in priority order:

1. **Agent context window inefficiency** — agents consume ~12K tokens of protocol content they don't need
2. **Maintainability** — changes to one section require reasoning about the whole file; ownership boundaries are implicit
3. **Human readability** — navigating and understanding the protocol requires reading a single monolithic document

## Solution

Split COLLABORATION.md into `.claude/protocol/` with a three-tier loading model. COLLABORATION.md becomes a human-readable index. Agents load only what they need through a base file, role profiles, and on-demand sub-files.

## Directory Structure

```
.claude/
  COLLABORATION.md                    # Human-readable index (~50 lines)
  protocol/
    base.md                           # Tier 0: universal behavioral floor (~70-80 lines)
    profiles/
      triad.md                        # Tier 1: PO, SA, SM (~60-80 lines)
      governance.md                   # Tier 1: Cx roles (~40-60 lines)
      specialist.md                   # Tier 1: domain specialists (~40-60 lines)
      cross-cutting.md                # Tier 1: platform-ops, knowledge-ops, auditor (~40-60 lines)
    ethos.md                          # Tier 2: full guiding ethos
    resource-stewardship.md           # Tier 2: full resource stewardship + budget table
    fleet-structure.md                # Tier 2: agent tiers + triad dynamics
    pace-control.md                   # Tier 2: pace definitions, rules, info needs
    principles.md                     # Tier 2: core principles 1-11
    metrics.md                        # Tier 2: DORA + flow quality + event logging table
    handoffs.md                       # Tier 2: handoff protocol + completion format
    coordination.md                   # Tier 2: coordination architecture (working state vs published view)
    lifecycle.md                      # Tier 2: 10-phase lifecycle + ad-hoc item rule + milestone release
    deployment.md                     # Tier 2: deployment progression + failures + acceptance failure
    regression.md                     # Tier 2: periodic regression testing + screenshot evidence
    branching.md                      # Tier 2: branch lifecycle, PRs, env discipline, fix ownership
    compliance-governance.md          # Tier 2: floor, hierarchy, governance pattern, CEO pace, Cx memory
    learning.md                       # Tier 2: findings, learning collective, memory integration, knowledge distribution
    escalation.md                     # Tier 2: conflict resolution, escalation rules, success criteria, deferred concerns
```

## Three-Tier Loading Model

### Tier 0: Base File (`base.md`)

Loaded unconditionally for every agent. Not configurable — no agent (harness or app-level) can override or exclude it.

Contains condensed versions of:

- **Guiding Ethos** (~10 lines) — the 5 behavioral commitments (own your work, act ethically, value transparency, pursue quality, deliver value)
- **Core Principles** (~20 lines) — principle names + one-line summaries; full explanations in `protocol/principles.md`
- **Autonomy model** (~10 lines) — 3-tier table + "default when uncertain: Propose"
- **Compliance floor is sacred** (~5 lines) — floor rules override everything
- **Resource stewardship** (~5 lines) — "choose the cheapest effective approach"
- **Separation of duties** (~5 lines) — "request, don't reach" + domain ownership
- **Documentation currency** (~5 lines) — the rule, not the exceptions

**Target: ~70-80 lines.** Roughly 10% of the original file.

**Deliberately excluded from base:** fleet structure (agents know their own tier), handoff format (goes in profiles), metrics/DORA (operational detail), lifecycle phases (triad/specialist concern), regression testing (specialist concern).

### Tier 1: Role Profiles (`profiles/`)

Hybrid files that inline small content (<~20 lines) and reference larger sub-files. Each profile is tailored to a category of agent.

**How references work:** References in profile files are markdown links of the form `See [Topic](../sub-file.md)`. Agents read the linked file when the current task requires that topic. There is no automated resolution — agents exercise judgment about when to load a referenced sub-file based on the task at hand.

**`profiles/triad.md`** — loaded by: product-owner, solution-architect, scrum-master

- Inlines: handoff format (~25 lines), model tiering table (~15 lines)
- References: lifecycle, deployment, metrics, pace-control, branching, regression, fleet-structure, learning, coordination

**`profiles/governance.md`** — loaded by: compliance-officer, ciso, ceo, cto, cfo, coo, cko

- Inlines: escalation rules table (~10 lines), governance collaboration pattern summary (~15 lines)
- References: compliance-governance, metrics, pace-control, fleet-structure, learning, escalation

**`profiles/specialist.md`** — loaded by: app-defined domain specialists (no harness agents use this profile; it exists for project-level agents defined via templates)

- Inlines: handoff format (~25 lines), branching conventions (~15 lines)
- References: lifecycle, deployment, regression, metrics

**`profiles/cross-cutting.md`** — loaded by: platform-ops, knowledge-ops, compliance-auditor

- Inlines: handoff format (~25 lines)
- References: metrics, compliance-governance, learning, lifecycle

**Template-only agents** (e.g., security-reviewer) do not have harness agent definitions. App-defined agents based on templates should declare `protocol.profile` in their frontmatter. Harness templates will include the appropriate default (e.g., `protocol.profile: cross-cutting` for security-reviewer).

**Output agents** (doc-quality, training-enablement, stakeholder-comms) are defined per-project. They should use `protocol.profile: specialist` unless a project creates a dedicated output profile. Output agents primarily consume documentation, so the specialist profile (with lifecycle and deployment references) provides sufficient context.

**Duplication note:** Handoff format appears in 3 profiles. This is intentional under the "agent reliability" DRY exception — it's small (~25 lines) and critical to get right. The standalone `handoffs.md` sub-file exists as the source of truth for the handoff format — profiles inline a copy for context efficiency, and `handoffs.md` is the canonical reference when the format is updated.

**Unreferenced sub-files:** `ethos.md`, `resource-stewardship.md`, and `principles.md` are not referenced by any profile because their content is condensed in `base.md`. The full versions exist as reference material, loadable via `protocol.additional` when an agent needs the complete text.

### Tier 2: Sub-Files (15 files)

Each sub-file covers one cohesive topic. Available for on-demand loading via profile references or `protocol.additional` in agent frontmatter.

| File                       | ~Lines | Content                                                                                     |
| -------------------------- | ------ | ------------------------------------------------------------------------------------------- |
| `ethos.md`                 | 18     | Full guiding ethos                                                                          |
| `resource-stewardship.md`  | 27     | Resource stewardship + budget management table                                              |
| `fleet-structure.md`       | 70     | All 4 agent tiers + triad collaboration dynamics                                            |
| `pace-control.md`          | 40     | Pace definitions, rules, information needs tracker                                          |
| `principles.md`            | 100    | Core Principles 1-11 (full explanations)                                                    |
| `metrics.md`               | 40     | DORA + flow quality metrics + "who logs what" event table                                   |
| `handoffs.md`              | 25     | Handoff protocol + completion format                                                        |
| `coordination.md`          | 25     | Two-layer coordination architecture (working state vs published view), write-lock awareness |
| `lifecycle.md`             | 55     | 10-phase lifecycle table + ad-hoc item rule + milestone release dispatch                    |
| `deployment.md`            | 50     | Deployment progression, deployment failures, acceptance failure                             |
| `regression.md`            | 60     | Periodic regression testing, screenshot evidence, scope monitoring                          |
| `branching.md`             | 35     | Branch lifecycle, PR-native code review, environment discipline, fix ownership              |
| `compliance-governance.md` | 90     | Compliance floor, hierarchy, governance collaboration, CEO pace, Cx memory                  |
| `learning.md`              | 70     | Findings, learning collective, suggestions, memory integration, knowledge distribution      |
| `escalation.md`            | 30     | Conflict resolution, escalation rules, success criteria, deferred concerns                  |

## Protocol Compiler

Protocol loading is enforced by a **compile step**, not runtime agent self-loading. This ensures consistent behavior — agents cannot forget, skip, or selectively load protocol content.

### How It Works

The protocol compiler reads agent frontmatter, resolves the protocol dependency chain, and produces compiled protocol blocks that are baked into each agent's context at dispatch time.

```
Source (maintained in protocol/):
  base.md + profiles/triad.md + sub-files

Agent frontmatter (compiler input):
  protocol.profile: triad
  protocol.additional: [regression]

Compiler resolves:
  1. base.md (always)
  2. triad.md inlined content
  3. regression.md (from additional)

Output (what agent sees):
  Compiled protocol block in agent context
```

**Tier 0 (base) and Tier 1 (profile inlines) are compiled into the agent's context.** The agent receives them automatically — no self-loading, no judgment calls, no opt-out.

**Tier 2 (sub-files referenced by profiles) remain on-demand.** The profile's reference list is included in the compiled output as a "load when needed" index. The agent reads these via the Read tool when a task requires them.

### Agent Frontmatter

Agents declare protocol dependencies via a `protocol` frontmatter field:

```yaml
---
name: product-owner
protocol:
  profile: triad
---
```

**Rules:**

- Every agent implicitly includes `base.md`. No opt-out. The compiler enforces this regardless of what the frontmatter says.
- `protocol.profile` selects which profile to compile. Inheritable, overridable.
- `protocol.additional` adds extra sub-files compiled into context beyond what the profile provides. Inheritable, overridable.
- `protocol.exclude` is **not supported**. You can swap profiles or add files, never remove base or subtract from a profile.

**Inheritance:** Follows the existing agent inheritance mechanism. If an app agent doesn't declare `protocol`, it inherits from the harness agent. If it declares `protocol`, it overrides at the field level:

- `protocol.profile` uses **replace** semantics — declaring it replaces the inherited profile entirely.
- `protocol.additional` uses **replace** semantics — declaring it replaces the inherited list entirely. To extend the inherited list, the app agent must include all desired entries (inherited + new).

This is consistent with the existing "app fields override harness fields of the same name" rule. No merge semantics are introduced.

```yaml
---
extends: harness/scrum-master
protocol:
  additional:
    - regression # SM doesn't normally load this, but this project needs it
    # If harness SM had additional entries, they must be re-listed here
---
```

### Compiler Properties

The protocol compiler follows the same design principles as the compliance compiler:

- **Documented controls** — protocol rules are authored as human-readable markdown in `protocol/`, reviewable and auditable
- **Programmatic enforcement** — the compiler produces the compiled output; agents do not self-assemble their protocol context
- **Auditable** — `--verify` flag checks that compiled outputs match current sources. Drift between source and compiled output is detectable.
- **Observable** — compilation logs which sources were included for each agent, enabling tracing of what protocol content each agent received
- **Idempotent** — running the compiler twice produces identical output
- **Dry-run capable** — `--dry-run` shows what would be compiled without writing

### Compiler Architecture

Two separate compilers with a shared utility library. Each compiler does one thing well; the shared library provides a well-defined API for the common mechanics.

```
ops/
  lib/
    compiler-utils.sh         # Shared API — frontmatter, verify, dry-run, logging
  compile-floor.sh            # Compliance compiler (enforcement blocks, hooks, auditor rules)
  compile-protocol.sh         # Protocol compiler (agent context assembly)
```

**Rationale:** The compliance compiler produces _enforcement artifacts_ (hooks, auditor rules). The protocol compiler produces _context artifacts_ (what agents see at dispatch). These are different enough in output to warrant separate tools, but similar enough in mechanics to share infrastructure.

### Shared Utility API (`ops/lib/compiler-utils.sh`)

The shared library is extracted from proven code in the existing `compile-floor.sh`. It provides a small, stable API that both compilers (and future compilers from implementers) can source.

**Extracted from existing compiler (~200 lines):**

| Function                                                | Source                                    | Purpose                                                   |
| ------------------------------------------------------- | ----------------------------------------- | --------------------------------------------------------- |
| `generate_manifest <source> <output_dir> [proposal_id]` | `compile-floor.sh:generate_manifest`      | SHA256 manifest of source + artifacts for drift detection |
| `verify_manifest <source> <output_dir>`                 | `compile-floor.sh:verify_manifest`        | Compare current hashes against recorded manifest          |
| `compile_log <event> [args]`                            | `compile-floor.sh:log_violation/log_pass` | Structured logging (integrates with `metrics-log.sh`)     |
| `emit_header <compiler_name> <source_files>`            | Pattern from `generate_prose`             | Standard "GENERATED by X from Y" traceability header      |

**New (required by protocol compiler, not in existing compiler):**

| Function                           | Purpose                                                                                                                               |
| ---------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------- |
| `parse_frontmatter <file> <field>` | Extract a YAML frontmatter field from a markdown file (new capability — existing compiler parses enforcement fences, not frontmatter) |

**Standardized patterns (not functions, but conventions both compilers follow):**

- Arg parsing: `--dry-run`, `--verify` flags with consistent semantics
- Mode dispatch: single `dispatch()` entry point routing to mode-specific functions
- Exit codes: 0 = success, 1 = drift/failure, 2 = validation error

**Design principles:**

- **Small API surface** — only extract what both compilers actually need. The shared library is ~5 functions, not a framework.
- **Shell functions, not a framework** — compilers `source ops/lib/compiler-utils.sh` and call functions. No plugin architecture, no registration, no lifecycle hooks.
- **Implementer-extensible** — an implementer adding a third compiler (e.g., for custom policy enforcement) sources the same library and gets manifest/verify/logging for free.
- **Each compiler owns its own logic** — the library handles plumbing (manifests, verification, logging). Each compiler handles its domain (what to compile, how to assemble, where to write).
- **Extracted, not invented** — shared functions come from working code in the existing compliance compiler, not speculative design.

### Protocol Compiler (`ops/compile-protocol.sh`)

```bash
ops/compile-protocol.sh                    # Compile all agent protocol contexts
ops/compile-protocol.sh --verify           # Check compiled outputs match sources
ops/compile-protocol.sh --dry-run          # Show what would be compiled
ops/compile-protocol.sh --agent <name>     # Compile for a single agent
```

**Compilation flow:**

1. Read each agent's frontmatter → extract `protocol.profile` and `protocol.additional`
2. Resolve inheritance chain (app agent → harness agent) for protocol fields
3. Assemble: `base.md` (always) + profile inlined content + additional sub-files
4. Write compiled protocol block with traceability header (source files, timestamp, compiler version)
5. Include Tier 2 reference index (list of on-demand sub-files from profile references)

**Output location:** Compiled protocol blocks are written alongside agent definitions or to a designated output directory. The exact location is an implementation decision.

### Compliance Compiler Updates

The existing `ops/compile-floor.sh` is refactored to source `ops/lib/compiler-utils.sh` for shared functions. No functional changes to compliance compilation — this is a mechanical refactor to extract the shared API.

### Future Consideration: gomplate

[gomplate](https://github.com/hairyhenderson/gomplate) (v5.0.0, MIT, 10 years old, actively maintained) is a single-binary Go template engine with native YAML datasource support, file `include` directives, and batch directory processing.

**When to adopt:** If the protocol compiler grows beyond simple concatenation — specifically if implementers need conditional includes, template logic in profiles, or multi-project compilation. gomplate would make profiles into real templates with `{{ include }}` and agent frontmatter as a datasource.

**Not adopted initially because:** The core compilation logic is ~40 lines of bash with `yq` + `cat`. gomplate is more powerful than needed today, and adding a dependency should be justified by complexity, not anticipated complexity.

**Compliance compiler simplification:** Separately evaluate whether gomplate could simplify `compile-floor.sh` (1429 lines). The natural trigger is the shared utility extraction — at that point, assess whether the remaining floor-specific generation (~1000 lines of enforcement blocks, hook scripts, semgrep/eslint rules) benefits from a templating engine. This is a separate work item, not part of this spec.

## Hub File (COLLABORATION.md)

COLLABORATION.md becomes a ~50-line human-readable index. It contains:

- Opening paragraph (source of truth declaration)
- Table mapping each sub-file to a one-line summary
- Note that agents should load protocol files directly, not this hub

No protocol content lives in the hub. Agents never load it — they go through `base.md` + profile. The hub is optimized for human navigation.

## Cross-Reference Migration

All files that currently reference COLLABORATION.md (~33 files, excluding self-references) are updated to point to specific sub-files:

- **Agent definitions (13 files):** Add `protocol.profile` frontmatter. Rewrite prose references to specific sub-files.
- **Skills (7 files):** Rewrite section references to sub-file paths.
- **CLAUDE.md:** Update directory structure, reference documents, workflow lifecycle reference.
- **docs/ files (3 files):** `GETTING-STARTED.md`, `AGENT-FLEET-PATTERN.md`, `COLLABORATION-MODEL.md` update cross-links.
- **Other (9 files):** `settings.json`, templates, `compliance/targets.md`, `DOCUMENTATION-STYLE.md` update references. `ops/hooks/collab-sync-check.sh` is rewritten or replaced to verify protocol compilation output instead of checking the monolithic file.

**Migration rule:** Every reference becomes a direct link to the most specific sub-file. No reference should point to the hub. Upon completion, deferred concern #3 (COLLABORATION.md length) is removed as resolved.

## Ownership Model

| Artifact                    | Owner                        | Change Control                                                          |
| --------------------------- | ---------------------------- | ----------------------------------------------------------------------- |
| `base.md`                   | Compliance Officer           | Same as compliance floor: `/compliance propose`, user approval required |
| `profiles/*.md`             | Scrum Master                 | SM owns; CO reviews if compliance-relevant content is affected          |
| `protocol/*.md` (sub-files) | Domain owner of that content | Domain owner makes changes; SM reviews for floor compliance             |
| `COLLABORATION.md` (hub)    | Scrum Master                 | Maintenance — updated when sub-files are added/removed                  |

## Protocol Change Governance

### SM as Protocol Guardian

The Scrum Master owns protocol profiles and coordinates sub-file changes with these constraints:

- SM must not make or adopt changes that violate the compliance floor
- SM must not permit suggestions from any agent that would violate the floor to be adopted

### Floor-Change Proposals (SM as Filter)

When a suggestion requires a change to the compliance floor:

1. **SM evaluates:** Does this bring value? What risks does it introduce? Would the Cx executive team accept those risks? Are there mitigations that would make it acceptable?
2. **SM seeks triad consensus** (PO + SA + SM) on whether to escalate to the executive team
3. **Triad agrees** → SM checks pace (see Pace Governs Escalation Autonomy below). If pace permits autonomous escalation, SM escalates to Cx executive team via the existing governance collaboration pattern. If pace requires user approval, SM presents the triad's recommendation to the user first.
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

## Context Savings Estimate

| Agent Type          | Before (tokens)     | After (tokens)          | Savings |
| ------------------- | ------------------- | ----------------------- | ------- |
| Triad agent         | ~12,300 (full file) | ~2,500 (base + profile) | ~80%    |
| Governance agent    | ~12,300             | ~2,000 (base + profile) | ~84%    |
| Specialist agent    | ~12,300             | ~1,800 (base + profile) | ~85%    |
| Cross-cutting agent | ~12,300             | ~1,700 (base + profile) | ~86%    |

Sub-files loaded on-demand add ~200-800 tokens each, only when needed for the current task.

## Line Count Expansion

The split intentionally increases the total line count from ~792 to ~1050-1100 lines across all files. This expansion comes from:

- Condensed summaries in `base.md` that duplicate sub-file content at a higher level
- Handoff format inlined in 3 profiles (~50 extra lines)
- File headers, frontmatter, and navigation links in each sub-file

This tradeoff is acceptable because no single agent loads more than ~20% of the total. The metric that matters is per-agent token cost, not total line count across all files.

## Content Validation

During migration, every line of the original 792-line COLLABORATION.md must end up in exactly one sub-file (or in condensed form in `base.md`). Validation approach:

- **Line-level coverage check:** Script that maps each non-blank, non-heading line in the original to its destination sub-file. Any unmapped line is a gap.
- **Compiler verify:** After initial compilation, `--verify` confirms compiled outputs match sources. This becomes the ongoing drift check.
- **Agent smoke test:** Dispatch each agent type with a protocol-awareness prompt ("What protocol sections do you have access to?") and verify the response matches expectations.

## Implementation Notes

Implementation ordering, phasing strategy, validation approach, and rollback plan are outside the scope of this spec and will be defined in the implementation plan. The spec defines the target state; the plan defines how to get there.
