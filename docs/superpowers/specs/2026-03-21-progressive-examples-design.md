# Progressive Examples Suite — Design Spec

_Part of [Venutian Antfarm](../../../README.md) by RD Digital Consulting Services, LLC._

## Problem

The current `example/` directory is a configuration-only skeleton — 7 files, no application code, no metrics history, no backlog items. It demonstrates how to configure the framework but not how to use it. New adopters lack a progressive learning path from first contact to operational maturity.

## Solution

Replace the single `example/` directory with a numbered progression of 5 examples under `examples/`, each teaching increasingly advanced framework concepts. A shared test script (`ops/test-example.sh`) creates isolated git worktrees for functional walk-throughs without disrupting the framework repo.

## Directory Structure

```
examples/
├── README.md                              # Index with progression guide
├── 01-getting-started/
│   ├── README.md
│   ├── .claude/agents/
│   │   └── developer.md
│   ├── compliance-floor.md
│   ├── fleet-config.json
│   └── ops/deploy.sh
├── 02-ecommerce/                          # Migrated from current example/
│   ├── README.md
│   ├── .claude/agents/
│   │   ├── frontend-specialist.md
│   │   └── backend-specialist.md
│   ├── .claude/overrides/
│   │   └── scrum-master.md
│   ├── compliance-floor.md
│   ├── fleet-config.json
│   └── ops/deploy.sh
├── 03-multi-team/
│   ├── README.md
│   ├── .claude/agents/
│   │   ├── frontend-specialist.md
│   │   ├── backend-specialist.md
│   │   └── security-reviewer.md
│   ├── .claude/overrides/
│   │   └── scrum-master.md
│   ├── compliance-floor.md
│   ├── fleet-config.json
│   └── ops/deploy.sh
├── 04-compliance-heavy/
│   ├── README.md
│   ├── .claude/agents/
│   │   ├── backend-specialist.md
│   │   └── security-reviewer.md
│   ├── .claude/overrides/
│   │   └── compliance-officer.md
│   ├── compliance-floor.md
│   ├── fleet-config.json
│   ├── ops/deploy.sh
│   └── setup.sh
├── 05-operational-maturity/
│   ├── README.md
│   ├── .claude/agents/
│   │   ├── frontend-specialist.md
│   │   ├── backend-specialist.md
│   │   └── e2e-test-engineer.md
│   ├── .claude/overrides/
│   │   ├── scrum-master.md
│   │   └── cko.md
│   ├── compliance-floor.md
│   ├── fleet-config.json
│   ├── ops/deploy.sh
│   └── setup.sh
ops/
└── test-example.sh                        # Shared test runner
```

## Example Progression

| Example                 | Focus                                         | Specialists                  | Compliance Rules | Pace  | Setup Hook                 |
| ----------------------- | --------------------------------------------- | ---------------------------- | ---------------- | ----- | -------------------------- |
| 01-getting-started      | Full lifecycle, minimum useful config         | 1 (developer)                | 3                | Crawl | —                          |
| 02-ecommerce            | Multi-specialist, inheritance, overrides      | 2 (frontend + backend)       | 5                | Crawl | —                          |
| 03-multi-team           | Review gates, cross-team pathways             | 2 + 1 reviewer               | 4                | Crawl | —                          |
| 04-compliance-heavy     | Regulated domain, thick floor, CO override    | 1 + 1 reviewer               | 7                | Crawl | Seeds compliance proposals |
| 05-operational-maturity | Mature fleet, tuned cadences, metrics history | 3 (frontend + backend + e2e) | 5                | Walk  | Seeds metrics events       |

## Example Details

### 01-getting-started

The minimum useful setup. One generalist specialist (`developer`), three compliance rules, declared pathways, and a deploy stub. Complete enough to run a work item through the full lifecycle: PO grooms, developer builds with TDD, PO reviews, deploy.

**fleet-config.json:**

