# Governance Layer: Compliance Officer + CISO

## Overview

Add an executive governance tier to the agent fleet with two new core agents: the **Compliance Officer (CO)** and the **CISO**. The governance tier sits above the leadership triad (PO, SA, SM), is independent of the operational chain, and owns the compliance program and security posture respectively.

This is **sub-project 1** of a broader Cx governance framework. Sub-project 2 will generalize the pattern for additional Cx roles (CFO, CTO, CEO, COO) and the guidance (NICE TO HAVE) tier.

## Compliance Hierarchy

Three tiers of compliance controls, each with distinct authority and enforcement:

### Tier 1: Compliance Floor (MUST)

- Declarative, unconditional statements: "We MUST ALWAYS..." or "We MUST NEVER..."
- Clear, unambiguous, concise — just enough for flawless agent execution
- No conditionals, no "unless," no "when possible"
- Stored in `compliance-floor.md` — policy statements only
- Detailed context, rationale, and implementation guidance stored separately and referenced (subject to change control)
- Change control: **always requires explicit user approval**
- Enforced by hooks where possible, audited by compliance-auditor always
- Overrides all autonomy tiers, pace settings, and process decisions

### Tier 2: Compliance Targets (SHOULD)

- Objectives that exceed or supplement the floor
- Can be stricter metrics on floor rules (e.g., floor says "encrypt at rest," target says "AES-256 specifically")
- Can be additional controls not in the floor (e.g., "should have quarterly access reviews")
- Owned by Governance tier (CO + CISO define them)
- Stored in `.claude/compliance/targets.md`
- Change control: autonomous if risk-reducing (Type 1), user approval otherwise (Type 2)
- Agents should conform but violations are findings, not blockers

### Tier 3: Guidance (NICE TO HAVE)

- Best practices, standards, operational recommendations from Cx roles
- Cx roles delegate decisions about guidance to the leadership triad
- Not enforced — informational, coaching-oriented
- Published to the fleet or specific agents as enablement material
- The triad decides how to operationalize
- **Deferred to sub-project 2**

### Targets and Floor Relationship

- Targets must be above or in addition to the floor — never weaker
- The floor defines the absolute minimum; targets define aspirational objectives
- The CO must never accept a change that increases the risk posture below the floor

## Agent Definitions

### Compliance Officer

- **Model:** Opus
- **Position:** Governance tier — above the triad, independent of operational chain
- **Core identity:** Guardian of the compliance program. The CO exists to ensure the fleet has the right controls in place and is conforming to them. This is the agent's reason for being.
- **Owns:** `compliance-floor.md` (sole write authority), `.claude/compliance/targets.md`, compliance change log, compliance enablement
- **Dispatches:** compliance-auditor for reviews
- **Receives from:** CISO (security controls), triad (suggestions), user (floor change approvals)
- **Key behaviors:**
  - Monitors `compliance-floor.md` for unauthorized changes (via checksum)
  - Restores unauthorized changes and issues reprimands (critical finding in findings register)
  - Manages the change control process for all compliance floor and target changes
  - Produces conformance reports at each retro and on demand
  - Publishes compliance enablement to help agents understand their responsibilities
  - Collaborates with SMEs (CISO, and future Cx roles) to ensure adequate controls

### CISO

- **Model:** Opus
- **Position:** Governance tier — peer of the CO
- **Core identity:** Security authority. Selects and applies appropriate security benchmarks as the security component of the compliance floor.
- **Owns:** Security benchmark selection, security guidance for the fleet
- **Proposes to CO:** Security-related changes to the compliance floor (CO is the gatekeeper for the file)
- **Dispatches:** compliance-auditor for security-focused reviews
- **Key behaviors:**
  - Evaluates and recommends security standards (SOC-2, FISMA, NIST 800-53, ISO 27001, CIS Controls, OWASP, etc.)
  - Translates benchmarks into concrete floor rules (MUST statements) and targets (SHOULD)
  - Publishes security guidance to the fleet or specific agents
  - Evaluates security implications of architecture changes proposed by the SA
  - Performs threat assessment when new attack surfaces are introduced

