# Example: E-Commerce Platform

A minimal but complete example of the Venutian Antfarm harness applied to an e-commerce platform. Demonstrates:

- 2 specialist agents (frontend + backend) using `extends:`
- A compliance floor with both security and non-security rules
- A deploy.sh that echoes what it would do
- A fleet-config.json with sensible defaults
- An override changing retro cadence to every 2 iterations

## Structure

```
example/
├── .claude/
│   ├── agents/
│   │   ├── frontend-specialist.md   # Extends harness template
│   │   └── backend-specialist.md    # Extends harness template
│   └── overrides/
│       └── scrum-master.md          # Retro cadence override
├── compliance-floor.md              # E-commerce compliance rules
├── fleet-config.json                # Fleet configuration
└── ops/
    └── deploy.sh                    # Deploy stub
```

## Quick Start

```bash
# Copy example into a new project
cp -r example/ my-ecommerce-project/
cd my-ecommerce-project/

# The 5 core agents + 2 specialists are ready
# Open Claude Code and start with /po
```