- Project: `getting-started`
- Metrics: JSONL
- Deploy: single environment (`dev`)
- Pace: Crawl with default thresholds
- Agents: governance + core + 1 specialist (`developer`)
- Pathways: `product-owner <-> developer`, escalation to SA and SM, governance to CO and CEO

**compliance-floor.md** (3 rules):

1. No secrets in code — environment variables only
2. All changes are tested — no shipping without tests
3. Plan before build — non-trivial items need approved plan first

**developer.md:**

- Extends `harness/backend-specialist`
- General-purpose: handles all implementation, tests, build, deploy
- Compliance awareness mirrors the floor

**ops/deploy.sh:**

- Minimal stub, single environment, echoes what it would do

**README.md teaches:**

- Minimum files needed to activate the framework
- That governance + core agents come from the harness
- The full work item lifecycle end-to-end
- How metrics accumulate from the first item

### 02-ecommerce

Migrated from the current `example/` directory. Two specialists (frontend + backend) with distinct tech stacks, a 5-rule domain-specific compliance floor (PCI, GDPR, audit logging), a scrum-master retro cadence override, and knowledge distribution cadence.

No content changes from the existing `example/` — this is a relocation.

**What this teaches beyond 01:**

- Splitting work across multiple specialists with distinct domains
- Agent inheritance with `extends:` for specialists and overrides for core agents
- Domain-specific compliance (payment handling, personal data, audit trails)
- Tuning framework knobs: retro cadence, knowledge cadence

### 03-multi-team

A SaaS platform with frontend, backend, and a security reviewer who gates deployments. Introduces the review tier, cross-specialist pathways, and compliance rules that mandate agent involvement.

**fleet-config.json differences from 02:**

- Agents: adds `security-reviewer` to reviewers
- Pathways: cross-specialist (`frontend <-> backend`), review tier (`specialists -> security-reviewer -> specialists`)
- Deploy: three environments (`dev`, `staging`, `prod`)

**compliance-floor.md** (4 rules):

1. Tenant data isolation on every query
2. No secrets in code
3. Security review before staging — mandates security-reviewer involvement
4. Plan before build

**security-reviewer.md:**

- Extends `harness/security-reviewer`
- Focus: tenant isolation, auth, input validation, dependencies, secrets
- Gate criteria: approve, approve with suggestions, or block with required changes

**What this teaches beyond 02:**

- Adding a review agent and gating deployments through it
- Cross-specialist direct communication pathways
- Compliance rules that mandate agent involvement (not just technical constraints)
- Three-environment promotion (dev → staging → prod)
- How `ops/pathways.sh` catches undeclared communication

### 04-compliance-heavy

A healthcare data platform under HIPAA. The thickest compliance floor in the series (7 rules), a compliance officer override with domain-specific enforcement priorities, tighter pace thresholds, and a `setup.sh` that seeds a compliance proposal.

**fleet-config.json differences:**

- Pace thresholds: tighter (CFR 5/2, FPY 90) reflecting lower risk tolerance
- Retro: every single item
- Knowledge cadence: every item even at Walk pace

**compliance-floor.md** (7 rules):

1. All PHI encrypted at rest and in transit
2. Minimum necessary access on every data operation
3. Audit every PHI access with immutable entries (6-year retention)
4. No PHI in logs or external services
5. Plan before build — no exceptions
6. Security review on every change — no fast-track bypasses
7. BAA required for third-party services

**compliance-officer.md override:**

- HIPAA focus: PHI rules non-negotiable, BAA verification prerequisite, audit log completeness verified every cycle, breach notification documented before PHI features ship

**setup.sh:**

- Seeds a sample compliance proposal (`001-add-analytics.md`) showing a backend-specialist proposing PostHog integration with compliance impact analysis
- Gives the user an in-flight proposal to interact with immediately

**What this teaches beyond 03:**

- Thick compliance floors for regulated domains
- Overriding governance agents with domain-specific priorities
- Tighter pace thresholds reflecting lower risk tolerance
- The compliance change management workflow (proposals, review, approval)
- `setup.sh` pre-seeding state for a richer starting experience

