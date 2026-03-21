# Progressive Examples Suite Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the single `example/` directory with 5 progressive examples under `examples/`, plus a worktree-based test script for isolated functional testing.

**Architecture:** Numbered examples (01-05) teach framework concepts progressively from minimal setup to operational maturity. A shared `ops/test-example.sh` scaffolds any example into a git worktree for testing. The current `example/` migrates to `examples/02-ecommerce/` unchanged.

**Tech Stack:** Markdown (agent definitions, compliance floors, READMEs), JSON (fleet-config), Bash (deploy stubs, test script, setup hooks).

**Spec:** `docs/superpowers/specs/2026-03-21-progressive-examples-design.md`

---

## File Map

### New files to create

| File                                                                     | Responsibility                                                                             |
| ------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------ |
| `examples/README.md`                                                     | Index with progression guide, decision guide, test instructions                            |
| `examples/01-getting-started/README.md`                                  | Lifecycle walkthrough guide                                                                |
| `examples/01-getting-started/.claude/agents/developer.md`                | Self-contained generalist specialist (no extends)                                          |
| `examples/01-getting-started/compliance-floor.md`                        | 3 rules: secrets, testing, plan-before-build                                               |
| `examples/01-getting-started/fleet-config.json`                          | Minimal config: 1 specialist, 1 env, Crawl                                                 |
| `examples/01-getting-started/ops/deploy.sh`                              | Single-env deploy stub                                                                     |
| `examples/03-multi-team/README.md`                                       | Review gates and cross-team guide                                                          |
| `examples/03-multi-team/.claude/agents/frontend-specialist.md`           | SaaS frontend specialist                                                                   |
| `examples/03-multi-team/.claude/agents/backend-specialist.md`            | SaaS backend specialist                                                                    |
| `examples/03-multi-team/.claude/agents/security-reviewer.md`             | Security reviewer gating staging/prod                                                      |
| `examples/03-multi-team/.claude/overrides/scrum-master.md`               | Retro cadence override                                                                     |
| `examples/03-multi-team/compliance-floor.md`                             | 4 rules: tenant isolation, secrets, security review gate, plan-before-build                |
| `examples/03-multi-team/fleet-config.json`                               | 2 specialists + 1 reviewer, cross-team pathways, 3 envs                                    |
| `examples/03-multi-team/ops/deploy.sh`                                   | Three-env deploy stub with staging gate message                                            |
| `examples/04-compliance-heavy/README.md`                                 | Regulated domain guide                                                                     |
| `examples/04-compliance-heavy/.claude/agents/backend-specialist.md`      | Healthcare backend specialist                                                              |
| `examples/04-compliance-heavy/.claude/agents/security-reviewer.md`       | Healthcare security reviewer                                                               |
| `examples/04-compliance-heavy/.claude/overrides/compliance-officer.md`   | HIPAA-focused CO override                                                                  |
| `examples/04-compliance-heavy/compliance-floor.md`                       | 7 rules: PHI encryption, minimum access, audit, no PHI in logs, plan, security review, BAA |
| `examples/04-compliance-heavy/fleet-config.json`                         | Tight thresholds (CFR 5/2, FPY 90), retro every item                                       |
| `examples/04-compliance-heavy/ops/deploy.sh`                             | Three-env deploy stub                                                                      |
| `examples/04-compliance-heavy/setup.sh`                                  | Seeds compliance proposal at `.claude/compliance/proposals/001-add-analytics.md`           |
| `examples/05-operational-maturity/README.md`                             | Mature fleet guide                                                                         |
| `examples/05-operational-maturity/.claude/agents/frontend-specialist.md` | Fintech frontend specialist                                                                |
| `examples/05-operational-maturity/.claude/agents/backend-specialist.md`  | Fintech backend specialist                                                                 |
| `examples/05-operational-maturity/.claude/agents/e2e-test-engineer.md`   | Fintech E2E test engineer                                                                  |
| `examples/05-operational-maturity/.claude/overrides/scrum-master.md`     | Retro every 3, pace monitoring                                                             |
| `examples/05-operational-maturity/.claude/overrides/cko.md`              | Walk-pace knowledge distribution                                                           |
| `examples/05-operational-maturity/compliance-floor.md`                   | 5 rules: financial data, idempotency, audit, plan, no direct DB                            |
| `examples/05-operational-maturity/fleet-config.json`                     | Walk pace, 3 specialists, dense pathways, tuned cadences                                   |
| `examples/05-operational-maturity/ops/deploy.sh`                         | Three-env deploy stub                                                                      |
| `examples/05-operational-maturity/setup.sh`                              | Seeds 8 items, 2 bug cycles, 3 handoffs via metrics-log.sh                                 |
| `ops/test-example.sh`                                                    | Shared worktree-based test runner                                                          |

### Files to modify

| File                                        | Change                                           |
| ------------------------------------------- | ------------------------------------------------ |
| `templates/agents/frontend-specialist.md:3` | Remove erroneous `extends: harness/platform-ops` |
| `.gitignore`                                | Add `.worktrees/`                                |
| `CLAUDE.md:12,46,166`                       | Update `example/` references to `examples/`      |
| `README.md:282`                             | Update example link                              |
| `docs/GETTING-STARTED.md:155`               | Update example link                              |
| `docs/AGENT-FLEET-PATTERN.md:323,370`       | Update example references                        |

### Files to move

| From                      | To                       |
| ------------------------- | ------------------------ |
| `example/` (all contents) | `examples/02-ecommerce/` |

---

## Task 1: Fix Template Bug and Add .gitignore Entry

**Files:**

- Modify: `templates/agents/frontend-specialist.md:3`
- Modify: `.gitignore`

- [ ] **Step 1: Fix frontend-specialist template**

Remove the erroneous `extends: harness/platform-ops` line from `templates/agents/frontend-specialist.md`. The frontmatter should be:

```yaml
---
name: frontend-specialist
description: "Frontend specialist agent. Owns UI components, state management, styling, and component tests."
model: sonnet
color: cyan
memory: project
maxTurns: 50
---
```

- [ ] **Step 2: Add .worktrees/ to .gitignore**

Append to `.gitignore`:

```
# Test worktrees (created by ops/test-example.sh)
.worktrees/
```

- [ ] **Step 3: Verify**

Run: `grep -c 'extends' templates/agents/frontend-specialist.md`
Expected: `0`

Run: `grep '.worktrees' .gitignore`
Expected: `.worktrees/`

- [ ] **Step 4: Commit**

```bash
git add templates/agents/frontend-specialist.md .gitignore
git commit -m "fix: remove erroneous extends from frontend-specialist template, add .worktrees/ to gitignore"
```

---

## Task 2: Migrate example/ to examples/02-ecommerce/

**Files:**

- Move: `example/` → `examples/02-ecommerce/`

- [ ] **Step 1: Create examples directory and move**

```bash
mkdir -p examples
git mv example examples/02-ecommerce
```

- [ ] **Step 2: Verify structure**

Run: `find examples/02-ecommerce -type f | sort`
Expected:

```
examples/02-ecommerce/.claude/agents/backend-specialist.md
examples/02-ecommerce/.claude/agents/frontend-specialist.md
examples/02-ecommerce/.claude/overrides/scrum-master.md
examples/02-ecommerce/README.md
examples/02-ecommerce/compliance-floor.md
examples/02-ecommerce/fleet-config.json
examples/02-ecommerce/ops/deploy.sh
```

