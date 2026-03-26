# Example 01: Getting Started

The minimum useful Venutian Antfarm setup. One generalist specialist, three compliance rules, and a deploy stub. Complete enough to run a work item through the full lifecycle.

## What This Teaches

- The minimum files needed to activate the framework
- That governance + core agents come from the harness — you only define specialists
- The full work item lifecycle end-to-end (groom → build → review → deploy → accept)
- How metrics start accumulating from the first item

## Structure

```
01-getting-started/
├── .claude/agents/
│   └── developer.md          # Self-contained generalist specialist
├── floors/
│   └── compliance.md         # 3 rules: secrets, testing, plan-before-build
├── fleet-config.json         # Minimal config: 1 specialist, 1 env, Crawl
└── ops/
    └── deploy.sh             # Deploy stub
```

## Try It

```bash
# From the framework root
ops/test-example.sh 01-getting-started

# Then follow the printed instructions to cd into the worktree
# Open Claude Code and run:
/po
```

## What to Try

1. **`/po`** — See the PO status overview. The fleet is alive.
2. **Ask for a work item** — e.g., "Create a utility function that validates email addresses"
3. **Watch the lifecycle** — PO grooms it, developer builds with TDD, PO reviews, deploy
4. **`ops/dora.sh`** — See your first metrics after completing the item

## Next Example

Once you're comfortable with the lifecycle, move to [02-ecommerce](../02-ecommerce/) to learn about multiple specialists and agent inheritance.
