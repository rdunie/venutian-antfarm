---
name: retro
description: "Run a retrospective for the last completed work item. Pulls DORA metrics, summarizes flow, captures keep/stop/start."
argument-hint: "[item-id]"
---

# Retrospective

Run a team retrospective as defined in `.claude/COLLABORATION.md` § Team Retrospective (Phase 8).

## Usage

- `/retro` -- Retro for the most recently accepted item
- `/retro 42` -- Retro for a specific item

## Workflow

0. **Check escalations.** Run `ops/feedback-log.sh check-escalations` to process any stale proposals before the retro begins.

1. **Gather metrics.** Run `ops/dora.sh --item <id>` (or `ops/dora.sh` if no item specified) to pull DORA + flow quality data for this iteration.

2. **Summarize the flow.** For the target item, report:
   - Lead time (promoted → accepted)
   - Number of handoff cycles and rework loops
   - First-pass yield at each handoff boundary
   - Any findings logged during the item's lifecycle
   - Bugs found and fixed (count, severity)
   - PR metrics: review rounds, time-to-merge (branch created → PR merged), PR comment count

3. **Collect reflections.** For each agent that participated in the item, generate a reflection:
   - **Keep:** What worked well and should continue
   - **Change:** What caused friction, rework, or delays
   - **Try:** New approaches to experiment with next iteration

4. **Synthesize.** SM consolidates reflections into 3-5 actionable proposals. Each proposal should be:
   - Specific (not "communicate better" but "include schema diffs in handoff artifacts")
   - Measurable (tied to a metric that will show improvement)
   - Scoped (applies to a specific agent, phase, or handoff boundary)

5. **Present to user.** Show the metrics summary, agent reflections, and proposals. Ask the user to approve, modify, or defer each proposal.

6. **Apply approved changes.** For each approved proposal:
   - If it changes an agent's behavior → update the agent's memory or definition
   - If it changes a process rule → update `.claude/COLLABORATION.md`
   - If it changes a metric threshold → update `fleet-config.json`
   - Log the retro outcome to findings register

7. **Checkpoint.** After applying changes, SM runs Phase 9 (Checkpoint): evaluate pace, assess process health, and determine if a pace promotion or demotion is warranted based on updated metrics.

## Output Format

```
## Retrospective: Item #<id> — <title>

### Metrics
- Lead time: X
- Handoff cycles: X
- First-pass yield: X%
- Bugs: X found, X fixed
- Rework loops: X
- PR review rounds: X
- Time-to-merge: X
- PR comments: X

### Agent Reflections
#### <agent-name>
- Keep: ...
- Change: ...
- Try: ...

### Proposals
1. [proposal] — Metric: [what improves] — Scope: [who/what]
2. ...

### Pace Check
Current: <pace> | Recommended: <pace> | Reason: ...
```
