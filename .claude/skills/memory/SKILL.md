---
name: memory
description: "Memory management. Audit consistency, distribute learnings, optimize memory files, detect knowledge gaps."
argument-hint: "[audit|distribute|optimize|gaps]"
---

# Memory

Dispatch memory management operations to the knowledge-ops agent. See `.claude/agents/knowledge-ops.md` for the agent's full responsibilities. Knowledge-ops operates under CKO direction.

## Usage

- `/memory audit` -- Cross-agent consistency audit
- `/memory distribute` -- Distribute recent learnings across agents
- `/memory optimize` -- Optimize memory files for token efficiency
- `/memory gaps` -- Detect knowledge gaps in agent memories

## Workflow: Audit

1. **Dispatch knowledge-ops agent.** The agent performs a consistency audit:
   - Cross-agent consistency: contradictions between agent memories
   - Memory-vs-docs consistency: memories that contradict CLAUDE.md or docs/
   - Memory-vs-code consistency: memories about patterns the code no longer follows
   - DRY compliance: memories that duplicate doc content

2. **Present report.** Show inconsistencies found, with source references and recommended fixes.

3. **Confirm fixes.** For each inconsistency, user approves or defers the fix. Agent applies approved fixes.

## Workflow: Distribute

1. **Gather recent learnings.** Read the findings register for recently accepted findings with refinements.

2. **Dispatch knowledge-ops agent.** The agent:
   - Identifies which learnings are cross-cutting (benefit multiple agents)
   - Translates each learning for the relevant agent's domain context
   - Proposes memory writes for each target agent

3. **Present distribution plan.** Show what will be written to which agent's memory. User confirms.

4. **Apply.** Write approved memory entries.

## Workflow: Optimize

1. **Dispatch knowledge-ops agent.** The agent scans all memory files:
   - Identify oversized entries that should be references instead of inline content
   - Identify stale entries no longer relevant to active work
   - Identify duplicate or near-duplicate entries
   - Check MEMORY.md index sizes (should stay under 200 lines)

2. **Present optimization plan.** Show proposed changes (consolidate, prune, convert to references).

3. **Confirm and apply.** User approves changes. Agent applies them.

## Workflow: Gaps

1. **Dispatch knowledge-ops agent.** The agent identifies missing knowledge:
   - New agents without critical project knowledge
   - Existing agents with outdated memories after significant changes
   - Missing cross-references between related memories
   - Patterns observed in code that no agent has documented

2. **Present gap report.** Show gaps ranked by impact (how likely the gap causes a problem).

3. **Propose fills.** For each gap, suggest what content should be added and where.

## Model Tiering

| Subcommand           | Model  | Rationale                                   |
| -------------------- | ------ | ------------------------------------------- |
| `/memory audit`      | Sonnet | Systematic comparison, structured reporting |
| `/memory distribute` | Sonnet | Translation and routing                     |
| `/memory optimize`   | Sonnet | File analysis, structured reporting         |
| `/memory gaps`       | Sonnet | Analysis and reporting                      |

## Extensibility

Implementers can override to add domain-specific memory categories, custom staleness rules, or integration with external knowledge bases.
