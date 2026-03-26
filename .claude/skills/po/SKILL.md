---
name: po
description: Product Owner commands -- backlog management, prioritization, grooming, review, and status. Routes to the product-owner agent.
argument-hint: "[groom|promote <item>|review|triage|next|backlog]"
---

# Product Owner

Route PO commands to the `product-owner` agent.

## Usage

- `/po` -- WIP status overview (what is in progress, what is next, grooming needs)
- `/po next` -- Recommend the highest-priority ready item to work on
- `/po groom` -- Scan active tiers, propose refinements for items missing DoR fields
- `/po promote <item>` -- Expand a tier file item into a full work item with story + AC, create feature branch and draft PR
- `/po review` -- Review completed work against acceptance criteria + DoD
- `/po review <item>` -- Review a specific item
- `/po triage` -- Phase 0: triage the backlog. Collect signals, assess priorities, write triage report, surface summary to user
- `/po backlog` -- Full backlog health report

## Model Tiering

| Subcommand     | Model  | Rationale                                                  |
| -------------- | ------ | ---------------------------------------------------------- |
| `/po` (status) | Sonnet | Data lookup, structured reporting                          |
| `/po next`     | Sonnet | Data lookup with simple priority logic                     |
| `/po groom`    | Opus   | Judgment: writing AC, WSJF scoring, NFR drafting           |
| `/po promote`  | Sonnet | Template expansion, structured output                      |
| `/po review`   | Opus   | Judgment: AC verification, accept/reject                   |
| `/po triage`   | Opus   | Judgment: signal assessment, prioritization, triage report |
| `/po backlog`  | Sonnet | Data aggregation, structured reporting                     |

## Steps

1. Parse the subcommand from the arguments. If no argument, default to status overview.
2. Dispatch the product-owner agent with the model from the tiering table above.
3. Build the agent prompt based on the subcommand.
4. Review the agent's output and present the summary to the user.
5. If the agent proposes changes, summarize what will be modified and confirm before applying.

## Review and Acceptance Workflow

When the subcommand is `review`, the PO verifies work against acceptance criteria on the deployed environment:

1. **Verify each AC.** Check every acceptance criterion against the deployed result. Document pass/fail for each.
2. **If all pass:** Log `ops/metrics-log.sh item-accepted <item-id>`. Item moves to Done. Proceed to Retro (Phase 8).
3. **If any fail:** Log `ops/metrics-log.sh item-rejected-at-acceptance <item-id> --reason "<description>"`. Item returns to Fix (Phase 5), then back through Build → Review → Deploy → Accept. The original author agent fixes the issue on the existing branch. See `.claude/COLLABORATION.md` § Acceptance Failure for the full process.

## Promote Branching Workflow

When the subcommand is `promote`, after the PO agent expands the item into a full work item:

1. **Create feature branch.** Run: `git checkout -b <type>/<item-id>-<slug>` where type is `feat`, `fix`, `chore`, or `docs` based on the item category. Push: `git push -u origin <branch-name>`.
2. **Create draft PR.** Use GitHub MCP `create_pull_request` with `draft: true`. PR body includes the work item's story, acceptance criteria, and NFR flags. PR title format: `<type>: <description> (#<item-id>)`.
3. **Log events.** Run: `ops/metrics-log.sh branch-created <item-id> --branch <branch-name>` and `ops/metrics-log.sh pr-opened <item-id> --pr <pr-number>`.
4. **Report.** Present the branch name and PR URL to the user.

## Triage Workflow

When the subcommand is `triage`, the PO runs Phase 0:

1. **Determine last triage.** Find the most recent `docs/plans/triage-YYYY-MM-DD.md` file. If none exists, this is the first triage.
2. **Collect signals.** Check event log for: items accepted since last triage, `item-rejected-at-build` events, `task-blocked` events without corresponding `task-unblocked`, compliance violations. Check `.claude/findings/register.md` for findings with severity > normal. Check tier files for items unchanged since last triage.
3. **Assess priorities.** Using collected signals, evaluate: what's newly urgent, what's stale, what's missing, what should be dropped, what needs reordering.
4. **Update tier files.** Add, reorder, move, or drop items as needed.
5. **Write triage report.** Save to `docs/plans/triage-YYYY-MM-DD.md` using the template from the spec.
6. **Surface summary.** Present 2-5 sentence summary covering: what's done, what changed, what's next (with rationale), what needs user input.
7. **Guided input.** If items need user decisions, offer to walk through each one. Record decisions in the triage report.
8. **Log event.** Run: `ops/metrics-log.sh backlog-triaged --items-reviewed <N> --items-added <N> --items-dropped <N> --items-reordered <N>`
9. **Record findings.** If process issues were discovered during triage, log them via `/findings`.
