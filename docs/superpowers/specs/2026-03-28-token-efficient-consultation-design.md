# Token-Efficient Multi-Agent Consultation

**Issue:** [#30](https://github.com/rdunie/venutian-antfarm/issues/30)
**Date:** 2026-03-28
**Status:** Draft

## Problem

The cross-floor risk consultation protocol (§ Cross-Floor Risk Facilitation in the CRO agent) dispatches the CRO, who then consults all 6 peer Cx agents sequentially for every floor change proposal. Most agents respond with "not impacted / abstain" — wasted tokens. Open-ended responses further inflate cost. Multiple rounds compound the problem. A single floor change can cost 100K+ tokens with little incremental value.

## Goals

1. **Tiered consultation** -- CRO triages proposals and only consults Cx agents whose domain is relevant, using its own judgment (Opus-tier) plus optional domain tags from the proposer as hints.
2. **Structured responses** -- guided template keeps agent responses to ~50-100 tokens while preserving nuance.
3. **Early abort** -- if round 1 consensus is unanimous, skip further rounds. Cap at 2 rounds total.
4. **Budget observability** -- soft token budget in fleet-config for CFO monitoring. No hard enforcement in v1.

## Non-Goals

- Hard token budget enforcement (can't reliably measure per-turn tokens at runtime)
- Parallel agent dispatch (requires #21 multi-context orchestration)
- Automated consultation throttling based on cost
- Changing the CRO's role as risk facilitator

## Design

### 1. Consultation Flow

**Before:**

```
Guardian → CRO → all 6 peer Cx agents → synthesize → [round N] → result
```

**After:**

```
Guardian → CRO triage
               ↓
         Read proposal + domain tags (hints, not constraints)
         Apply CRO judgment to select impacted Cx agents (typically 2-3)
               ↓
         Dispatch selected agents with guided template
               ↓
         Round 1 synthesis → unanimous? → done (early abort)
                               ↓ no
                          Round 2 (concerned agents only)
                               ↓
                          Final synthesis → done
```

The CRO has broader scope than individual agents or proposers. Domain tags are advisory input — the CRO can add agents the proposer didn't tag and skip agents they did tag. The triage decision is the CRO's.

Non-consulted agents are recorded in the assessment as "not consulted (triaged out by CRO)" for audit trail.

### 2. Guided Response Template

When the CRO dispatches to a Cx agent, it provides:

```markdown
## Floor Change Assessment — [agent-name]

**Proposal:** [brief summary from CRO]
**Floor:** [compliance|behavioral]

### Your Assessment

**Impact:** [impacted | not-impacted | abstain]
**Rationale:** [1-2 sentences explaining your position]
**Conditions:** [optional — conditions under which your position changes]
**Risk level:** [none | low | medium | high]
```

Agents fill in the template fields as the minimum response. They may add free-text below if they have substantive concerns that don't fit the structured fields. This keeps most responses to ~50-100 tokens instead of open-ended multi-paragraph analysis.

The CRO's synthesis reads structured fields for quick consensus detection, then reviews free-text for nuance.

### 3. Early Abort Logic

After round 1, the CRO checks for unanimous consensus:

- **All not-impacted/abstain** → abort with "no concerns raised, recommend approval"
- **All impacted with no conditions and same risk level** → abort with consolidated position
- **Any disagreement, conditions, or high risk** → proceed to round 2 with only the agents who raised concerns

**Special cases:**

- **Zero agents consulted:** If the CRO determines no peer Cx domain is impacted, the CRO issues a solo assessment with recommendation. The assessment must note "No Cx agents consulted -- CRO solo assessment" for audit trail. Expected for narrow, low-risk changes.
- **Single agent consulted:** If only one agent is consulted and raises concerns in round 1, the CRO synthesizes directly without a round 2 -- there is no additional perspective to gather. Round 2 is only meaningful with 2+ consulted agents.
- **Minimum guideline:** The CRO should consult at least 2 Cx agents for any floor-level (Type 3) change. For target-level changes, a single-agent consultation is acceptable.

Round 2 is capped: maximum 2 total rounds (round 1 + round 2). If positions still diverge after round 2, the CRO synthesizes what it has and flags the disagreement in the assessment. The user decides — no infinite consultation loops.

**Implementation note:** The CRO agent definition must include explicit instructions to (a) parse structured Impact/Risk fields from each response, (b) apply the abort criteria before drafting synthesis, and (c) log the abort decision rationale.

### 4. Proposal Domain Tags

The `/floor propose`, `/compliance propose`, and `/behavioral propose` skills get an optional `--domains` flag:

```
/floor propose behavioral "Add SLA for review turnaround" --domains process,delivery
/compliance propose "Add secret scanning rule" --domains security,technology
```

Valid domain tags (matching Cx agent scopes):

| Tag          | Cx Agent |
| ------------ | -------- |
| `security`   | CISO     |
| `strategy`   | CEO      |
| `technology` | CTO      |
| `cost`       | CFO      |
| `process`    | COO      |
| `knowledge`  | CKO      |

Note: CRO is excluded from the tag table — the CRO is the facilitator, not a consultee. The CRO provides its own risk position as part of the synthesis, not as a dispatched assessment.

If `--domains` is omitted, the CRO triages with no hints — works fine, just slightly less efficient. Tags are passed through to the CRO's triage context as advisory input, never as constraints.

### 5. Token Budget Observability

No hard enforcement in v1. Groundwork for future CFO monitoring:

- Consultation dispatches already emit `agent-invoked` metrics (with `--tokens` and `--turns`) through the existing metrics pipeline.
- Fleet-config gets a `consultation` section with soft targets:

```json
"consultation": {
  "max_rounds": 2,
  "budget_tokens_hint": 50000,
  "budget_note": "Advisory. CFO monitors via ops/dora.sh --cost. Not enforced."
}
```

- The CFO can query consultation cost via `ops/dora.sh --cost` and flag patterns (e.g., "last 3 consultations averaged 80K tokens"). No automated throttling.

## File Inventory

### Modified Files

| File                                 | Change                                                                                              |
| ------------------------------------ | --------------------------------------------------------------------------------------------------- |
| `.claude/agents/cro.md`              | Update § Cross-Floor Risk Facilitation with triage step, guided template, early abort, max 2 rounds |
| `.claude/skills/floor/SKILL.md`      | Add `--domains` flag to `/floor propose`                                                            |
| `.claude/skills/compliance/SKILL.md` | Add `--domains` flag to `/compliance propose`                                                       |
| `.claude/skills/behavioral/SKILL.md` | Add `--domains` flag to `/behavioral propose`                                                       |
| `templates/fleet-config.json`        | Add `consultation` section with max_rounds, budget_tokens_hint                                      |
| `docs/GOVERNANCE-FLOORS.md`          | Document the efficient consultation protocol                                                        |

### No New Files

All changes are to existing files. No new scripts — this is protocol and agent definition work.

## Related Issues

- [#29](https://github.com/rdunie/venutian-antfarm/issues/29) -- Multi-floor governance (base system, completed)
- [#21](https://github.com/rdunie/venutian-antfarm/issues/21) -- Multi-context orchestration (future: enables parallel dispatch)
