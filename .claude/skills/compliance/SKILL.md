---
name: compliance
description: "Compliance program management. Propose changes, review proposals, apply approved changes, audit conformance, view change log."
argument-hint: "[status|propose <change>|review <id>|apply <id>|audit|log]"
---

# Compliance

Manage the compliance program through the CRO (Chief Risk Officer). All changes to the compliance floor and targets go through this skill.

## Usage

- `/compliance` or `/compliance status` -- Conformance posture report
- `/compliance propose "We MUST ALWAYS encrypt PII at rest"` -- Submit a change proposal
- `/compliance review 001` -- CRO reviews and classifies a proposal
- `/compliance apply 001` -- CRO applies an approved change (only path through the hook)
- `/compliance audit` -- Dispatch compliance-auditor for a full check
- `/compliance log` -- View the compliance change log

## Workflow: Status (default)

1. Read compliance state: `floors/compliance.md` (count rules), `.claude/compliance/targets.md` (count targets), `.claude/compliance/change-log.md` (recent activity), `.claude/findings/register.md` (compliance-related findings).
2. Compile report: floor rule count, last full audit date, violations since last retro, target conformance, change activity summary.
3. Present structured report to user.

## Workflow: Propose

1. Parse the proposed change text from argument.
2. Assign next sequential ID (zero-padded 3 digits) in `.claude/compliance/proposals/`.
3. Create proposal file `.claude/compliance/proposals/<id>-<slug>.md` with frontmatter (`id`, `status: pending`, `type: TBD`, `requested-by`, `date`) and body (`change-to: floor|targets`, rule before/after, rationale, benchmark reference, risk assessment). Prompt user for missing fields.
4. Log `compliance-proposed` event via `ops/metrics-log.sh`. Notify CRO of pending proposal.

## Workflow: Review

1. Load the proposal file.
2. Dispatch CRO agent (Opus). CRO classifies as Type 1/2/3, assesses risk.
3. Cx consultation: CRO dispatches the consultation as a subagent since CRO is both guardian and risk facilitator for the compliance floor. Consults each active Cx role (CISO) for domain impact. Build consensus.
4. Decision gate: Type 1 with consensus -> CRO approves, notifies user. Type 2-3 or no consensus -> present to user.
5. Update proposal status. Log event.

## Workflow: Apply

1. Verify proposal status is "approved".
2. Create sentinel: `.claude/floors/compliance/.applying` with proposal ID and timestamp.
3. Apply the change to `floors/compliance.md` or `.claude/compliance/targets.md`.
4. **Run `ops/compile-floor.sh --proposal <id>`** — if compilation fails (exit 2), revert via `git checkout -- floors/compliance.md`, remove sentinel, report error. The apply is atomic.
5. Update checksum: regenerate `.claude/floors/compliance/floor-checksum.sha256`.
6. Append entry to `.claude/compliance/change-log.md`.
7. Remove sentinel. Log `compliance-applied` event. Update proposal to "applied".

## Workflow: Audit

1. Dispatch compliance-auditor with current floor rules and scope.
2. Present results. Findings automatically copied to CRO.

## Workflow: Log

1. Read `.claude/compliance/change-log.md`.
2. Present recent entries.

## Model Tiering

| Subcommand            | Model  | Rationale                                      |
| --------------------- | ------ | ---------------------------------------------- |
| `/compliance status`  | Sonnet | Data aggregation                               |
| `/compliance propose` | Sonnet | Structured formatting                          |
| `/compliance review`  | Opus   | Judgment: risk classification, Cx consultation |
| `/compliance apply`   | Sonnet | Controlled file modification                   |
| `/compliance audit`   | Sonnet | Dispatches Sonnet-tier auditor                 |
| `/compliance log`     | Sonnet | Data lookup                                    |

## Extensibility

Implementers can override to add domain-specific proposal templates, automated compliance scanning (SAST/DAST), or integration with external GRC tools.
