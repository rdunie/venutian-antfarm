---
name: governance
description: "Executive governance operations. Manage the executive brief, publish guidance, grant CEO autonomy."
argument-hint: "[status|brief|decide <id>|grant <description>|guidance <topic>|guidance list]"
---

# Governance

Executive governance operations complementing `/compliance` (which handles floor/targets). Manages the executive brief, CEO autonomy grants, and guidance registry.

## Usage

- `/governance` or `/governance status` -- Executive summary (brief status, guidance count, CEO pace)
- `/governance brief` -- Open the executive brief for review with the user
- `/governance decide 001` -- Resolve a pending decision
- `/governance grant "autonomously prioritize ready backlog items"` -- Grant CEO a specific autonomy scope
- `/governance guidance "TypeScript Required for Backend"` -- Publish new guidance to the registry
- `/governance guidance list` -- Show the guidance registry

## Workflow: Status (default)

1. Read executive brief (`.claude/governance/executive-brief.md`) — count pending decisions, list CEO grants.
2. Read guidance registry (`.claude/governance/guidance-registry.md`) — count active entries.
3. Present one-screen summary: pending decisions, CEO autonomy grants, guidance count.

## Workflow: Brief

1. Dispatch CEO agent (Opus) to review the executive brief.
2. CEO surfaces pending decisions with context and options.
3. Present to user for discussion and resolution.

## Workflow: Decide

1. Load the pending decision by ID from the executive brief.
2. Dispatch CEO (Opus) to present options with Cx input.
3. User decides. CEO records the outcome.
4. Update executive brief: move to Resolved with one-line summary, write decision detail to `.claude/governance/decisions/<date>-<slug>.md`.

## Workflow: Grant

1. Parse the autonomy scope description from arguments.
2. Add to the CEO Autonomy Grants table in executive brief with date and "active" status.
3. Log `ceo-autonomy-granted` event via `ops/metrics-log.sh`.
4. Confirm to user: "CEO granted: [scope]".

## Workflow: Guidance (publish)

1. Parse topic name and prompt the Cx role for guidance content.
2. Determine if small enough to inline or needs a detail doc.
3. Add entry to guidance registry. If detail doc needed, create in `.claude/governance/guidance/<cx-role>/<topic>.md`.
4. Log `guidance-published` event.

## Workflow: Guidance List

1. Read `.claude/governance/guidance-registry.md`.
2. Present active entries.

## Model Tiering

| Subcommand                  | Model  | Rationale                          |
| --------------------------- | ------ | ---------------------------------- |
| `/governance status`        | Sonnet | Data aggregation                   |
| `/governance brief`         | Opus   | Judgment: CEO-user decision-making |
| `/governance decide`        | Opus   | Judgment: decision resolution      |
| `/governance grant`         | Sonnet | Structured update                  |
| `/governance guidance`      | Sonnet | Structured publishing              |
| `/governance guidance list` | Sonnet | Data lookup                        |

## Extensibility

Implementers override for custom decision workflows or governance dashboards.
