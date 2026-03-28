---
name: behavioral
description: "Behavioral floor management. Propose changes, review proposals, apply approved changes, view status. Routes to COO as behavioral floor guardian."
argument-hint: "[status|propose <change> [--domains <d1,d2>]|review <id>|apply <id>|log]"
---

# Behavioral Floor

Manage the behavioral floor through the COO (behavioral floor guardian). All changes to the behavioral floor go through this skill.

## Usage

- `/behavioral` or `/behavioral status` -- Behavioral floor posture report
- `/behavioral propose "We MUST ALWAYS run full validation before handoff"` -- Submit a change proposal
- `/behavioral review 001` -- COO reviews and classifies a proposal
- `/behavioral apply 001` -- COO applies an approved change (only path through the hook)
- `/behavioral log` -- View the behavioral floor change log

## Workflow: Status (default)

1. Read behavioral floor state: `floors/behavioral.md` (count rules), `.claude/floors/behavioral/compiled/` (compilation status).
2. Compile report: floor rule count, last compile date, violations since last retro.
3. Present structured report to user.

## Workflow: Propose

1. Parse the proposed change text from argument.
2. Assign next sequential ID (zero-padded 3 digits) in `.claude/floors/behavioral/proposals/`.
3. Create proposal file with frontmatter (`id`, `status: pending`, `type: TBD`, `requested-by`, `date`) and body.
4. If `--domains` was provided, include domain tags in the proposal file frontmatter as `domains: [d1, d2]`. These are passed to the CRO via COO as advisory triage hints.
5. Dispatch COO agent. COO classifies as Type 1/2/3.
6. COO dispatches CRO subagent for cross-floor risk consultation.
7. CRO facilitates multi-round Cx consultation, returns consolidated assessment.
8. COO presents to user with risk assessment, Cx positions, recommendation.
9. Log `behavioral-floor-proposed` event via `ops/metrics-log.sh`.

## Workflow: Review

1. Load the proposal file.
2. Dispatch COO agent (Sonnet). COO classifies, dispatches CRO for Cx consultation.
3. Decision gate: Type 1 with consensus → COO approves, notifies user. Type 2-3 or no consensus → present to user.
4. Update proposal status. Log event.

## Workflow: Apply

1. Verify proposal status is "approved".
2. Create sentinel: `.claude/floors/behavioral/.applying` with proposal ID and timestamp.
3. Apply the change to `floors/behavioral.md`.
4. Run `ops/compile-floor.sh floors/behavioral.md .claude/floors/behavioral/compiled --proposal <id>` — if compilation fails, revert via `git checkout -- floors/behavioral.md`, remove sentinel, report error.
5. Update checksum in `.claude/floors/behavioral/floor-checksum.sha256`.
6. Remove sentinel. Log `behavioral-floor-applied` event.

## Workflow: Log

1. Read `.claude/floors/behavioral/change-log.md`.
2. Present recent entries.

## Model Tiering

| Subcommand            | Model  | Rationale                                      |
| --------------------- | ------ | ---------------------------------------------- |
| `/behavioral status`  | Sonnet | Data aggregation                               |
| `/behavioral propose` | Opus   | Judgment: risk classification, Cx consultation |
| `/behavioral review`  | Opus   | Judgment: risk assessment                      |
| `/behavioral apply`   | Sonnet | Controlled file modification                   |
| `/behavioral log`     | Sonnet | Data lookup                                    |
