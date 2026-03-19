---
name: pace
description: "Pace control. Show current pace, evaluate readiness for promotion/demotion, apply pace changes."
argument-hint: "[status|evaluate|change <pace>]"
---

# Pace

Manage fleet pace as defined in `.claude/COLLABORATION.md` § Pace Control.

## Usage

- `/pace` -- Show current pace and quick health summary
- `/pace evaluate` -- Full evaluation with DORA + flow signals and SM recommendation
- `/pace change walk` -- Apply a pace change (with confirmation)

## Workflow: Status (default)

1. **Read current pace.** Parse from `.claude/COLLABORATION.md` (the `Current Pace: **X**` line).

2. **Quick health check.** Run `ops/dora.sh --sm` and extract the key signals:
   - CFR (change failure rate)
   - FPY (first-pass yield)
   - Current recommendation

3. **Report.** One-screen summary:

   ```
   ## Pace Status

   Current: Walk
   CFR: 8% (threshold: <=10% for Walk, <=5% for Run)
   FPY: 92% (threshold: >=80% for Run)
   Recommendation: Advance to Run
   ```

## Workflow: Evaluate

1. **Run full metrics.** Execute `ops/dora.sh` (full dashboard) to get DORA + flow quality data.

2. **Dispatch SM agent.** The scrum-master evaluates pace readiness using Opus model:
   - Review all DORA signals against thresholds in `fleet-config.json`
   - Review flow quality signals (FPY by boundary, rework cycles, blocked time)
   - Consider qualitative signals (findings trends, handoff clarity, specialist autonomy)
   - Produce a recommendation with evidence

3. **Present evaluation.** Show the SM's full analysis and recommendation. Include the evidence that supports or argues against a pace change.

## Workflow: Change

1. **Parse target pace.** Must be one of: Crawl, Walk, Run, Fly.

2. **Validate the change.**
   - Pace can only move one step at a time (Crawl→Walk, Walk→Run, Run→Fly, or reverse)
   - Exception: any pace can drop to Crawl immediately (emergency slowdown)

3. **Confirm with user.** Show current pace, target pace, and the SM's most recent evaluation. Wait for explicit confirmation.

4. **Apply the change.** Update the `Current Pace: **X**` line in `.claude/COLLABORATION.md`.

5. **Log the event.** Record the pace change in the findings register as a "learning" category finding with the rationale. Also log via `ops/metrics-log.sh` if a `pace-changed` event type is available; otherwise, note this gap as a finding for the platform-ops agent to address.

6. **Announce.** Confirm the pace change and summarize what autonomy behaviors change at the new pace.

## Model Tiering

| Subcommand       | Model  | Rationale                                              |
| ---------------- | ------ | ------------------------------------------------------ |
| `/pace` (status) | Sonnet | Data lookup, structured reporting                      |
| `/pace evaluate` | Opus   | Judgment: interpreting signals, qualitative assessment |
| `/pace change`   | Sonnet | Validation and file update                             |

## Extensibility

Implementers can override to add custom pace signals (e.g., test coverage thresholds, deployment success rates from CI/CD). The thresholds themselves are already configurable in `fleet-config.json`.
