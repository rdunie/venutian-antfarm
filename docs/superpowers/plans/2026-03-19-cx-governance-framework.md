# Cx Governance Framework Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add 5 new Cx governance agents (CEO, CTO, CFO, COO, CKO), fleet-wide guidance mechanism, executive brief, `/governance` skill, rename memory-manager to knowledge-ops, and update all framework docs.

**Architecture:** 5 new Opus/Sonnet agent definitions in `.claude/agents/`, governance infrastructure in `.claude/governance/`, a `/governance` skill for executive operations, 4 new metrics event types, and updates across COLLABORATION.md, README, CLAUDE.md, fleet-config, settings.json.

**Tech Stack:** Markdown (agents, skills, governance files), Bash (metrics-log.sh), JSON (settings.json, fleet-config.json).

**Spec:** `docs/superpowers/specs/2026-03-19-cx-governance-framework-design.md`

**Design principle:** Same as governance layer — communicate everything needed for fidelity with minimum tokens. Cross-reference COLLABORATION.md for shared protocol. Inline only what is unique to each agent.

---

## File Structure

### New Files

| File                                      | Responsibility                       |
| ----------------------------------------- | ------------------------------------ |
| `.claude/agents/ceo.md`                   | CEO agent definition                 |
| `.claude/agents/cto.md`                   | CTO agent definition                 |
| `.claude/agents/cfo.md`                   | CFO agent definition                 |
| `.claude/agents/coo.md`                   | COO agent definition                 |
| `.claude/agents/cko.md`                   | CKO agent definition                 |
| `.claude/agents/knowledge-ops.md`         | Renamed from memory-manager          |
| `.claude/governance/executive-brief.md`   | CEO-user collaboration document      |
| `.claude/governance/guidance-registry.md` | Fleet-wide guidance index            |
| `.claude/governance/guidance/.gitkeep`    | Guidance detail docs directory       |
| `.claude/governance/decisions/.gitkeep`   | Executive decision records directory |
| `.claude/skills/governance/SKILL.md`      | `/governance` skill                  |

### Modified Files

| File                                   | What Changes                                                                                                                                                   |
| -------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `.claude/agents/compliance-officer.md` | Add CEO autonomy monitoring                                                                                                                                    |
| `.claude/skills/memory/SKILL.md`       | Update references: memory-manager → knowledge-ops                                                                                                              |
| `.claude/COLLABORATION.md`             | Add guidance mechanism, update governance tier (7 Cx), add CEO pace, CKO/knowledge-ops, pace-based distribution cadence, rename memory-manager → knowledge-ops |
| `README.md`                            | Update architecture diagram (7 governance), agent table, rename                                                                                                |
| `CLAUDE.md`                            | Update agent count, directory structure, rename                                                                                                                |
| `templates/fleet-config.json`          | Add 5 Cx roles to governance, add knowledge config, rename in core                                                                                             |
| `templates/agents/cx-role.md`          | Make model-agnostic                                                                                                                                            |
| `.claude/settings.json`                | Update PreCompact context string                                                                                                                               |
| `ops/metrics-log.sh`                   | Add 4 new governance event types                                                                                                                               |

### Deleted Files

| File                               | Replaced By                       |
| ---------------------------------- | --------------------------------- |
| `.claude/agents/memory-manager.md` | `.claude/agents/knowledge-ops.md` |

---

## Task 1: Governance Directory Structure

**Files:**

- Create: `.claude/governance/executive-brief.md`
- Create: `.claude/governance/guidance-registry.md`
- Create: `.claude/governance/guidance/.gitkeep`
- Create: `.claude/governance/decisions/.gitkeep`

- [ ] **Step 1: Create directories**

Run: `mkdir -p .claude/governance/guidance .claude/governance/decisions`

- [ ] **Step 2: Create the executive brief**

Create `.claude/governance/executive-brief.md` with the structure from the spec: CEO Autonomy Grants table (empty), Pending Decisions section, In Progress section, Resolved section.

