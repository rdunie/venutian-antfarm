# Example 05: Operational Maturity

A fintech API platform at Walk pace with 8 completed items of history. Three specialists with dense cross-team pathways, tuned knowledge distribution, and overrides on scrum-master and CKO reflecting lessons learned. This is what the framework looks like after it's had time to learn.

## What This Teaches Beyond 04

- What a **mature fleet** looks like after multiple iterations
- **Three specialists** with dense cross-team coordination (including e2e-test-engineer)
- **Tuning knowledge and retro cadences** as the fleet matures
- **SM and CKO overrides** reflecting operational learning
- **Seeded metrics** producing a real DORA dashboard via `setup.sh`

## Structure

```
05-operational-maturity/
├── .claude/
│   ├── agents/
│   │   ├── frontend-specialist.md  # Fintech frontend (extends harness)
│   │   ├── backend-specialist.md   # Fintech backend (extends harness)
│   │   └── e2e-test-engineer.md    # Full-stack E2E testing (extends harness)
│   └── overrides/
│       ├── scrum-master.md         # Retro every 3, pace monitoring
│       └── cko.md                  # Walk-pace knowledge distribution
├── compliance-floor.md             # 5 rules (fintech-oriented)
├── fleet-config.json               # Walk pace, 3 specialists, dense pathways
├── ops/
│   └── deploy.sh                   # Deploy stub with idempotency/E2E checks
└── setup.sh                        # Seeds 8 items of metrics history
```

## Try It

```bash
ops/test-example.sh 05-operational-maturity
# cd into the worktree, open Claude Code
```

## What to Try

1. **`ops/dora.sh`** — See a dashboard with real history (seeded by `setup.sh`)
2. **`ops/dora.sh --sm`** — See the SM's pace recommendation based on metrics
3. **`ops/dora.sh --flow`** — See handoff quality across specialist boundaries
4. **`/po`** — Notice the fleet is at Walk pace, not Crawl
5. **Build a feature** — watch three specialists coordinate with dense pathways
6. **`ops/pathways.sh`** — Compare declared vs actual agent communication

## Prerequisites

You should be comfortable with all previous examples. This one shows the operational destination — what earlier examples are building toward.
