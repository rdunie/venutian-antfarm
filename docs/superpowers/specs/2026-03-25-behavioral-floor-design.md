# Multi-Floor Governance — Generalized Behavioral Floors

**Issue:** [#29](https://github.com/rdunie/venutian-antfarm/issues/29)
**Date:** 2026-03-25
**Status:** Draft

## Problem

The compliance floor is a powerful pattern — declarative rules, compiler-generated enforcement, hook protection, checksum integrity, single guardian — but it's locked to a single domain (compliance). Other Cx domains (process quality, security, cost, technical standards) have no equivalent mechanism for defining non-negotiable rules with the same enforcement weight.

## Goals

1. **Generalize the floor pattern** so any Cx officer can own a governance floor with the same enforcement machinery.
2. **Ship two concrete instances** — compliance (CRO) and behavioral (COO) — while the pattern supports N floors.
3. **Rename Compliance Officer → Chief Risk Officer (CRO)** — the role expands from guarding one floor to facilitating risk assessment across all floors.
4. **Context-efficient consultation** — multi-round Cx consultations run as subagent dispatches so they don't pollute the main conversation context.

## Non-Goals

- Implementing floors beyond compliance and behavioral (future Cx officers add theirs when needed)
- Token optimization of the consultation process beyond subagent isolation (see #30)
- Multi-context orchestration (#21) — this spec works within the single-context model

## Design

### 1. Multi-Floor Model

The compliance floor becomes one instance of a general governance floor pattern. Any Cx officer can own a floor.

**V1 ships two floors:**

| Floor | File | Guardian | Domain |
|-------|------|----------|--------|
| Compliance | `floors/compliance.md` | CRO | Risk, regulatory, data governance |
| Behavioral | `floors/behavioral.md` | COO | Process quality, delivery standards, collaboration norms |

**Future candidates (pattern supports, not implemented):**

| Floor | Guardian | Domain |
|-------|----------|--------|
| Security | CISO | Security controls, threat posture |
| Technical | CTO | Architecture constraints, tech standards |
| Cost | CFO | Budget controls, efficiency requirements |

**Principles:**
- Each floor is a separate markdown file in `floors/`
- Each has one guardian (a Cx officer) with sole write authority
- All floors share the same enforcement weight — violations are blockers
- The existing three-tier hierarchy (Floor/Targets/Guidance) applies per domain
- `fleet-config.json` declares which floors are active and their guardians
- Adding a new floor is configuration, not code

### 2. CRO Rename and Role Evolution

The Compliance Officer becomes the **Chief Risk Officer (CRO)**.

**Role changes:**
- Still owns and guards the compliance floor specifically
- New responsibility: **Cross-Floor Risk Facilitation** — facilitates risk assessment across all floors when any floor change is proposed
- The CRO does not assess risk alone — they run the consultation where each Cx agent advocates for their domain
- The CRO synthesizes Cx positions into a consolidated risk assessment

**The floor guardian role:**

Each floor guardian (CRO for compliance, COO for behavioral):
- Has **sole write authority** to their floor file
- **Receives proposals** for changes to their floor
- **Classifies** proposals (Type 1: risk-reducing / Type 2: other / Type 3: new rule)
- **Requests CRO risk facilitation** before proceeding
- **Consults domain-relevant Cx roles** for impact assessment
- **Builds consensus** with impacted Cx roles
- **Monitors integrity** of their floor file (checksum verification on SessionStart)
- **Reverts unauthorized changes** and issues reprimands
- **Produces conformance reports** for their floor at retros

For compliance floor changes, the CRO is both guardian and risk facilitator.

### 3. Consultation Process

When a floor change is proposed:

1. **Floor guardian receives proposal**
2. **Guardian dispatches CRO as a subagent** with the proposal
3. **CRO subagent runs multi-round Cx consultation internally:**
   - CRO distributes proposal to all Cx agents
   - Round 1: Each Cx agent advocates their domain impact (impacted / not impacted / concerns)
   - CRO synthesizes — identifies conflicts, cross-domain interactions, open questions
   - Round N: If unresolved concerns or conflicts, CRO facilitates further rounds — Cx agents respond to each other's positions, refine assessments, surface new implications
   - CRO closes consultation when positions stabilize
4. **CRO subagent returns:** consolidated risk assessment, each Cx position, recommendation
5. **Only the compact result enters the main context** — round-by-round discussion stays in the subagent and is dropped
6. **Guardian presents to user** with full context (risk assessment, Cx positions, recommendation)

**Context efficiency:** The entire multi-round consultation is a single subagent dispatch. The main conversation context sees only: one dispatch + one structured result. This prevents governance chatter from displacing working context.

### 4. User Decision Handling

Three outcomes when the guardian presents a proposal to the user:

**Accept:** Guardian applies the change — sentinel file bypass, compiler re-run, checksum update, change log entry. Same mechanism as today's compliance floor.

**Modify:** The user suggests changes. This does not short-circuit the process:

1. User's suggested changes go back to the Cx team via a new CRO subagent dispatch
2. CRO facilitates a new consultation round with the user's input
3. Cx agents assess the modified proposal — they advocate their domains even when the user suggests changes (e.g., if the user's modification introduces a security risk, the CISO says so)
4. Multiple rounds until positions stabilize
5. Guardian presents the refined proposal back to the user with Cx assessment (risks, benefits, trade-offs)
6. Cycle repeats until the user accepts a version or declines

**Decline:** The proposal is not adopted, but:

1. Log the decision in the change log with the reason and context
2. Record as a **signal for future consideration** — not a blanket denial of similar proposals
3. The finding stays in the system so it can be resurfaced when context changes (e.g., "declined because mid-release, but the underlying concern is valid")
4. Future proposals in the same area should reference the prior decline and explain what changed

A decline means "not now" or "not this way" — not "never think about this again."

### 5. Compiler Generalization

The existing `compile-floor.sh` becomes floor-agnostic. The interface is already parameterized:

```bash
ops/compile-floor.sh [options] [floor-file] [output-dir]
```

**Changes:**
- Default floor file: read from `fleet-config.json` floors list (fall back to `floors/compliance.md`)
- Default output dir: derived from floor name (e.g., `floors/compliance.md` → `.claude/floors/compliance/compiled/`)
- New `--all` flag: compiles all active floors declared in `fleet-config.json`

**Compiled artifact layout:**
```
.claude/floors/
├── compliance/
│   ├── compiled/              # Output of compiling floors/compliance.md
│   └── floor-checksum.sha256
├── behavioral/
│   ├── compiled/              # Output of compiling floors/behavioral.md
│   └── floor-checksum.sha256
```

**Migration:** `compliance-floor.md` (at repo root) → `floors/compliance.md`. Existing implementers need a one-time migration (documented in release notes).

### 6. Fleet Config and Hook Changes

**`fleet-config.json` gains a `floors` section:**

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
}
```

Adding a new floor is config — declare it, assign a guardian, specify the compiled directory.

**Hook generalization:**
- **PreToolUse (Edit/Write):** Block edits to any `floors/*.md` unless the appropriate sentinel file exists (`.claude/floors/<name>/.applying`)
- **SessionStart:** Verify checksums for all active floors
- Hooks use glob patterns (`floors/*.md`) rather than hardcoded filenames

**Skill additions:**
- `/behavioral` skill — routes to COO (behavioral floor guardian), mirrors `/compliance` structure
- `/floor propose <floor-name>` — generic skill that routes to the declared guardian for any floor
- `/compliance` remains as a convenience alias

## File Inventory

### Renamed Files

| From | To |
|------|-----|
| `.claude/agents/compliance-officer.md` | `.claude/agents/cro.md` |

### New Files

| File | Purpose |
|------|---------|
| `floors/compliance.md` | Compliance floor (moved from root) |
| `templates/floors/behavioral.md` | Behavioral floor template |
| `templates/floors/compliance.md` | Compliance floor template (moved from `templates/compliance-floor.md`) |
| `.claude/skills/behavioral/SKILL.md` | `/behavioral` skill — routes to COO |
| `.claude/skills/floor/SKILL.md` | `/floor propose <name>` — generic floor skill |

### Modified Files

| File | Change |
|------|--------|
| `.claude/agents/cro.md` | Rename + cross-floor risk facilitation role |
| `.claude/agents/coo.md` | Add behavioral floor guardianship |
| `ops/compile-floor.sh` | Parameterize defaults from fleet-config, add `--all` flag |
| `ops/tests/test-compile-floor.sh` | Update tests for parameterized compiler |
| `templates/fleet-config.json` | Add `floors` section |
| `.claude/skills/onboard/SKILL.md` | Create `floors/` directory, per-floor scaffolding |
| `.claude/skills/compliance/SKILL.md` | Update CO → CRO references |
| `.claude/settings.json` | Generalize hooks from `compliance-floor.md` to `floors/*.md` |
| `CLAUDE.md` | Document multi-floor model, rename CO → CRO |
| `.claude/COLLABORATION.md` | Update Compliance Hierarchy → Governance Floors, CO → CRO |

### Deleted Files

| File | Reason |
|------|--------|
| `compliance-floor.md` (root) | Moved to `floors/compliance.md` |
| `templates/compliance-floor.md` | Moved to `templates/floors/compliance.md` |

### Not Changed

- CISO, CEO, CTO, CFO, CKO agents — already participate in consultation, no role change
- SM — process facilitation unchanged
- Rewards system — consumes floor signals, no change needed
- Compliance auditor — reads fleet-config to discover active floors, checks all of them

## Related Issues

- [#13](https://github.com/rdunie/venutian-antfarm/issues/13) — Rewards system (consumes floor signals)
- [#21](https://github.com/rdunie/venutian-antfarm/issues/21) — Multi-context orchestration (compiles + validates all floors on startup)
- [#22](https://github.com/rdunie/venutian-antfarm/issues/22) — Compiler simplification (natural pairing)
- [#25](https://github.com/rdunie/venutian-antfarm/issues/25) — Adaptive weighting (floor violations vs target misses)
- [#28](https://github.com/rdunie/venutian-antfarm/issues/28) — All agents deliver feedback with escalation chain
- [#30](https://github.com/rdunie/venutian-antfarm/issues/30) — Token-efficient consultation
