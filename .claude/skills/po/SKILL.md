---
name: po
description: Product Owner commands -- backlog management, prioritization, grooming, review, and status. Routes to the product-owner agent.
argument-hint: "[groom|promote <item>|review|prioritize|next|backlog]"
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
- `/po prioritize` -- Recalculate WSJF scores for active tiers, propose reordering
- `/po backlog` -- Full backlog health report

## Model Tiering

| Subcommand       | Model  | Rationale                                        |
| ---------------- | ------ | ------------------------------------------------ |
| `/po` (status)   | Sonnet | Data lookup, structured reporting                |
| `/po next`       | Sonnet | Data lookup with simple priority logic           |
| `/po groom`      | Opus   | Judgment: writing AC, WSJF scoring, NFR drafting |
| `/po promote`    | Sonnet | Template expansion, structured output            |
| `/po review`     | Opus   | Judgment: AC verification, accept/reject         |
| `/po prioritize` | Opus   | Judgment: WSJF scoring, tradeoff reasoning       |
| `/po backlog`    | Sonnet | Data aggregation, structured reporting           |

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
3. **If any fail:** Log `ops/metrics-log.sh item-rejected-at-acceptance <item-id> --reason "<description>"`. Item returns to Fix (Phase 5). The original author agent fixes the issue on the existing branch. See `.claude/COLLABORATION.md` § Acceptance Failure for the full process.

## Promote Branching Workflow

When the subcommand is `promote`, after the PO agent expands the item into a full work item:

1. **Create feature branch.** Run: `git checkout -b <type>/<item-id>-<slug>` where type is `feat`, `fix`, `chore`, or `docs` based on the item category. Push: `git push -u origin <branch-name>`.
2. **Create draft PR.** Use GitHub MCP `create_pull_request` with `draft: true`. PR body includes the work item's story, acceptance criteria, and NFR flags. PR title format: `<type>: <description> (#<item-id>)`.
3. **Log events.** Run: `ops/metrics-log.sh branch-created <item-id> --branch <branch-name>` and `ops/metrics-log.sh pr-opened <item-id> --pr <pr-number>`.
4. **Report.** Present the branch name and PR URL to the user.