- [ ] **Step 3: Create the guidance registry**

Create `.claude/governance/guidance-registry.md` with header explaining the registry purpose, format instructions (title, Cx role, summary, relevance, optional detail link), and "(no guidance published yet)" placeholder.

- [ ] **Step 4: Create gitkeep files**

Run: `touch .claude/governance/guidance/.gitkeep .claude/governance/decisions/.gitkeep`

- [ ] **Step 5: Commit**

```bash
git add .claude/governance/
git commit -m "feat: add governance directory structure (executive brief, guidance registry)"
```

---

## Task 2: Rename memory-manager → knowledge-ops

**Files:**

- Delete: `.claude/agents/memory-manager.md`
- Create: `.claude/agents/knowledge-ops.md`
- Modify: `.claude/skills/memory/SKILL.md`

Do the rename first because many subsequent tasks reference knowledge-ops.

- [ ] **Step 1: Read the current memory-manager agent**

Read `.claude/agents/memory-manager.md`.

- [ ] **Step 2: Create knowledge-ops agent**

Create `.claude/agents/knowledge-ops.md` with the same content as memory-manager.md but:

- Frontmatter `name: knowledge-ops` (was `memory-manager`)
- Frontmatter `description:` updated to mention operating under CKO direction
- Opening line: "You are the **Knowledge Ops** agent for this project." (was "Memory Manager")
- Add after the opening paragraph: "You operate under the direction of the **CKO** (Chief Knowledge Officer), who sets knowledge quality standards and distribution policy. You execute: audits, distribution, optimization, gap detection."
- All other content (responsibilities, autonomy model, communication style, persistent memory) stays the same

- [ ] **Step 3: Delete memory-manager.md**

Run: `git rm .claude/agents/memory-manager.md`

- [ ] **Step 4: Update /memory skill**

Read `.claude/skills/memory/SKILL.md`. Replace all references to "memory-manager" with "knowledge-ops". Update the intro to mention CKO direction.

- [ ] **Step 5: Verify**

Run: `grep -c 'memory-manager' .claude/agents/knowledge-ops.md .claude/skills/memory/SKILL.md`
Expected: 0 matches in both files

- [ ] **Step 6: Commit**

```bash
git add .claude/agents/knowledge-ops.md .claude/skills/memory/SKILL.md
git commit -m "feat: rename memory-manager to knowledge-ops, add CKO direction"
```

---

## Task 3: CEO Agent

**Files:**

- Create: `.claude/agents/ceo.md`

- [ ] **Step 1: Write the CEO agent definition**

Create `.claude/agents/ceo.md` following the spec's CEO section. Key elements:

**Frontmatter:** `name: ceo`, `model: opus`, `color: gold`, `memory: project`, `maxTurns: 50`

**Opening:** Reference `.claude/COLLABORATION.md` § Governance Collaboration Pattern and § Executive Memory Architecture.

**Identity:** Digital twin of the implementer. Proxy for user's strategic judgment. Represents user intent when not directly engaged.

**Position:** Governance tier. Independent pace starting at Crawl.

**What You Own:** Strategic priorities, product direction, executive brief (`.claude/governance/executive-brief.md`).

**Floor/Target Domain:** Strategic alignment floor rules + targets. Examples from spec.

**Trust and Safety:** Cannot increase own pace. Can slow down. Can recommend autonomy grants. CO monitors. Violation = work stops.

**Autonomy Model:** Table from spec (7 rows including floor/target rows, all propose-to-user at Crawl).

**Communication Style:** Mission-aligned, evidence-based, concise.

**Executive Memory:** Three-tier per spec cross-reference.

Keep to ~80 lines of body. Cross-reference COLLABORATION.md, don't duplicate.

- [ ] **Step 2: Verify**

Run: `head -8 .claude/agents/ceo.md`
Expected: Valid frontmatter with `name: ceo`, `model: opus`

