# Expanded Behavioral Feedback — Specialist Recommendations with Escalation

**Issue:** [#28](https://github.com/rdunie/venutian-antfarm/issues/28)
**Date:** 2026-03-28
**Status:** Draft

## Problem

Only 10 agents (7 governance + PO, SA, SM) can issue behavioral feedback. Specialist and reviewer agents observe behavior directly (e.g., a security-reviewer sees shallow work from a backend-specialist) but cannot record that observation. Valuable signals are lost because the agents closest to the work have no voice in the feedback system.

## Goals

1. **Universal feedback participation** -- every agent can propose behavioral feedback, not just governance and core agents.
2. **Tiered authority** -- specialist proposals route through a supervisor for formalization. Governance/core agents retain direct issuance.
3. **Escalation enforcement** -- stale proposals auto-escalate so supervisors cannot silently ignore specialist observations.
4. **Origin tracking** -- every ledger entry records its origin tier so adaptive weighting (#25) can key off it later.
5. **Natural trigger points** -- agents know when and why to propose feedback through domain-specific triggers, handoff prompts, and completion reminders.

## Non-Goals

- Adaptive weight math (future: #25 -- this spec lays the data foundation only)
- Auto-blocking or auto-promotion based on proposal counts
- Changing the existing direct feedback flow for governance/core agents
- Signal bus integration (#24 -- forward-compatible but not dependent)

## Approach

**Recommendation model** within the existing single-script architecture. Specialists call `recommend` to create a pending proposal (`P-xxx`). The resolved supervisor calls `formalize` or `reject`. A `check-escalations` subcommand enforces deadlines programmatically via hooks and retro. The script is renamed from `rewards-log.sh` to `feedback-log.sh` to reflect its expanded scope.

## Design

### 1. Proposal Lifecycle

```
specialist --recommend--> P-xxx (pending)
                            |
              +-----------+-----------+
              |           |           |
         formalize     reject     escalate (auto)
              |           |           |
         R/K-xxx      P-xxx        P-xxx reassigned
        (new entry)   (rejected)   to next-tier supervisor
```

Proposals use the `P-xxx` ID prefix. States: `pending` -> `formalized` | `rejected` | `escalated`.

When formalized, a new `R-xxx` or `K-xxx` entry is created with `**Origin:** P-xxx`. The P-entry status updates to `formalized (R-015)`. The original proposal is never rewritten -- status updates and backrefs preserve the append-only contract.

### 2. Proposal Ledger Entry

```markdown
### P-001 [proposal] 2026-03-28 -- security-reviewer / security

**Type:** reprimand
**Severity:** medium
**Subject:** backend-specialist
**Item:** 42
**Description:** Shallow input validation on API endpoint
**Evidence:** No sanitization in handler.ts:45
**Supervisor:** ciso
**Status:** pending
**Escalation deadline:** 2026-04-04
```

### 3. Origin Tier Tracking

Every ledger entry records its origin tier:

| Tier         | Agents                                | Feedback mode            | Weight hint               |
| ------------ | ------------------------------------- | ------------------------ | ------------------------- |
| `governance` | CRO, CISO, CEO, CTO, CFO, COO, CKO    | Direct (kudo/reprimand)  | highest                   |
| `core`       | PO, SA, SM                            | Direct (kudo/reprimand)  | high                      |
| `specialist` | All specialist/reviewer/output agents | Propose only (recommend) | lower (via formalization) |

Direct entries include `**Origin tier:** governance` or `**Origin tier:** core`. Formalized entries include `**Origin tier:** specialist` and `**Origin:** P-xxx`.

The `profile` subcommand extends to show feedback by origin tier alongside the existing by-domain breakdown.

### 4. Feedback Pathways & Supervisor Resolution

Fleet-config gets a new `feedback` pathway type under `pathways.declared`:

```json
"feedback": [
  "backend-specialist -> solution-architect",
  "security-reviewer -> ciso",
  "frontend-specialist -> product-owner",
  "e2e-test-engineer -> product-owner"
]
```

**Resolution order:**

1. Check `pathways.declared.feedback` for an explicit mapping for the issuer
2. Fall back to `pathways.declared.escalation` wildcards (`* -> SA`, `* -> PO`, `* -> SM`) -- first match wins
3. If no match found, reject the recommendation with an error

### 5. Escalation Chain

When a supervisor does not act on a proposal within the deadline:

1. Resolve the supervisor's own supervisor from `pathways.declared.governance` (e.g., `ciso -> cro` means CRO oversees CISO)
2. If no governance path found, escalate to CEO (terminal escalation)
3. The `check-escalations` subcommand updates the P-entry: new supervisor, reset deadline, status note `escalated from <previous>`
4. A findings register entry is created for visibility
5. A `feedback-escalated` metric event is emitted

**Escalation deadline** is configurable:

```json
"rewards": {
  "escalation_deadline_days": 7
}
```

### 6. Programmatic Enforcement

The escalation deadline is enforced at two natural touchpoints:

1. **SessionStart hook** -- runs `ops/feedback-log.sh check-escalations` at every session start. Past-deadline proposals are auto-escalated and surfaced in PO status output.
2. **SM retro phase** -- during Phase 8 (Retro), `feedback-log.sh check-escalations` runs as a mandatory step before the retro summary.
3. **Formalization nudge** -- when a governance/core agent issues direct feedback via `kudo`/`reprimand`, the script checks if they have pending proposals awaiting action and warns them (nudge, not block).

### 7. Script Changes (`feedback-log.sh`)

Rename `ops/rewards-log.sh` to `ops/feedback-log.sh`. Existing subcommands unchanged. New subcommands:

| Subcommand          | Who calls it     | What it does                                                                                |
| ------------------- | ---------------- | ------------------------------------------------------------------------------------------- |
| `recommend`         | Any agent        | Creates `P-xxx` entry, resolves supervisor from feedback/escalation pathways, sets deadline |
| `formalize <P-id>`  | Named supervisor | Creates new `R/K-xxx` with `Origin: P-xxx`, updates P-entry to `formalized`                 |
| `reject <P-id>`     | Named supervisor | Updates P-entry to `rejected`, requires `--reason`                                          |
| `check-escalations` | Hook / SM retro  | Scans for past-deadline pending proposals, auto-escalates, emits metric events              |

**`recommend` parameters:**

- Required: `--issuer`, `--subject`, `--type` (kudo|reprimand), `--domain`, `--description`, `--evidence`
- Required if type is reprimand: `--severity`
- Optional: `--item`

**`formalize` validation:**

- Caller's `--issuer` must match the P-entry's current `Supervisor` field
- P-entry must be in `pending` status

**`reject` validation:**

- Same issuer/status checks as `formalize`
- Requires `--reason`

### 8. New Metric Events

| Event                 | Fields                                                                                                  | When                        |
| --------------------- | ------------------------------------------------------------------------------------------------------- | --------------------------- |
| `feedback-proposed`   | `issuer`, `subject`, `type` (kudo/reprimand), `domain`, `severity`, `item`, `proposal_id`, `supervisor` | Recommendation created      |
| `feedback-formalized` | `proposal_id`, `reward_id`, `formalizer`                                                                | Supervisor formalizes       |
| `feedback-rejected`   | `proposal_id`, `rejector`, `reason`                                                                     | Supervisor rejects          |
| `feedback-escalated`  | `proposal_id`, `from_supervisor`, `to_supervisor`                                                       | Auto-escalation on deadline |

Existing events (`reward-issued`, `tension-detected`) unchanged. Direct feedback from governance/core still emits `reward-issued`. Formalization emits both `feedback-formalized` and `reward-issued` (for the new R/K entry).

### 9. Agent Feedback Triggers

Feedback awareness is layered across three mechanisms:

**Layer 1: Domain-specific triggers (agent definitions)**
Each specialist template gets criteria for when to propose feedback. Examples:

- security-reviewer: "When reviewing code, if you find critical vulnerabilities that should have been caught earlier, propose a reprimand. If the code demonstrates strong security practices, propose a kudo."
- e2e-test-engineer: "When tests reveal systematic quality issues or exceptional coverage, propose feedback."

**Layer 2: Handoff-aware prompting (handoff skill)**
When a specialist receives work via handoff, the handoff skill includes a reminder to evaluate the sender's work quality and propose feedback if warranted.

**Layer 3: SubagentStop hook (catch-all)**
The existing SubagentStop hook is extended with: "Before finishing, consider whether any agent you interacted with deserves a kudo or reprimand. Use `ops/feedback-log.sh recommend` if so."

### 10. Agent Definition Changes

**Specialist agent templates** (`templates/agents/`) -- add to all 5 (backend-specialist, frontend-specialist, security-reviewer, e2e-test-engineer, infrastructure-ops):

```markdown
## Behavioral Feedback

You may propose behavioral feedback using `ops/feedback-log.sh recommend`. Your proposals
route to your designated supervisor for formalization. You cannot issue kudos or reprimands
directly.

- **Propose reprimands:** When another agent's work falls short of standards in your domain. Include evidence and severity.
- **Propose kudos:** When another agent demonstrates excellence observable from your domain. Include evidence.
- **Judgment:** Propose feedback at natural review points (after receiving handoffs, during reviews). Reserve proposals for patterns or notable events, not every minor observation.
```

**Governance + core agents** (`.claude/agents/`) -- update the 10 existing issuers:

- Rename all `rewards-log.sh` references to `feedback-log.sh`
- Add formalization responsibility: "Review pending proposals from your reports. Use `ops/feedback-log.sh formalize <P-id>` or `ops/feedback-log.sh reject <P-id> --reason '...'`"

**SM agent** -- extend behavioral profile review to include pending proposals and escalation status.

### 11. Fleet-Config Changes

```json
"rewards": {
  "escalation_deadline_days": 7
},
"pathways": {
  "declared": {
    "feedback": [
      "backend-specialist -> solution-architect",
      "security-reviewer -> ciso",
      "frontend-specialist -> product-owner",
      "e2e-test-engineer -> product-owner"
    ]
  }
}
```

### 12. Rename Plan

| From                            | To                                                                            |
| ------------------------------- | ----------------------------------------------------------------------------- |
| `ops/rewards-log.sh`            | `ops/feedback-log.sh`                                                         |
| `ops/tests/test-rewards-log.sh` | `ops/tests/test-feedback-log.sh`                                              |
| `REWARDS_LEDGER` env var        | `FEEDBACK_LEDGER` (keep `REWARDS_LEDGER` as deprecated alias for one version) |
| `REWARDS_CHECKSUM` env var      | `FEEDBACK_CHECKSUM` (keep `REWARDS_CHECKSUM` as deprecated alias)             |
| Agent refs to `rewards-log.sh`  | Updated to `feedback-log.sh`                                                  |
| CLAUDE.md command docs          | Updated to `feedback-log.sh`                                                  |

## File Inventory

### New Files

None -- all changes are to existing files.

### Modified Files

| File                                                                | Change                                                                                                                   |
| ------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------ |
| `ops/rewards-log.sh` -> `ops/feedback-log.sh`                       | Rename + add `recommend`, `formalize`, `reject`, `check-escalations` subcommands + origin tier tagging on direct entries |
| `ops/tests/test-rewards-log.sh` -> `ops/tests/test-feedback-log.sh` | Rename + add tests for new subcommands                                                                                   |
| `ops/metrics-log.sh`                                                | Add `feedback-proposed`, `feedback-formalized`, `feedback-rejected`, `feedback-escalated` event types                    |
| `.claude/settings.json`                                             | SessionStart hook adds `check-escalations`; SubagentStop hook adds feedback prompt; update ledger protection refs        |
| `.claude/agents/*.md` (10 agents)                                   | Rename `rewards-log.sh` -> `feedback-log.sh`, add formalization responsibility                                           |
| `templates/agents/*.md` (5 templates)                               | Add `## Behavioral Feedback` section with propose-only capability and domain triggers                                    |
| `templates/fleet-config.json`                                       | Add `escalation_deadline_days` to `rewards`, add `feedback` pathway type                                                 |
| `CLAUDE.md`                                                         | Update Commands section, rename references                                                                               |
| `.claude/skills/handoff.md`                                         | Add feedback evaluation prompt on handoff receipt                                                                        |
| `.claude/skills/retro.md`                                           | Add mandatory `check-escalations` step                                                                                   |

## Related Issues

- [#13](https://github.com/rdunie/venutian-antfarm/issues/13) -- Rewards system (base system, completed)
- [#25](https://github.com/rdunie/venutian-antfarm/issues/25) -- Adaptive weighting (consumes origin tier data)
- [#24](https://github.com/rdunie/venutian-antfarm/issues/24) -- Signal bus (future replacement for direct script calls)