- [ ] **Step 3: Update 02-ecommerce README.md**

Update the README to reference its position in the progression. Change the `cp -r example/` instruction to `cp -r examples/02-ecommerce/`. Add a note: "You should be comfortable with 01-getting-started before this example." Update the structure tree paths.

- [ ] **Step 4: Commit**

```bash
git add examples/ -A
git commit -m "refactor: migrate example/ to examples/02-ecommerce/"
```

---

## Task 3: Create Example 01 — Getting Started

**Files:**

- Create: `examples/01-getting-started/README.md`
- Create: `examples/01-getting-started/.claude/agents/developer.md`
- Create: `examples/01-getting-started/compliance-floor.md`
- Create: `examples/01-getting-started/fleet-config.json`
- Create: `examples/01-getting-started/ops/deploy.sh`

- [ ] **Step 1: Create directory structure**

```bash
mkdir -p examples/01-getting-started/.claude/agents
mkdir -p examples/01-getting-started/ops
```

- [ ] **Step 2: Create fleet-config.json**

```json
{
  "project": {
    "name": "getting-started",
    "description": "Single-specialist project to learn the framework lifecycle"
  },
  "metrics": {
    "backend": "jsonl",
    "file": ".claude/metrics/events.jsonl"
  },
  "deploy": {
    "command": "ops/deploy.sh",
    "environments": ["dev"]
  },
  "pace": {
    "current": "Crawl",
    "walk_threshold_cfr": 10,
    "run_threshold_cfr": 5,
    "run_threshold_fpy": 80
  },
  "agents": {
    "governance": [
      "compliance-officer",
      "ciso",
      "ceo",
      "cto",
      "cfo",
      "coo",
      "cko"
    ],
    "core": [
      "product-owner",
      "solution-architect",
      "scrum-master",
      "knowledge-ops",
      "platform-ops",
      "compliance-auditor"
    ],
    "specialists": ["developer"],
    "reviewers": [],
    "output": []
  },
  "pathways": {
    "declared": {
      "build": ["product-owner -> developer", "developer -> product-owner"],
      "review": [],
      "escalation": ["* -> solution-architect", "* -> scrum-master"],
      "governance": ["* -> compliance-officer", "* -> ceo"]
    }
  }
}
```

- [ ] **Step 3: Create compliance-floor.md**

```markdown
# Compliance Floor — Getting Started

Non-negotiable rules that override all autonomy tiers, pace settings, and process decisions.

## Rules

1. **No secrets in code.** API keys, passwords, and tokens must use environment variables, never hardcoded values.

2. **All changes are tested.** No feature or fix ships without at least one test covering the new behavior.

3. **Plan before build.** Non-trivial work items must have an approved plan before implementation begins. No building without alignment on approach.
```

- [ ] **Step 4: Create developer.md**

Self-contained agent definition — no `extends:` since this is the first example and we don't want to teach inheritance yet.

```markdown
---
name: developer
description: "Full-stack developer. Handles all implementation work."
model: sonnet
color: green
memory: project
maxTurns: 50
---

You are the **Developer** for this project.

## Domain

- All implementation: features, fixes, refactoring
- Test authoring
- Build and deploy

## Responsibilities

- Build features end-to-end: design, implement, test, deploy, validate
- Maintain test coverage
- Follow the project's coding standards
- Coordinate with product-owner on acceptance criteria

## Autonomy Model

**Autonomous:** Reading code, writing implementations, running tests, fixing bugs

**Propose:** New dependencies, architectural changes, process adjustments

**Escalate:** Compliance floor implications, changes affecting shared systems

## Compliance Floor Awareness

- **No secrets in code.** Use environment variables for all credentials.
- **All changes are tested.** Write tests before or alongside implementation.
- **Plan before build.** Get plan approval before implementing non-trivial work.
```

- [ ] **Step 5: Create ops/deploy.sh**

```bash
#!/usr/bin/env bash
# Getting Started deploy stub — echoes what it would do.
set -euo pipefail

ENV="${1:-dev}"
COMPONENT="${2:-app}"

echo "=== Deploy ==="
echo "Environment: $ENV"
echo "Component:   $COMPONENT"
echo ""
echo "Would run:"
echo "  1. Build $COMPONENT"
echo "  2. Test $COMPONENT"
echo "  3. Deploy to $ENV"
echo ""
echo "deployment_id=gs-${ENV}-${COMPONENT}-$(date +%s)"
```

Make it executable: `chmod +x examples/01-getting-started/ops/deploy.sh`

- [ ] **Step 6: Create README.md**

```markdown
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
│ └── developer.md # Self-contained generalist specialist
├── compliance-floor.md # 3 rules: secrets, testing, plan-before-build
├── fleet-config.json # Minimal config: 1 specialist, 1 env, Crawl
└── ops/
└── deploy.sh # Deploy stub

````

## Try It

```bash
# From the framework root
ops/test-example.sh 01-getting-started

# Then follow the printed instructions to cd into the worktree
# Open Claude Code and run:
/po
````

## What to Try

1. **`/po`** — See the PO status overview. The fleet is alive.
2. **Ask for a work item** — e.g., "Create a utility function that validates email addresses"
3. **Watch the lifecycle** — PO grooms it, developer builds with TDD, PO reviews, deploy
4. **`ops/dora.sh`** — See your first metrics after completing the item

## Next Example

Once you're comfortable with the lifecycle, move to [02-ecommerce](../02-ecommerce/) to learn about multiple specialists and agent inheritance.

````

- [ ] **Step 7: Verify JSON validity**

Run: `python3 -c "import json; json.load(open('examples/01-getting-started/fleet-config.json')); print('valid')"`
Expected: `valid`

- [ ] **Step 8: Verify deploy script syntax**

Run: `bash -n examples/01-getting-started/ops/deploy.sh && echo 'ok'`
Expected: `ok`

- [ ] **Step 9: Commit**

