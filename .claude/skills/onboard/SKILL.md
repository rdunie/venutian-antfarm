---
name: onboard
description: "Interactive project setup: copy templates, configure fleet, define compliance floor, add first specialist agent."
---

# Onboard

Interactive setup for a new project using the Venutian Antfarm harness. Follows `docs/GETTING-STARTED.md`.

## Workflow

### Step 1: Check Prerequisites

Verify required tools are available:

```bash
command -v git && command -v claude && command -v bash
command -v jq  # optional but recommended
```

Report any missing prerequisites before proceeding.

### Step 2: Compliance Floor

Check if `compliance-floor.md` exists at project root.

- **If missing:** Copy from `templates/compliance-floor.md` and ask the user to define 3-5 non-negotiable rules for their domain. Provide examples:
  - E-commerce: "No credit card numbers stored outside the payment processor"
  - Healthcare: "No PHI transmitted without encryption"
  - SaaS: "Tenant data isolation enforced on every query"
- **If exists:** Read it, confirm with user, move on.

### Step 3: Fleet Configuration

Check if `fleet-config.json` exists at project root.

- **If missing:** Copy from `templates/fleet-config.json` and walk the user through:
  - `project.name` — their project name
  - `metrics.backend` — recommend `"jsonl"` to start
  - `agents.specialists` — which specialist agents they plan to add
  - `retro.cadence` — recommend `1` (retro after every item) for new teams
- **If exists:** Read it, confirm with user, move on.

### Step 4: First Specialist Agent

Ask the user what their primary tech stack is, then recommend a specialist template:

| Stack                       | Template                                  |
| --------------------------- | ----------------------------------------- |
| Node/Python/Go/Rust backend | `templates/agents/backend-specialist.md`  |
| React/Vue/Angular frontend  | `templates/agents/frontend-specialist.md` |
| Security-focused            | `templates/agents/security-reviewer.md`   |
| E2E testing                 | `templates/agents/e2e-test-engineer.md`   |
| Infrastructure/DevOps       | `templates/agents/infrastructure-ops.md`  |

Copy the chosen template to `.claude/agents/` and help the user customize:

- Domain description
- Responsibilities
- Tech stack specifics

### Step 5: First Backlog Item

Help the user create their first tier file at `docs/plans/tier-1-launch-blockers.md` with at least one work item. Walk them through the item format defined in `.claude/COLLABORATION.md`.

### Step 6: Validate

Run validation to confirm everything is wired up:

```bash
ops/dora.sh          # metrics pipeline works
ops/pathways.sh      # pathway analysis works
bash -n ops/*.sh     # all scripts parse
```

### Step 7: Summary

Print a checklist of what was set up:

```
## Onboarding Complete

- [x] Compliance floor defined
- [x] Fleet configured
- [x] Specialist agent added: <name>
- [x] First backlog item created
- [x] Validation passed

Next steps:
- Run `/po` to see your status overview
- Run `/po groom` to refine your first item
- Start building with `/po next`
```
