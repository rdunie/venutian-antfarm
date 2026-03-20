# Documentation Sync

## Overview

Update all framework documentation and diagrams to reflect the current state: 13 core agents (7 governance + 6 operational), knowledge-ops (renamed from memory-manager), governance tier, PR branching strategy, compliance hierarchy, and all new skills. Introduce a layered diagram approach with consistent tier-based color coding.

## Stale Files

| File                          | What's Stale                                                           | Severity |
| ----------------------------- | ---------------------------------------------------------------------- | -------- |
| `docs/GETTING-STARTED.md`     | "6 core agents"                                                        | HIGH     |
| `docs/COLLABORATION-MODEL.md` | "memory-manager" in Mermaid diagrams + text, missing governance tier   | HIGH     |
| `docs/AGENT-FLEET-PATTERN.md` | No mention of governance tier or Cx model                              | MEDIUM   |
| `example/README.md`           | "6 core agents"                                                        | HIGH     |
| `example/fleet-config.json`   | "memory-manager", missing governance roster/pathways/knowledge cadence | HIGH     |

## What We Leave Alone

- `docs/superpowers/specs/` and `docs/superpowers/plans/` — historical documents reflecting the state at time of writing. Not updated.

## Color System

Every diagram across the framework uses tier-based colors for architecture visualization:

| Color  | Meaning              | Used For                                 | Fill      | Stroke    |
| ------ | -------------------- | ---------------------------------------- | --------- | --------- |
| Purple | Governance           | CO, CISO, CEO, CTO, CFO, COO, CKO        | `#ce93d8` | `#6a1b9a` |
| Blue   | Strategic/Leadership | PO, SA, SM, User                         | `#90caf9` | `#1565c0` |
| Green  | Execution/Build      | Specialists, knowledge-ops, platform-ops | `#a5d6a7` | `#2e7d32` |
| Red    | Review/Compliance    | Compliance-auditor, security-reviewer    | `#ef9a9a` | `#b71c1c` |
| Orange | Output               | Output agents, deploy artifacts          | `#ffcc80` | `#e65100` |
| Gray   | Infrastructure       | Config files, metrics, governance files  | `#bdbdbd` | `#424242` |

### Color System vs Agent Identity Colors

Diagrams use **tier colors** to communicate architecture (which tier does this agent belong to?). Agent frontmatter uses **identity colors** (unique per agent, for UI differentiation). These are separate systems:

- Diagram: all governance agents are purple, regardless of their identity color
- Frontmatter: CO is crimson, CISO is darkred, CEO is gold, etc.

Document this distinction in `.claude/DOCUMENTATION-STYLE.md`.

## Diagram Structure

### Orienting Text Pattern

Each diagram gets a 1-2 sentence intro that tells the reader: what this diagram shows, how it connects to adjacent diagrams, and what to look for. This orients the reader before they parse the visual.

### Overview Diagram (README.md)

Shows tiers as grouped boxes, not individual agents. Communicates authority flow:

```
User → Governance Layer (7 Cx roles) → Leadership Triad (PO, SA, SM) → Operational Layer → App Layer
```

The governance layer shows a summary label (e.g., "CO CISO CEO CTO CFO COO CKO") but as a compact group, not 7 separate nodes with edges. This keeps the overview scannable.

### Tier Detail Diagrams (COLLABORATION-MODEL.md)

Three focused diagrams, one per tier:

**1. Governance Tier Detail**

Shows the 7 Cx roles and their key relationships:

- CISO → CO (security controls for the floor)
- CTO → SA (technology direction)
- CFO → platform-ops (cost data interpretation)
- COO → SM (operational standards)
- CKO → knowledge-ops (distribution direction)
- CEO ↔ User (executive brief)
- All Cx → CO (floor rule proposals)

Orienting text: "The governance tier sets policy and standards. Each Cx role owns a domain and proposes controls to the CO for the compliance floor. The CEO is the user's proxy; the CO monitors all governance agents."

**2. Leadership + Operational Tier Detail**

The triad (PO, SA, SM) with their operational counterparts:

- PO orchestrates work items, dispatches specialists
- SA provides architecture guidance to specialists
- SM facilitates process, triggers knowledge distribution
- knowledge-ops executes under CKO direction
- platform-ops tracks metrics, manages CI/CD
- compliance-auditor reviews during Phase 4

Orienting text: "The leadership triad orchestrates day-to-day delivery. Operational agents execute within the standards set by governance. Specialists are defined per-project."

**3. Governance ↔ Operational Bridge**

How standards flow down and data flows up:

- Down: Cx roles → floor rules, targets, guidance → agents comply
- Up: metrics, findings, compliance reports → Cx roles interpret
- The CO is the gateway for floor/target changes
- The CKO is the gateway for knowledge distribution

Orienting text: "Governance sets the rules; operations follows them. Data flows up to inform governance decisions. The CO and CKO are the primary bridges."

### Flow Diagrams (COLLABORATION-MODEL.md)

Update existing flow diagrams:

- Rename memory-manager → knowledge-ops wherever it appears
- Add governance agents only to flows where they actively participate (compliance flow, security flow)
- Do not add governance agents to every flow — keep them focused

## File-by-File Changes

### docs/GETTING-STARTED.md

- Update "6 core agents" to "13 core agents (7 governance + 6 operational)"
- List the governance tier agents alongside the existing operational agents
- Add a note about the governance tier being active from the first session (onboarding activates CO + CISO)

### docs/COLLABORATION-MODEL.md

- Replace all "memory-manager" references with "knowledge-ops"
- Redesign the overview diagram using the layered approach
- Add the three tier detail diagrams
- Update existing flow diagrams for knowledge-ops rename
- Add orienting text before each diagram
- Apply consistent tier color coding

### docs/AGENT-FLEET-PATTERN.md

- Add a "Governance Tier" section describing the Cx model
- Reference the governance layer design for full detail
- Update agent counts in the pattern description

### example/README.md

- Update "6 core agents" reference
- Update any memory-manager references

### example/fleet-config.json

- Add governance roster (7 Cx roles)
- Rename memory-manager → knowledge-ops in core
- Add knowledge cadence config
- Add governance pathways

### .claude/DOCUMENTATION-STYLE.md

- Add the color system table
- Document the distinction between tier colors (diagrams) and identity colors (agent frontmatter)
- Add the orienting text pattern guidance
