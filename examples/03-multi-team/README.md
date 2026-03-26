# Example 03: Multi-Team

A SaaS platform with frontend, backend, and a security reviewer who gates deployments to staging and production. Demonstrates cross-team coordination and review gates.

## What This Teaches Beyond 02

- Adding a **review agent** to the workflow and gating deployments through it
- **Cross-specialist pathways** — frontend and backend hand off directly to each other
- Compliance rules that **mandate agent involvement** (not just technical constraints)
- **Three-environment promotion** — dev → staging → prod
- How `ops/pathways.sh` catches undeclared communication between agents
- **Enforcement blocks** in the compliance floor that the compiler extracts into hook rules

## Structure

```
03-multi-team/
├── .claude/
│   ├── agents/
│   │   ├── frontend-specialist.md   # SaaS frontend (extends harness)
│   │   ├── backend-specialist.md    # SaaS backend (extends harness)
│   │   └── security-reviewer.md     # Gates staging/prod (extends harness)
│   └── overrides/
│       └── scrum-master.md          # Retro cadence override
├── floors/
│   └── compliance.md              # 5 rules + 2 enforcement blocks (secrets, metrics)
├── fleet-config.json                # 2 specialists + 1 reviewer, cross-team pathways
└── ops/
    └── deploy.sh                    # Three-env deploy stub
```

## Try It

```bash
ops/test-example.sh 03-multi-team
# cd into the worktree, open Claude Code
/po
```

## What to Try

1. **Build a feature that touches both frontend and backend** — watch cross-specialist handoffs
2. **Try deploying to staging** — the security-reviewer gate kicks in
3. **Run `ops/pathways.sh`** — see declared vs actual agent communication
4. **Introduce an undeclared pathway** — watch pathway analysis flag it

## Prerequisites

You should be comfortable with [01-getting-started](../01-getting-started/) and [02-ecommerce](../02-ecommerce/) before this example.
