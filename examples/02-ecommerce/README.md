# Example 02: E-Commerce Platform

A two-specialist e-commerce setup demonstrating agent inheritance, overrides, and domain-specific compliance. This is the first example that uses `extends:` to inherit from harness templates.

## What This Teaches Beyond 01

- Splitting work across **multiple specialists** with distinct domains and tech stacks
- **Agent inheritance** with `extends:` for specialists and overrides for core agents
- **Domain-specific compliance** (PCI, GDPR, audit logging)
- **Tuning framework knobs**: retro cadence, knowledge cadence

## Structure

```
02-ecommerce/
├── .claude/
│   ├── agents/
│   │   ├── frontend-specialist.md   # Extends harness template
│   │   └── backend-specialist.md    # Extends harness template
│   └── overrides/
│       └── scrum-master.md          # Retro cadence override
├── floors/
│   └── compliance.md              # 5 rules (PCI, GDPR, audit)
├── fleet-config.json                # 2 specialists, pathways, knowledge cadence
└── ops/
    └── deploy.sh                    # Deploy stub
```

## Try It

```bash
ops/test-example.sh 02-ecommerce
# cd into the worktree, open Claude Code
/po
```

## What to Try

1. **`/po`** — See the fleet with two specialists
2. **Build a feature touching both frontend and backend** — watch the PO dispatch to each specialist
3. **Look at the agent files** — see how `extends: harness/frontend-specialist` works
4. **Look at the scrum-master override** — see how retro cadence is changed without redefining the whole agent

## Prerequisites

You should be comfortable with [01-getting-started](../01-getting-started/) before this example.

## Next Example

Move to [03-multi-team](../03-multi-team/) to learn about review gates and cross-team pathways.
