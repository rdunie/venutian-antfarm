# CLAUDE.md

## Project Overview

**Venutian Antfarm** is an agent fleet harness framework for structured multi-agent software delivery. It provides 5 core agents (PO, SA, SM, memory-manager, platform-ops), a collaboration protocol with progressive autonomy, DORA + flow quality metrics, and an agent inheritance mechanism for domain-specific specialization.

## Directory Structure

```
.
├── .claude/
│   ├── settings.json                # Hook configuration
│   ├── COLLABORATION.md             # Collaboration protocol (source of truth)
│   ├── DOCUMENTATION-STYLE.md       # Documentation style guide
│   ├── agents/                      # Core agent definitions (5)
│   ├── skills/                      # Slash command skills
│   ├── findings/                    # Findings register + information needs
│   └── metrics/                     # Event log (JSONL)
├── docs/
│   ├── COLLABORATION-MODEL.md       # Visual collaboration model (Mermaid)
│   ├── AGENT-FLEET-PATTERN.md       # Pattern specification
│   ├── GETTING-STARTED.md           # Onboarding guide
│   └── plans/                       # Backlog and roadmap
├── ops/
│   ├── metrics-log.sh               # Event logging helper (pluggable backend)
│   ├── dora.sh                      # DORA + flow quality dashboard
│   ├── deploy.sh                    # Deploy contract (implementers override)
│   └── hooks/                       # Git/tool hooks
├── templates/                       # Templates for extending the harness
├── example/                         # Working example app
└── memory/
    ├── harness/                     # Framework-level memories
    └── app/                         # Application-specific memories
```

## Commands

### Metrics

```bash
# Log events (agents never write JSON directly)
ops/metrics-log.sh item-promoted 42
ops/metrics-log.sh item-accepted 42
ops/metrics-log.sh ext-deployed my-component --type planned
ops/metrics-log.sh bug-found 42 --severity high --source regression
ops/metrics-log.sh bug-fixed 42 --bug-id b1
ops/metrics-log.sh handoff-sent 42 --from backend-specialist --to security-reviewer
ops/metrics-log.sh handoff-rejected 42 --from backend-specialist --to security-reviewer --reason missing-tests
ops/metrics-log.sh agent-invoked product-owner --tokens 45800 --turns 10 --model opus --item 42
ops/metrics-log.sh task-restarted 42 --reason insufficient-detail
ops/metrics-log.sh task-blocked 42 --reason awaiting-decision
ops/metrics-log.sh task-unblocked 42

# Dashboard
ops/dora.sh                   # full dashboard (DORA + flow quality)
ops/dora.sh --sm              # SM pace recommendation
ops/dora.sh --item 42         # single item detail
ops/dora.sh --flow            # flow quality only
ops/dora.sh --cost            # agent cost analysis
ops/dora.sh --since 7d        # 7-day window
```

### Deployment

```bash
ops/deploy.sh <env> <component> [--type planned|hotfix]
```

Implementers replace `ops/deploy.sh` with their deployment logic. The contract: exit 0 = success, exit 1 = failure. stdout should include deployment URL or identifier.

## Workflow

1. **Clarify** -- Confirm intent before designing. Ask if ambiguous.
2. **Plan** -- Plan before building for non-trivial tasks. Get approval first.
3. **Research** -- Fetch docs before guessing at APIs.
4. **TDD** -- Tests first. Write tests before implementation.
5. **Commit often** -- Conventional commits after each passing task.
6. **Validate** -- Full validation cycle: code, test, typecheck, build, deploy.

## Agent Inheritance

App-level agents can extend harness agents using frontmatter:

```yaml
---
extends: harness/scrum-master
---
# App-specific additions and overrides go here
```

When `extends` is present:
- App fields override harness fields of the same name
- Harness fields not mentioned in the app definition are preserved
- The merged result is what the agent sees at runtime

## Compliance Floor

The compliance floor defines non-negotiable rules that override all autonomy tiers, pace settings, and process decisions. It encompasses security, data governance, audit requirements, regulatory controls, access policies, and domain-specific compliance rules.

Define your compliance floor in `compliance-floor.md` at the project root. Keep it short (3-5 rules), absolute, and enforced by hooks where possible.

## Architecture Constraints

1. **Compliance floor is sacred.** No agent deprioritizes, defers, or works around compliance floor rules.
2. **Config over code.** Use framework configuration before writing custom code.
3. **Agent isolation.** Each agent owns a specific domain and does not modify artifacts outside that domain without involving the domain owner.
4. **Metrics-driven decisions.** Pace changes, process adjustments, and quality assessments are grounded in measured data.

## Anti-Patterns

Never implement:

- Disabling compliance floor mechanisms as a "fix" -- always fix the root cause
- Skipping the findings loop -- every notable event should be recorded
- Binary autonomy (all-or-nothing) -- use progressive pace control
- Writing metrics JSON directly -- always use `ops/metrics-log.sh`
- Documenting planned features as current state -- mark unimplemented with `(planned)`
- Duplicating documentation -- cross-link to the source of truth

## Reference Documents

- `.claude/COLLABORATION.md` -- Collaboration protocol (source of truth)
- `.claude/DOCUMENTATION-STYLE.md` -- Documentation style guide
- `docs/COLLABORATION-MODEL.md` -- Visual collaboration model with Mermaid diagrams
- `docs/AGENT-FLEET-PATTERN.md` -- Full pattern specification
- `docs/GETTING-STARTED.md` -- Onboarding guide
- `docs/plans/roadmap-index.md` -- Backlog structure
