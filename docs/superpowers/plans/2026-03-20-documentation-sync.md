# Documentation Sync Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Update all stale documentation and diagrams to reflect the current framework state: 13 core agents (7 governance + 6 operational), knowledge-ops rename, governance tier, compliance hierarchy, new skills, and tier-based color system.

**Architecture:** Update 5 stale doc files, 1 example config, and 1 style guide. Introduce layered diagram approach with 6-color tier-based palette. Add table of contents to COLLABORATION-MODEL.md.

**Tech Stack:** Markdown (docs, diagrams), JSON (example/fleet-config.json), Mermaid (diagrams).

**Spec:** `docs/superpowers/specs/2026-03-20-documentation-sync-design.md`

---

## File Structure

| File                             | What Changes                                                                                                            |
| -------------------------------- | ----------------------------------------------------------------------------------------------------------------------- |
| `.claude/DOCUMENTATION-STYLE.md` | Replace 5-color semantic palette with 6-color tier-based system                                                         |
| `docs/GETTING-STARTED.md`        | Agent count, skills list, learning loop, governance onboarding                                                          |
| `docs/COLLABORATION-MODEL.md`    | Rename memory-manager, restructure Fleet Structure diagram, add 3 governance diagrams, TOC, orienting text, tier colors |
| `docs/AGENT-FLEET-PATTERN.md`    | Rename Memory Manager, add governance tier, update counts and colors                                                    |
| `example/README.md`              | Agent count                                                                                                             |
| `example/fleet-config.json`      | Rename, add governance roster/pathways/knowledge cadence, add compliance-auditor                                        |

---

## Task 1: Update DOCUMENTATION-STYLE.md Color System

**Files:**

- Modify: `.claude/DOCUMENTATION-STYLE.md`

- [ ] **Step 1: Read the current file**

Read `.claude/DOCUMENTATION-STYLE.md` to find the existing color palette section.

- [ ] **Step 2: Replace the color palette**

Replace the existing 5-color semantic palette with the 6-color tier-based system:

| Color  | Tier              | Used For                                      | Fill      | Stroke    |
| ------ | ----------------- | --------------------------------------------- | --------- | --------- |
| Purple | Governance        | CO, CISO, CEO, CTO, CFO, COO, CKO             | `#ce93d8` | `#6a1b9a` |
| Blue   | Harness (core)    | PO, SA, SM, knowledge-ops, platform-ops, User | `#90caf9` | `#1565c0` |
| Red    | Review/Compliance | Compliance-auditor, security-reviewer         | `#ef9a9a` | `#b71c1c` |
| Green  | Execution/Build   | App-defined specialists                       | `#a5d6a7` | `#2e7d32` |
| Orange | Output            | Output agents, deploy artifacts               | `#ffcc80` | `#e65100` |
| Gray   | Infrastructure    | Config files, metrics, governance files       | `#bdbdbd` | `#424242` |

Add after the table:

```markdown
### Tier Colors vs Agent Identity Colors

Diagrams use **tier colors** to show architecture (which tier does this agent belong to?). Agent frontmatter uses **identity colors** (unique per agent, for UI differentiation). These are separate systems — all governance agents are purple in diagrams regardless of their individual frontmatter color.

### Orienting Text

Each diagram should have a 1-2 sentence introduction that tells the reader: what this diagram shows, how it connects to adjacent diagrams, and what to look for.
```

- [ ] **Step 3: Commit**

```bash
git add .claude/DOCUMENTATION-STYLE.md
git commit -m "docs: replace color palette with 6-color tier-based system"
```

---

## Task 2: Update docs/GETTING-STARTED.md

**Files:**

- Modify: `docs/GETTING-STARTED.md`

- [ ] **Step 1: Read the file**

Read `docs/GETTING-STARTED.md` fully.

- [ ] **Step 2: Apply all updates**

