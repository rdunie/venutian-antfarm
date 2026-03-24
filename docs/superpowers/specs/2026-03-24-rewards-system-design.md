# Rewards System — Cx Behavioral Feedback

**Issue:** [#13](https://github.com/rdunie/venutian-antfarm/issues/13)
**Date:** 2026-03-24
**Status:** Draft

## Problem

Agents receive corrective enforcement (hooks block violations, CO reverts unauthorized changes) but no structured behavioral feedback loop. There is no mechanism for governance or leadership agents to recognize good work or flag concerning patterns. The CO's ad-hoc reprimand (a critical finding on floor tampering) is the only precedent, and it lacks accumulation, counterbalancing kudos, or conflict resolution.

## Goals

1. **Behavioral shaping over time** — accumulated signals that inform pace decisions, autonomy grants, and agent prompting. Not just punishment.
2. **Domain-scoped authority** — each issuer gives feedback within their expertise. A CISO reprimand on security carries different weight than a PO kudo on delivery speed.
3. **Conflict visibility** — when signals contradict on the same work, surface the tension rather than silently resolving it.
4. **Tamper resistance** — protect the ledger with the same hook + checksum pattern used for the compliance floor.
5. **Forward compatibility** — design interfaces so the signal bus (#24) and adaptive weighting (#25) slot in without rework.

## Non-Goals

- Auto-throttling or auto-promotion based on signal counts (future: #25)
- Automatic prompt injection of behavioral profiles into agent context
- Floor-level enforcement — rewards are shaping, not compliance rules
- Tamper-proof storage (future: #23 tamper-resistant configuration)

## Approach

**Approach B (ledger-first)** with forward-compatible interfaces for Approach C (signal bus, #24).

A dedicated behavioral ledger (`.claude/rewards/ledger.md`) is the primary artifact. A helper script (`ops/rewards-log.sh`) manages all writes, emits metrics events for audit, detects conflicts, and updates checksums. Agents read the ledger directly for behavioral context. The helper script is the abstraction boundary — when the signal bus lands, it becomes a consumer rather than being called directly.

## Design

### 1. Signal Sources and Issuance Authority

Governance agents (Cx) and the leadership triad (PO, SA, SM) may issue behavioral feedback, each scoped to their domain:

| Issuer | Domain Scope             | Example Reprimand                          | Example Kudo                                 |
| ------ | ------------------------ | ------------------------------------------ | -------------------------------------------- |
| CO     | Compliance floor/targets | Floor violation, unauthorized change       | Clean audit streak, proactive compliance     |
| CISO   | Security                 | Shallow security review, missed vuln class | Caught real threat, thorough threat model    |
| CEO    | Strategic alignment      | Work drifting from mission                 | Strong stakeholder alignment                 |
| CTO    | Technical standards      | Ignored architecture constraints           | Clean, well-tested implementation            |
| CFO    | Cost/efficiency          | Token waste, unnecessary agent invocations | Efficient agent usage, under-budget delivery |
| COO    | Process quality          | SLA miss, skipped process step             | Consistent process adherence                 |
| CKO    | Knowledge quality        | Stale docs, knowledge hoarding             | Good knowledge distribution                  |
| PO     | Delivery quality         | Incomplete AC, false "done"                | Clean first-pass acceptance                  |
| SA     | Architecture/design      | Shallow testing, poor isolation            | Solid design, thorough edge cases            |
| SM     | Process adherence        | Skipped retro, ignored WIP limits          | Good collaboration, findings filed           |

Specialist, reviewer, and output agents receive feedback but do not issue it.

### 2. Signal Structure

Every reward or reprimand carries:

```yaml
id: R-001 # auto-generated (R-NNN for reprimands, K-NNN for kudos)
type: reprimand | kudo
issuer: ciso # who issued it
subject: backend-specialist # who it's about
domain: security # issuer's domain scope
item: 42 # work item (optional, for item-scoped signals)
severity: low | medium | high # reprimands only
description: "Skipped edge-case testing for auth token expiry"
evidence: "Review of PR #87 found no expiry tests"
timestamp: 2026-03-24T14:00:00Z
```

### 3. Conflict Detection

When a kudo and reprimand reference the same `item` and `subject`, the helper script auto-generates:

1. A **tension entry** in the ledger (T-NNN) linking the conflicting signal IDs
2. A **tension finding** in `.claude/findings/register.md` with category `boundary-tension`

The SM surfaces tensions during retro. No auto-resolution — the user sees the full picture.

### 4. Behavioral Ledger

**Location:** `.claude/rewards/ledger.md`

Append-only markdown, grouped by subject agent:

```markdown
# Behavioral Ledger

## backend-specialist

### R-001 [reprimand] 2026-03-24 — CISO / security

**Severity:** high
**Item:** 42
**Description:** Skipped edge-case testing for auth token expiry
**Evidence:** Review of PR #87 found no expiry tests

### K-001 [kudo] 2026-03-24 — PO / delivery

**Item:** 42
**Description:** Delivered auth feature with clean first-pass AC acceptance
**Evidence:** All 5 acceptance criteria passed on first review

### T-001 [tension] 2026-03-24 — auto / item-42

**Signals:** K-001 vs R-001
**Description:** PO praised delivery; CISO flagged shallow security testing on same item
**Status:** open
**Referred to:** SM for retro
```

**Protection model** (mirrors compliance floor):

- **PreToolUse hook** blocks Edit/Write to `.claude/rewards/ledger.md` unless the sentinel file exists (same bypass pattern as compliance floor)
- **Checksum file** at `.claude/rewards/ledger-checksum.sha256` — verified on SessionStart by the CO
- **Tampering response** — revert from git, log `compliance-violation`, issue a reprimand to the tampering agent (if identifiable)

### 5. Helper Script Interface

`ops/rewards-log.sh` is the single entry point for all ledger operations:

```bash
# Issue a reprimand
ops/rewards-log.sh reprimand \
  --issuer <agent> --subject <agent> --domain <domain> \
  --severity low|medium|high \
  [--item <id>] \
  --description "..." --evidence "..."

# Issue a kudo
ops/rewards-log.sh kudo \
  --issuer <agent> --subject <agent> --domain <domain> \
  [--item <id>] \
  --description "..." --evidence "..."

# Query an agent's profile (read-only)
ops/rewards-log.sh profile <agent>

# Query open tensions
ops/rewards-log.sh tensions [--item <id>]
```

The script:

1. Assigns the next ID (R-NNN / K-NNN / T-NNN)
2. Appends to the ledger under the subject's section (creates section if new)
3. Emits `reward-issued` or `reprimand-issued` event via `ops/metrics-log.sh`
4. Checks for conflicts (same item + subject, opposing signal types) — auto-generates tension entry + findings register entry
5. Updates the checksum

**Forward compatibility:** This script is the abstraction boundary. When the signal bus (#24) lands, `rewards-log.sh` becomes a consumer that receives signals rather than being called directly. The ledger format and protection model don't change.

### 6. New Metrics Events

| Event              | Fields                                                                                                          | When                       |
| ------------------ | --------------------------------------------------------------------------------------------------------------- | -------------------------- |
| `reward-issued`    | `type` (kudo/reprimand), `issuer`, `subject`, `domain`, `severity` (reprimands), `item` (optional), `reward_id` | Every kudo or reprimand    |
| `tension-detected` | `reward_ids` (the conflicting pair), `item`, `subject`                                                          | Auto-generated on conflict |

### 7. Consumption Points

**Retro (Phase 8):** SM reads the subject agent's profile via `ops/rewards-log.sh profile <agent>`. Tensions, patterns, and repeat signals are surfaced in the retro summary.

**Pace decisions:** SM considers behavioral profile alongside DORA metrics when evaluating pace promotion/demotion. v1 uses judgment; adaptive weighting (#25) formalizes this later.

**Autonomy grants:** CEO references the ledger when recommending increased agent autonomy. Concrete evidence: "8 kudos, 0 reprimands over 10 items."

**Conformance reports:** CO includes behavioral summary stats: total signals, open tensions, repeat patterns, most active domains.

**Agent dispatching (selective):** The dispatching agent (usually PO or SM) may reference specific ledger entries when relevant context for the task. No automatic prompt injection.

**Not consumed in v1:** No auto-throttling, auto-promotion, or dispatch blocking based on signal counts.

### 8. Agent Definition Changes

**All issuers (CO, CISO, CEO, CTO, CFO, COO, CKO, PO, SA, SM)** — add a `## Behavioral Feedback` section granting authority and providing usage guidance:

```markdown
## Behavioral Feedback

You may issue kudos and reprimands within your domain scope using `ops/rewards-log.sh`.

- **Reprimands:** When an agent's work falls short of standards in your domain. Include evidence and severity.
- **Kudos:** When an agent demonstrates excellence in your domain. Include evidence.
- **Judgment:** Issue feedback at natural review points (Phase 4 Review, retros, audits). Do not issue feedback for every minor observation — reserve it for patterns or notable events.

When issuing feedback on the same item where another agent has already issued opposing feedback, a tension will be auto-generated. This is expected and healthy.
```

**CO** — add `§7 Ledger Guardianship`:

```markdown
### 7. Ledger Guardianship

Monitor `.claude/rewards/ledger.md` integrity. On SessionStart, verify the checksum in `.claude/rewards/ledger-checksum.sha256`. If a mismatch is detected:

1. Restore via `git checkout <commit> -- .claude/rewards/ledger.md`
2. Log `compliance-violation` event
3. Issue a reprimand to the tampering agent (if identifiable)
```

**SM** — add `§ Behavioral Profile Review`:

```markdown
### Behavioral Profile Review

During retros (Phase 8), review the subject agent's behavioral profile via `ops/rewards-log.sh profile <agent>`. Surface tensions, patterns, and repeat signals. Include behavioral observations in the retro summary.
```

## File Inventory

### New Files

| File                                     | Purpose                                       | Protected       |
| ---------------------------------------- | --------------------------------------------- | --------------- |
| `.claude/rewards/ledger.md`              | Behavioral ledger (append-only)               | Hook + checksum |
| `.claude/rewards/ledger-checksum.sha256` | Integrity verification                        | Hook            |
| `ops/rewards-log.sh`                     | Helper script — all ledger writes and queries | —               |
| `templates/rewards/ledger.md`            | Starter ledger for new projects               | —               |

### Modified Files

| File                                   | Change                                                 |
| -------------------------------------- | ------------------------------------------------------ |
| `ops/metrics-log.sh`                   | Add `reward-issued` and `tension-detected` event types |
| `.claude/settings.json`                | Add PreToolUse hooks for ledger protection             |
| `.claude/agents/compliance-officer.md` | Add §7 Ledger Guardianship                             |
| `.claude/agents/ciso.md`               | Add §Behavioral Feedback                               |
| `.claude/agents/ceo.md`                | Add §Behavioral Feedback                               |
| `.claude/agents/cto.md`                | Add §Behavioral Feedback                               |
| `.claude/agents/cfo.md`                | Add §Behavioral Feedback                               |
| `.claude/agents/coo.md`                | Add §Behavioral Feedback                               |
| `.claude/agents/cko.md`                | Add §Behavioral Feedback                               |
| `.claude/agents/product-owner.md`      | Add §Behavioral Feedback                               |
| `.claude/agents/solution-architect.md` | Add §Behavioral Feedback                               |
| `.claude/agents/scrum-master.md`       | Add §Behavioral Profile Review                         |
| `CLAUDE.md`                            | Document `ops/rewards-log.sh` in Commands section      |
| `templates/fleet-config.json`          | Add `rewards` section (placeholder for #25)            |

### Not Changed (Intentionally)

- `compliance-floor.md` — rewards are behavioral shaping, not floor rules
- `.claude/COLLABORATION.md` — consumption integrates into existing phases via agent definitions
- Specialist/reviewer agents — receive feedback, don't issue it

## Related Issues

- [#23](https://github.com/rdunie/venutian-antfarm/issues/23) — Tamper-resistant configuration (future: stronger protection)
- [#24](https://github.com/rdunie/venutian-antfarm/issues/24) — Signal bus architecture (future: replaces point-to-point)
- [#25](https://github.com/rdunie/venutian-antfarm/issues/25) — Adaptive weighting (future: configurable impact by agent/decay)
- [#21](https://github.com/rdunie/venutian-antfarm/issues/21) — Multi-context orchestration (enables real per-agent permissions)
