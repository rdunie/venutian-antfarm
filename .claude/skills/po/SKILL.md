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
- `/po promote <item>` -- Expand a tier file item into a full work item with story + AC
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
