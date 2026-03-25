# CLAUDE.md

## Project Overview

**Venutian Antfarm** is an agent fleet harness framework for structured multi-agent software delivery. It provides 13 core agents across 2 tiers: governance (CO, CISO, CEO, CTO, CFO, COO, CKO) and operational (PO, SA, SM, knowledge-ops, platform-ops, compliance-auditor), a collaboration protocol with progressive autonomy, DORA + flow quality metrics, and an agent inheritance mechanism for domain-specific specialization.

## Quick Start

```bash
cp templates/fleet-config.json fleet-config.json   # configure your fleet
cp templates/compliance-floor.md compliance-floor.md # define non-negotiable rules
# See examples/ for progressive working references
```

**Prerequisites:** Claude Code CLI, Git, Bash, jq (optional).

## Directory Structure

```
.
├── .claude/
│   ├── settings.json                # Hook configuration
│   ├── COLLABORATION.md             # Collaboration protocol (source of truth)
│   ├── DOCUMENTATION-STYLE.md       # Documentation style guide
│   ├── agents/                      # Core agent definitions (13)
│   ├── governance/                  # Governance infrastructure (executive brief, guidance registry, decisions)
│   ├── skills/                      # Slash command skills (/po, /retro, /onboard)
│   ├── compliance/                   # Compliance governance (change log, targets, proposals)
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
│   ├── pathways.sh                  # Agent pathway analysis
│   ├── deploy.sh                    # Deploy contract (implementers override)
│   └── hooks/                       # Git/tool hooks
├── templates/
│   ├── compliance-floor.md          # Starter compliance floor
│   ├── fleet-config.json            # Fleet configuration template
│   └── agents/                      # Specialist agent templates (5)
├── examples/                        # Progressive examples (01-05)
└── memory/
    ├── harness/                     # Framework-level memories
    └── app/                         # Application-specific memories
```

## Key Files

- **`fleet-config.json`** -- Project-level fleet configuration: pace thresholds, agent roster, declared pathways, metrics backend, retro cadence. Copy from `templates/fleet-config.json`.
- **`.claude/agents/*.md`** -- Agent definitions with frontmatter (`name`, `model`, `color`). The 13 agents: 7 governance (compliance-officer, ciso, ceo, cto, cfo, coo, cko) + 6 operational (product-owner, solution-architect, scrum-master, knowledge-ops, platform-ops, compliance-auditor).
- **`.claude/findings/register.md`** -- Findings register where notable events are recorded during work.
- **`.claude/metrics/events.jsonl`** -- Event log (append-only, written by `ops/metrics-log.sh`, never directly).
- **`.mcp.json`** -- Team-shared MCP server configuration (GitHub MCP). Checked into git.

## Commands

### Metrics

```bash
# Log events (agents never write JSON directly)
ops/metrics-log.sh item-promoted 42
ops/metrics-log.sh item-accepted 42
ops/metrics-log.sh bug-found 42 --severity high --source regression
ops/metrics-log.sh handoff-sent 42 --from backend-specialist --to security-reviewer
ops/metrics-log.sh agent-invoked product-owner --tokens 45800 --turns 10 --model opus --item 42
ops/metrics-log.sh backlog-triaged --items-reviewed 12 --items-added 2 --items-dropped 1 --items-reordered 3
# Other event types: ext-deployed, bug-fixed, handoff-rejected, item-rejected-at-build,
# task-restarted, task-discarded, task-blocked, task-unblocked, regression-run

# Dashboard
ops/dora.sh                   # full dashboard (DORA + flow quality)
ops/dora.sh --sm              # SM pace recommendation
ops/dora.sh --item 42         # single item detail
ops/dora.sh --flow            # flow quality only
ops/dora.sh --cost            # agent cost analysis
ops/dora.sh --since 7d        # 7-day window
```

### Rewards

```bash
# Issue behavioral feedback
ops/rewards-log.sh reprimand --issuer <agent> --subject <agent> --domain <domain> \
  --severity low|medium|high [--item <id>] --description "..." --evidence "..."
ops/rewards-log.sh kudo --issuer <agent> --subject <agent> --domain <domain> \
  [--item <id>] --description "..." --evidence "..."

# Query behavioral profiles
ops/rewards-log.sh profile <agent>
ops/rewards-log.sh tensions [--item <id>]
```

### Pathway Analysis

