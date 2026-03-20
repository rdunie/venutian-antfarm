# Cx Governance Framework

## Overview

Sub-project 2 of the governance layer. Adds 5 new Cx agents (CEO, CTO, CFO, COO, CKO), a fleet-wide guidance mechanism (Tier 3), an executive brief for CEO-user collaboration, CEO-specific trust/pace model, pace-based knowledge distribution cadence, and renames memory-manager to knowledge-ops with a new CKO governance agent directing it.

**After this sub-project, the fleet has:**

- **7 Cx governance agents:** CO, CISO, CEO, CTO, CFO, COO, CKO
- **7 operational agents:** PO, SA, SM, platform-ops, knowledge-ops, compliance-auditor, + app-defined specialists

## Guidance Mechanism (Tier 3)

### Fleet-Wide Registry

`.claude/governance/guidance-registry.md` — a fleet-wide index loaded into agent context. Contains one entry per active guidance topic with: title, issuing Cx role, summary, relevance statement ("what's in it for me?"), and link to detail doc (if the guidance is large enough to warrant one).

Small guidance is inlined directly in the registry entry — no separate detail doc needed. Large guidance gets the summary + reference pattern. The CKO (via knowledge-ops) monitors guidance size and optimizes the balance between inlining and referencing over time.

### Detail Documents

`.claude/governance/guidance/<cx-role>/<topic>.md` — full guidance content for topics too large to inline. Not loaded into context by default — agents read when they need the detail.

### Example Registry Entry

```markdown
### Secrets Management (CISO)

All credentials must use environment variables or a secrets manager. Never hardcode, never commit.
**Relevance:** Every agent that writes code or configuration must follow this.
**Detail:** `.claude/governance/guidance/ciso/secrets-management.md`
```

### Example Inlined Entry (no detail doc)

```markdown
### TypeScript Required for Backend (CTO)

All new backend code must be written in TypeScript. No new JavaScript files.
**Relevance:** Backend specialists must use TypeScript. Frontend specialists follow their own stack guidance.
```

### Maintenance

- Each Cx role writes and maintains their own guidance detail docs
- The CKO maintains the registry index (adds/removes entries when Cx roles publish or retire guidance)
- The triad operationalizes guidance — decides how to incorporate it into agent workflows
- Guidance is Tier 3 (NICE TO HAVE). Cx roles publish autonomously. No user approval required.

### Targeted Guidance (deferred)

Fleet-wide guidance is the v1 mechanism. Targeted guidance (role-specific delivery with layered depth — summary for most, detail for specialists) is deferred to a future iteration. The CKO will own the design of the targeted delivery mechanism when the fleet has enough guidance content to warrant it.

## Agent Definitions

### CEO (Digital Twin of Implementer)

- **Model:** Opus
- **Core identity:** Proxy for the user's strategic judgment. Represents the user's intent when they're not directly engaged. Ensures fleet decisions align with mission, vision, and stakeholder commitments.
- **Owns:** Strategic priorities, product direction, executive brief
- **Independent pace:** Starts at Crawl, separate from fleet pace. CEO can never increase its own pace — only the user can promote. CEO can slow itself down. CEO can recommend specific autonomy grants but requires explicit user approval for each.
- **Guidance domain:** Mission alignment, strategic priorities, stakeholder commitments

#### CEO Trust and Safety Model

- CEO starts at Crawl — all decisions escalated to user
- CEO can **never** increase its own pace — only the user can grant autonomy
- CEO **can** slow itself down when it recognizes complexity or uncertainty
- CEO can **recommend** specific decisions it believes it could handle autonomously, but requires **explicit user approval** for each grant
- Autonomy grants are specific and scoped (e.g., "CEO may autonomously prioritize between ready backlog items" — not blanket promotions)
- The CO monitors CEO autonomy. If the CEO acts beyond its granted autonomy: **work stops immediately**, control returns to the user, violation logged as critical compliance finding
- CEO autonomy grants are tracked in the executive brief

#### CEO Autonomy Model

| Action                                      | Autonomy                                        |
| ------------------------------------------- | ----------------------------------------------- |
| Surfacing decisions to executive brief      | Autonomous                                      |
| Recommending strategic priorities           | Propose to user (always, at current Crawl pace) |
| Making strategic decisions on user's behalf | Only with explicit autonomy grant from user     |
| Slowing own pace                            | Autonomous                                      |
| Increasing own pace                         | Never — user only                               |

