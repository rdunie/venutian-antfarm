# Documentation Sync

## Overview

Update all framework documentation and diagrams to reflect the current state: 13 core agents (7 governance + 6 operational), knowledge-ops (renamed from memory-manager), governance tier, compliance hierarchy, and all new skills. Introduce a layered diagram approach with consistent tier-based color coding.

## Stale Files

| File                          | What's Stale                                                                              | Severity |
| ----------------------------- | ----------------------------------------------------------------------------------------- | -------- |
| `docs/GETTING-STARTED.md`     | "6 core agents"                                                                           | HIGH     |
| `docs/COLLABORATION-MODEL.md` | "memory-manager" in Mermaid diagrams + text, missing governance tier                      | HIGH     |
| `docs/AGENT-FLEET-PATTERN.md` | "Memory Manager" in diagrams + worked example, missing governance tier, stale agent count | HIGH     |
| `example/README.md`           | "6 core agents"                                                                           | HIGH     |
| `example/fleet-config.json`   | "memory-manager", missing governance roster/pathways/knowledge cadence                    | HIGH     |

## What We Leave Alone

- `docs/superpowers/specs/` and `docs/superpowers/plans/` — historical documents reflecting the state at time of writing. Not updated.

## Color System

Every diagram across the framework uses tier-based colors for architecture visualization:

This replaces the existing 5-color semantic palette in `.claude/DOCUMENTATION-STYLE.md` with a 6-color tier-based system:

| Color  | Tier              | Used For                                      | Fill      | Stroke    |
| ------ | ----------------- | --------------------------------------------- | --------- | --------- |
| Purple | Governance        | CO, CISO, CEO, CTO, CFO, COO, CKO             | `#ce93d8` | `#6a1b9a` |
| Blue   | Harness (core)    | PO, SA, SM, knowledge-ops, platform-ops, User | `#90caf9` | `#1565c0` |
| Red    | Review/Compliance | Compliance-auditor, security-reviewer         | `#ef9a9a` | `#b71c1c` |
| Green  | Execution/Build   | App-defined specialists                       | `#a5d6a7` | `#2e7d32` |
| Orange | Output            | Output agents, deploy artifacts               | `#ffcc80` | `#e65100` |
| Gray   | Infrastructure    | Config files, metrics, governance files       | `#bdbdbd` | `#424242` |

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

- CO ↔ User (floor changes require user approval; CO reports conformance posture)
- CEO ↔ User (executive brief; all CEO decisions escalated at Crawl pace)
- All Cx ↔ CO (propose floor rules + targets; CO consults all Cx on changes for consensus)
- CISO → CO (security controls for the floor)
- CTO → SA (technology direction)
- CFO → platform-ops (cost data interpretation)
- COO → SM (operational standards)
- CKO → knowledge-ops (distribution direction)
- CO monitors CEO autonomy grants

Orienting text: "The governance tier sets policy and standards. The CO is the compliance floor guardian — all floor changes require user approval. Each Cx role proposes controls to the CO and participates in consensus when consulted. The CEO is the user's proxy and operates on an independent trust-based pace."

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

- Replace all "memory-manager" references with "knowledge-ops" (diagrams and text)
- Redesign the overview diagram using the layered approach
- Add the three tier detail diagrams (governance, leadership+operational, bridge)
- Update existing flow diagrams for knowledge-ops rename
- Add orienting text before each diagram
- Apply consistent tier color coding
- Add a table of contents at the top of the file for navigation (the file will have 17+ diagrams)

### docs/AGENT-FLEET-PATTERN.md

- Rename "Memory Manager" → "Knowledge Ops" in all Mermaid diagrams and the worked example table
- Add a "Governance Tier" section describing the Cx model
- Reference the governance layer design for full detail
- Update agent counts throughout (e.g., "Core agent definitions (6 files)" → 13)
- Update diagram color coding to match the tier color system

### example/README.md

- Update "6 core agents" reference
- Update any memory-manager references

### example/fleet-config.json

- Add governance roster (7 Cx roles)
- Rename memory-manager → knowledge-ops in core
- Add knowledge cadence config
- Add governance pathways

### .claude/DOCUMENTATION-STYLE.md

- Replace the existing 5-color semantic palette with the 6-color tier-based system
- Document the distinction between tier colors (diagrams) and identity colors (agent frontmatter)
- Add the orienting text pattern guidance