### 05-operational-maturity

A fintech API platform at Walk pace with 8 completed items of history. Three specialists including an e2e-test-engineer, tuned knowledge distribution, wider retro cadence, and overrides on both scrum-master and CKO reflecting lessons learned.

**fleet-config.json differences:**

- Pace: Walk (already promoted from Crawl)
- Retro: every 3 items (stabilized team)
- Knowledge cadence: wider (3 at Walk, 5 at Run)
- Agents: 3 specialists with dense pathway mesh including e2e-test-engineer

**compliance-floor.md** (5 rules):

1. No plaintext financial data at rest — KMS for key management
2. All API mutations idempotent with client-provided keys
3. Audit trail on all financial operations (7-year retention)
4. Plan before build
5. No direct database writes — all mutations through service layer

**e2e-test-engineer.md:**

- Extends `harness/e2e-test-engineer`
- Owns integration and E2E test suites across the full stack
- Coordinates with both implementation specialists via handoffs

**scrum-master.md override:**

- Retro cadence: every 3 items
- Pace monitoring: actively watches for Run promotion readiness

**cko.md override:**

- Distribution strategy tuned for Walk pace maturity
- Knowledge artifacts should be refined (onboarding quality), not raw

**setup.sh:**

- Seeds 8 completed items, 2 bug cycles, and 3 cross-specialist handoffs via `ops/metrics-log.sh`
- `ops/dora.sh` displays a meaningful dashboard immediately

**What this teaches beyond 04:**

- What a mature fleet looks like after multiple iterations
- Three specialists with dense cross-team coordination
- Tuning knowledge and retro cadences as the fleet matures
- SM and CKO overrides reflecting operational learning
- Seeded metrics producing a real DORA dashboard

## Test Mechanism: `ops/test-example.sh`

### Usage

```bash
ops/test-example.sh <example-name>          # Set up isolated test environment
ops/test-example.sh --cleanup <example-name> # Remove test environment
```

### Test Mode

1. Validates the example exists in `examples/<name>/`
2. Creates a git worktree at `.worktrees/test-<name>-<timestamp>` on a temporary branch
3. Copies example files into the worktree root (so `.claude/agents/`, `compliance-floor.md`, etc. land where the framework expects them)
4. Copies harness infrastructure into the worktree:
   - `.claude/agents/*.md` (core agent definitions)
   - `.claude/COLLABORATION.md`, `.claude/DOCUMENTATION-STYLE.md`
   - `.claude/skills/`, `.claude/governance/`, `.claude/compliance/`, `.claude/findings/`
   - `ops/` (then overwritten by example's `ops/deploy.sh` if present)
   - `templates/`
5. Applies overrides: copies `.claude/overrides/*.md` into `.claude/agents/`
6. Runs `setup.sh` if present in the example
7. Prints instructions with path, first command to try, and cleanup command

### Cleanup Mode

1. Finds worktrees matching `test-<name>-*`
2. Removes the worktree and deletes the temporary branch
3. Confirms cleanup

### Edge Cases

- Existing worktree for same example: warns, offers cleanup first
- `setup.sh` failure: warns but does not abort — example is usable without seeded state
- Framework repo working tree: never modified

## Migration

The current `example/` directory is removed and its contents relocated to `examples/02-ecommerce/`. References to `example/` in CLAUDE.md, README.md, and GETTING-STARTED.md are updated to point to `examples/`.

## Design Principles

- **Progressive complexity:** Each example introduces one or two new concepts, not a wall of configuration
- **Self-contained:** Each example works independently — no dependency on other examples
- **Isolation:** Testing happens in worktrees, never in the framework repo's working tree
- **Setup hooks:** Advanced examples use `setup.sh` to pre-seed state, keeping simpler examples clean
- **Config when flexible, code when predictable:** Matches the framework's own architecture constraint
