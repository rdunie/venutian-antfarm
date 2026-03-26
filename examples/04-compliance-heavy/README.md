# Example 04: Compliance-Heavy

A healthcare data platform under HIPAA requirements. The thickest compliance floor in the series (7 rules with 3 enforcement blocks), a CRO override with domain-specific enforcement, tighter pace thresholds, and a seeded compliance proposal to interact with.

## What This Teaches Beyond 03

- **Thick compliance floors** for regulated domains — more rules, tighter language
- **Enforcement blocks** embedded in floor rules (file-pattern, content-pattern, custom-script)
- **Overriding governance agents** (CRO) with domain-specific enforcement priorities
- **Tighter pace thresholds** reflecting lower risk tolerance (CFR 5/2, FPY 90)
- The **compliance change management workflow** — proposals, review, approval
- Using `setup.sh` to **pre-seed state** for a richer starting experience

## Structure

```
04-compliance-heavy/
├── .claude/
│   ├── agents/
│   │   ├── backend-specialist.md   # PHI-handling specialist (extends harness)
│   │   └── security-reviewer.md   # Reviews every change (extends harness)
│   └── overrides/
│       └── cro.md                 # HIPAA-focused CRO override
├── floors/
│   └── compliance.md              # 7 rules + 3 enforcement blocks (HIPAA-oriented)
├── fleet-config.json               # Tight thresholds, retro every item, floors config
├── ops/
│   ├── checks/
│   │   └── verify-audit-log.sh    # Custom enforcement script (audit log integrity)
│   └── deploy.sh                  # Deploy stub with PHI checks
└── setup.sh                       # Seeds a compliance proposal
```

## Try It

```bash
ops/test-example.sh 04-compliance-heavy
# cd into the worktree, open Claude Code
/po
```

## What to Try

1. **`/compliance`** — See the seeded proposal from `setup.sh` and run it through review
2. **Build a PHI-handling feature** — watch the thick compliance floor enforce constraints
3. **Try to skip security review** — the floor blocks it
4. **`/audit`** — Run a compliance audit to see the auditor verify conformance
5. **Notice the enforcement blocks** — file-pattern blocks PHI config access, content-pattern catches SSN/DOB patterns, custom-script verifies audit log integrity
6. **Notice the pace thresholds** — tighter than other examples, reflecting regulated domain risk tolerance

## Prerequisites

You should be comfortable with [03-multi-team](../03-multi-team/) before this example. This example focuses on compliance depth, not team breadth.
