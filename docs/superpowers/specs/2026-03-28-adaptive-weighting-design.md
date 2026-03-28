# Adaptive Weighting for Behavioral Feedback

**Issue:** [#25](https://github.com/rdunie/venutian-antfarm/issues/25)
**Date:** 2026-03-28
**Status:** Draft

## Problem

The behavioral feedback system stores raw signals (kudos, reprimands) in the ledger but treats them all equally. A security reprimand from the CISO carries the same weight as a kudo from a specialist. Older signals count the same as recent ones. There is no way to tune the impact of feedback by role, domain, or recency, making behavioral profiles coarse and hard to use for pace decisions, autonomy grants, or retro prioritization.

## Goals

1. **Configurable impact** -- project owners can tune how much different signals matter via fleet-config.json.
2. **Three weighting axes** -- tier-based (governance vs core vs specialist), type-based (reprimand vs kudo), and domain-based (domain × subject agent) multipliers.
3. **Temporal decay** -- older signals lose impact based on accepted item count, not calendar time. Step-function model with a cliff.
4. **Read-time computation** -- the ledger is never modified. Weighting is applied when `profile` or `score` is called, preserving the factual record.
5. **Backward compatible** -- projects without weighting config get unweighted behavior (all multipliers 1.0, no decay).

## Non-Goals

- Auto-throttling or auto-promotion based on weighted scores (consumers apply judgment)
- Changing the ledger format or write path
- Complex decay models (linear, exponential) in v1 -- step-function only, with extensibility for future models
- Per-agent weighting overrides (all agents in a tier share the same multiplier)

## Design

### 1. Weighting Formula

Every signal in the ledger gets a computed weight at read time:

```
weight = tier_multiplier * type_multiplier * domain_multiplier * decay_multiplier
```

Kudos contribute positive weight, reprimands contribute negative weight. Net score = sum of all weighted kudos - sum of all weighted reprimands.

| Axis   | Source                                                    | Default                                   |
| ------ | --------------------------------------------------------- | ----------------------------------------- |
| Tier   | `Origin tier` field on ledger entry                       | governance=1.0, core=0.8, specialist=0.5  |
| Type   | Entry type (kudo vs reprimand)                            | reprimand=1.5, kudo=1.0                   |
| Domain | Domain field × subject agent lookup                       | 1.0 (configurable per domain per subject) |
| Decay  | Step-function based on global accepted items since signal | Within cliff: 1.0, beyond cliff: 0.25     |

### 2. Temporal Decay — Item-Based Step Function

Decay is based on the number of globally accepted work items since the signal was issued, not calendar time. This aligns with the framework's iteration-based pace model.

```
signal_age = total_accepted_items - items_accepted_at_signal_time
if signal_age <= cliff_items: decay = 1.0
else: decay = post_cliff_multiplier
```

**Computing the timeline (O(n + m), not O(n \* m)):**

1. One pass through the metrics log: extract all `item-accepted` timestamps, build an associative array mapping each date to its cumulative accepted count. O(m).
2. Count total accepted items. O(1) after step 1.
3. For each signal: look up its date in the associative array to get accepted count at that time, compute age, apply decay. O(n).

**Edge case:** If the metrics log is empty or missing, all signals are treated as recent (decay = 1.0). Correct for new projects with no accepted items yet.

### 3. Fleet-Config Schema

```json
"rewards": {
  "escalation_deadline_days": 7,
  "weighting": {
    "tier_multipliers": {
      "governance": 1.0,
      "core": 0.8,
      "specialist": 0.5
    },
    "type_multipliers": {
      "reprimand": 1.5,
      "kudo": 1.0
    },
    "domain_multipliers": {
      "security": { "security-reviewer": 1.5, "_default": 1.0 },
      "delivery": { "product-owner": 1.5, "_default": 1.0 },
      "_default": 1.0
    },
    "decay": {
      "model": "step",
      "cliff_items": 10,
      "post_cliff_multiplier": 0.25
    }
  }
}
```

**Defaults:** If `weighting` is absent or any section is missing, all multipliers default to 1.0 and decay is disabled. Existing projects work unchanged.

**Extensibility:** The `decay.model` field supports `"step"` in v1. Future models (linear, exponential) can be added as new model names with their own parameters without changing the config shape.

**Domain multiplier resolution order:**

1. Look up `domain_multipliers.<signal_domain>.<subject_agent>` -- exact match
2. Look up `domain_multipliers.<signal_domain>._default` -- domain default
3. Look up `domain_multipliers._default` -- global default
4. Fall back to 1.0

### 4. Script Changes

#### New `score` subcommand

```
ops/feedback-log.sh score <agent>
```

Output (key=value, machine-parseable):

```
net=3.2
kudos=4.1
reprimands=-0.9
signals=7
recent=5
```

- `net` = sum of weighted kudos - sum of weighted reprimands
- `kudos` = sum of positive weighted signals
- `reprimands` = sum of negative weighted signals (shown as negative number)
- `signals` = total R/K entries for this agent
- `recent` = entries within the decay cliff window

#### Profile extension

After the existing "By tier:" section in the `profile` subcommand, add a weighted summary line:

```
Weighted: net=3.2 (kudos=4.1, reprimands=-0.9, 5 of 7 recent)
```

One line — delegates to the same computation logic.

#### Shared computation function

`compute_weighted_score()` is a bash function (proper function, so `local` is fine) that:

1. Takes the agent name as argument
2. Reads weighting config from fleet-config.json (defaults if absent)
3. Builds accepted-items timeline from metrics log using `declare -A` associative array
4. Parses the agent's ledger section -- for each R/K entry, extracts: type, origin tier, domain, date
5. For each entry: computes `tier * type * domain * decay` weight
6. Returns structured key=value output

Both `profile` and `score` call this function.

### 5. Consumption Points

Weighted scores are informational -- consumers apply judgment, not automation.

| Consumer                  | How they use it                                                                                  |
| ------------------------- | ------------------------------------------------------------------------------------------------ |
| SM (retro, Phase 8)       | References weighted profile when summarizing agent performance. High negative net flags concern. |
| SM (pace decisions)       | Considers weighted score alongside DORA metrics. Not a threshold -- a signal.                    |
| CEO (autonomy grants)     | References weighted score as evidence when granting increased autonomy.                          |
| CRO (conformance reports) | Includes weighted summary stats in conformance reports.                                          |

No consumer auto-acts on the score. It's evidence for human-in-the-loop decisions.

## File Inventory

### Modified Files

| File                             | Change                                                                                                 |
| -------------------------------- | ------------------------------------------------------------------------------------------------------ |
| `ops/feedback-log.sh`            | Add `compute_weighted_score` function, `score` subcommand, extend `profile` with weighted summary line |
| `ops/tests/test-feedback-log.sh` | Tests for score output, profile weighted line, decay behavior, default fallback when no config         |
| `templates/fleet-config.json`    | Add `weighting` section to `rewards` with tier/type/domain multipliers and decay config                |
| `CLAUDE.md`                      | Document `score` subcommand in Feedback commands section                                               |

### No New Files

All changes are to existing files.

## Related Issues

- [#13](https://github.com/rdunie/venutian-antfarm/issues/13) -- Rewards system (base system, completed)
- [#28](https://github.com/rdunie/venutian-antfarm/issues/28) -- Expanded feedback (origin tier data, completed)
- [#24](https://github.com/rdunie/venutian-antfarm/issues/24) -- Signal bus (future: replaces direct script calls)
