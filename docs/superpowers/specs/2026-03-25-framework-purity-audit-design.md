# Framework Purity Audit — Move Implementer Artifacts to Templates + Onboarding

**Issue:** [#27](https://github.com/rdunie/venutian-antfarm/issues/27)
**Date:** 2026-03-25
**Status:** Draft

## Problem

The framework repo ships with 13 runtime artifacts in `.claude/` that should only exist after onboarding. These are empty-but-initialized files (compliance targets, change logs, findings registers, executive briefs, etc.) that live in runtime locations instead of `templates/`. This violates the framework-purity boundary: the repo IS the product, not an implementation.

## Goals

1. **Clean separation** — The repo contains only framework files (agents, skills, protocol, tooling, templates). Runtime artifacts are created during onboarding.
2. **Onboarding creates everything** — A single onboarding step scaffolds all runtime directories and copies templates.
3. **No runtime breakage** — Agent definitions, skills, and hooks that reference `.claude/` paths continue to work because the paths are still correct at runtime.

## Non-Goals

- Changing the onboarding UX beyond adding one step
- Updating examples (that's #14)
- Changing how hooks, agents, or skills reference paths

## Design

### 1. Artifact Inventory

**Move to templates:**

| Current Location | Destination |
|---|---|
| `.claude/compliance/change-log.md` | `templates/compliance/change-log.md` |
| `.claude/compliance/targets.md` | `templates/compliance/targets.md` |
| `.claude/governance/executive-brief.md` | `templates/governance/executive-brief.md` |
| `.claude/governance/guidance-registry.md` | `templates/governance/guidance-registry.md` |
| `.claude/findings/register.md` | `templates/findings/register.md` |
| `.claude/findings/information-needs.md` | `templates/findings/information-needs.md` |

**Delete (no template needed — created by `mkdir -p` or `touch` at onboarding):**

| File | Reason |
|------|--------|
| `.claude/compliance/proposals/.gitkeep` | Directory scaffold |
| `.claude/compliance/compiled/.gitkeep` | Directory scaffold |
| `.claude/compliance/eslint/no-eval.json` | Empty stub — compiler generates these |
| `.claude/compliance/semgrep/no-hardcoded-secrets.yaml` | Empty stub — compiler generates these |
| `.claude/governance/guidance/ceo/.gitkeep` | Directory scaffold |
| `.claude/governance/guidance/cfo/.gitkeep` | Directory scaffold |
| `.claude/governance/guidance/ciso/.gitkeep` | Directory scaffold |
| `.claude/governance/guidance/cko/.gitkeep` | Directory scaffold |
| `.claude/governance/guidance/coo/.gitkeep` | Directory scaffold |
| `.claude/governance/guidance/cto/.gitkeep` | Directory scaffold |
| `.claude/governance/decisions/.gitkeep` | Directory scaffold |
| `.claude/metrics/events.jsonl` | Empty file |

**What stays in `.claude/`:** Agent definitions (`agents/`), skills (`skills/`), `COLLABORATION.md`, `DOCUMENTATION-STYLE.md`, `settings.json`. These ARE the framework.

### 2. Onboarding Expansion

Add **Step 2c: Scaffold Runtime Artifacts** to `.claude/skills/onboard/SKILL.md`, immediately after Step 2b (Governance Activation):

```markdown
### Step 2c: Scaffold Runtime Artifacts

Create the runtime directory structure and copy templates:

```bash
# Compliance
mkdir -p .claude/compliance/proposals
mkdir -p .claude/compliance/compiled
cp templates/compliance/change-log.md .claude/compliance/change-log.md
cp templates/compliance/targets.md .claude/compliance/targets.md

# Governance
mkdir -p .claude/governance/decisions
mkdir -p .claude/governance/guidance/{ceo,cfo,ciso,cko,coo,cto}
cp templates/governance/executive-brief.md .claude/governance/executive-brief.md
cp templates/governance/guidance-registry.md .claude/governance/guidance-registry.md

# Findings
mkdir -p .claude/findings
cp templates/findings/register.md .claude/findings/register.md
cp templates/findings/information-needs.md .claude/findings/information-needs.md

# Metrics
mkdir -p .claude/metrics
touch .claude/metrics/events.jsonl

# Rewards (if templates exist)
if [ -d templates/rewards ]; then
  mkdir -p .claude/rewards
  cp templates/rewards/ledger.md .claude/rewards/ledger.md
  sha256sum .claude/rewards/ledger.md > .claude/rewards/ledger-checksum.sha256
fi
```
```

The onboarding summary checklist adds:
```
- [x] Runtime artifacts scaffolded (compliance, governance, findings, metrics)
```

### 3. Reference Updates

**CLAUDE.md Directory Structure** — The `.claude/` tree remains accurate (it describes runtime state). Add a comment noting these are created during onboarding:

```
├── .claude/
│   ├── settings.json                # Hook configuration
│   ├── COLLABORATION.md             # Collaboration protocol (source of truth)
│   ├── DOCUMENTATION-STYLE.md       # Documentation style guide
│   ├── agents/                      # Core agent definitions (13)
│   ├── governance/                  # Governance infrastructure (created at onboarding)
│   ├── skills/                      # Slash command skills (/po, /retro, /onboard)
│   ├── compliance/                  # Compliance governance (created at onboarding)
│   ├── findings/                    # Findings register (created at onboarding)
│   └── metrics/                     # Event log (created at onboarding)
```

**CLAUDE.md Quick Start** — Add onboarding reference:

```bash
cp templates/fleet-config.json fleet-config.json   # configure your fleet
cp templates/compliance-floor.md compliance-floor.md # define non-negotiable rules
# Or run /onboard for guided setup including all runtime artifacts
```

**CLAUDE.md templates/ tree** — Update to show new subdirectories:

```
├── templates/
│   ├── compliance-floor.md          # Starter compliance floor
│   ├── fleet-config.json            # Fleet configuration template
│   ├── agents/                      # Specialist agent templates (5)
│   ├── compliance/                  # Runtime compliance artifacts
│   ├── governance/                  # Runtime governance artifacts
│   ├── findings/                    # Runtime findings artifacts
│   └── rewards/                     # Runtime rewards artifacts
```

**settings.json hooks** — No changes needed. Existing hooks (compliance artifact check, rewards checksum check) already handle missing files gracefully with `|| true`.

**Agent definitions and skills** — No changes needed. They reference `.claude/` paths which are correct at runtime (post-onboarding).

## File Inventory

### New Files

| File | Purpose |
|------|---------|
| `templates/compliance/change-log.md` | Template for compliance change log |
| `templates/compliance/targets.md` | Template for compliance targets |
| `templates/governance/executive-brief.md` | Template for executive brief |
| `templates/governance/guidance-registry.md` | Template for guidance registry |
| `templates/findings/register.md` | Template for findings register |
| `templates/findings/information-needs.md` | Template for information needs |

### Deleted Files

| File | Reason |
|------|--------|
| `.claude/compliance/change-log.md` | Moved to templates |
| `.claude/compliance/targets.md` | Moved to templates |
| `.claude/compliance/proposals/.gitkeep` | Created at onboarding |
| `.claude/compliance/compiled/.gitkeep` | Created at onboarding |
| `.claude/compliance/eslint/no-eval.json` | Empty stub — compiler output |
| `.claude/compliance/semgrep/no-hardcoded-secrets.yaml` | Empty stub — compiler output |
| `.claude/governance/executive-brief.md` | Moved to templates |
| `.claude/governance/guidance-registry.md` | Moved to templates |
| `.claude/governance/guidance/ceo/.gitkeep` | Created at onboarding |
| `.claude/governance/guidance/cfo/.gitkeep` | Created at onboarding |
| `.claude/governance/guidance/ciso/.gitkeep` | Created at onboarding |
| `.claude/governance/guidance/cko/.gitkeep` | Created at onboarding |
| `.claude/governance/guidance/coo/.gitkeep` | Created at onboarding |
| `.claude/governance/guidance/cto/.gitkeep` | Created at onboarding |
| `.claude/governance/decisions/.gitkeep` | Created at onboarding |
| `.claude/metrics/events.jsonl` | Created at onboarding |

### Modified Files

| File | Change |
|------|--------|
| `.claude/skills/onboard/SKILL.md` | Add Step 2c: Scaffold Runtime Artifacts |
| `CLAUDE.md` | Update directory tree comments, quick start note, templates tree |

### Not Changed (Intentionally)

- Agent definitions — runtime paths unchanged
- Other skills — they read `.claude/` paths, which exist post-onboarding
- `settings.json` — hooks gracefully handle missing files
- Examples — refresh is #14

## Related Issues

- [#14](https://github.com/rdunie/venutian-antfarm/issues/14) — Examples refresh (separate, after this)
- [#13](https://github.com/rdunie/venutian-antfarm/issues/13) — Rewards system (already follows this pattern)
