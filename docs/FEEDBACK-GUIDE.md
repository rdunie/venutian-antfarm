# Feedback Guide

Behavioral feedback is recorded and queried via `ops/feedback-log.sh`. Governance and core agents issue feedback directly; specialist agents report feedback for governance review.

## Issuing and Reporting Feedback

```bash
# Governance/core agents issue feedback
ops/feedback-log.sh issue --agent <agent> --type reprimand|kudo --domain <domain> \
  [--severity low|medium|high] [--item <id>] --description "..." --evidence "..."

# Specialist agents report feedback
ops/feedback-log.sh report --agent <agent> --type reprimand|kudo --domain <domain> \
  [--item <id>] --description "..." --evidence "..."

# Feedback proposals (tracked with proposal ID)
ops/feedback-log.sh propose --agent <agent> --type reprimand|kudo --domain <domain> \
  [--severity low|medium|high] [--item <id>] --proposal <proposal-id> \
  --description "..." --evidence "..."
```

## Querying Behavioral Profiles

```bash
# Agent behavioral profile summary
ops/feedback-log.sh profile <agent>

# Feedback history with optional filters
ops/feedback-log.sh history <agent> [--since 7d] [--domain <domain>]

# Cross-agent tensions (disagreements, reprimand patterns)
ops/feedback-log.sh tensions [--item <id>] [--since 7d]

# Computed behavioral score for an agent
ops/feedback-log.sh score <agent>
```

## Subcommand Reference

| Subcommand | Who | Purpose |
|---|---|---|
| `issue` | Governance / core agents | Record a reprimand or kudo with direct authority |
| `report` | Specialist agents | Submit feedback for governance review |
| `propose` | Any agent | Attach feedback to a compliance proposal |
| `profile` | Any | View an agent's behavioral summary |
| `history` | Any | List feedback events for an agent |
| `tensions` | Any | Identify cross-agent friction patterns |
| `score` | Any | Get a computed behavioral score for an agent |

## Notes

- Feedback is always attributed to the issuing agent (`--agent`).
- `--severity` is required for `reprimand` type when using `issue`; optional for `kudo`.
- `--proposal` links feedback to a compliance change proposal tracked in `.claude/compliance/`.
- The `score` subcommand derives a weighted score from the agent's reprimand/kudo history; higher scores indicate stronger behavioral alignment.
- For escalation patterns and cross-floor risk, the CRO reviews tensions reports during compliance audits.

## Related

- `ops/rewards-log.sh` -- Legacy rewards interface (reprimand/kudo); prefer `ops/feedback-log.sh` for new work.
- `docs/GOVERNANCE-FLOORS.md` -- How behavioral feedback ties into floor enforcement.
- `.claude/COLLABORATION.md` -- Collaboration protocol and agent roles.
