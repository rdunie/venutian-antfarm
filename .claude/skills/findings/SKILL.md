---
name: findings
description: "Manage the findings register. Log findings, review patterns, triage open items, track refinement effectiveness."
argument-hint: "[log <text>|review|patterns|triage]"
---

# Findings

Manage the findings register as defined in `.claude/COLLABORATION.md` § Learning Through Findings.

## Usage

- `/findings log "Handoff from backend lacked schema diff"` -- Log a new finding
- `/findings log "Handoff from backend lacked schema diff" --urgency high --category boundary-tension` -- Log with metadata
- `/findings review` -- SM reviews open findings, groups by pattern, proposes refinements
- `/findings patterns` -- Analyze recurring finding types and refinement effectiveness
- `/findings triage` -- Route unprocessed findings to the appropriate agent

## Workflow: Log

1. **Parse arguments.** Extract the finding description, urgency (default: normal), and category (default: infer from description).

2. **Format the finding.** Create an entry using the register format from `.claude/findings/register.md`:

   ```markdown
   ### [DATE] [URGENCY] -- [BRIEF TITLE]

   **Found by:** [current agent or user]
   **Category:** surprise | pattern | boundary-tension | learning | success
   **Description:** [what happened]
   **Proposed action:** [what should change]
   **Status:** open
   ```

3. **Append to register.** Add the entry under "## Active Findings" in `.claude/findings/register.md`.

4. **Acknowledge.** Confirm the finding was logged with its urgency. If urgency is critical, alert: "Critical finding logged. Escalate immediately per protocol."

## Workflow: Review

1. **Read the register.** Load `.claude/findings/register.md`.

2. **Dispatch SM agent.** The scrum-master reviews open findings:
   - Group by category
   - Identify patterns (same category recurring = refinement not landing)
   - Propose refinements for each pattern (specific, measurable, scoped)
   - Recommend status changes: accepted, deferred, or dismissed with rationale

3. **Present to user.** Show grouped findings with SM's proposals. Wait for user to approve, modify, or defer each proposal.

4. **Apply approved changes.** Update finding statuses in the register. If a refinement changes agent behavior, note which agent definition or memory needs updating.

## Workflow: Patterns

1. **Read the register.** Load `.claude/findings/register.md`.

2. **Analyze.** Count findings by category, by urgency, by status. Identify:
   - Categories with rising counts (refinements not working)
   - Categories with declining counts (refinements landing)
   - Agents that generate the most findings
   - Time-to-resolution for accepted findings

3. **Report.** Present a structured summary with trend indicators.

## Workflow: Triage

1. **Read the register.** Filter for `Status: open` findings.

2. **Route each finding.** Based on category and content, recommend which agent should own the response:
   - boundary-tension → SM
   - surprise (technical) → SA
   - surprise (business) → PO
   - pattern → SM for review
   - success → SM for distribution

3. **Present routing recommendations.** User confirms or adjusts.

## Model Tiering

| Subcommand           | Model  | Rationale                                        |
| -------------------- | ------ | ------------------------------------------------ |
| `/findings log`      | Sonnet | Structured formatting, minimal judgment          |
| `/findings review`   | Opus   | Judgment: pattern analysis, refinement proposals |
| `/findings patterns` | Sonnet | Data aggregation, structured reporting           |
| `/findings triage`   | Sonnet | Routing logic, structured output                 |

## Extensibility

Implementers can override to add domain-specific finding categories (e.g., "compliance-gap", "performance-regression") or integrate with external issue trackers.