### CTO (Technology Enablement Authority)

- **Model:** Opus
- **Core identity:** Technology enablement authority. Ensures the fleet has the controls, practices, and tools needed to build effectively, efficiently, securely, and sustainably. Does not focus on risk (COO's domain) — focuses on whether the team has what it needs.
- **Owns:** Technology floor (minimum practices/tools), technology targets, tech stack direction
- **Relationship to SA:** CTO sets strategic technology direction; SA applies it within work items. SA may propose deviations; CTO evaluates.
- **Guidance domain:** Technology standards, architecture patterns, coding conventions, tooling

#### CTO's Domain

- **Technology floor:** Minimum practices and tools that must be in place (e.g., "we must have automated testing", "we must have CI/CD", "we must use type-safe languages for backend"). Proposed to CO via `/compliance propose`.
- **Technology targets:** Aspirational practices that enable better outcomes (e.g., "we should have observability dashboards", "we should adopt infrastructure-as-code").
- **Technology enablement:** Ensuring the fleet can make good technology choices — the right abstractions, the right tools, the right patterns available.

#### CTO Autonomy Model

| Action                                                              | Autonomy                         |
| ------------------------------------------------------------------- | -------------------------------- |
| Publishing technology guidance                                      | Autonomous                       |
| Proposing floor rules to CO (technology practices/tooling minimums) | Autonomous (CO manages approval) |
| Defining technology targets                                         | Autonomous                       |
| Setting tech stack direction                                        | Propose to user (strategic)      |
| Evaluating whether fleet has adequate technology controls           | Autonomous                       |
| Evaluating SA architecture proposals for technology alignment       | Autonomous                       |

### CFO (Cost Governance)

- **Model:** Sonnet (cost-conscious by design)
- **Core identity:** Balanced cost governance. Not lowest cost, not maximum throughput — the right investment proportional to pace and value delivered.
- **Owns:** Token budget strategy, cost-per-item baselines, resource allocation guidance
- **Relationship to platform-ops:** Platform-ops measures costs (tracks token usage, model split). CFO interprets the data and sets strategy.
- **Guidance domain:** Cost expectations, budget thresholds, efficiency standards

#### CFO Autonomy Model

| Action                              | Autonomy                         |
| ----------------------------------- | -------------------------------- |
| Monitoring cost metrics             | Autonomous                       |
| Publishing cost guidance            | Autonomous                       |
| Setting budget thresholds/alerts    | Propose to user                  |
| Recommending model tier adjustments | Propose to SM (process decision) |
| Flagging cost overruns              | Autonomous (alert to user + SM)  |

### COO (Operational Efficiency)

- **Model:** Sonnet
- **Core identity:** Operational standards authority. Ensures the fleet operates efficiently, consistently, and with appropriate quality standards beyond compliance. Owns the risk lens — asks "is this operationally sound?"
- **Owns:** Process standards, SLAs, operational readiness criteria, quality benchmarks, risk management
- **Relationship to SM:** COO sets operational standards; SM ensures the process follows them. SM may propose adjustments; COO evaluates.
- **Guidance domain:** Operational standards, quality benchmarks, SLAs, readiness criteria

#### COO Autonomy Model

| Action                                             | Autonomy                                       |
| -------------------------------------------------- | ---------------------------------------------- |
| Publishing operational standards                   | Autonomous                                     |
| Proposing floor rules to CO (operational controls) | Autonomous (CO manages approval)               |
| Defining operational targets/SLAs                  | Autonomous if risk-reducing, propose otherwise |
| Evaluating SM process proposals                    | Autonomous                                     |
| Setting operational readiness criteria             | Propose to user (strategic)                    |

### CKO (Chief Knowledge Officer)

- **Model:** Sonnet
- **Core identity:** Knowledge quality authority. Sets the standards for what the fleet should know, when learnings should distribute, and what the quality bar is for agent knowledge. Directs knowledge-ops to execute.
- **Owns:** Knowledge quality standards, distribution cadence strategy, knowledge gap identification
- **Relationship to knowledge-ops:** CKO sets policy and direction; knowledge-ops executes (audits, distributes, optimizes files). Same pattern as CISO → compliance-auditor.
- **Guidance domain:** Knowledge quality standards, learning distribution practices

#### CKO Autonomy Model

| Action                                                          | Autonomy                              |
| --------------------------------------------------------------- | ------------------------------------- |
| Setting knowledge quality standards                             | Autonomous                            |
| Directing knowledge-ops distribution cadence                    | Autonomous (follows pace-based rules) |
| Publishing knowledge guidance                                   | Autonomous                            |
| Proposing floor rules to CO (knowledge governance)              | Autonomous (CO manages approval)      |
| Overriding pace-based cadence for exception-driven distribution | Autonomous (SM triggers, CKO directs) |

## Executive Brief

**Location:** `.claude/governance/executive-brief.md`

Shared document between the user and CEO. Active items are surfaced for decision; resolved items get a one-line summary with a link to the full decision record.

### Structure

```markdown
# Executive Brief

## CEO Autonomy Grants

| Grant | Scope | Granted By | Date | Status |
| ----- | ----- | ---------- | ---- | ------ |

(none yet — CEO starts at Crawl)

## Pending Decisions

### [DATE] [TITLE]

**Raised by:** [Cx role or agent]
**Context:** [why this needs executive input]
**Options:** [A/B/C with tradeoffs]
**Cx input:** [which Cx roles weighed in, their positions]
**Status:** pending

## In Progress

(decisions actively being discussed)

## Resolved

- [DATE] [TITLE] — [one-line outcome] → [detail link]
```

### Decision Detail

Resolved decision records stored in `.claude/governance/decisions/<date>-<slug>.md`. Keeps the brief scannable; full detail is referenced.

### Who Writes To It

- CEO adds pending decisions (things requiring user input)
- Any Cx role can raise items to the CEO for the brief
- The user and CEO resolve items together
- CO audits that the CEO autonomy grants section reflects reality

## Pace-Based Knowledge Distribution

Learning distribution frequency is inversely proportional to delivery pace. Stability earns less disruption; complexity demands faster feedback.

### Default Cadence

These are the harness defaults. Implementers override by setting `knowledge.cadence` in `fleet-config.json`.

| Pace  | Knowledge-Ops Cadence                                      | Rationale                                             |
| ----- | ---------------------------------------------------------- | ----------------------------------------------------- |
| Crawl | Every item — distribute learnings after each accepted item | Fleet is actively calibrating                         |
| Walk  | Every 2-3 items — batch distribution at checkpoints        | Process is stabilizing                                |
| Run   | Every 3-5 items — distribute only significant learnings    | Fleet is proven; don't change what works for outliers |
| Fly   | On-demand or at retros only — minimal intervention         | High autonomy earned through stability                |

### Implementer Override

Add to `fleet-config.json`:

```json
"knowledge": {
  "cadence": {
    "crawl": 1,
    "walk": 2,
    "run": 4,
    "fly": 0
  },
  "note": "Items between knowledge distributions per pace. 0 = on-demand/retro only. Harness defaults shown."
}
```

Implementers adjust based on their domain. A high-risk compliance domain might use `{"crawl": 1, "walk": 1, "run": 2, "fly": 3}` (more frequent distribution at all paces). A stable maintenance project might use `{"crawl": 1, "walk": 3, "run": 5, "fly": 0}` (less frequent).

### Triggers

- **Scheduled:** SM triggers knowledge distribution at the cadence above during Checkpoint (Phase 9)
- **Exception-driven:** If SM detects a spike in findings, rework, or handoff rejections (regardless of pace), knowledge-ops is triggered immediately — cadence override does not suppress exception-driven distribution
- **On-demand:** Any agent or user can request `/memory distribute` at any time

The SM owns the trigger decision. Knowledge-ops executes under CKO direction.

### Guard Against Thrashing

At Run/Fly pace, the CKO requires a **pattern** (multiple instances) before distributing a learning fleet-wide. A single outlier event at high pace is a finding, not a fleet-wide learning — unless it's a compliance violation or critical bug.

## Rename: memory-manager → knowledge-ops

The existing `memory-manager` agent is renamed to `knowledge-ops` at the operational level. Its responsibilities remain the same (consistency audits, learning distribution, optimization, gap detection), but it now operates under the direction of the CKO governance agent.

### Files Affected

| File                               | Change                                                                  |
| ---------------------------------- | ----------------------------------------------------------------------- |
| `.claude/agents/memory-manager.md` | Rename to `.claude/agents/knowledge-ops.md`, update name in frontmatter |
| `.claude/skills/memory/SKILL.md`   | Update to reference knowledge-ops agent                                 |
| `.claude/COLLABORATION.md`         | All memory-manager references → knowledge-ops                           |
| `CLAUDE.md`                        | Agent references                                                        |
| `README.md`                        | Agent table, architecture diagram                                       |
| `templates/fleet-config.json`      | Agent roster                                                            |
| `.claude/settings.json`            | PreCompact context string                                               |

## Hardening and Extensibility

### Hardening Principle

All Cx roles should automate and harden routine, mission-critical practices:

- Practices that are proven and repeatable → codify into hooks, scripts, or agent instructions
- Practices that require judgment → keep as agent-driven with appropriate autonomy tier
- Progression: manual → guided → automated → enforced (via hooks)

### Extensibility Principle

Every hardened element must provide an easy extension point for implementers:

- Hooks can be overridden in project-level `settings.json`
- Agent definitions can be extended via `extends:` frontmatter
- Guidance docs can be overridden by creating the same path in the project
- Scripts can be replaced (same contract: exit 0/1)
- No harness behavior should be locked in a way that implementers can't customize

## `/governance` Skill

Single entry point for executive governance operations. Complements `/compliance` (which handles floor/targets).

| Subcommand                         | What it does                                             | Who can invoke |
| ---------------------------------- | -------------------------------------------------------- | -------------- |
| `/governance status`               | Show executive brief summary, active decisions, CEO pace | Anyone         |
| `/governance brief`                | Open the executive brief for review with the user        | CEO, user      |
| `/governance decide <decision-id>` | Resolve a pending decision in the executive brief        | CEO + user     |
| `/governance grant <description>`  | Grant the CEO a specific autonomy scope                  | User only      |
| `/governance guidance <topic>`     | Publish new guidance to the registry                     | Any Cx role    |
| `/governance guidance list`        | Show the guidance registry                               | Anyone         |

### Model Tiering

| Subcommand                  | Model  | Rationale                            |
| --------------------------- | ------ | ------------------------------------ |
| `/governance status`        | Sonnet | Data aggregation                     |
| `/governance brief`         | Opus   | Judgment: CEO-user decision-making   |
| `/governance decide`        | Opus   | Judgment: decision resolution        |
| `/governance grant`         | Sonnet | Structured update to executive brief |
| `/governance guidance`      | Sonnet | Structured publishing                |
| `/governance guidance list` | Sonnet | Data lookup                          |

### CEO Invocation

The CEO is invoked in three ways:

1. **Via `/governance brief` or `/governance decide`** — direct user-CEO interaction
2. **By other Cx roles** — any Cx role can raise items to the CEO for the executive brief via `/governance guidance` or through a handoff
3. **At checkpoints** — SM can invoke the CEO during Phase 9 (Checkpoint) to review strategic alignment

The CEO does NOT run continuously or monitor passively. It is dispatched when executive judgment is needed.

## Metrics Integration

New event types for `ops/metrics-log.sh`:

| Event                    | When                                   | Args                                                          |
| ------------------------ | -------------------------------------- | ------------------------------------------------------------- |
| `guidance-published`     | Cx role publishes guidance to registry | `--by <cx-role> --topic <title>`                              |
| `ceo-autonomy-granted`   | User grants CEO a new autonomy scope   | `--scope <description>`                                       |
| `ceo-autonomy-violation` | CO detects CEO acting beyond grants    | `--action <description>`                                      |
| `knowledge-distributed`  | Knowledge-ops distributes learnings    | `--trigger <scheduled\|exception\|on-demand> --items <count>` |

## Governance Pathways

Add to `pathways.declared` in `fleet-config.json`:

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

## CO Updates

The compliance-officer gains an additional monitoring responsibility:

- **CEO autonomy monitoring:** CO audits the executive brief's autonomy grants section against CEO actions during each compliance audit cycle (dispatched during Phase 4 Review or via `/compliance audit`). If CEO actions exceed granted autonomy: work stops immediately, control returns to user, `ceo-autonomy-violation` event logged, critical compliance finding recorded.

## Governance-Triad Interaction Clarification

Governance agents set direction but do not direct day-to-day work. When a Cx role evaluates a triad member's proposal (CTO evaluates SA architecture, COO evaluates SM process, CFO recommends model tiers to SM), this is governance oversight — setting and enforcing standards — not operational direction. The triad retains full operational authority within the standards set by governance.

## Technology Targets Clarification

"Technology targets" proposed by the CTO are compliance targets — they go into `.claude/compliance/targets.md` via the CO's change control process (`/compliance propose`). There is no separate concept. All Cx roles use the same three-tier hierarchy: floor rules (MUST) and targets (SHOULD) go through the CO; guidance (NICE TO HAVE) goes through the CKO-maintained registry.

## CEO Pace Model

CEO pace is independent of fleet pace and stored in the executive brief under "CEO Autonomy Grants."

- **Storage:** The executive brief's autonomy grants section IS the pace record. No grants = Crawl. Each grant expands the CEO's autonomy scope incrementally.
- **Promotion:** User adds a grant via `/governance grant`. This is not a pace "promotion" in the fleet sense — it's a scoped delegation of specific decision authority.
- **No thresholds:** Unlike fleet pace (which has CFR/FPY thresholds), CEO autonomy is purely trust-based. The user decides when to grant, based on their experience working with the CEO.

## SM/CKO/Knowledge-Ops Dispatch Chain

When learning distribution is triggered:

1. **SM decides to trigger** (based on pace-based cadence or exception signal)
2. **SM dispatches CKO** with the trigger context (what prompted the distribution)
3. **CKO evaluates** what should be distributed (applies quality standards, guards against thrashing at high pace)
4. **CKO dispatches knowledge-ops** with specific instructions (which learnings to distribute, to which agents)
5. **Knowledge-ops executes** the distribution (writes to memories, updates cross-references)

Two dispatches, clear handoffs: SM → CKO → knowledge-ops.

## Guidance Registry Protection

The guidance registry (`.claude/governance/guidance-registry.md`) is NOT protected by hooks. This is an intentional design choice:

- Guidance is Tier 3 — informational, not enforced
- Cx roles publish autonomously — hook protection would add friction without safety benefit
- The CKO monitors registry quality and optimizes size as part of knowledge management
- If the registry grows too large for context, the CKO restructures it (more references, fewer inlined entries)

## Cx Role Template Update

Update `templates/agents/cx-role.md` to be model-agnostic:

- Change `model: opus` to `model: opus  # adjust based on role — use Sonnet for data-driven roles, Opus for judgment-heavy roles`
- Add a note: "CEO, CTO, CISO use Opus (strategic judgment). CFO, COO, CKO use Sonnet (data-driven, cost-conscious)."

## Framework Updates

### COLLABORATION.md

- Update governance tier table: 7 Cx roles (add CEO, CTO, CFO, COO, CKO)
- Add guidance mechanism section
- Add CEO pace model (independent of fleet pace)
- Add CKO/knowledge-ops relationship
- Add pace-based knowledge distribution cadence
- Rename memory-manager → knowledge-ops throughout

### README.md

- Update agent table to show all agents across tiers
- Update architecture diagram (governance layer expands to 7)
- Update agent count references

### CLAUDE.md

- Update agent count and directory structure
- Add `.claude/governance/` to directory tree

### templates/fleet-config.json

- Add CEO, CTO, CFO, COO, CKO to governance roster
- Update governance pathways (add new Cx agent communication paths)
- Rename memory-manager → knowledge-ops in core roster

### .claude/settings.json

- Update PreCompact context string with full agent roster

## Governance Directory Structure

```
.claude/governance/
├── executive-brief.md              # CEO-user collaboration document
├── guidance-registry.md            # Fleet-wide guidance index
├── guidance/                       # Detail docs by Cx role
│   ├── ciso/
│   ├── cto/
│   ├── cfo/
│   ├── coo/
│   ├── cko/
│   └── ceo/
└── decisions/                      # Resolved executive decision records
    └── ...
```

## What Does NOT Change

- **CO and CISO** agent definitions — unchanged (CO gains CEO monitoring responsibility, noted above)
- **compliance-auditor** — unchanged
- **PO, SA, SM, platform-ops** — unchanged
- **`/compliance` skill** — unchanged
- **Compliance floor mechanism** — unchanged (Cx roles propose floor rules through CO)
- **`ops/` scripts** — unchanged except `ops/metrics-log.sh` (4 new event types added)
- **Work item lifecycle** — unchanged
