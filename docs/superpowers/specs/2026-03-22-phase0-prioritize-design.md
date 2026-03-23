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

An **iteration** is defined as the interval between two Phase 0 triage runs. It is not a fixed time period or a fixed number of items — it is bounded by triage events. The first iteration begins at the start of the project (or when Phase 0 is adopted). Subsequent iterations begin when the PO runs triage again, typically after a batch of items has been accepted. The PO uses judgment to determine when the current iteration's work is substantially complete and a new triage is warranted.

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

| Value           | When Phase 0 runs                                                     |
| --------------- | --------------------------------------------------------------------- |
| `per-iteration` | Once per iteration — PO determines when a batch is complete (default) |
| `per-session`   | At the start of each session                                          |
| `per-item`      | Before every item enters Groom                                        |

When `prioritize_cadence` is absent from `fleet-config.json`, the default is `per-iteration`.

### How the PO determines "last triage"

The PO determines when the last triage occurred by checking the most recent `triage-YYYY-MM-DD.md` file in `docs/plans/`. The file's date suffix is the triage date. If no triage file exists, this is the first triage. All "since last triage" references in signal collection (Section 2) and triage reports (Section 3) use this date as the baseline.

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
| Stale items             | Tier files + triage history            | Items unchanged since the previous triage (present in last triage report with no status change)    |
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
- Stale items (unchanged since last triage): [list or "none"]
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

## User Decisions (recorded during guided input)

- [Decision]: [user's choice] — [rationale if provided]
```

### Report Lifecycle

- One report per triage. Reports accumulate in `docs/plans/` and provide a history of prioritization decisions.
- The report is finalized at the end of Phase 0, after all user decisions from guided input have been recorded. Until then, it may be updated with user decision outcomes.
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

If the user accepts, the PO presents each decision sequentially — one per message — with context and options. The PO records user decisions in the "User Decisions" section of the triage report and updates tier files accordingly.

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

**Implementation note:** `ops/metrics-log.sh` must be extended to accept the `backlog-triaged` event type with the flags above (`--items-reviewed`, `--items-added`, `--items-dropped`, `--items-reordered`).

---

## Section 8: Integration Points

### `/po` Skill

The `/po` skill gains a `triage` subcommand that triggers Phase 0. This **replaces** the existing `/po prioritize` subcommand — triage is the full Phase 0 workflow (signal collection, assessment, report, user summary), while the old prioritize was limited to WSJF rescoring. Any WSJF recalculation becomes part of the triage assessment rather than a standalone operation.

### SessionStart Hook

When `prioritize_cadence` is `per-session`, the SessionStart hook prompts for triage. The hook reads `fleet-config.json` using `jq` (consistent with existing hooks that read fleet config):

```bash
[ -f fleet-config.json ] && command -v jq &>/dev/null && {
  CADENCE=$(jq -r '.prioritize_cadence // "per-iteration"' fleet-config.json 2>/dev/null)
  [ "$CADENCE" = "per-session" ] && echo '[PO] Backlog triage is due. Run /po triage to review priorities.'
} || true
```

When `prioritize_cadence` is absent from `fleet-config.json`, the hook defaults to `per-iteration` and does not prompt. This makes the hook safe to include before an implementer configures the cadence.

For `per-iteration` cadence, the PO determines when triage is due based on judgment (no SessionStart prompt).

### COLLABORATION.md

The work item lifecycle table is updated to include Phase 0. The description of the lifecycle changes from "9-phase" to "10-phase" wherever referenced.

### CLAUDE.md

The workflow section references Phase 0 as the entry point: "Prioritize before grooming."

### `templates/fleet-config.json`

The fleet configuration template is updated with the new key and its default:

```json
{
  "prioritize_cadence": "per-iteration"
}
```

---

## Resolved Design Decisions

1. **Phase 0, not Phase 1:** Prioritize is numbered 0 to signal it runs per-iteration (not per-item) and is a pre-cycle step. Existing phase numbers are preserved to avoid cascading renumbering across the codebase.

2. **Iteration defined by triage events:** An iteration is the interval between two triage runs, not a fixed time period. This avoids introducing calendar-based mechanics into a framework that operates on work-completion cadence. The PO uses judgment to determine when a batch is complete.

3. **Triage report location:** Reports live in `docs/plans/` alongside tier files, not in `.claude/findings/`. They are about the backlog, not about process observations. Findings discovered during triage go to the findings register separately.

4. **Configurable cadence:** Default is `per-iteration`. Implementers can change to `per-session` (more frequent) or `per-item` (most frequent) based on their project's pace and complexity.

5. **Combined signal + judgment approach:** Automated signals flag items for attention, but the PO owns the prioritization decision. This prevents both oversight (signals catch what the PO might miss) and rigidity (PO can override signals with context).

6. **Summary is conversational, not a file:** The user sees a 2-5 sentence summary in the session. The full triage report is the persistent artifact for traceability.

7. **`/po triage` replaces `/po prioritize`:** The triage subcommand subsumes the old prioritize functionality. WSJF rescoring becomes part of triage rather than a standalone operation. This avoids overlapping commands with unclear boundaries.

8. **Report finalized at end of Phase 0:** The triage report is not an immutable snapshot at creation — it is finalized at the end of Phase 0, after user decisions from guided input are recorded. This avoids the contradiction of "never updated" vs. recording user input.