```bash
ops/pathways.sh              # Compare declared vs actual agent communication pathways
ops/pathways.sh --since 7d   # Scoped to recent window
```

### Deployment

```bash
ops/deploy.sh <env> <component> [--type planned|hotfix]
```

Implementers replace `ops/deploy.sh` with their deployment logic. The contract: exit 0 = success, exit 1 = failure. stdout should include deployment URL or identifier.

### Compliance Compiler

```bash
ops/compile-floor.sh                              # Compile floor → artifacts
ops/compile-floor.sh --dry-run                     # Validate without writing
ops/compile-floor.sh --verify                      # Check artifacts match source
ops/compile-floor.sh --proposal 003                # Tag artifacts with proposal ID
ops/tests/test-compile-floor.sh                    # Run compiler tests
```

### Validation

```bash
ops/dora.sh                          # Verify metrics pipeline works
ops/pathways.sh                      # Verify pathway analysis works
bash -n ops/*.sh                     # Syntax-check all scripts
```

## Workflow

1. **Prioritize** -- Triage the backlog before grooming. Run `/po triage`.
2. **Track** -- When the user requests work not currently tracked, add an item to the backlog before or alongside execution. No untracked work.
3. **Clarify** -- Confirm intent before designing. Ask if ambiguous.
4. **Plan** -- Plan before building for non-trivial tasks. Get approval first.
5. **Research** -- Fetch docs before guessing at APIs.
6. **Delegate** -- Dispatch specialists for domain-specific work. Ad-hoc requests go to the backlog first.
7. **TDD** -- Tests first. Write tests before implementation.
8. **Commit often** -- Conventional commits after each passing task.
9. **Validate** -- Full validation cycle: code, test, typecheck, build, deploy.

Work items follow the 10-phase lifecycle defined in `.claude/COLLABORATION.md` § Work Item Lifecycle: Prioritize, Groom, Promote, Build, Review, Fix, Deploy, Accept, Retro, Checkpoint.

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

Define your compliance floor in `compliance-floor.md` at the project root (see `templates/compliance-floor.md` for a starter). Keep it short (3-5 rules), absolute, and enforced by hooks where possible.

## Hooks (settings.json)

Active hooks that affect every session:

- **PreToolUse (Edit/Write)**: Blocks edits to `.env`, lock files, and secrets
- **PreToolUse (Bash)**: Blocks direct writes to `events.jsonl` (enforces `ops/metrics-log.sh`)
- **PostToolUse (Edit/Write)**: Auto-runs prettier and eslint on changed files; syncs collaboration doc; `bash -n` syntax check on `.sh` files
- **PostToolUse (Bash)**: Prompts PO review on feat/fix commits
- **SubagentStop**: Logs agent completion; prompts PO review or findings check
- **PreCompact**: Preserves key context (agent fleet summary) during auto-compression
- **SessionStart**: Prompts PO status overview

## Architecture Constraints

1. **Compliance floor is sacred.** No agent deprioritizes, defers, or works around compliance floor rules.
2. **Config when flexible, code when predictable.** Use framework configuration (fleet-config.json, agent frontmatter, hooks) when flexibility and rapid iteration deliver more value. Use code (scripts, tools, custom logic) when predictability, performance, or cost optimization are the primary drivers.
3. **Agent isolation.** Each agent owns a specific domain and does not modify artifacts outside that domain without involving the domain owner.
4. **Metrics-driven decisions.** Pace changes, process adjustments, and quality assessments are grounded in measured data.

## Gotchas

- **Metrics backend is pluggable**: Default is JSONL, but `fleet-config.json` supports webhook, StatsD, and OpenTelemetry backends. Always use `ops/metrics-log.sh` regardless of backend.
- **Pathway analysis catches governance bypasses**: `ops/pathways.sh` compares declared pathways in `fleet-config.json` against actual handoff events. Undeclared paths are flagged -- they may be innovation or unauthorized communication.
- **Pace thresholds are in `fleet-config.json`**, not in COLLABORATION.md. The collaboration doc records the _current_ pace; the config defines _when_ to promote.
- **The `examples/` directory contains 5 progressive examples** from minimum setup (01-getting-started) to operational maturity (05-operational-maturity). Test any example with `ops/test-example.sh <name>`.
- **Editing `settings.json`**: Use Write (full rewrite) instead of Edit for `settings.json` — complex escaped strings in hook commands cause JSON validation failures with partial edits.

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
