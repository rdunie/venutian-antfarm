# Feedback Guide

Behavioral feedback is recorded and queried via `ops/feedback-log.sh`. The script is the single entry point for all ledger writes and reads — agents never edit the ledger directly.

Two tracks exist: governance and core agents issue feedback directly; specialist agents propose it for supervisor review.

## Direct Feedback (Governance and Core Agents)

### `reprimand`

Records a negative behavioral signal. All fields are required.

```bash
ops/feedback-log.sh reprimand \
  --issuer <agent> \
  --subject <agent> \
  --domain <domain> \
  --severity low|medium|high \
  --description "What happened" \
  --evidence "Concrete reference" \
  [--item <id>]
```

Example:

```bash
ops/feedback-log.sh reprimand \
  --issuer cro \
  --subject compliance-auditor \
  --domain security \
  --severity medium \
  --description "Skipped evidence collection before closing finding" \
  --evidence "Finding F-017 closed with no attached evidence block" \
  --item 38
```

### `kudo`

Records a positive behavioral signal. `--severity` is not required.

```bash
ops/feedback-log.sh kudo \
  --issuer <agent> \
  --subject <agent> \
  --domain <domain> \
  --description "What was good" \
  --evidence "Concrete reference" \
  [--item <id>]
```

Both subcommands print `reward_id=<R-NNN|K-NNN>` on success and emit a `reward-issued` metric event. If a new signal conflicts with an existing one (same subject, same item, opposing type), a tension entry is auto-generated.

---

## Specialist Proposals

Specialists cannot issue feedback directly. Instead they `recommend`, and the routed supervisor `formalize`s or `reject`s.

### `recommend`

Proposes feedback. The script resolves the supervisor from `fleet-config.json` (`pathways.declared.feedback`) and records a `P-NNN` proposal with a 7-day escalation deadline.

```bash
ops/feedback-log.sh recommend \
  --issuer <specialist-agent> \
  --subject <agent> \
  --type kudo|reprimand \
  --domain <domain> \
  --description "..." \
  --evidence "..." \
  [--severity low|medium|high]   # required when --type reprimand
  [--item <id>]
```

Prints `proposal_id=P-NNN` on success.

### `formalize`

Supervisor approves a pending proposal. Converts the proposal to a `K-NNN` or `R-NNN` entry and marks the proposal as `formalized`.

```bash
ops/feedback-log.sh formalize P-001 --issuer <supervisor-agent>
```

The issuer must match the supervisor recorded on the proposal. Prints `reward_id=<K|R>-NNN`.

### `reject`

Supervisor declines a pending proposal.

```bash
ops/feedback-log.sh reject P-001 --issuer <supervisor-agent> --reason "Insufficient evidence"
```

`--reason` is required. Marks the proposal as `rejected — <reason>`.

---

## Escalation

### `check-escalations`

Scans the ledger for pending proposals whose deadline has passed and escalates them to the next agent in the governance pathway. Each escalation extends the deadline by 7 days, updates the supervisor, adds a finding to the register, and emits a `feedback-escalated` metric.

```bash
ops/feedback-log.sh check-escalations
```

Run this periodically — the SM typically calls it before or during a retro. No arguments needed.

---

## Queries

### `profile`

Human-readable behavioral summary for an agent: signal counts, breakdown by domain and tier, 5 most recent entries, pending proposal count, and weighted score.

```bash
ops/feedback-log.sh profile <agent>
```

Example output:

```
compliance-auditor: 4 kudos, 2 reprimands, 1 tensions (1 open)
By domain:
  security (3)
  process (2)
  delivery (1)
Recent:
  R-004 [reprimand] 2026-03-20 — cro / security
  K-005 [kudo] 2026-03-22 — coo / delivery
  ...
Weighted: net=3.2 (kudos=4.0, reprimands=-0.8, 5 of 6 recent)
```

### `score`

Machine-parseable version of the weighted score. Useful for automation or dashboard scripting.

```bash
ops/feedback-log.sh score <agent>
```

Output lines: `net=`, `kudos=`, `reprimands=`, `signals=`, `recent=`.

### `tensions`

Lists open tension entries — cases where opposing feedback (a kudo and a reprimand) exists for the same subject on the same item. Optionally filter by item.

```bash
ops/feedback-log.sh tensions
ops/feedback-log.sh tensions --item 38
```

The SM should surface open tensions during retros. The CRO reviews patterns during compliance audits.

---

## Weighted Scoring

The score is not a simple count. Each signal is weighted across three axes:

- **Tier multiplier** — governance (1.0) > core (0.8) > specialist (0.5). Feedback from a governance agent carries more weight.
- **Type multiplier** — reprimands (1.5) are weighted higher than kudos (1.0). A single reprimand has more pull than a kudo.
- **Domain multiplier** — configurable per domain and per agent in `fleet-config.json` under `rewards.weighting.domain_multipliers`. Defaults to 1.0.

Decay applies a step function: signals older than `cliff_items` accepted items drop to `post_cliff_multiplier` (default: beyond 10 accepted items, weight drops to 0.25x). This prevents old signals from dominating the score indefinitely.

Defaults come from the script. Override them in `fleet-config.json`:

```json
"rewards": {
  "weighting": {
    "tier_multipliers": { "governance": 1.0, "core": 0.8, "specialist": 0.5 },
    "type_multipliers": { "reprimand": 1.5, "kudo": 1.0 },
    "domain_multipliers": { "security": 1.2, "_default": 1.0 },
    "decay": { "cliff_items": 10, "post_cliff_multiplier": 0.25 }
  },
  "escalation_deadline_days": 7
}
```

---

## Subcommand Reference

| Subcommand          | Who                    | What it does                          |
| ------------------- | ---------------------- | ------------------------------------- |
| `reprimand`         | Governance / core      | Record a negative signal directly     |
| `kudo`              | Governance / core      | Record a positive signal directly     |
| `recommend`         | Specialist             | Propose feedback, route to supervisor |
| `formalize`         | Supervisor             | Approve a pending proposal            |
| `reject`            | Supervisor             | Decline a pending proposal            |
| `check-escalations` | Any (SM by convention) | Auto-escalate stale proposals         |
| `profile`           | Any                    | Human-readable behavioral summary     |
| `score`             | Any                    | Machine-parseable weighted score      |
| `tensions`          | Any                    | List open conflicting-signal entries  |

---

## Related

- `docs/GOVERNANCE-FLOORS.md` — How behavioral feedback ties into floor enforcement.
- `.claude/COLLABORATION.md` — Collaboration protocol and agent roles.
- `fleet-config.json` — Pathway declarations and scoring configuration.
