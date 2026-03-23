# Phase 0: Prioritize — Backlog Triage Before Work Begins

**Date:** 2026-03-22
**Status:** Draft

## Problem

The work item lifecycle starts at Groom (Phase 1), which operates on individual items already in the backlog. There is no structured moment to step back and examine the backlog as a whole — to ask whether priorities have shifted, whether new items should be added, whether existing items are stale or superseded, or whether the ordering still reflects reality.

Without this, the fleet risks working on the next item in queue by inertia rather than by current need. Completed work, new findings, compliance signals, and user requests can all change what matters most — but nothing in the lifecycle forces that reassessment.

## Design Goals

- Add a structured pre-cycle step that re-examines the full backlog before the next item is groomed
- Produce a persistent triage report so prioritization decisions are traceable
- Surface a concise summary to the user so they can steer without reading the full report
- Make the cadence configurable for different project contexts
- Route any findings discovered during triage to the existing findings register

## Non-Goals

- Replacing Groom — Prioritize decides _what_ to work on next; Groom prepares _how_ to work on it
- Automated reprioritization — the PO uses judgment, informed by signals
- Changing the per-item lifecycle (Phases 1-9) — those remain unchanged

---

## Section 1: Lifecycle Position

Phase 0 is added before the existing 9 phases, making the lifecycle 10 phases total. The existing phases retain their numbering (1-9). Phase 0 runs **per-iteration** by default, while Phases 1-9 run per-item.

| Phase             | What Happens                                                       | Who Leads                    | Cadence       |
| ----------------- | ------------------------------------------------------------------ | ---------------------------- | ------------- |
| **0. Prioritize** | Triage the backlog: add, drop, reorder items. Write triage report. | PO leads, SA + SM contribute | Per-iteration |
| **1. Groom**      | (unchanged)                                                        | PO leads, SA + SM contribute | Per-item      |
| **2-9**           | (unchanged)                                                        | (unchanged)                  | Per-item      |

### Cadence Configuration

The iteration cadence is configurable in `fleet-config.json`:

```json
{
  "prioritize_cadence": "per-iteration"
}
```

Valid values:

| Value           | When Phase 0 runs                              |
| --------------- | ---------------------------------------------- |
| `per-iteration` | Once before each batch of work items (default) |
| `per-session`   | At the start of each session                   |
| `per-item`      | Before every item enters Groom                 |

The PO checks the cadence setting and determines whether Phase 0 is due. If the cadence is `per-iteration`, Phase 0 runs when the previous iteration's items have been accepted (or at the start of the first iteration).

---

## Section 2: Signal Collection

Phase 0 uses a combination of automated signal flags and PO judgment. Signals prevent things from being overlooked; the PO owns the assessment.

### Automated Signal Flags

The PO collects these signals before beginning triage:

| Signal                  | Source                                 | Flag condition                                                                                     |
| ----------------------- | -------------------------------------- | -------------------------------------------------------------------------------------------------- |
| Completed items         | `ops/metrics-log.sh` event log         | Items accepted since last triage                                                                   |
| High-severity findings  | `.claude/findings/register.md`         | Findings with severity > normal                                                                    |
| Blocked items           | Tier files + event log                 | Items with `task-blocked` and no corresponding `task-unblocked`                                    |
| Stale items             | Tier files                             | Items unchanged for > 2 iterations                                                                 |
| Untracked user requests | Session context                        | User requests not yet in a tier file                                                               |
| Compliance events       | `ops/metrics-log.sh` compliance events | Violations or new rules since last triage                                                          |
| Build rejections        | `ops/metrics-log.sh` event log         | Items rejected at build (`item-rejected-at-build`) — patterns may indicate systemic backlog issues |

### PO Judgment Assessment

Using the collected signals, the PO evaluates:

- **What's newly urgent?** — Signals that shift priority (e.g., a high-severity finding makes a related backlog item critical)
- **What's stale?** — Items that haven't moved and may no longer be relevant
- **What's missing?** — Work that should be tracked but isn't
- **What should be dropped?** — Items superseded by completed work or changed context
- **What needs reordering?** — Items whose relative priority has shifted

---

## Section 3: Triage Report

The PO writes a triage report to `docs/plans/triage-YYYY-MM-DD.md`. This is the persistent artifact of Phase 0.

### Report Structure

