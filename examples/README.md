# Examples

Progressive examples that teach the Venutian Antfarm framework from first setup to operational maturity. Each example is self-contained and introduces one or two new concepts.

## Which Example Should I Start With?

- **First time?** Start with [01-getting-started](01-getting-started/) — the minimum useful setup
- **Setting up a regulated project?** Look at [04-compliance-heavy](04-compliance-heavy/) for compliance patterns
- **Curious what maturity looks like?** Skip to [05-operational-maturity](05-operational-maturity/) and work backward

## Progression

| Example                                             | Focus                                         | Specialists                  | Compliance Rules | Pace  | Setup Hook                 |
| --------------------------------------------------- | --------------------------------------------- | ---------------------------- | ---------------- | ----- | -------------------------- |
| [01-getting-started](01-getting-started/)           | Full lifecycle, minimum useful config         | 1 (developer)                | 3                | Crawl | —                          |
| [02-ecommerce](02-ecommerce/)                       | Multi-specialist, inheritance, overrides      | 2 (frontend + backend)       | 5                | Crawl | —                          |
| [03-multi-team](03-multi-team/)                     | Review gates, cross-team pathways             | 2 + 1 reviewer               | 4                | Crawl | —                          |
| [04-compliance-heavy](04-compliance-heavy/)         | Regulated domain, thick floor, CO override    | 1 + 1 reviewer               | 7                | Crawl | Seeds compliance proposals |
| [05-operational-maturity](05-operational-maturity/) | Mature fleet, tuned cadences, metrics history | 3 (frontend + backend + e2e) | 5                | Walk  | Seeds metrics events       |

## How to Test Any Example

```bash
# Set up an isolated test environment (git worktree)
ops/test-example.sh <example-name>

# Follow the printed instructions to cd into the worktree
# Open Claude Code and run /po

# Clean up when done
ops/test-example.sh --cleanup <example-name>
```

Testing happens in isolated git worktrees — your framework repo is never modified.
