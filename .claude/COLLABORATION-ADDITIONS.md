# COLLABORATION.md Additions

Sections to be merged into `.claude/COLLABORATION.md`. Each section header indicates where it belongs.

---

## Pace Consensus Protocol

> Merge into: Pace Rules (after existing rules)

**Rule 1 detail:** "Always ask before increasing pace." Agents recommend pace changes with evidence ("Last 5 items had zero rework, findings register is clean -- recommend moving to Run"). The user decides. **Exception:** when the leadership triad (PO, SA, SM) reaches high consensus on a pace that is slower than or equal to the current pace, they inform the user and proceed at that pace without waiting for explicit approval.

**Rule 5 detail:** "Significant problems trigger triad consultation." When a significant problem occurs (major regression, architectural surprise, delivery blocker), the leadership triad convenes to assess impact and recommend how to adjust the pace. If the triad reaches high consensus, they present a unified recommendation to the user. If consensus is low or the triad disagrees on the right response, they escalate to the user with each perspective so the user can decide.

---

## Information Needs Tracker

> Merge into: Pace Control section (after Pace Rules)

Agents maintain a running list of upcoming information needs -- decisions, context, or access the user can provide ahead of time to prevent blocking later. The product-owner aggregates these during `/po` status.

```
## Upcoming Information Needs

| What | Agent | Needed By | Why |
|------|-------|-----------|-----|
| API credentials for staging environment | infrastructure-ops | Before deploy pipeline work begins | Cannot build integration tests without access |
| Decision: cache topology (local vs. distributed) | solution-architect | Before performance work starts | Architecture decision affects all consumers |
```

This list lives in `.claude/findings/information-needs.md` and is surfaced in `/po` status and `/po next` outputs.

---

## Thinking-Time Caps

> Merge into: Model Tiering section (after the model tier table)

Model selection and thinking budget are separate cost axes. Cap thinking time to prevent unbounded cost:

| Task Type        | Model Tier | Thinking Budget  | Rationale                                        |
| ---------------- | ---------- | ---------------- | ------------------------------------------------ |
| **Judgment**     | Expensive  | Medium (default) | Deep enough for tradeoffs, bounded               |
| **Coordination** | Mid-tier   | Low              | Structured reporting, no extended reasoning      |
| **Routine**      | Cheap      | None (disabled)  | Mechanical checks, no reasoning needed           |

If an agent hits the thinking ceiling and needs more, that is a finding: either the task was mis-classified (should be Judgment, not Coordination) or the context needs enriching so the agent can reason faster with less effort.

Each skill documents which model to use per subcommand. Agent frontmatter `model` fields define the default, but skills override per subcommand when a lighter model suffices.

**Monitoring:** Track model usage distribution via fleet observability. If expensive model usage exceeds 40% of total dispatches, investigate whether some judgment tasks could be downgraded with better context enrichment.

---

## Handoff Completion Format

> Merge into: Handoff Protocol section (after the handoff template)

When returning completed work to the requesting agent, use this format:

```
**Handoff Complete: [to-agent] -> [from-agent]**
**What was done:** [summary of work completed]
**Result:** [success / partial / blocked -- details]
**Artifacts:** [files changed, test results]
**Follow-up needed:** [yes/no -- what remains]
```

The receiving agent should be able to determine next steps without asking for clarification. If the handoff completion is ambiguous about whether work succeeded, that is a finding.

---

## Memory Integration

> Merge into: new section after Learning Collective, or as a subsection of it

### Memory Layers

The memory system has two layers with distinct ownership and lifecycle:

| Layer | Path | Contains | Updated By | When |
|-------|------|----------|------------|------|
| **harness/** | `.claude/memory/harness/` | Framework learnings -- collaboration protocol patterns, tool usage, generic process insights | memory-manager (on harness upgrade) | Harness version changes only |
| **app/** | `.claude/memory/app/` | Domain learnings -- project-specific patterns, decisions, gotchas, environment quirks | Any agent during work | Continuously during sessions |

### Rules

- **Agents write to app/ during work.** When an agent discovers a domain-specific pattern, gotcha, or decision worth preserving, it writes to `app/` memory.
- **harness/ is read-only during normal operation.** Implementers do not modify harness memories. These are updated only when the harness itself is upgraded.
- **memory-manager curates both layers.** It flags stale entries, resolves contradictions, distributes learnings across agents, and ensures memories stay accurate and useful.
- **Cross-pollination.** When an app/ learning reveals a generic pattern that would benefit any project using this harness, the memory-manager flags it for potential promotion to harness/ in the next harness upgrade cycle.

---

## Build Rejection Tracking

> Merge into: Work Item Lifecycle, Phase 3 (Build)

At the start of Phase 3 (Build), the building agent re-evaluates the item's premise against current code, context, and needs before beginning work. If the item is no longer needed or the context has shifted enough to invalidate the approach:

1. Log `item-rejected-at-build` with `--reason` and `--source`:
   - `--reason`: `context-changed` | `flawed-suggestion` | `superseded` | `duplicate`
   - `--source`: originating agent that proposed or groomed the item
2. Update the tier file to reflect the rejection.
3. Move on to the next item.

### Rejection Pattern Analysis

The SM reviews rejection patterns during retro:

| High Rate Of | Signal | Action |
|-------------|--------|--------|
| `context-changed` | Groom-to-build latency is too high -- items go stale before they are built | Reduce WIP, shorten queue, groom closer to build time |
| `flawed-suggestion` | Decision quality gap -- items are being promoted without sufficient analysis | Improve grooming rigor, add SA review gate |
| `superseded` | Scope churn -- priorities are shifting faster than execution | Stabilize priorities, batch related changes |
| `duplicate` | Backlog hygiene gap -- items are not being deduplicated during grooming | PO dedup pass before promotion |

---

## Milestone Release Dispatch

> Merge into: new section after Work Item Lifecycle, or as a subsection of Deploy

When a batch of related items reaches acceptance and constitutes a meaningful release:

### Process

1. **Declaration.** The user or PO declares a milestone with a version tag and scope summary.
2. **Parallel dispatch.** Output agents are dispatched in parallel, each producing artifacts independently:
   - **doc-quality** -- documentation updates, changelog, release notes
   - **training-enablement** -- user guides, onboarding materials, walkthroughs
   - **stakeholder-video/comms** -- stakeholder communications, demo scripts, announcements
3. **Independent production.** Each output agent works from the accepted items and current documentation. No sequential dependency between output agents.
4. **Version archive.** After all output agents complete, the release is tagged in version control and archived.

### Milestone Event Logging

```
ops/metrics-log.sh milestone-declared v1.2.0 --items "41,42,43"
ops/metrics-log.sh milestone-complete v1.2.0
```

Output agents do not need to wait for each other. If one agent is blocked, the others continue. The PO tracks completion and tags the archive when all are done.