```markdown
# Backlog Triage — YYYY-MM-DD

## Changes Since Last Triage

- Items completed: [list with item IDs]
- Items added: [list with brief descriptions]
- Items dropped: [list with rationale]

## Signal Flags

- Blocked items: [list or "none"]
- High-severity findings: [list or "none"]
- Stale items (> 2 iterations unchanged): [list or "none"]
- Compliance events: [list or "none"]
- Build rejections: [list or "none"]

## Priority Changes

- [Item X] moved above [Item Y] — reason: [rationale]
- [Item Z] dropped — reason: [rationale]

## Recommended Next

Items recommended for Groom (Phase 1):

1. [Item] — [why now]
2. [Item] — [why now]

## Needs User Decision

- [Item or question requiring user input]
```

### Report Lifecycle

- One report per triage. Reports accumulate in `docs/plans/` and provide a history of prioritization decisions.
- Reports are not updated after creation — they are point-in-time snapshots.
- The PO references the most recent triage report when deciding what to groom next.

---

## Section 4: User Summary

After writing the triage report, the PO surfaces a concise summary to the user. This is conversational output, not a file — the user sees it in the session.

### Summary Format

The summary covers four areas, each only if there's something to say:

1. **What's done** — Items completed since last triage
2. **What changed** — Priority shifts, items added/dropped, with brief rationale
3. **What's next** — Recommended items for grooming, each with a short rationale for why now
4. **What needs you** — Items or decisions requiring user input

### Example

> Since last triage: 2 items completed (compliance compiler gaps, SessionStart fix). 1 new item added (rewards system spec). Reprioritized examples refresh below rewards system — rewards consumes compiler signals so it should land first. Recommended next: rewards system spec — it consumes compliance compiler signals and should be designed while that context is fresh. 1 item needs your input. Want me to walk you through it?

The summary should be 2-5 sentences. If there are no changes, the summary says so: "No priority changes since last triage. Recommended next: [item] — [rationale]."

### Guided Input

After presenting the summary, if there are items in "What needs you," the PO offers to guide the user through each decision one at a time:

> "There are N items that need your input. Want me to walk you through them?"

If the user accepts, the PO presents each decision sequentially — one per message — with context and options. The PO records decisions in the triage report and updates tier files accordingly.

---

## Section 5: Backlog Updates

During Phase 0, the PO may modify tier files in `docs/plans/`:

- **Add items** — New work identified from signals or user requests
- **Reorder items** — Change priority within a tier
- **Move items between tiers** — Promote or demote based on urgency
- **Drop items** — Remove items that are no longer relevant (with rationale in triage report)

All changes are reflected in the triage report so they are traceable.

---

## Section 6: Findings During Triage

If the PO discovers findings during triage (e.g., a pattern of build rejections suggesting a process issue, or a stale item that reveals a gap), these are recorded in the findings register via `/findings`. They are not embedded in the triage report — the triage report references them by finding ID.

---

## Section 7: Metrics Event

Phase 0 logs a `backlog-triaged` event via `ops/metrics-log.sh`:

```bash
ops/metrics-log.sh backlog-triaged \
  --items-reviewed <count> \
  --items-added <count> \
  --items-dropped <count> \
  --items-reordered <count>
```

This enables tracking of triage frequency and scope over time — useful for SM during Checkpoint (Phase 9) to assess whether triage cadence is appropriate.

---

## Section 8: Integration Points

### `/po` Skill

The `/po` skill gains a `triage` subcommand that triggers Phase 0. The PO can also run Phase 0 as part of `/po status` when the cadence indicates it's due.

### SessionStart Hook

When `prioritize_cadence` is `per-session`, the SessionStart hook prompts: `[PO] Backlog triage is due. Run /po triage to review priorities.`

### COLLABORATION.md

The work item lifecycle table is updated to include Phase 0. The description of the lifecycle changes from "9-phase" to "10-phase" wherever referenced.

### CLAUDE.md

The workflow section references Phase 0 as the entry point: "Prioritize before grooming."

---

## Resolved Design Decisions

1. **Phase 0, not Phase 1:** Prioritize is numbered 0 to signal it runs per-iteration (not per-item) and is a pre-cycle step. Existing phase numbers are preserved to avoid cascading renumbering across the codebase.

2. **Triage report location:** Reports live in `docs/plans/` alongside tier files, not in `.claude/findings/`. They are about the backlog, not about process observations. Findings discovered during triage go to the findings register separately.

3. **Configurable cadence:** Default is `per-iteration`. Implementers can change to `per-session` (more frequent) or `per-item` (most frequent) based on their project's pace and complexity.

4. **Combined signal + judgment approach:** Automated signals flag items for attention, but the PO owns the prioritization decision. This prevents both oversight (signals catch what the PO might miss) and rigidity (PO can override signals with context).

5. **Summary is conversational, not a file:** The user sees a 2-5 sentence summary in the session. The full triage report is the persistent artifact for traceability.