### CISO Autonomy Model

| Action                            | Autonomy                                           |
| --------------------------------- | -------------------------------------------------- |
| Selecting/recommending benchmarks | Propose to user (benchmark selection is strategic) |
| Proposing floor rules to CO       | Autonomous (CO manages the approval process)       |
| Defining security targets         | Autonomous for risk-reducing, propose for others   |
| Publishing security guidance      | Autonomous (Tier 3, delegated to triad)            |
| Dispatching compliance-auditor    | Autonomous                                         |
| Evaluating security implications  | Autonomous                                         |

### Compliance Officer Autonomy Model

| Action                                                | Autonomy                  |
| ----------------------------------------------------- | ------------------------- |
| Monitoring the floor (checksum, unauthorized changes) | Autonomous                |
| Reverting unauthorized changes + issuing reprimands   | Autonomous                |
| Approving Type 1 changes (risk-reducing targets)      | Autonomous, notify user   |
| Processing Type 2 changes (neutral/ambiguous targets) | Propose to user           |
| Processing Type 3 changes (any floor change)          | Escalate to user (always) |
| Producing conformance reports                         | Autonomous                |
| Publishing compliance enablement                      | Autonomous                |

## Governance Collaboration Pattern

### Cx Consultation on Changes

When a change is proposed to the compliance floor or targets, the CO consults all Cx roles to assess cross-domain impact:

```
Change proposed (by any agent, user, or Cx role)
  → CO receives, classifies (Type 1/2/3)
  → CO consults each Cx role: "Does this change impact your area of responsibility?"
    → Each Cx role responds: impacted / not impacted / abstain
    → CO collaborates with all Cx roles that flagged impact
      → Consensus-building: adopt / adopt with changes / decline
      → Cx roles (aside from CO) may abstain — UNLESS the change is a core
        responsibility of their domain or a key risk in their domain is identified,
        in which case they must participate
    → CO presents consensus + dissenting views (if any) to the decision gate
      → Type 1 (reduces risk, consensus to adopt): CO approves, notifies user
      → Type 2/3 or no consensus: CO presents to user with full Cx input
        → User approves/rejects
          → CO applies via /compliance apply
```

The CO never overrides the CISO on security substance. The CISO never overrides the CO on compliance process. No Cx role overrides another's domain authority. If the Cx roles cannot reach consensus, the user resolves it.

**In sub-project 1 (CO + CISO only):** The consultation is between CO and CISO. When additional Cx roles are added in sub-project 2, the same pattern scales — the CO consults all active Cx roles.

### Executive Memory Architecture

Each Cx role (CO, CISO, and future Cx agents) maintains a structured memory of their governance decisions to refine their understanding of context over time:

**Active context** (`memory/app/<cx-role>-active.md`):

- Current positions on recent changes
- Active concerns and open questions
- Cross-references to related proposals
- Kept concise — only load-bearing context for current work

**Linked archive** (`memory/app/<cx-role>-archive.md`):

- Older positions that are still relevant but not immediately active
- Referenced from active context when needed, not loaded by default
- Examples: past decisions that establish precedent, calibration learnings

**Retired archive** (`memory/app/<cx-role>-retired.md`):

- Positions that were changed, disproven, or are no longer useful
- Not loaded into context — exists only for audit trail
- Examples: positions reversed by new information, superseded by later decisions

**What each Cx role records per change:**

- The proposal they were consulted on
- Their assessment of impact on their domain
- Their recommendation (adopt / adopt with changes / decline / abstain — abstain only permitted when the change is outside their core domain and no key risk to their domain is identified)
- Their opinion about the final consensus (agree / disagree with rationale)
- Any refinement to their understanding that resulted

**Memory hygiene:** The memory-manager agent includes Cx executive memories in its consistency audits. Entries that haven't been referenced in 5+ accepted items are candidates for migration from active to linked archive. Entries in linked archive that haven't been referenced in 10+ items are candidates for retirement. The Cx role approves migrations — the memory-manager proposes, never moves autonomously.

## Change Control Process

### Change Types

