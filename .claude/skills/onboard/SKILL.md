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

Check if `floors/compliance.md` exists at project root.

- **If missing:** Copy from `templates/floors/compliance.md` and ask the user to define 3-5 non-negotiable rules for their domain. Provide examples:
  - E-commerce: "No credit card numbers stored outside the payment processor"
  - Healthcare: "No PHI transmitted without encryption"
  - SaaS: "Tenant data isolation enforced on every query"
- **If exists:** Read it, confirm with user, move on.

### Step 2b: Governance Activation

After the compliance floor is defined:

1. **CRO takes guardianship.** Generate initial checksum:
   ```bash
   mkdir -p .claude/floors/compliance
   sha256sum floors/compliance.md | cut -d' ' -f1 > .claude/floors/compliance/floor-checksum.sha256
   echo "$(git rev-parse HEAD)" >> .claude/floors/compliance/floor-checksum.sha256
   ```
2. **CISO security review.** Dispatch the CISO agent to evaluate whether the floor adequately covers security for the project's domain. The CISO may propose additions via `/compliance propose`.
3. **Process proposals.** If the CISO proposed additions, the CRO processes them through the standard change control process. User approves the final floor.

### Step 2c: Behavioral Floor Setup

Ask the user if they want to define behavioral rules for their team.

- **If yes:** Copy from `templates/floors/behavioral.md` to `floors/behavioral.md`. Walk the user through example behavioral rules:
  - "We MUST ALWAYS run full validation before handoff"
  - "We MUST NEVER skip the findings loop on notable events"
  - "We MUST ALWAYS confirm intent before designing for non-trivial tasks"
- Help the user define 2-4 behavioral rules appropriate for their team's workflow.
- Generate initial checksum:
  ```bash
  mkdir -p .claude/floors/behavioral
  sha256sum floors/behavioral.md | cut -d' ' -f1 > .claude/floors/behavioral/floor-checksum.sha256
  echo "$(git rev-parse HEAD)" >> .claude/floors/behavioral/floor-checksum.sha256
  ```
- **If no:** Skip. The behavioral floor can be added later via `/behavioral propose`.

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
- [x] Compliance floor guardianship activated (CRO + checksum)
- [x] Security review completed (CISO)
- [ ] Behavioral floor defined (optional)

Next steps:
- Run `/po` to see your status overview
- Run `/po groom` to refine your first item
- Start building with `/po next`
```
