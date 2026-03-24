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

## Agent Frontmatter

Agents declare protocol loading via a new `protocol` frontmatter field:

```yaml
---
name: product-owner
protocol:
  profile: triad
---
```

**Loading order:**

1. `base.md` — always, not configurable
2. Profile file — from `protocol.profile` (inherited or overridden)
3. Additional files — from `protocol.additional` (inherited or overridden)

**Rules:**

- Every agent implicitly loads `base.md`. No opt-out.
- `protocol.profile` selects which profile to load. Inheritable, overridable.
- `protocol.additional` adds extra sub-files beyond what the profile references. Inheritable, overridable.
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
- **Other (9 files):** `settings.json`, `ops/hooks/collab-sync-check.sh`, templates, `compliance/targets.md`, `DOCUMENTATION-STYLE.md` update references.

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
3. **Triad agrees** → SM escalates to Cx executive team via the existing governance collaboration pattern (CO receives, consults Cx roles, consensus or user decides)
4. **Triad disagrees** → User decides whether to escalate

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

## Implementation Notes

Implementation ordering, phasing strategy, validation approach, and rollback plan are outside the scope of this spec and will be defined in the implementation plan. The spec defines the target state; the plan defines how to get there.