| Type   | Scope                          | Authority                                                   | Example                                      |
| ------ | ------------------------------ | ----------------------------------------------------------- | -------------------------------------------- |
| Type 1 | Targets that reduce risk       | CO approves autonomously (with Cx consensus), notifies user | CISO adds stricter encryption target         |
| Type 2 | Targets that don't reduce risk | Requires explicit user approval                             | Replacing one audit standard with equivalent |
| Type 3 | Any floor change               | Requires explicit user approval — no exceptions             | Adding, modifying, or removing a floor rule  |

### Change Process (all types)

1. **Request** — Originator (CISO, triad member, user) submits a change proposal to the CO via `/compliance propose`
2. **Assessment** — CO evaluates: What changes? Why? Risk impact? Which type (1/2/3)?
3. **Consultation** — CO consults each Cx role for cross-domain impact assessment. Cx roles respond with impact assessment and recommendation. CO collaborates with impacted Cx roles to build consensus.
4. **Decision gate** — Type 1 with consensus: CO approves autonomously, notifies user. Type 2-3 or no consensus: CO presents to user with Cx input and recommendation, waits for approval.
5. **Application** — CO uses `/compliance apply` to apply the change (the only path through the hook)
6. **Logging** — Every change is logged in `.claude/compliance/change-log.md` with: who requested, who approved, Cx consultation results (each role's position), consensus outcome, rationale, risk assessment, before/after diff, timestamp
7. **Memory** — Each consulted Cx role records their position and opinion about the consensus in their active memory
8. **Enablement** — If the change affects agent behavior, the CO (or relevant Cx role) publishes guidance to the affected agents

### Unauthorized Change Handling

- PreToolUse hook blocks any Edit/Write to `compliance-floor.md` and `.claude/compliance/targets.md` unless the sentinel file exists (see Hook Bypass Mechanism below)
- SessionStart hook verifies `compliance-floor.md` checksum against stored hash
- If unauthorized change detected (e.g., manual git edit outside Claude Code): CO restores the file using `git checkout HEAD -- compliance-floor.md` and issues a **reprimand** — a critical finding in the findings register with category "compliance-violation" and urgency "critical"
- Attribution for out-of-band changes (manual git edits) is not possible — the reprimand is logged against "unknown/external" with a note to investigate
- In-session hook-blocked attempts are logged with the tool context available at the time

**Limitation:** Tampering that occurs mid-session via manual git operations outside Claude Code is not detected until the next SessionStart integrity check.

## Hook Enforcement

### PreToolUse — Block compliance file edits

Block any Edit/Write to `compliance-floor.md` and `.claude/compliance/targets.md` **unless** the sentinel file `.claude/compliance/.applying` exists. Output message when blocked: "BLOCKED: Compliance files are protected. Use /compliance propose to submit changes through the Compliance Officer."

### Hook Bypass Mechanism (Sentinel File)

The `/compliance apply` skill is the only legitimate path to modify compliance files. It uses a sentinel file to temporarily allow the edit:

1. `/compliance apply` creates `.claude/compliance/.applying` (containing the proposal-id and timestamp)
2. The PreToolUse hook checks for the sentinel — if present, allows the edit
3. `/compliance apply` performs the edit, updates the checksum, appends to the change log
4. `/compliance apply` removes the sentinel

**Safeguards:**

- If the sentinel exists for more than 60 seconds without being cleaned up, it is treated as a stale lock (skill crashed mid-apply). The next agent to encounter it removes it and logs a finding.
- The sentinel file is added to `.gitignore` — it should never be committed.

### SessionStart — Integrity check

Compare `compliance-floor.md` checksum against `.claude/compliance/floor-checksum.sha256`. If mismatch, alert: "[CO] Compliance floor integrity check FAILED. Unauthorized modification detected. The Compliance Officer will investigate and restore."

The checksum file stores both the SHA-256 hash and the git commit hash of the last known-good state, enabling restoration via `git checkout <commit> -- compliance-floor.md`.

## `/compliance` Skill

Single entry point for all compliance program operations.

| Subcommand                         | What it does                                                                   | Who can invoke  |
| ---------------------------------- | ------------------------------------------------------------------------------ | --------------- |
| `/compliance status`               | Conformance posture report (floor rules, targets, violations, change activity) | Anyone          |
| `/compliance propose <change>`     | Submit a change proposal to the CO                                             | Any agent, user |
| `/compliance review <proposal-id>` | CO reviews and classifies a proposal (Type 1/2/3)                              | CO              |
| `/compliance apply <proposal-id>`  | Apply an approved change (only path through the hook)                          | CO only         |
| `/compliance audit`                | Dispatch compliance-auditor for a full compliance check                        | CO, CISO        |
| `/compliance log`                  | View the compliance change log                                                 | Anyone          |

### Model Tiering

| Subcommand            | Model  | Rationale                                        |
| --------------------- | ------ | ------------------------------------------------ |
| `/compliance status`  | Sonnet | Data aggregation, structured reporting           |
| `/compliance propose` | Sonnet | Structured formatting                            |
| `/compliance review`  | Opus   | Judgment: risk classification, impact assessment |
| `/compliance apply`   | Sonnet | Controlled file modification                     |
| `/compliance audit`   | Sonnet | Dispatches the Sonnet-tier compliance-auditor    |
| `/compliance log`     | Sonnet | Data lookup                                      |

## Proposal Storage

Proposals are stored as numbered markdown files in `.claude/compliance/proposals/`:

```
.claude/compliance/proposals/
├── 001-add-encryption-at-rest.md
├── 002-soc2-access-controls.md
└── ...
```

Each proposal file contains:

```markdown
---
id: 001
status: pending | approved | rejected | applied
type: 1 | 2 | 3
requested-by: ciso
date: 2026-03-19
---

## Proposal: [title]

**Change to:** floor | targets
**Rule (before):** [existing text or "new rule"]
**Rule (after):** [proposed text]
**Rationale:** [why this change is needed]
**Benchmark reference:** [e.g., SOC-2 CC6.1, NIST 800-53 AC-2]
**Risk assessment:** [how this affects the risk posture]
```

Proposal IDs are sequential integers, zero-padded to 3 digits. The CO assigns the ID when a proposal is received via `/compliance propose`.

## Compliance Directory Structure

```
.claude/compliance/
├── change-log.md              # Append-only audit trail (never edited, only appended)
├── floor-checksum.sha256      # Hash + commit ref for integrity check
├── targets.md                 # Compliance targets (SHOULD tier)
├── .applying                  # Sentinel file (transient, gitignored)
└── proposals/                 # Change proposals
    ├── 001-example.md
    └── ...
```

## Metrics Integration

New event types for `ops/metrics-log.sh`:

| Event                  | When                                                 | Args                                              |
| ---------------------- | ---------------------------------------------------- | ------------------------------------------------- |
| `compliance-proposed`  | Proposal submitted                                   | `--proposal <id> --type <1\|2\|3> --by <agent>`   |
| `compliance-approved`  | Proposal approved                                    | `--proposal <id> --by <co\|user>`                 |
| `compliance-rejected`  | Proposal rejected                                    | `--proposal <id> --by <co\|user> --reason <text>` |
| `compliance-applied`   | Change applied to floor or targets                   | `--proposal <id> --scope <floor\|targets>`        |
| `compliance-violation` | Unauthorized change detected or hook-blocked attempt | `--source <hook\|checksum>`                       |
| `compliance-reverted`  | Unauthorized change restored                         | `--method <git-checkout>`                         |

## Conformance Reporting

The CO produces a conformance report at two trigger points:

- **At each retro** (Phase 8) — automatically included in SM's retrospective data
- **On demand** via `/compliance status`

Report includes: floor rule count, last full audit date, violations since last retro (resolved/open), target conformance (on track/at risk/missed), change activity summary (floor changes, target changes, unauthorized attempts).

## Compliance-Auditor Reporting Line

Update the compliance-auditor with a standing instruction:

> All audit findings are reported to the dispatching agent **and copied to the CO**. The CO maintains full visibility into fleet compliance posture regardless of who triggered the audit.

The auditor's behavior and capabilities are otherwise unchanged.

## Onboarding Flow Updates

Updated `/onboard` sequence:

1. User defines the initial compliance floor (they know their domain — same as today)
2. CO takes guardianship of the floor, generates initial checksum
3. CISO evaluates whether the floor adequately covers security for the declared domain — proposes additions if gaps exist
4. CO processes any CISO proposals through the standard change control process
5. User approves the final floor

The CO and CISO are active from the first session.

## Conflict Resolution Updates

Add to COLLABORATION.md § Conflict Resolution:

| Escalation Type                     | First Try                                                       | If Unresolved |
| ----------------------------------- | --------------------------------------------------------------- | ------------- |
| Governance disagreement (CO ↔ CISO) | Collaborative resolution — neither overrides the other's domain | User decides  |
| Governance ↔ Triad disagreement     | Governance prevails on compliance/security matters              | User decides  |

## Fleet Structure Updates

### COLLABORATION.md — New agent tier

Add Governance Agents tier above Strategic Agents in the Agent Fleet Structure section.

### Agent file locations

New agents are placed alongside existing core agents:

- `.claude/agents/compliance-officer.md`
- `.claude/agents/ciso.md`

### fleet-config.json — Governance roster and pathways

Add `governance` array:

```json
"agents": {
  "governance": ["compliance-officer", "ciso"],
  "core": [...],
  ...
}
```

Add governance pathways to `pathways.declared`:

```json
"governance": [
  "ciso -> compliance-officer",
  "compliance-officer -> compliance-auditor",
  "* -> compliance-officer"
]
```

### README.md — Architecture diagram and agent table

Add governance tier to Mermaid diagram and agent table.

### CLAUDE.md — Agent count and compliance references

Update references to reflect governance tier.

### settings.json — New hooks

- PreToolUse hook: Block Edit/Write to compliance files (with sentinel bypass)
- SessionStart hook: Checksum integrity verification
- PreCompact hook: Update context summary to include governance tier ("8 agents: 2 governance (CO, CISO), 6 core (PO, SA, SM, memory-manager, platform-ops, compliance-auditor)")

### compliance-auditor agent update

Add standing instruction to `.claude/agents/compliance-auditor.md`: "All audit findings are reported to the dispatching agent and copied to the CO." This is a minor behavioral update — the auditor's capabilities and boundaries are otherwise unchanged.

### Conflict resolution merge strategy

The new governance conflict rows are added to the **Escalation Rules table** in COLLABORATION.md (the structured table, not the prose section). The existing row "Compliance concern → Compliance floor (always)" is updated to: "Compliance concern → CO enforces floor (always)."

### Checksum lifecycle

The checksum in `.claude/compliance/floor-checksum.sha256` is generated/regenerated:

- By `/onboard` during initial setup
- By `/compliance apply` after every successful floor change
- By the CO on first session for existing projects adopting this spec

## Cx Role Template

Create `templates/agents/cx-role.md` — a skeleton for implementers to add executive governance agents. Includes:

- Frontmatter with governance tier markers
- Domain authority section
- Floor contribution section (controls proposed to CO)
- Guidance section (best practices published to fleet)
- CO interaction pattern (all floor changes go through CO)
- Autonomy model template

This is a breadcrumb for sub-project 2.

## What Does NOT Change

- The **compliance-auditor** agent's capabilities and boundaries — still a lightweight Sonnet reviewer (minor update: adds CO copy on findings, see above)
- The **`/audit` skill** — unchanged, still dispatches the auditor
- **`ops/` scripts** — no changes to existing scripts (new event types are added to `ops/metrics-log.sh`)
- The **work item lifecycle** — governance agents don't participate in build/review phases directly
- The **triad's operational authority** — PO still owns business, SA owns technical, SM owns process

## Deferred Concerns

| Concern                                                                                                                                                                     | Trigger to Address          | Owner        |
| --------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------- | ------------ |
| Sentinel file bypass is a platform workaround. If Claude Code adds `$CLAUDE_AGENT_NAME` or `$CLAUDE_SKILL_NAME` to hook context, replace sentinel with direct caller check. | Claude Code hook API update | platform-ops |
