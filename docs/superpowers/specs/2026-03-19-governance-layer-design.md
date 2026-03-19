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

## CO-CISO Interaction Pattern

```
CISO identifies security control needed
  → CISO submits /compliance propose with security rationale + benchmark reference
    → CO receives, classifies (Type 1/2/3), assesses risk impact
      → Type 1 (reduces risk): CO approves, applies, notifies user
      → Type 2/3: CO presents to user with CISO's rationale + CO's assessment
        → User approves/rejects
          → CO applies via /compliance apply
```

The CO never overrides the CISO on security substance. The CISO never overrides the CO on compliance process. If they disagree, the user resolves it.

## Change Control Process

### Change Types

| Type   | Scope                          | Authority                                       | Example                                      |
| ------ | ------------------------------ | ----------------------------------------------- | -------------------------------------------- |
| Type 1 | Targets that reduce risk       | CO approves autonomously, notifies user         | CISO adds stricter encryption target         |
| Type 2 | Targets that don't reduce risk | Requires explicit user approval                 | Replacing one audit standard with equivalent |
| Type 3 | Any floor change               | Requires explicit user approval — no exceptions | Adding, modifying, or removing a floor rule  |

### Change Process (all types)

1. **Request** — Originator (CISO, triad member, user) submits a change proposal to the CO via `/compliance propose`
2. **Assessment** — CO evaluates: What changes? Why? Risk impact? Which type (1/2/3)?
3. **Decision gate** — Type 1: CO approves autonomously, notifies user. Type 2-3: CO presents to user with recommendation, waits for approval.
4. **Application** — CO uses `/compliance apply` to apply the change (the only path through the hook)
5. **Logging** — Every change is logged in `.claude/compliance/change-log.md` with: who requested, who approved, rationale, risk assessment, before/after diff, timestamp
6. **Enablement** — If the change affects agent behavior, the CO (or CISO for security) publishes guidance to the affected agents

### Unauthorized Change Handling

- PreToolUse hook blocks any Edit/Write to `compliance-floor.md` and `.claude/compliance/targets.md`
- SessionStart hook verifies `compliance-floor.md` checksum against stored hash
- If unauthorized change detected (e.g., manual git edit outside Claude Code): CO reverts and issues a **reprimand** — a critical finding in the findings register with category "compliance-violation"
- Repeated violations by the same agent trigger escalation to the user

## Hook Enforcement

### PreToolUse — Block compliance file edits

Block any Edit/Write to `compliance-floor.md` and `.claude/compliance/targets.md`. Output message: "BLOCKED: Compliance files are protected. Use /compliance propose to submit changes through the Compliance Officer."

### SessionStart — Integrity check

Compare `compliance-floor.md` checksum against `.claude/compliance/floor-checksum.sha256`. If mismatch, alert: "[CO] Compliance floor integrity check FAILED. Unauthorized modification detected. The Compliance Officer will investigate and restore."

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

## Compliance Directory Structure

```
.claude/compliance/
├── change-log.md              # Append-only audit trail (never edited, only appended)
├── floor-checksum.sha256      # Integrity check for compliance-floor.md
└── targets.md                 # Compliance targets (SHOULD tier)
```

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

### fleet-config.json — Governance roster

Add `governance` array:

```json
"agents": {
  "governance": ["compliance-officer", "ciso"],
  "core": [...],
  ...
}
```

### README.md — Architecture diagram and agent table

Add governance tier to Mermaid diagram and agent table.

### CLAUDE.md — Agent count and compliance references

Update references to reflect governance tier.

### settings.json — New hooks

Add PreToolUse and SessionStart hooks for compliance file protection and integrity checking.

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

- The **compliance-auditor** agent — unchanged, still a lightweight Sonnet reviewer
- The **`/audit` skill** — unchanged, still dispatches the auditor
- **`ops/` scripts** — no changes needed
- The **work item lifecycle** — governance agents don't participate in build/review phases directly
- The **triad's operational authority** — PO still owns business, SA owns technical, SM owns process