1. Line 104: Change "The 6 core agents are ready:" to "The 13 core agents are ready (7 governance + 6 operational):" and list the governance agents (CO, CISO, CEO, CTO, CFO, COO, CKO) alongside the operational agents.

2. After the existing skills usage section (around line 106), add the new skills:
   - `/compliance` — compliance program management
   - `/governance` — executive governance operations
   - `/pace` — pace control
   - `/audit` — compliance audit
   - `/memory` — knowledge management
   - `/deploy` — deployment orchestration
   - `/findings` — findings register
   - `/handoff` — structured agent handoffs

3. Line 129: Update the learning loop description — SM triggers distribution, knowledge-ops executes under CKO direction (not SM distributing directly).

4. Line 138: Verify "11 core principles" count against current COLLABORATION.md. Update if different.

5. Line 140: Add a note that governance tier agents (CO, CISO at minimum) are active from the first session — the `/onboard` skill activates them during setup.

- [ ] **Step 3: Commit**

```bash
git add docs/GETTING-STARTED.md
git commit -m "docs: update GETTING-STARTED for 13 agents, governance tier, new skills"
```

---

## Task 3: Update docs/AGENT-FLEET-PATTERN.md

**Files:**

- Modify: `docs/AGENT-FLEET-PATTERN.md`

- [ ] **Step 1: Read the file**

Read `docs/AGENT-FLEET-PATTERN.md` fully to find all stale references.

- [ ] **Step 2: Rename Memory Manager → Knowledge Ops**

Replace "Memory Manager" with "Knowledge Ops" in:

- Line 37: Mermaid diagram node `MM["Memory Manager"]` → `MM["Knowledge Ops"]`
- Line 318: Worked example table "knowledge/memory manager" → "knowledge-ops"

- [ ] **Step 3: Add governance layer to Pattern Overview diagram**

In the Mermaid diagram (lines 31-66), add a Governance subgraph above the Harness layer with the 7 Cx roles. Apply purple styling. Keep the diagram compact — use abbreviated labels (CO, CISO, CEO, CTO, CFO, COO, CKO).

- [ ] **Step 4: Add Governance Tier section**

After the "When to Use This Pattern" section and before "Pattern Overview", add a section describing the governance tier and the Cx model. Reference the governance layer design spec for full detail. Keep concise — this is a pattern document, not a full spec.

- [ ] **Step 5: Update agent counts**

- Line 350: "Core agent definitions (6 files)" → "Core agent definitions (13 files)"
- Any other references to agent counts in the document

- [ ] **Step 6: Update diagram colors**

Apply the tier color system to all Mermaid diagrams in the file. Purple for governance nodes.

- [ ] **Step 7: Commit**

```bash
git add docs/AGENT-FLEET-PATTERN.md
git commit -m "docs: update AGENT-FLEET-PATTERN for governance tier, knowledge-ops rename"
```

---

## Task 4: Update docs/COLLABORATION-MODEL.md

**Files:**

- Modify: `docs/COLLABORATION-MODEL.md`

This is the largest task — the file has 16 Mermaid diagrams.

- [ ] **Step 1: Read the file**

Read `docs/COLLABORATION-MODEL.md` to identify all diagrams and stale references.

- [ ] **Step 2: Add table of contents**

Add a TOC at the top of the file (after the intro) listing all diagram sections for navigation. The file has 16+ diagrams — readers need a map.

- [ ] **Step 3: Rename memory-manager → knowledge-ops throughout**

Replace all occurrences:

- Line 19: "memory" in Reviewers node — restructure to remove knowledge-ops from the reviewer category (it's a harness operational agent)
- Line 259: `"memory-manager\ndistributes"` → `"knowledge-ops\ndistributes"`
- Line 441: "The memory-manager curates both" → "knowledge-ops curates both (under CKO direction)"
- Line 454: `MM(["Memory Manager"])` → `MM(["Knowledge Ops"])`
- Any other occurrences

- [ ] **Step 4: Restructure the Fleet Structure diagram**

The first diagram (lines 15-35) currently shows User → Strategic → Specialists/Reviewers. Add a Governance tier between User and Strategic. Apply tier colors. This is the first diagram readers see — it must reflect the current architecture.

- [ ] **Step 5: Add three governance tier diagrams**

Add after the existing Fleet Structure section:

1. **Governance Tier Detail** — 7 Cx roles with relationships (CO ↔ User, CEO ↔ User, All Cx ↔ CO, CISO→CO, CTO→SA, CFO→platform-ops, COO→SM, CKO→knowledge-ops). Add orienting text.

2. **Leadership + Operational Tier Detail** — triad + operational agents. Add orienting text.

3. **Governance ↔ Operational Bridge** — standards flowing down, data flowing up. Add orienting text.

- [ ] **Step 6: Add orienting text to existing diagrams**

For each existing diagram that lacks an intro sentence, add 1-2 sentences explaining what the diagram shows and how it connects to others.

- [ ] **Step 7: Apply tier color coding**

Update all Mermaid style lines to use the tier-based color system. Purple for governance, blue for harness core, green for specialists, red for review, orange for output, gray for infrastructure.

- [ ] **Step 8: Commit**

```bash
git add docs/COLLABORATION-MODEL.md
git commit -m "docs: add governance diagrams, TOC, knowledge-ops rename, tier colors to COLLABORATION-MODEL"
```

---

## Task 5: Update example/ Files

**Files:**

- Modify: `example/README.md`
- Modify: `example/fleet-config.json`

- [ ] **Step 1: Read both files**

Read `example/README.md` and `example/fleet-config.json`.

- [ ] **Step 2: Update example/README.md**

Line 34: Change "6 core agents" to "13 core agents".

- [ ] **Step 3: Update example/fleet-config.json**

1. Rename `"memory-manager"` to `"knowledge-ops"` in the core array
2. Add `"compliance-auditor"` to the core array (pre-existing gap)
3. Add `"governance": ["compliance-officer", "ciso", "ceo", "cto", "cfo", "coo", "cko"]` to the agents section
4. Add knowledge cadence config after retro section:
   ```json
   "knowledge": {
     "cadence": { "crawl": 1, "walk": 2, "run": 4, "fly": 0 },
     "note": "Items between knowledge distributions per pace. 0 = on-demand/retro only."
   }
   ```
5. Add governance pathways to pathways.declared

- [ ] **Step 4: Verify JSON**

Run: `python3 -c "import json; d=json.load(open('example/fleet-config.json')); print(len(d['agents']['governance']), 'governance agents')"`
Expected: `7 governance agents`

- [ ] **Step 5: Commit**

```bash
git add example/
git commit -m "docs: update example/ for 13 agents, governance roster, knowledge-ops rename"
```

---

## Task 6: Final Validation

- [ ] **Step 1: No stale memory-manager references in updated files**

Run: `grep -r 'memory-manager' docs/GETTING-STARTED.md docs/COLLABORATION-MODEL.md docs/AGENT-FLEET-PATTERN.md example/ .claude/DOCUMENTATION-STYLE.md`
Expected: No matches

- [ ] **Step 2: Governance tier present in key docs**

Run: `grep -c 'Governance' docs/GETTING-STARTED.md docs/COLLABORATION-MODEL.md docs/AGENT-FLEET-PATTERN.md`
Expected: At least 1 match per file

- [ ] **Step 3: Example fleet-config is valid JSON**

Run: `python3 -c "import json; d=json.load(open('example/fleet-config.json')); print('valid', len(d['agents']['governance']), 'governance')"`
Expected: `valid 7 governance`

- [ ] **Step 4: Color system documented**

Run: `grep -c 'Purple.*Governance' .claude/DOCUMENTATION-STYLE.md`
Expected: 1

- [ ] **Step 5: COLLABORATION-MODEL has TOC**

Run: `grep -c 'Table of Contents' docs/COLLABORATION-MODEL.md`
Expected: 1