- [ ] **Step 3: Commit**

```bash
git add .claude/agents/ceo.md
git commit -m "feat: add CEO agent definition (digital twin of implementer)"
```

---

## Task 4: CTO Agent

**Files:**

- Create: `.claude/agents/cto.md`

- [ ] **Step 1: Write the CTO agent definition**

Create `.claude/agents/cto.md` following the spec's CTO section.

**Frontmatter:** `name: cto`, `model: opus`, `color: indigo`, `memory: project`, `maxTurns: 50`

**Identity:** Technology enablement authority. Ensures fleet has controls, practices, tools to build effectively. Not risk-focused (that's COO).

**What You Own:** Technology floor, technology targets, tech stack direction.

**Relationship to SA:** CTO sets strategic direction; SA applies within items. SA may propose deviations.

**CTO's Domain:** Technology floor (MUST — proposed to CO), technology targets (SHOULD), technology enablement.

**Floor/Target Domain:** Already in spec with examples.

**Autonomy Model:** 6-row table from spec. Publishing and proposing autonomous; tech stack direction proposes to user.

Keep to ~70 lines of body.

- [ ] **Step 2: Verify and commit**

```bash
git add .claude/agents/cto.md
git commit -m "feat: add CTO agent definition (technology enablement authority)"
```

---

## Task 5: CFO Agent

**Files:**

- Create: `.claude/agents/cfo.md`

- [ ] **Step 1: Write the CFO agent definition**

Create `.claude/agents/cfo.md` following the spec's CFO section.

**Frontmatter:** `name: cfo`, `model: sonnet`, `color: green`, `memory: project`, `maxTurns: 40`

**Identity:** Balanced cost governance. Right investment proportional to pace and value.

**What You Own:** Token budget strategy, cost-per-item baselines, resource allocation guidance.

**Floor/Target Domain:** Cost governance floor rules + targets. Examples from spec.

**Relationship to platform-ops:** Platform-ops measures; CFO interprets and sets strategy.

**Autonomy Model:** 7-row table from spec. Monitoring and publishing autonomous; budget thresholds propose to user; model tier adjustments propose to SM.

Keep to ~60 lines of body.

- [ ] **Step 2: Verify and commit**

```bash
git add .claude/agents/cfo.md
git commit -m "feat: add CFO agent definition (balanced cost governance)"
```

---

## Task 6: COO Agent

**Files:**

- Create: `.claude/agents/coo.md`

- [ ] **Step 1: Write the COO agent definition**

Create `.claude/agents/coo.md` following the spec's COO section. This is the most detailed Cx agent because of the performance monitoring and retraining responsibilities.

**Frontmatter:** `name: coo`, `model: sonnet`, `color: teal`, `memory: project`, `maxTurns: 50`

**Identity:** Operational standards authority. Risk lens. Agent performance monitor.

**What You Own:** Process standards, SLAs, readiness criteria, quality benchmarks, risk management, agent performance metrics.

**Floor/Target Domain:** Operational floor rules + targets. Examples from spec.

**Relationship to SM:** COO sets standards; SM follows them.

**Agent Performance and Retraining:** Full section from spec including performance signals (5 bullets), mandate on metrics, retraining process (4 steps with structured questions), user approval required.

**Autonomy Model:** 8-row table from spec including monitoring, mandating metrics, recommending retraining (always propose to user).

Keep to ~90 lines of body — this agent has the most responsibilities.

- [ ] **Step 2: Verify and commit**

```bash
git add .claude/agents/coo.md
git commit -m "feat: add COO agent definition (operational efficiency + agent performance)"
```

---

## Task 7: CKO Agent

**Files:**

- Create: `.claude/agents/cko.md`

- [ ] **Step 1: Write the CKO agent definition**

Create `.claude/agents/cko.md` following the spec's CKO section.

**Frontmatter:** `name: cko`, `model: sonnet`, `color: slate`, `memory: project`, `maxTurns: 40`

**Identity:** Knowledge quality authority. Sets standards for fleet knowledge, distribution cadence, quality bar. Directs knowledge-ops.

**What You Own:** Knowledge quality standards, distribution cadence strategy, knowledge gap identification, guidance registry.

**Floor/Target Domain:** Knowledge governance floor rules + targets. Examples from spec.

**Relationship to knowledge-ops:** CKO sets policy; knowledge-ops executes. Same pattern as CISO → compliance-auditor.

**Pace-Based Distribution Cadence:** Reference the cadence table in COLLABORATION.md (will be added in Task 10). Note that implementers override via `knowledge.cadence` in fleet-config.json.

**SM/CKO/Knowledge-Ops Dispatch Chain:** 5-step chain from spec.

**Guard Against Thrashing:** At Run/Fly, require pattern before fleet-wide distribution.

**Guidance Registry Ownership:** CKO maintains the registry. Not protected by hooks (intentional — Tier 3 is informational).

**Autonomy Model:** 5-row table from spec.

Keep to ~75 lines of body.

- [ ] **Step 2: Verify and commit**

```bash
git add .claude/agents/cko.md
git commit -m "feat: add CKO agent definition (knowledge quality authority)"
```

---

## Task 8: `/governance` Skill

**Files:**

- Create: `.claude/skills/governance/SKILL.md`

- [ ] **Step 1: Create skill directory**

Run: `mkdir -p .claude/skills/governance`

- [ ] **Step 2: Write the skill file**

Create `.claude/skills/governance/SKILL.md` following the same pattern as `/compliance` and `/po` skills.

**Frontmatter:**

- `name: governance`
- `description: "Executive governance operations. Manage the executive brief, publish guidance, grant CEO autonomy."`
- `argument-hint: "[status|brief|decide <id>|grant <description>|guidance <topic>|guidance list]"`

**Body — `# Governance`**

Intro: Executive governance operations complementing `/compliance` (which handles floor/targets). Manages the executive brief, CEO autonomy grants, and guidance registry.

**Usage** (6 examples from spec).

**Workflow: Status (default)** — 3 steps: Read executive brief (pending decisions count, CEO grants), guidance registry (entry count), CEO pace. Present one-screen summary.

**Workflow: Brief** — 3 steps: Dispatch CEO agent (Opus). CEO reviews executive brief, surfaces pending decisions. Present to user for discussion.

**Workflow: Decide** — 4 steps: Load the pending decision by ID. Dispatch CEO (Opus) to present options with Cx input. User decides. Update executive brief (move to Resolved, write decision detail to `.claude/governance/decisions/<date>-<slug>.md`).

**Workflow: Grant** — 4 steps: Parse the autonomy scope description. Add to the CEO Autonomy Grants table in executive brief. Log `ceo-autonomy-granted` event. Confirm to user.

**Workflow: Guidance (publish)** — 4 steps: Parse topic and content. Determine if small enough to inline or needs a detail doc. Add entry to guidance registry. Log `guidance-published` event.

**Workflow: Guidance List** — 2 steps: Read guidance registry. Present entries.

**Model Tiering:** Table from spec (6 rows).

**Extensibility:** Implementers override for custom decision workflows or governance dashboards.

- [ ] **Step 3: Verify frontmatter**

Run: `head -5 .claude/skills/governance/SKILL.md`
Expected: Valid frontmatter with `name: governance`

- [ ] **Step 4: Commit**

```bash
git add .claude/skills/governance/SKILL.md
git commit -m "feat: add /governance skill for executive operations"
```

---

## Task 9: Add Governance Metrics Event Types

**Files:**

- Modify: `ops/metrics-log.sh`

- [ ] **Step 1: Read the current metrics-log.sh**

Read `ops/metrics-log.sh` to find variable initialization, flag parsing, event handlers, and valid types list.

- [ ] **Step 2: Add new variables and flags**

Add to variable initialization: `TOPIC="" BY=""`

Add to flag parsing:

```bash
    --topic) TOPIC="$2"; shift 2 ;;
    --by)    BY="$2";    shift 2 ;;
    --trigger) TRIGGER="$2"; shift 2 ;;
    --action) ACTION="$2"; shift 2 ;;
    --items) ITEMS="$2"; shift 2 ;;
```

Also add `TRIGGER="" ACTION="" ITEMS=""` to variable initialization.

- [ ] **Step 3: Add event handlers**

Before the `*)` catch-all, add:

```bash
  guidance-published)
    emit_event "$(jq -cn --arg ts "$TS" --arg event "$EVENT_TYPE" \
       --arg by "$BY" --arg topic "$TOPIC" --arg agent "$AGENT" \
       '{"ts":$ts,"event":$event,"by":$by,"topic":$topic,"agent":$agent}')"
    ;;

  ceo-autonomy-granted)
    emit_event "$(jq -cn --arg ts "$TS" --arg event "$EVENT_TYPE" \
       --arg scope "$SCOPE" --arg agent "$AGENT" \
       '{"ts":$ts,"event":$event,"scope":$scope,"agent":$agent}')"
    ;;

  ceo-autonomy-violation)
    emit_event "$(jq -cn --arg ts "$TS" --arg event "$EVENT_TYPE" \
       --arg action "$ACTION" --arg agent "$AGENT" \
       '{"ts":$ts,"event":$event,"action":$action,"agent":$agent}')"
    ;;

  knowledge-distributed)
    emit_event "$(jq -cn --arg ts "$TS" --arg event "$EVENT_TYPE" \
       --arg trigger "$TRIGGER" --arg items "$ITEMS" --arg agent "$AGENT" \
       '{"ts":$ts,"event":$event,"trigger":$trigger,"items":$items,"agent":$agent}')"
    ;;
```

- [ ] **Step 4: Update valid types error message**

Add: `echo "             guidance-published ceo-autonomy-granted ceo-autonomy-violation knowledge-distributed" >&2`

- [ ] **Step 5: Verify syntax**

Run: `bash -n ops/metrics-log.sh`
Expected: No errors

- [ ] **Step 6: Commit**

```bash
git add ops/metrics-log.sh
git commit -m "feat: add governance event types to metrics-log.sh"
```

---

## Task 10: Update COLLABORATION.md

**Files:**

- Modify: `.claude/COLLABORATION.md`

This is the largest task — multiple sections to update.

- [ ] **Step 1: Read the target sections**

Read `.claude/COLLABORATION.md` to find: governance tier table (around line 48-60), cross-cutting agents table (around line 100), memory integration section (around line 645), and executive memory architecture (around line 595).

- [ ] **Step 2: Update governance tier table**

The current table has 2 rows (CO, CISO). Replace with 7 rows:

| Agent                  | Role                   | Responsibility                                               |
| ---------------------- | ---------------------- | ------------------------------------------------------------ |
| **compliance-officer** | Compliance program     | Floor guardianship, change control, conformance monitoring   |
| **ciso**               | Security authority     | Security benchmarks, security controls, threat assessment    |
| **ceo**                | Strategic alignment    | Digital twin of implementer, mission/vision, executive brief |
| **cto**                | Technology enablement  | Technology floor, tech standards, architecture direction     |
| **cfo**                | Cost governance        | Token budget strategy, cost efficiency, resource allocation  |
| **coo**                | Operational efficiency | Process standards, SLAs, agent performance, retraining       |
| **cko**                | Knowledge quality      | Knowledge standards, distribution cadence, guidance registry |

Update the intro text from "Two agents provide independent compliance and security oversight" to "Seven agents provide independent governance across compliance, security, strategy, technology, cost, operations, and knowledge."

- [ ] **Step 3: Update cross-cutting agents table**

Rename `memory-manager` to `knowledge-ops` in the cross-cutting agents table. Update description to mention CKO direction.

- [ ] **Step 4: Rename memory-manager → knowledge-ops throughout**

Replace all remaining references to `memory-manager` with `knowledge-ops` in the file. There should be approximately 4-5 occurrences in the memory integration section and executive memory architecture section.

- [ ] **Step 5: Add guidance mechanism section**

After the Compliance Hierarchy section and before the Governance Collaboration Pattern section, add a "### Guidance Mechanism (Tier 3)" section explaining the registry, detail docs, maintenance, and CKO ownership. Keep concise — reference the spec for full detail.

- [ ] **Step 6: Add CEO pace model section**

After the Governance Collaboration Pattern section, add a "### CEO Independent Pace" section covering: independent of fleet pace, starts at Crawl, can never self-promote, autonomy grants tracked in executive brief, CO monitors.

- [ ] **Step 7: Add pace-based knowledge distribution section**

After the executive memory architecture section, add a "### Pace-Based Knowledge Distribution" section with the cadence table (Crawl/Walk/Run/Fly), triggers (scheduled/exception/on-demand), SM/CKO/knowledge-ops dispatch chain, and guard against thrashing. Note implementer override via `fleet-config.json` `knowledge.cadence`.

- [ ] **Step 8: Verify**

Run: `grep -c 'knowledge-ops' .claude/COLLABORATION.md` — expected: 5+
Run: `grep -c 'memory-manager' .claude/COLLABORATION.md` — expected: 0
Run: `grep -c 'CEO Independent Pace' .claude/COLLABORATION.md` — expected: 1

- [ ] **Step 9: Commit**

```bash
git add .claude/COLLABORATION.md
git commit -m "feat: expand governance tier to 7 Cx roles, add guidance/CEO pace/knowledge distribution"
```

---

## Task 11: Update CO Agent for CEO Monitoring

**Files:**

- Modify: `.claude/agents/compliance-officer.md`

- [ ] **Step 1: Read the current CO agent**

Read `.claude/agents/compliance-officer.md`.

- [ ] **Step 2: Add CEO autonomy monitoring**

In the Core Responsibilities section, after "### 5. Enablement", add:

```markdown
### 6. CEO Autonomy Monitoring

Audit the executive brief's autonomy grants section against CEO actions during each compliance audit cycle (dispatched during Phase 4 Review or via `/compliance audit`). If CEO actions exceed granted autonomy:

1. **Stop work immediately** — halt all fleet activity
2. **Return control to user** — present the violation with evidence
3. **Log events** — `ceo-autonomy-violation` via `ops/metrics-log.sh` and critical compliance finding in `.claude/findings/register.md`
```

Add to the autonomy table: `| CEO autonomy monitoring | Autonomous |`

- [ ] **Step 3: Commit**

```bash
git add .claude/agents/compliance-officer.md
git commit -m "feat: add CEO autonomy monitoring to compliance-officer"
```

---

## Task 12: Update README.md

**Files:**

- Modify: `README.md`

- [ ] **Step 1: Update architecture diagram**

Read `README.md` lines 41-75 (Mermaid diagram). Update the Gov subgraph to include all 7 Cx roles:

```mermaid
    subgraph Gov ["Governance Layer"]
        CO["CO"]
        CISO_A["CISO"]
        CEO_A["CEO"]
        CTO_A["CTO"]
        CFO_A["CFO"]
        COO_A["COO"]
        CKO_A["CKO"]
    end
```

Add purple styling for all governance nodes.

- [ ] **Step 2: Update agent table**

Update the heading from "**8 agents**" to "**14 agents**" (7 governance + 7 operational). Add 5 new governance rows and rename memory-manager → knowledge-ops. The table should have:

- 7 Governance rows: CO, CISO, CEO, CTO, CFO, COO, CKO
- 7 Operational rows: PO, SA, SM, knowledge-ops, platform-ops, compliance-auditor (+ app-defined note)

- [ ] **Step 3: Update the overview line**

Find the opening description that mentions agents and update the count.

- [ ] **Step 4: Add `/governance` to the Skills table**

Add: `| /governance | Executive governance: brief, decisions, guidance, CEO autonomy | ceo |`

- [ ] **Step 5: Update `/memory` skill primary agent in the Skills table**

Change primary agent from `memory-manager` to `knowledge-ops`.

- [ ] **Step 6: Commit**

```bash
git add README.md
git commit -m "docs: update README for 14 agents, 7 Cx governance roles, /governance skill"
```

---

## Task 13: Update CLAUDE.md

**Files:**

- Modify: `CLAUDE.md`

- [ ] **Step 1: Update project overview**

Change "8 agents across 2 tiers: governance (compliance-officer, CISO) and operational" to "14 agents across 2 tiers: governance (CO, CISO, CEO, CTO, CFO, COO, CKO) and operational (PO, SA, SM, knowledge-ops, platform-ops, compliance-auditor)".

- [ ] **Step 2: Update key files agent description**

Update the `.claude/agents/*.md` description to reflect 14 agents (7 governance + 7 operational) and rename memory-manager → knowledge-ops.

- [ ] **Step 3: Add `.claude/governance/` to directory structure**

If not already present, add with description: "Governance infrastructure (executive brief, guidance registry, decisions)".

- [ ] **Step 4: Commit**

```bash
git add CLAUDE.md
git commit -m "docs: update CLAUDE.md for 14 agents, governance directory"
```

---

## Task 14: Update fleet-config Template

**Files:**

- Modify: `templates/fleet-config.json`

- [ ] **Step 1: Read the current template**

Read `templates/fleet-config.json`.

- [ ] **Step 2: Add 5 Cx roles to governance roster**

Change `"governance": ["compliance-officer", "ciso"]` to `"governance": ["compliance-officer", "ciso", "ceo", "cto", "cfo", "coo", "cko"]`.

- [ ] **Step 3: Rename memory-manager in core roster**

Change `"memory-manager"` to `"knowledge-ops"` in the core array.

- [ ] **Step 4: Add knowledge cadence config**

Add after the `retro` section:

```json
"knowledge": {
  "cadence": {
    "crawl": 1,
    "walk": 2,
    "run": 4,
    "fly": 0
  },
  "note": "Items between knowledge distributions per pace. 0 = on-demand/retro only."
}
```

- [ ] **Step 5: Update governance pathways**

Replace the existing governance pathways with the expanded set from the spec:

```json
"governance": [
  "ciso -> compliance-officer",
  "compliance-officer -> compliance-auditor",
  "* -> compliance-officer",
  "cko -> knowledge-ops",
  "cto -> solution-architect",
  "cfo -> platform-ops",
  "coo -> scrum-master",
  "* -> ceo"
]
```

- [ ] **Step 6: Verify JSON**

Run: `python3 -c "import json; d=json.load(open('templates/fleet-config.json')); print(len(d['agents']['governance']), 'governance agents'); print(d['knowledge']['cadence'])"`
Expected: `7 governance agents` and the cadence dict

- [ ] **Step 7: Commit**

```bash
git add templates/fleet-config.json
git commit -m "feat: add 5 Cx roles, knowledge cadence, expanded pathways to fleet-config"
```

---

## Task 15: Update settings.json and Cx Template

**Files:**

- Modify: `.claude/settings.json`
- Modify: `templates/agents/cx-role.md`

- [ ] **Step 1: Read and rewrite settings.json**

Read `.claude/settings.json`. Update the PreCompact context string from "2 governance agents (CO, CISO) and 6 core agents" to "7 governance agents (CO, CISO, CEO, CTO, CFO, COO, CKO) and 7 operational agents (PO, SA, SM, knowledge-ops, platform-ops, compliance-auditor)". Also rename any memory-manager reference to knowledge-ops. Use Write tool (full rewrite per CLAUDE.md gotchas).

- [ ] **Step 2: Verify JSON**

Run: `python3 -c "import json; json.load(open('.claude/settings.json')); print('valid')"`
Expected: `valid`

- [ ] **Step 3: Update cx-role template**

Read `templates/agents/cx-role.md`. Change `model: opus` to `model: opus  # adjust: use Sonnet for data-driven roles (CFO, COO, CKO), Opus for judgment-heavy roles (CEO, CTO, CISO)`. Also add a floor/target section to the template:

```markdown
## Floor and Targets

- **Floor rules (MUST):** Propose to the CO via `/compliance propose`. [Define your domain's non-negotiable minimums.]
- **Targets (SHOULD):** [Define aspirational objectives in your domain.] Proposed to CO; risk-reducing can be approved autonomously.
- **Guidance (NICE TO HAVE):** Publish to the guidance registry via `/governance guidance`. [Define best practices in your domain.]
```

- [ ] **Step 4: Commit**

```bash
git add .claude/settings.json templates/agents/cx-role.md
git commit -m "feat: update PreCompact for 14 agents, make cx-role template model-agnostic"
```

---

## Task 16: Final Validation

- [ ] **Step 1: Verify all new agent files exist with valid frontmatter**

Run: `for agent in ceo cto cfo coo cko knowledge-ops; do echo "=== $agent ===" && head -5 .claude/agents/$agent.md; done`
Expected: All 6 with valid YAML frontmatter

- [ ] **Step 2: Verify memory-manager is removed**

Run: `ls .claude/agents/memory-manager.md 2>&1`
Expected: "No such file or directory"

- [ ] **Step 3: Verify no memory-manager references remain (except spec/plan docs)**

Run: `grep -r 'memory-manager' .claude/ templates/ CLAUDE.md README.md ops/ --include='*.md' --include='*.json' --include='*.sh' | grep -v 'superpowers/' | grep -v 'plans/'`
Expected: No matches

- [ ] **Step 4: Verify governance skill frontmatter**

Run: `head -5 .claude/skills/governance/SKILL.md`
Expected: Valid frontmatter with `name: governance`

- [ ] **Step 5: Verify governance directory structure**

Run: `ls -la .claude/governance/`
Expected: executive-brief.md, guidance-registry.md, guidance/, decisions/

- [ ] **Step 6: Verify settings.json is valid JSON**

Run: `python3 -c "import json; json.load(open('.claude/settings.json')); print('valid')"`
Expected: `valid`

- [ ] **Step 7: Verify fleet-config has 7 governance agents**

Run: `python3 -c "import json; d=json.load(open('templates/fleet-config.json')); print(len(d['agents']['governance']), d['agents']['governance'])"`
Expected: `7 ['compliance-officer', 'ciso', 'ceo', 'cto', 'cfo', 'coo', 'cko']`

- [ ] **Step 8: Verify COLLABORATION.md has 7 Cx roles**

Run: `grep -c 'compliance-officer\|ciso\|ceo\|cto\|cfo\|coo\|cko' .claude/COLLABORATION.md | head -1`
Run: `grep -c 'CEO Independent Pace' .claude/COLLABORATION.md`
Expected: Multiple matches for Cx roles, 1 for CEO Independent Pace

- [ ] **Step 9: Verify metrics-log has governance events**

Run: `grep -c 'guidance-published\|ceo-autonomy-granted\|ceo-autonomy-violation\|knowledge-distributed' ops/metrics-log.sh`
Expected: At least 4

- [ ] **Step 10: Bash syntax check**

Run: `bash -n ops/*.sh`
Expected: No errors

- [ ] **Step 11: Verify existing agents unchanged**

Run: `git diff HEAD -- .claude/agents/product-owner.md .claude/agents/scrum-master.md .claude/agents/solution-architect.md .claude/agents/platform-ops.md .claude/agents/ciso.md`
Expected: No changes

- [ ] **Step 12: Verify README references 14 agents**

Run: `grep -c '14 agents' README.md`
Expected: At least 1