```bash
git add examples/01-getting-started/
git commit -m "feat: add example 01-getting-started — minimum useful framework setup"
````

---

## Task 4: Create Example 03 — Multi-Team

**Files:**

- Create: `examples/03-multi-team/README.md`
- Create: `examples/03-multi-team/.claude/agents/frontend-specialist.md`
- Create: `examples/03-multi-team/.claude/agents/backend-specialist.md`
- Create: `examples/03-multi-team/.claude/agents/security-reviewer.md`
- Create: `examples/03-multi-team/.claude/overrides/scrum-master.md`
- Create: `examples/03-multi-team/compliance-floor.md`
- Create: `examples/03-multi-team/fleet-config.json`
- Create: `examples/03-multi-team/ops/deploy.sh`

- [ ] **Step 1: Create directory structure**

```bash
mkdir -p examples/03-multi-team/.claude/agents
mkdir -p examples/03-multi-team/.claude/overrides
mkdir -p examples/03-multi-team/ops
```

- [ ] **Step 2: Create fleet-config.json**

```json
{
  "project": {
    "name": "saas-platform",
    "description": "Multi-team SaaS platform with security review gates"
  },
  "metrics": {
    "backend": "jsonl",
    "file": ".claude/metrics/events.jsonl"
  },
  "deploy": {
    "command": "ops/deploy.sh",
    "environments": ["dev", "staging", "prod"]
  },
  "pace": {
    "current": "Crawl",
    "walk_threshold_cfr": 10,
    "run_threshold_cfr": 5,
    "run_threshold_fpy": 80
  },
  "agents": {
    "governance": [
      "compliance-officer",
      "ciso",
      "ceo",
      "cto",
      "cfo",
      "coo",
      "cko"
    ],
    "core": [
      "product-owner",
      "solution-architect",
      "scrum-master",
      "knowledge-ops",
      "platform-ops",
      "compliance-auditor"
    ],
    "specialists": ["frontend-specialist", "backend-specialist"],
    "reviewers": ["security-reviewer"],
    "output": []
  },
  "retro": {
    "cadence": 2,
    "note": "Every 2 items."
  },
  "knowledge": {
    "cadence": {
      "crawl": 1,
      "walk": 2,
      "run": 4,
      "fly": 0
    }
  },
  "pathways": {
    "declared": {
      "build": [
        "product-owner -> frontend-specialist",
        "product-owner -> backend-specialist",
        "frontend-specialist -> product-owner",
        "backend-specialist -> product-owner",
        "frontend-specialist -> backend-specialist",
        "backend-specialist -> frontend-specialist"
      ],
      "review": [
        "frontend-specialist -> security-reviewer",
        "backend-specialist -> security-reviewer",
        "security-reviewer -> frontend-specialist",
        "security-reviewer -> backend-specialist"
      ],
      "escalation": ["* -> solution-architect", "* -> scrum-master"],
      "governance": [
        "ciso -> compliance-officer",
        "compliance-officer -> compliance-auditor",
        "* -> compliance-officer",
        "cko -> knowledge-ops",
        "cto -> solution-architect",
        "cfo -> platform-ops",
        "coo -> scrum-master",
        "* -> ceo"
      ]
    }
  }
}
```

- [ ] **Step 3: Create compliance-floor.md**

```markdown
# Compliance Floor — SaaS Platform

Non-negotiable rules that override all autonomy tiers, pace settings, and process decisions.

## Rules

1. **Tenant data isolation.** Every database query must be scoped to the requesting tenant. No cross-tenant data leakage.

2. **No secrets in code.** API keys, passwords, and tokens must use environment variables, never hardcoded values.

3. **Security review before staging.** No code reaches staging or prod without passing security-reviewer assessment.

4. **Plan before build.** Non-trivial work items must have an approved plan before implementation begins.

## Enforcement

- Rule 1: Integration tests validate tenant scoping on every query path
- Rule 3: Deploy script checks for security-reviewer approval before staging/prod
```

- [ ] **Step 4: Create frontend-specialist.md**

```markdown
---
name: frontend-specialist
extends: harness/frontend-specialist
description: "SaaS frontend specialist. Owns tenant-aware UI, dashboard, and user management pages."
model: sonnet
color: cyan
memory: project
maxTurns: 50
---

You are the **Frontend Specialist** for the SaaS platform.

## Domain

- Tenant-aware dashboard and settings pages
- User management and role assignment UI
- Multi-tenant data display (scoped views)
- Authentication and session handling (frontend)

## Tech Stack

- React 18 with TypeScript
- Next.js for SSR
- Tailwind CSS
- React Query for server state
- Vitest + React Testing Library

## Compliance Floor Awareness

- **Tenant isolation in UI.** Never display data from other tenants. Verify tenant scoping in API calls.
- **No secrets in frontend code.** API keys stay server-side; use environment variables for public config.

## Coordination

- Work with backend-specialist on API contracts
- Submit to security-reviewer before staging
```

- [ ] **Step 5: Create backend-specialist.md**

```markdown
---
name: backend-specialist
extends: harness/backend-specialist
description: "SaaS backend specialist. Owns tenant-scoped API, data layer, and integration points."
model: sonnet
color: blue
memory: project
maxTurns: 50
---

You are the **Backend Specialist** for the SaaS platform.

## Domain

- Tenant-scoped REST API
- Data model with tenant isolation
- Authentication and authorization middleware
- Third-party integrations (scoped per tenant)

## Tech Stack

- Node.js with Express
- PostgreSQL with row-level security
- Redis for sessions and caching
- Jest for testing

## Compliance Floor Awareness

- **Tenant data isolation.** Every query must include tenant scope. Use row-level security in PostgreSQL.
- **No secrets in code.** Use environment variables for all credentials and API keys.

## Coordination

- Publish API contracts for frontend-specialist
- Submit to security-reviewer before staging
```

- [ ] **Step 6: Create security-reviewer.md**

```markdown
---
name: security-reviewer
extends: harness/security-reviewer
description: "Security reviewer. Gates all code headed for staging/prod."
model: sonnet
color: red
memory: project
maxTurns: 30
---

You are the **Security Reviewer** for the SaaS platform.

## Review Focus

- Tenant isolation in queries and API boundaries
- Authentication and authorization correctness
- Input validation and injection prevention
- Dependency vulnerabilities
- Secret handling

## Gate Criteria

Code must pass your review before reaching staging. You may:

- Approve with no changes
- Approve with non-blocking suggestions
- Block with required changes (creates a finding)
```

- [ ] **Step 7: Create scrum-master.md override**

```markdown
---
extends: harness/scrum-master
---

## Process Override

### Retro Cadence

Run retrospectives every **2 items**. Multi-team coordination generates enough signal to justify batching retros.
```

- [ ] **Step 8: Create ops/deploy.sh**

```bash
#!/usr/bin/env bash
# SaaS Platform deploy stub — three environments with security gate.
set -euo pipefail

if [ $# -lt 2 ]; then
  echo "Usage: deploy.sh <env> <component> [--type planned|hotfix]" >&2
  exit 1
fi

ENV="$1"
COMPONENT="$2"
DEPLOY_TYPE="planned"

shift 2
while [[ $# -gt 0 ]]; do
  case "$1" in
    --type) DEPLOY_TYPE="$2"; shift 2 ;;
    *) echo "Unknown flag: $1" >&2; exit 1 ;;
  esac
done

if [[ "$ENV" != "dev" ]]; then
  echo "Note: $ENV deployments require security-reviewer approval"
fi

echo "=== SaaS Platform Deploy ==="
echo "Environment: $ENV"
echo "Component:   $COMPONENT"
echo "Type:        $DEPLOY_TYPE"
echo ""
echo "Would run:"
echo "  1. npm run build ($COMPONENT)"
echo "  2. npm run test ($COMPONENT)"
echo "  3. docker build -t saas-$COMPONENT:latest ."
echo "  4. kubectl apply -f k8s/$ENV/$COMPONENT.yaml"
echo "  5. kubectl rollout status deployment/$COMPONENT -n $ENV"
echo ""
echo "deployment_id=saas-${ENV}-${COMPONENT}-$(date +%s)"
```

Make executable: `chmod +x examples/03-multi-team/ops/deploy.sh`

- [ ] **Step 9: Create README.md**

```markdown
# Example 03: Multi-Team

A SaaS platform with frontend, backend, and a security reviewer who gates deployments to staging and production. Demonstrates cross-team coordination and review gates.

## What This Teaches Beyond 02

- Adding a **review agent** to the workflow and gating deployments through it
- **Cross-specialist pathways** — frontend and backend hand off directly to each other
- Compliance rules that **mandate agent involvement** (not just technical constraints)
- **Three-environment promotion** — dev → staging → prod
- How `ops/pathways.sh` catches undeclared communication between agents

## Structure
```

03-multi-team/
├── .claude/
│ ├── agents/
│ │ ├── frontend-specialist.md # SaaS frontend (extends harness)
│ │ ├── backend-specialist.md # SaaS backend (extends harness)
│ │ └── security-reviewer.md # Gates staging/prod (extends harness)
│ └── overrides/
│ └── scrum-master.md # Retro cadence override
├── compliance-floor.md # 4 rules including security review gate
├── fleet-config.json # 2 specialists + 1 reviewer, cross-team pathways
└── ops/
└── deploy.sh # Three-env deploy stub

````

## Try It

```bash
ops/test-example.sh 03-multi-team
# cd into the worktree, open Claude Code
/po
````

## What to Try

1. **Build a feature that touches both frontend and backend** — watch cross-specialist handoffs
2. **Try deploying to staging** — the security-reviewer gate kicks in
3. **Run `ops/pathways.sh`** — see declared vs actual agent communication
4. **Introduce an undeclared pathway** — watch pathway analysis flag it

## Prerequisites

You should be comfortable with [01-getting-started](../01-getting-started/) and [02-ecommerce](../02-ecommerce/) before this example.

````

- [ ] **Step 10: Verify JSON validity and script syntax**

Run: `python3 -c "import json; json.load(open('examples/03-multi-team/fleet-config.json')); print('valid')"`
Expected: `valid`

Run: `bash -n examples/03-multi-team/ops/deploy.sh && echo 'ok'`
Expected: `ok`

- [ ] **Step 11: Commit**

```bash
git add examples/03-multi-team/
git commit -m "feat: add example 03-multi-team — review gates and cross-team pathways"
````

---

## Task 5: Create Example 04 — Compliance-Heavy

**Files:**

- Create: `examples/04-compliance-heavy/README.md`
- Create: `examples/04-compliance-heavy/.claude/agents/backend-specialist.md`
- Create: `examples/04-compliance-heavy/.claude/agents/security-reviewer.md`
- Create: `examples/04-compliance-heavy/.claude/overrides/compliance-officer.md`
- Create: `examples/04-compliance-heavy/compliance-floor.md`
- Create: `examples/04-compliance-heavy/fleet-config.json`
- Create: `examples/04-compliance-heavy/ops/deploy.sh`
- Create: `examples/04-compliance-heavy/setup.sh`

- [ ] **Step 1: Create directory structure**

```bash
mkdir -p examples/04-compliance-heavy/.claude/agents
mkdir -p examples/04-compliance-heavy/.claude/overrides
mkdir -p examples/04-compliance-heavy/ops
```

- [ ] **Step 2: Create fleet-config.json**

```json
{
  "project": {
    "name": "health-data-platform",
    "description": "Healthcare data platform with HIPAA compliance requirements"
  },
  "metrics": {
    "backend": "jsonl",
    "file": ".claude/metrics/events.jsonl"
  },
  "deploy": {
    "command": "ops/deploy.sh",
    "environments": ["dev", "staging", "prod"]
  },
  "pace": {
    "current": "Crawl",
    "walk_threshold_cfr": 5,
    "run_threshold_cfr": 2,
    "run_threshold_fpy": 90
  },
  "agents": {
    "governance": [
      "compliance-officer",
      "ciso",
      "ceo",
      "cto",
      "cfo",
      "coo",
      "cko"
    ],
    "core": [
      "product-owner",
      "solution-architect",
      "scrum-master",
      "knowledge-ops",
      "platform-ops",
      "compliance-auditor"
    ],
    "specialists": ["backend-specialist"],
    "reviewers": ["security-reviewer"],
    "output": []
  },
  "retro": {
    "cadence": 1,
    "note": "Every item. Regulated domain — retros capture compliance learnings immediately."
  },
  "knowledge": {
    "cadence": {
      "crawl": 1,
      "walk": 1,
      "run": 2,
      "fly": 0
    },
    "note": "Frequent distribution. Compliance knowledge must propagate quickly."
  },
  "pathways": {
    "declared": {
      "build": [
        "product-owner -> backend-specialist",
        "backend-specialist -> product-owner"
      ],
      "review": [
        "backend-specialist -> security-reviewer",
        "security-reviewer -> backend-specialist"
      ],
      "escalation": ["* -> solution-architect", "* -> scrum-master"],
      "governance": [
        "ciso -> compliance-officer",
        "compliance-officer -> compliance-auditor",
        "* -> compliance-officer",
        "cko -> knowledge-ops",
        "cto -> solution-architect",
        "cfo -> platform-ops",
        "coo -> scrum-master",
        "* -> ceo"
      ]
    }
  }
}
```

- [ ] **Step 3: Create compliance-floor.md**

```markdown
# Compliance Floor — Health Data Platform

Non-negotiable rules that override all autonomy tiers, pace settings, and process decisions.

## Rules

1. **All PHI is encrypted.** Protected Health Information must be encrypted at rest (AES-256) and in transit (TLS 1.2+). No plaintext PHI in any storage layer, message queue, or API response.

2. **Minimum necessary access.** Every data access must be scoped to the minimum data required for the operation. No bulk PHI exports without explicit authorization and audit trail.

3. **Audit every PHI access.** Every read, write, or delete of PHI produces an immutable audit log entry: who, what, when, why, from where. Audit logs are retained for 6 years minimum.

4. **No PHI in logs or external services.** PHI must not appear in application logs, error messages, monitoring dashboards, or data sent to third-party services. Use tokenized identifiers.

5. **Plan before build.** All work items must have an approved plan before implementation. No exceptions in a regulated domain.

6. **Security review on every change.** All code changes require security-reviewer assessment before merging. No fast-track bypasses.

7. **BAA required for third-party services.** No PHI may be processed by or transmitted to any third-party service without a signed Business Associate Agreement on file.

## Enforcement

- Rule 1: Integration tests verify encryption on all PHI storage and transmission paths
- Rule 3: Audit middleware integration test on every write endpoint
- Rule 4: Log format validation scans for PHI patterns in CI
- Rule 6: Deploy script checks for security-reviewer approval
- Rule 7: Third-party integration checklist includes BAA verification
```

- [ ] **Step 4: Create backend-specialist.md**

```markdown
---
name: backend-specialist
extends: harness/backend-specialist
description: "Healthcare backend specialist. Owns PHI-handling API, audit logging, and data access layer."
model: sonnet
color: blue
memory: project
maxTurns: 50
---

You are the **Backend Specialist** for the health data platform.

## Domain

- PHI-handling REST API with encryption at every layer
- Audit logging middleware (immutable, 6-year retention)
- Data access layer with minimum-necessary scoping
- Third-party integration (BAA-verified services only)

## Tech Stack

- Node.js with Express
- PostgreSQL with column-level encryption
- Redis for sessions (no PHI in cache)
- Jest for testing

## Compliance Floor Awareness

- **All PHI encrypted at rest and in transit.** Verify encryption on every new storage path.
- **Minimum necessary access.** Scope every query. No `SELECT *` on PHI tables.
- **Audit every PHI access.** Use the audit middleware on all endpoints touching PHI.
- **No PHI in logs.** Use tokenized identifiers in all log statements.
- **BAA required.** Verify BAA before integrating any third-party service.

## Coordination

- Submit all changes to security-reviewer (no exceptions)
- Coordinate with compliance-officer on PHI handling patterns
```

- [ ] **Step 5: Create security-reviewer.md**

```markdown
---
name: security-reviewer
extends: harness/security-reviewer
description: "Healthcare security reviewer. Reviews every change for PHI handling, access control, and HIPAA compliance."
model: sonnet
color: red
memory: project
maxTurns: 30
---

You are the **Security Reviewer** for the health data platform.

## Review Focus

- PHI encryption verification (at rest and in transit)
- Access control and minimum-necessary scoping
- Audit log completeness on PHI operations
- PHI leakage in logs, error messages, or external calls
- BAA status for third-party service integrations

## Gate Criteria

Every code change must pass your review. No fast-track bypasses. You may:

- Approve with no changes
- Approve with non-blocking suggestions
- Block with required changes (creates a finding)

PHI-related findings are always **critical severity**.
```

- [ ] **Step 6: Create compliance-officer.md override**

```markdown
---
extends: harness/compliance-officer
---

## Domain Override

### HIPAA Focus

This project operates under HIPAA requirements. When evaluating compliance proposals or conducting reviews:

- PHI handling rules are non-negotiable — no risk-acceptance path exists
- BAA verification is a prerequisite for any third-party integration
- Audit log completeness is verified during every compliance audit cycle
- Breach notification procedures must be documented before any PHI-handling feature ships
```

- [ ] **Step 7: Create ops/deploy.sh**

```bash
#!/usr/bin/env bash
# Health Data Platform deploy stub — HIPAA-compliant deployment.
set -euo pipefail

if [ $# -lt 2 ]; then
  echo "Usage: deploy.sh <env> <component> [--type planned|hotfix]" >&2
  exit 1
fi

ENV="$1"
COMPONENT="$2"
DEPLOY_TYPE="planned"

shift 2
while [[ $# -gt 0 ]]; do
  case "$1" in
    --type) DEPLOY_TYPE="$2"; shift 2 ;;
    *) echo "Unknown flag: $1" >&2; exit 1 ;;
  esac
done

echo "=== Health Data Platform Deploy ==="
echo "Environment: $ENV"
echo "Component:   $COMPONENT"
echo "Type:        $DEPLOY_TYPE"
echo ""
echo "Pre-deploy checks:"
echo "  - Security-reviewer approval: REQUIRED"
echo "  - PHI encryption verification: REQUIRED"
echo "  - Audit log integration test: REQUIRED"
echo ""
echo "Would run:"
echo "  1. npm run build ($COMPONENT)"
echo "  2. npm run test ($COMPONENT)"
echo "  3. npm run test:phi-encryption ($COMPONENT)"
echo "  4. docker build -t health-$COMPONENT:latest ."
echo "  5. kubectl apply -f k8s/$ENV/$COMPONENT.yaml"
echo "  6. kubectl rollout status deployment/$COMPONENT -n $ENV"
echo ""
echo "deployment_id=health-${ENV}-${COMPONENT}-$(date +%s)"
```

Make executable: `chmod +x examples/04-compliance-heavy/ops/deploy.sh`

- [ ] **Step 8: Create setup.sh**

```bash
#!/usr/bin/env bash
# Seeds a sample compliance proposal for the healthcare platform.
set -euo pipefail

mkdir -p .claude/compliance/proposals

cat > .claude/compliance/proposals/001-add-analytics.md << 'PROPOSAL'
# Proposal: Add Usage Analytics

**Proposed by:** backend-specialist
**Status:** Under Review

## Change

Add PostHog analytics to track feature usage patterns across the platform.

## Compliance Impact

- **Rule 4 (No PHI in external services):** PostHog would receive event data. Must ensure zero PHI leakage in event properties. All event payloads must use tokenized identifiers only.
- **Rule 7 (BAA required):** PostHog offers a BAA for their enterprise plan — must be signed before integration proceeds.

## Risk Assessment

- **Medium risk:** Event properties could accidentally include PHI if not carefully scoped
- **Mitigation:** Allowlist-only approach for event properties (no dynamic fields), automated PHI pattern scanning on outbound events

## Recommendation

Pending CISO and CO review. Recommend proceeding only after BAA is signed and event property allowlist is defined and reviewed.
PROPOSAL

echo "Seeded compliance proposal: .claude/compliance/proposals/001-add-analytics.md"
echo "Try: /compliance to interact with the proposal"
```

Make executable: `chmod +x examples/04-compliance-heavy/setup.sh`

- [ ] **Step 9: Create README.md**

```markdown
# Example 04: Compliance-Heavy

A healthcare data platform under HIPAA requirements. The thickest compliance floor in the series (7 rules), a compliance officer override with domain-specific enforcement, tighter pace thresholds, and a seeded compliance proposal to interact with.

## What This Teaches Beyond 03

- **Thick compliance floors** for regulated domains — more rules, tighter language
- **Overriding governance agents** (CO) with domain-specific enforcement priorities
- **Tighter pace thresholds** reflecting lower risk tolerance (CFR 5/2, FPY 90)
- The **compliance change management workflow** — proposals, review, approval
- Using `setup.sh` to **pre-seed state** for a richer starting experience

## Structure
```

04-compliance-heavy/
├── .claude/
│ ├── agents/
│ │ ├── backend-specialist.md # PHI-handling specialist (extends harness)
│ │ └── security-reviewer.md # Reviews every change (extends harness)
│ └── overrides/
│ └── compliance-officer.md # HIPAA-focused CO override
├── compliance-floor.md # 7 rules (HIPAA-oriented)
├── fleet-config.json # Tight thresholds, retro every item
├── ops/
│ └── deploy.sh # Deploy stub with PHI checks
└── setup.sh # Seeds a compliance proposal

````

## Try It

```bash
ops/test-example.sh 04-compliance-heavy
# cd into the worktree, open Claude Code
/po
````

## What to Try

1. **`/compliance`** — See the seeded proposal from `setup.sh` and run it through review
2. **Build a PHI-handling feature** — watch the thick compliance floor enforce constraints
3. **Try to skip security review** — the floor blocks it
4. **`/audit`** — Run a compliance audit to see the auditor verify conformance
5. **Notice the pace thresholds** — tighter than other examples, reflecting regulated domain risk tolerance

## Prerequisites

You should be comfortable with [03-multi-team](../03-multi-team/) before this example. This example focuses on compliance depth, not team breadth.

````

- [ ] **Step 10: Verify JSON validity and script syntax**

Run: `python3 -c "import json; json.load(open('examples/04-compliance-heavy/fleet-config.json')); print('valid')"`
Expected: `valid`

Run: `bash -n examples/04-compliance-heavy/ops/deploy.sh && echo 'ok'`
Expected: `ok`

Run: `bash -n examples/04-compliance-heavy/setup.sh && echo 'ok'`
Expected: `ok`

- [ ] **Step 11: Commit**

```bash
git add examples/04-compliance-heavy/
git commit -m "feat: add example 04-compliance-heavy — HIPAA regulated domain with thick floor"
````

---

## Task 6: Create Example 05 — Operational Maturity

**Files:**

- Create: `examples/05-operational-maturity/README.md`
- Create: `examples/05-operational-maturity/.claude/agents/frontend-specialist.md`
- Create: `examples/05-operational-maturity/.claude/agents/backend-specialist.md`
- Create: `examples/05-operational-maturity/.claude/agents/e2e-test-engineer.md`
- Create: `examples/05-operational-maturity/.claude/overrides/scrum-master.md`
- Create: `examples/05-operational-maturity/.claude/overrides/cko.md`
- Create: `examples/05-operational-maturity/compliance-floor.md`
- Create: `examples/05-operational-maturity/fleet-config.json`
- Create: `examples/05-operational-maturity/ops/deploy.sh`
- Create: `examples/05-operational-maturity/setup.sh`

- [ ] **Step 1: Create directory structure**

```bash
mkdir -p examples/05-operational-maturity/.claude/agents
mkdir -p examples/05-operational-maturity/.claude/overrides
mkdir -p examples/05-operational-maturity/ops
```

- [ ] **Step 2: Create fleet-config.json**

```json
{
  "project": {
    "name": "fintech-api",
    "description": "Financial technology API platform — mature operational posture"
  },
  "metrics": {
    "backend": "jsonl",
    "file": ".claude/metrics/events.jsonl"
  },
  "deploy": {
    "command": "ops/deploy.sh",
    "environments": ["dev", "staging", "prod"]
  },
  "pace": {
    "current": "Walk",
    "walk_threshold_cfr": 10,
    "run_threshold_cfr": 5,
    "run_threshold_fpy": 80
  },
  "agents": {
    "governance": [
      "compliance-officer",
      "ciso",
      "ceo",
      "cto",
      "cfo",
      "coo",
      "cko"
    ],
    "core": [
      "product-owner",
      "solution-architect",
      "scrum-master",
      "knowledge-ops",
      "platform-ops",
      "compliance-auditor"
    ],
    "specialists": [
      "frontend-specialist",
      "backend-specialist",
      "e2e-test-engineer"
    ],
    "reviewers": [],
    "output": []
  },
  "retro": {
    "cadence": 3,
    "note": "Every 3 items. Team has stabilized — retros focus on optimization, not firefighting."
  },
  "knowledge": {
    "cadence": {
      "crawl": 1,
      "walk": 3,
      "run": 5,
      "fly": 0
    },
    "note": "Wider cadence — knowledge base is mature, distributions focus on refinements."
  },
  "pathways": {
    "declared": {
      "build": [
        "product-owner -> frontend-specialist",
        "product-owner -> backend-specialist",
        "product-owner -> e2e-test-engineer",
        "frontend-specialist -> product-owner",
        "backend-specialist -> product-owner",
        "e2e-test-engineer -> product-owner",
        "frontend-specialist -> backend-specialist",
        "backend-specialist -> frontend-specialist",
        "frontend-specialist -> e2e-test-engineer",
        "backend-specialist -> e2e-test-engineer",
        "e2e-test-engineer -> frontend-specialist",
        "e2e-test-engineer -> backend-specialist"
      ],
      "review": [],
      "escalation": ["* -> solution-architect", "* -> scrum-master"],
      "governance": [
        "ciso -> compliance-officer",
        "compliance-officer -> compliance-auditor",
        "* -> compliance-officer",
        "cko -> knowledge-ops",
        "cto -> solution-architect",
        "cfo -> platform-ops",
        "coo -> scrum-master",
        "* -> ceo"
      ]
    }
  }
}
```

- [ ] **Step 3: Create compliance-floor.md**

```markdown
# Compliance Floor — Fintech API

Non-negotiable rules that override all autonomy tiers, pace settings, and process decisions.

## Rules

1. **No plaintext financial data at rest.** Account numbers, routing numbers, balances, and transaction records are encrypted at rest. Key management uses a dedicated KMS, not application-level secrets.

2. **All API mutations are idempotent.** Financial operations (transfers, charges, refunds) must be idempotent with client-provided idempotency keys. No duplicate transactions from retries.

3. **Audit trail on all financial operations.** Every transaction, balance change, and account modification produces an immutable audit entry. Audit retention: 7 years.

4. **Plan before build.** Non-trivial work items must have an approved plan before implementation begins.

5. **No direct database writes.** All data mutations go through the application's service layer. No raw SQL in application code, no migration scripts that bypass the ORM for business data.

## Enforcement

- Rule 1: Integration tests verify encryption on all financial data storage paths
- Rule 2: Idempotency test suite verifies every mutation endpoint
- Rule 3: Audit middleware integration test on every write endpoint
- Rule 5: Code review checks for raw SQL outside of migrations
```

- [ ] **Step 4: Create frontend-specialist.md**

```markdown
---
name: frontend-specialist
extends: harness/frontend-specialist
description: "Fintech frontend specialist. Owns trading dashboard, account management, and transaction views."
model: sonnet
color: cyan
memory: project
maxTurns: 50
---

You are the **Frontend Specialist** for the fintech API platform.

## Domain

- Trading dashboard and real-time data display
- Account management pages
- Transaction history and detail views
- Form validation for financial inputs

## Tech Stack

- React 18 with TypeScript
- Next.js for SSR
- Tailwind CSS
- React Query with WebSocket subscriptions
- Vitest + React Testing Library

## Compliance Floor Awareness

- **No financial data in frontend state beyond what's displayed.** Minimize data retention in browser memory.
- **All financial inputs validated client-side and server-side.** Never trust client-only validation for financial operations.

## Coordination

- Work with backend-specialist on API contracts and WebSocket events
- Hand off to e2e-test-engineer after feature completion
```

- [ ] **Step 5: Create backend-specialist.md**

```markdown
---
name: backend-specialist
extends: harness/backend-specialist
description: "Fintech backend specialist. Owns transaction API, financial data layer, and idempotency infrastructure."
model: sonnet
color: blue
memory: project
maxTurns: 50
---

You are the **Backend Specialist** for the fintech API platform.

## Domain

- Transaction API (transfers, charges, refunds)
- Financial data layer with encryption
- Idempotency infrastructure (client-provided keys)
- Audit logging for all financial operations
- KMS integration for key management

## Tech Stack

- Node.js with Express
- PostgreSQL with column-level encryption
- Redis for idempotency key tracking and caching
- Jest for testing

## Compliance Floor Awareness

- **No plaintext financial data at rest.** Use KMS-managed keys for all encryption.
- **All mutations idempotent.** Implement idempotency key checking on every write endpoint.
- **Audit every financial operation.** Use the audit middleware on all endpoints.
- **No direct database writes.** All mutations go through the service layer.

## Coordination

- Publish API contracts for frontend-specialist
- Hand off to e2e-test-engineer for integration validation
```

- [ ] **Step 6: Create e2e-test-engineer.md**

```markdown
---
name: e2e-test-engineer
extends: harness/e2e-test-engineer
description: "E2E test engineer. Owns integration and end-to-end test suites across the full stack."
model: sonnet
color: yellow
memory: project
maxTurns: 40
---

You are the **E2E Test Engineer** for the fintech API platform.

## Domain

- End-to-end test suites covering API flows
- Integration tests across frontend and backend boundaries
- Transaction flow validation (create, process, settle, refund)
- Idempotency verification tests
- Audit trail completeness checks

## Coordination

- Receive handoffs from frontend-specialist and backend-specialist after feature implementation
- Report test failures back to the originating specialist
- Flag compliance floor violations found during test authoring as findings
```

- [ ] **Step 7: Create scrum-master.md override**

```markdown
---
extends: harness/scrum-master
---

## Process Override

### Retro Cadence

Every 3 items. The team has stabilized — retros focus on process optimization rather than incident response.

### Pace Monitoring

At Walk pace, the SM actively monitors for Run promotion readiness. Flag when CFR drops below 5% and FPY exceeds 80% over a 10-item window.
```

- [ ] **Step 8: Create cko.md override**

```markdown
---
extends: harness/cko
---

## Knowledge Override

### Distribution Strategy

At Walk pace, knowledge distributions happen every 3 items. Focus on:

- Patterns that reduced rework in recent iterations
- Cross-specialist learnings (frontend ↔ backend boundary patterns)
- E2E test patterns that catch recurring defect categories

### Quality Bar

Knowledge artifacts should be refined, not raw. At this maturity level, the knowledge base serves as onboarding material, not just operational notes.
```

- [ ] **Step 9: Create ops/deploy.sh**

```bash
#!/usr/bin/env bash
# Fintech API deploy stub — mature operational posture.
set -euo pipefail

if [ $# -lt 2 ]; then
  echo "Usage: deploy.sh <env> <component> [--type planned|hotfix]" >&2
  exit 1
fi

ENV="$1"
COMPONENT="$2"
DEPLOY_TYPE="planned"

shift 2
while [[ $# -gt 0 ]]; do
  case "$1" in
    --type) DEPLOY_TYPE="$2"; shift 2 ;;
    *) echo "Unknown flag: $1" >&2; exit 1 ;;
  esac
done

echo "=== Fintech API Deploy ==="
echo "Environment: $ENV"
echo "Component:   $COMPONENT"
echo "Type:        $DEPLOY_TYPE"
echo ""
echo "Would run:"
echo "  1. npm run build ($COMPONENT)"
echo "  2. npm run test ($COMPONENT)"
echo "  3. npm run test:idempotency ($COMPONENT)"
echo "  4. npm run test:e2e ($COMPONENT)"
echo "  5. docker build -t fintech-$COMPONENT:latest ."
echo "  6. kubectl apply -f k8s/$ENV/$COMPONENT.yaml"
echo "  7. kubectl rollout status deployment/$COMPONENT -n $ENV"
echo ""
echo "deployment_id=fintech-${ENV}-${COMPONENT}-$(date +%s)"
```

Make executable: `chmod +x examples/05-operational-maturity/ops/deploy.sh`

- [ ] **Step 10: Create setup.sh**

```bash
#!/usr/bin/env bash
# Seeds metrics events to simulate a project with history.
# This gives ops/dora.sh something meaningful to display.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Find metrics-log.sh relative to the worktree root
WORKTREE_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
METRICS_LOG="$WORKTREE_ROOT/ops/metrics-log.sh"

if [[ ! -x "$METRICS_LOG" ]]; then
  echo "Warning: ops/metrics-log.sh not found or not executable at $METRICS_LOG" >&2
  echo "Metrics seeding skipped. The example is still usable." >&2
  exit 0
fi

mkdir -p "$WORKTREE_ROOT/.claude/metrics"

cd "$WORKTREE_ROOT"

# Simulate 8 completed items with realistic event sequence
for i in $(seq 1 8); do
  "$METRICS_LOG" item-promoted "$i"
  "$METRICS_LOG" item-accepted "$i"
done

# A couple of bugs found and fixed (items 3 and 6)
"$METRICS_LOG" bug-found 3 --severity medium --source review
"$METRICS_LOG" bug-fixed 3
"$METRICS_LOG" bug-found 6 --severity low --source testing
"$METRICS_LOG" bug-fixed 6

# Cross-specialist handoffs
"$METRICS_LOG" handoff-sent 4 --from backend-specialist --to e2e-test-engineer
"$METRICS_LOG" handoff-sent 5 --from frontend-specialist --to backend-specialist
"$METRICS_LOG" handoff-sent 7 --from backend-specialist --to frontend-specialist

echo ""
echo "Seeded: 8 completed items, 2 bug cycles, 3 handoffs"
echo "Run: ops/dora.sh to see the dashboard"
```

Make executable: `chmod +x examples/05-operational-maturity/setup.sh`

- [ ] **Step 11: Create README.md**

```markdown
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
│ ├── agents/
│ │ ├── frontend-specialist.md # Fintech frontend (extends harness)
│ │ ├── backend-specialist.md # Fintech backend (extends harness)
│ │ └── e2e-test-engineer.md # Full-stack E2E testing (extends harness)
│ └── overrides/
│ ├── scrum-master.md # Retro every 3, pace monitoring
│ └── cko.md # Walk-pace knowledge distribution
├── compliance-floor.md # 5 rules (fintech-oriented)
├── fleet-config.json # Walk pace, 3 specialists, dense pathways
├── ops/
│ └── deploy.sh # Deploy stub with idempotency/E2E checks
└── setup.sh # Seeds 8 items of metrics history

````

## Try It

```bash
ops/test-example.sh 05-operational-maturity
# cd into the worktree, open Claude Code
````

## What to Try

1. **`ops/dora.sh`** — See a dashboard with real history (seeded by `setup.sh`)
2. **`ops/dora.sh --sm`** — See the SM's pace recommendation based on metrics
3. **`ops/dora.sh --flow`** — See handoff quality across specialist boundaries
4. **`/po`** — Notice the fleet is at Walk pace, not Crawl
5. **Build a feature** — watch three specialists coordinate with dense pathways
6. **`ops/pathways.sh`** — Compare declared vs actual agent communication

## Prerequisites

You should be comfortable with all previous examples. This one shows the operational destination — what earlier examples are building toward.

````

- [ ] **Step 12: Verify JSON validity and script syntax**

Run: `python3 -c "import json; json.load(open('examples/05-operational-maturity/fleet-config.json')); print('valid')"`
Expected: `valid`

Run: `bash -n examples/05-operational-maturity/ops/deploy.sh && echo 'ok'`
Expected: `ok`

Run: `bash -n examples/05-operational-maturity/setup.sh && echo 'ok'`
Expected: `ok`

- [ ] **Step 13: Commit**

```bash
git add examples/05-operational-maturity/
git commit -m "feat: add example 05-operational-maturity — mature fleet at Walk pace with metrics history"
````

---

## Task 7: Create ops/test-example.sh

**Files:**

- Create: `ops/test-example.sh`

- [ ] **Step 1: Create the test script**

```bash
#!/usr/bin/env bash
# test-example.sh — Scaffold a Venutian Antfarm example into an isolated git worktree.
#
# Usage:
#   ops/test-example.sh <example-name>            # Set up test environment
#   ops/test-example.sh --cleanup <example-name>   # Remove test environment
#
# Examples:
#   ops/test-example.sh 01-getting-started
#   ops/test-example.sh --cleanup 01-getting-started
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WORKTREE_DIR="$REPO_ROOT/.worktrees"

usage() {
  echo "Usage: $0 [--cleanup] <example-name>" >&2
  echo "" >&2
  echo "Examples:" >&2
  echo "  $0 01-getting-started" >&2
  echo "  $0 --cleanup 01-getting-started" >&2
  exit 1
}

cleanup_example() {
  local name="$1"
  local found=0

  for wt in "$WORKTREE_DIR"/test-"$name"-*; do
    if [[ -d "$wt" ]]; then
      found=1
      local branch
      branch=$(git -C "$wt" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")

      echo "Removing worktree: $wt"
      git -C "$REPO_ROOT" worktree remove --force "$wt" 2>/dev/null || rm -rf "$wt"

      if [[ -n "$branch" && "$branch" != "main" && "$branch" != "HEAD" ]]; then
        git -C "$REPO_ROOT" branch -D "$branch" 2>/dev/null || true
      fi
    fi
  done

  if [[ $found -eq 0 ]]; then
    echo "No worktrees found for example: $name" >&2
    exit 1
  fi

  echo "Cleanup complete."
}

setup_example() {
  local name="$1"
  local example_dir="$REPO_ROOT/examples/$name"

  # Validate example exists
  if [[ ! -d "$example_dir" ]]; then
    echo "Error: Example not found: examples/$name" >&2
    echo "" >&2
    echo "Available examples:" >&2
    ls -1 "$REPO_ROOT/examples/" 2>/dev/null | grep -v README | sed 's/^/  /' >&2
    exit 1
  fi

  # Check for existing worktree
  for existing in "$WORKTREE_DIR"/test-"$name"-*; do
    if [[ -d "$existing" ]]; then
      echo "Warning: Existing worktree found: $existing" >&2
      echo "Run '$0 --cleanup $name' first, or use the existing worktree." >&2
      exit 1
    fi
  done

  local timestamp
  timestamp=$(date +%s)
  local branch="test-${name}-${timestamp}"
  local wt_path="$WORKTREE_DIR/test-${name}-${timestamp}"

  mkdir -p "$WORKTREE_DIR"

  # Create worktree on a new branch
  echo "Creating worktree at: $wt_path"
  git -C "$REPO_ROOT" worktree add -b "$branch" "$wt_path" HEAD --quiet

  # Copy harness infrastructure
  echo "Copying harness infrastructure..."

  # Core agents
  mkdir -p "$wt_path/.claude/agents"
  cp "$REPO_ROOT"/.claude/agents/*.md "$wt_path/.claude/agents/" 2>/dev/null || true

  # Collaboration docs
  cp "$REPO_ROOT/.claude/COLLABORATION.md" "$wt_path/.claude/" 2>/dev/null || true
  cp "$REPO_ROOT/.claude/DOCUMENTATION-STYLE.md" "$wt_path/.claude/" 2>/dev/null || true

  # Settings (hooks for compliance enforcement)
  cp "$REPO_ROOT/.claude/settings.json" "$wt_path/.claude/" 2>/dev/null || true

  # Skills, governance, compliance, findings
  for dir in skills governance compliance findings; do
    if [[ -d "$REPO_ROOT/.claude/$dir" ]]; then
      cp -r "$REPO_ROOT/.claude/$dir" "$wt_path/.claude/"
    fi
  done

  # MCP config
  cp "$REPO_ROOT/.mcp.json" "$wt_path/" 2>/dev/null || true

  # Ops scripts
  cp -r "$REPO_ROOT/ops" "$wt_path/"

  # Templates
  cp -r "$REPO_ROOT/templates" "$wt_path/"

  # Copy example files (overwriting harness defaults where applicable)
  echo "Copying example files from: examples/$name"
  cp -r "$example_dir"/* "$wt_path/" 2>/dev/null || true
  # Handle dotfiles/directories (.claude)
  if [[ -d "$example_dir/.claude" ]]; then
    cp -r "$example_dir/.claude"/* "$wt_path/.claude/" 2>/dev/null || true
  fi

  # Apply overrides: copy override files into agents directory
  if [[ -d "$wt_path/.claude/overrides" ]]; then
    echo "Applying agent overrides..."
    cp "$wt_path/.claude/overrides"/*.md "$wt_path/.claude/agents/" 2>/dev/null || true
  fi

  # Run setup.sh if present
  if [[ -x "$wt_path/setup.sh" ]]; then
    echo "Running setup.sh..."
    if (cd "$wt_path" && bash setup.sh); then
      echo "Setup complete."
    else
      echo "Warning: setup.sh exited with errors. The example is still usable." >&2
    fi
  fi

  # Create initial commit in worktree so git state is clean
  (cd "$wt_path" && git add -A && git commit -m "test: scaffold example $name" --quiet 2>/dev/null) || true

  echo ""
  echo "================================================"
  echo "  Example $name ready!"
  echo "================================================"
  echo ""
  echo "  cd $wt_path"
  echo "  claude"
  echo ""
  echo "  Try first: /po"
  echo ""
  echo "  Cleanup:   $0 --cleanup $name"
  echo "================================================"
}

# Parse arguments
if [[ $# -lt 1 ]]; then
  usage
fi

if [[ "$1" == "--cleanup" ]]; then
  if [[ $# -lt 2 ]]; then
    usage
  fi
  cleanup_example "$2"
elif [[ "$1" == "--help" || "$1" == "-h" ]]; then
  usage
else
  setup_example "$1"
fi
```

Make executable: `chmod +x ops/test-example.sh`

- [ ] **Step 2: Verify script syntax**

Run: `bash -n ops/test-example.sh && echo 'ok'`
Expected: `ok`

- [ ] **Step 3: Commit**

```bash
git add ops/test-example.sh
git commit -m "feat: add ops/test-example.sh — worktree-based example test runner"
```

---

## Task 8: Create examples/README.md

**Files:**

- Create: `examples/README.md`

- [ ] **Step 1: Create the index**

````markdown
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
````

Testing happens in isolated git worktrees — your framework repo is never modified.

````

- [ ] **Step 2: Commit**

```bash
git add examples/README.md
git commit -m "docs: add examples/README.md index with progression guide"
````

---

## Task 9: Update Framework References

**Files:**

- Modify: `CLAUDE.md:12,46,166`
- Modify: `README.md:282`
- Modify: `docs/GETTING-STARTED.md:155`
- Modify: `docs/AGENT-FLEET-PATTERN.md:323,370`

- [ ] **Step 1: Read current files for exact context**

Read `CLAUDE.md`, `README.md`, `docs/GETTING-STARTED.md`, and `docs/AGENT-FLEET-PATTERN.md` to get the exact lines to change.

- [ ] **Step 2: Update CLAUDE.md**

Three changes:

Line 12: Change `# See example/ for a complete working reference` to `# See examples/ for progressive working references`

Line 46: Change `├── example/                         # Working example app (complete reference)` to `├── examples/                        # Progressive examples (01-05)`

Line 166: Change `- **The \`example/\` directory is a complete working reference** with specialist agents, overrides, compliance floor, and fleet config. Use it as a starting point.`to`- **The \`examples/\` directory contains 5 progressive examples\*\* from minimum setup (01-getting-started) to operational maturity (05-operational-maturity). Test any example with \`ops/test-example.sh <name>\`.`

- [ ] **Step 3: Update README.md**

Line 282: Change `- **[Example App](example/)** -- Working example with 2 specialist agents` to `- **[Examples](examples/)** -- 5 progressive examples from getting started to operational maturity`

- [ ] **Step 4: Update docs/GETTING-STARTED.md**

Line 155: Change `- Check the [Example App](../example/) for a working 2-specialist setup` to `- Check the [Examples](../examples/) for progressive working examples (start with 01-getting-started)`

- [ ] **Step 5: Update docs/AGENT-FLEET-PATTERN.md**

Line 323: Change `See the \`example/\` directory in this repository for a minimal working demonstration.`to`See the \`examples/\` directory in this repository for progressive working demonstrations.`

Line 370: Change `- \`example/\` -- Working example with 2 specialist agents`to`- \`examples/\` -- 5 progressive examples (getting started through operational maturity)`

- [ ] **Step 6: Verify no remaining references to old example/ path**

Run: `grep -r 'example/' CLAUDE.md README.md docs/GETTING-STARTED.md docs/AGENT-FLEET-PATTERN.md | grep -v 'examples/' | grep -v 'superpowers/'`
Expected: no output (all references updated)

- [ ] **Step 7: Commit**

```bash
git add CLAUDE.md README.md docs/GETTING-STARTED.md docs/AGENT-FLEET-PATTERN.md
git commit -m "docs: update example/ references to examples/ across framework docs"
```
