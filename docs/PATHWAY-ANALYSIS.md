<img src="assets/venutian-antfarm-icon.jpg" alt="Venutian Antfarm" width="80" align="right">

# Pathway Analysis Guide

_Part of [Venutian Antfarm](../README.md) by [RD Digital Consulting Services, LLC](https://robdunie.com/)._

How to understand, use, and interpret the agent communication pathway analysis tool.

## What is Pathway Analysis?

Pathway analysis answers a fundamental governance question: **are agents communicating the way we designed, or has the fleet evolved its own patterns?**

Every time an agent hands work to another agent, a `handoff-sent` event is logged. The pathway analysis tool (`ops/pathways.sh`) compares these actual communication patterns against the pathways you declared in `fleet-config.json`. The delta between declared and actual is the signal:

- **Actual matches declared** — the fleet is operating as designed
- **Undeclared paths appear** — agents found a need to communicate outside the designed topology. This could be innovation (a useful shortcut worth formalizing) or a governance bypass (an agent circumventing controls)
- **Declared paths go unused** — a designed communication route was never exercised. The topology may be over-specified, or a workflow hasn't been triggered yet

This is analogous to network flow analysis in security: you declare expected traffic patterns and flag deviations.

## Why It Matters

Without pathway analysis, you have no visibility into how the fleet's communication topology is evolving. Over time:

- Agents may develop ad-hoc shortcuts that bypass review or compliance checks
- Bottleneck agents may emerge (one agent on every critical path)
- Designed workflows may go unused, indicating a mismatch between the plan and reality
- The fleet may silently reorganize itself in ways that undermine governance

Pathway analysis makes the invisible visible. It turns agent-to-agent communication into an observable, measurable, and governable system property.

## Declaring Pathways

Pathways are declared in `fleet-config.json` under `pathways.declared`. They are organized by category:

```json
"pathways": {
  "declared": {
    "build": [
      "product-owner -> backend-specialist",
      "product-owner -> frontend-specialist",
      "backend-specialist -> security-reviewer",
      "frontend-specialist -> e2e-test-engineer",
      "security-reviewer -> product-owner",
      "e2e-test-engineer -> product-owner"
    ],
    "review": [
      "product-owner -> security-reviewer",
      "product-owner -> e2e-test-engineer"
    ],
    "escalation": [
      "* -> solution-architect",
      "* -> scrum-master",
      "* -> product-owner"
    ],
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
```

### Pathway Categories

| Category     | Purpose                                              | Example                     |
| ------------ | ---------------------------------------------------- | --------------------------- |
| `build`      | Expected agent communication during the Build phase  | Specialist → reviewer → PO  |
| `review`     | Expected agent communication during the Review phase | PO → reviewer dispatch      |
| `escalation` | Paths any agent can use to reach strategic agents    | `* -> solution-architect`   |
| `governance` | Cx role communication with operational agents        | `cto -> solution-architect` |

### Wildcards

Use `*` to declare that **any agent** can communicate with a target:

- `* -> solution-architect` — any agent can escalate to the SA
- `* -> compliance-officer` — any agent can propose compliance changes

Wildcards match against the source or target side of actual paths. They are evaluated during delta analysis.

### Declaring vs. Not Declaring

**Declare a pathway when:**

- You expect and want this communication to happen regularly
- The pathway represents a designed workflow (build → review → accept)
- You want to track whether the pathway is being used

**Don't declare a pathway when:**

- The communication is ad-hoc and should be evaluated case by case
- You want to be alerted when this communication happens (let it show up as undeclared)

## Running the Analysis

```bash
ops/pathways.sh              # Full analysis (default: last 30 days)
ops/pathways.sh --since 7d   # Last 7 days only
ops/pathways.sh --since 2026-03-01  # Since a specific date
```

## Understanding the Output

The report has 5 sections. Here is a complete example with annotations explaining how to interpret each section.

### Section 1: Actual Pathways

```
  ACTUAL PATHWAYS (inferred from handoff-sent events)

  From                           To                           Count
  ----                           --                           -----
  backend-specialist             security-reviewer            42
  frontend-specialist            ux-reviewer                  35
  backend-specialist             compliance-auditor           28
  frontend-specialist            compliance-auditor           22
  infra-specialist               security-reviewer            18
  e2e-test-engineer              product-owner                15
  backend-specialist             frontend-specialist          8
```

**What it shows:** Every unique agent-to-agent handoff that actually happened in the time window, sorted by frequency.

**How to read it:**

- Each row is a communication path: agent A handed work to agent B this many times
- High counts indicate well-established patterns — these are the fleet's primary communication channels
- Low counts may indicate occasional or emerging patterns
- Look for **asymmetry**: if `backend-specialist → security-reviewer` has 42 handoffs but `security-reviewer → backend-specialist` has 0, the security-reviewer is a sink (receives work, doesn't hand back). This is expected for a reviewer role.

### Section 2: Declared Pathways

```
  DECLARED PATHWAYS (from fleet-config.json)

  Category     Pathway                                     Active?
  --------     -------                                     -------
  build        product-owner -> backend-specialist          yes
  build        product-owner -> frontend-specialist         yes
  build        backend-specialist -> security-reviewer      yes
  build        frontend-specialist -> e2e-test-engineer     yes
  build        security-reviewer -> product-owner           yes
  build        e2e-test-engineer -> product-owner           yes
  review       product-owner -> security-reviewer           yes
  review       product-owner -> e2e-test-engineer           yes
  escalation   * -> solution-architect                      no
  escalation   * -> scrum-master                            no
  escalation   * -> product-owner                           yes
  governance   ciso -> compliance-officer                   no
  governance   compliance-officer -> compliance-auditor     yes
  governance   * -> compliance-officer                      yes
  governance   cko -> knowledge-ops                         yes
  governance   cto -> solution-architect                    no
  governance   coo -> scrum-master                          no
  governance   * -> ceo                                     no
```

**What it shows:** Every pathway you declared in `fleet-config.json` and whether it was exercised in the time window.

**How to read it:**

- `Active? yes` — this pathway was used. The fleet is communicating as designed.
- `Active? no` — this pathway was declared but never used. This might be fine (the workflow hasn't been triggered yet) or a signal (a designed workflow is being bypassed).
- **Escalation paths showing `no`** are often expected — escalation is for exceptions, not routine work.
- **Governance paths showing `no`** may indicate that governance roles haven't been fully activated yet.

### Section 3: Pathway Delta

```
  PATHWAY DELTA

  Undeclared paths (1):
    ! backend-specialist -> frontend-specialist (8x)

  These paths were used but not declared in fleet-config.json.
  Evaluate: innovation (add to declared) or bypass (address).
```

**What it shows:** The gap between what was designed and what actually happened.

**How to read it:**

**Undeclared paths** are the most important signal. For each one, ask:

1. **Is this useful cross-domain coordination?** Example: `backend-specialist → frontend-specialist` for API contract changes. If yes, add it to `fleet-config.json` as a declared pathway.

2. **Is this a governance bypass?** Example: `specialist → specialist` skipping a reviewer. If yes, investigate why the designed pathway wasn't followed. Was the reviewer unavailable? Was the handoff unnecessary? Was the agent trying to shortcut the process?

3. **Is this a one-time exception?** Low-count undeclared paths (1-2 occurrences) may be isolated events. Monitor but don't over-react. Pattern is the signal, not a single instance.

**Unused declared paths** are a softer signal:

```
  Unused declared paths (3):
    - ciso -> compliance-officer (governance)
    - cto -> solution-architect (governance)
    - coo -> scrum-master (governance)

  These paths were declared but never used in the time window.
  May indicate over-declared topology or unexercised workflows.
```

Unused paths mean the designed workflow hasn't been triggered. Ask:

- Is this pathway needed for the current work? (If no items touched security, CISO → CO wouldn't fire.)
- Has this workflow been superseded? (Maybe the CTO coaches the SA directly without a formal handoff.)
- Is the fleet too young? (New agents may not have had opportunities to use all pathways yet.)

### Section 4: Fleet Density

```
  FLEET DENSITY
    Active agents in handoffs: 7
    Unique communication paths: 7
    Density: 17% of possible paths (7/42)
```

**What it shows:** How interconnected the fleet's actual communication is, as a percentage of all possible agent-to-agent paths.

**How to read it:**

| Density                | Interpretation                                                                                                                                                      |
| ---------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| < 20% with many agents | **Potential bottleneck.** Few paths means most communication flows through a small number of agents. Check if one agent is on every critical path.                  |
| 20-50%                 | **Healthy.** Agents communicate through structured channels without excessive coordination overhead.                                                                |
| 50-70%                 | **Getting chatty.** More paths means more coordination. Evaluate whether all paths are necessary.                                                                   |
| > 70%                  | **Warning: coordination overhead.** Almost every agent talks to every other agent. This suggests weak boundaries or agents reaching outside their domain too often. |

Density should **decrease** as the fleet matures. Mature fleets have well-established pathways and don't need ad-hoc communication. Rising density at high pace is a process smell.

### Section 5: Top Communicators

```
  TOP COMMUNICATORS

  Agent                          Sent       Received   Total
  -----                          ----       --------   -----
  backend-specialist             78         0          78
  security-reviewer              0          60         60
  frontend-specialist            57         8          65
  compliance-auditor             0          50         50
  ux-reviewer                    0          35         35
  infra-specialist               18         0          18
  e2e-test-engineer              15         0          15
  product-owner                  0          15         15
```

**What it shows:** Each agent's communication volume, split by sent (initiated handoffs) and received (received handoffs).

**How to read it:**

**Healthy patterns:**

- **Specialists have high sent, low received** — they build and hand off for review
- **Reviewers have low sent, high received** — they receive work for review
- **PO has moderate received** — receives acceptance handoffs from reviewers

**Warning patterns:**

- **An agent with high sent AND high received** — may be a bottleneck or coordination hub. This is expected for the PO but concerning for a specialist.
- **An agent with 0 sent and 0 received** — not participating in handoffs. Either the agent isn't being dispatched or it's working in isolation (which violates the handoff protocol).
- **Extreme imbalance** (one agent has 80% of total) — the fleet may be over-relying on one agent. Consider whether work distribution is healthy.

## Using Pathway Analysis in Retros

The SM should include pathway analysis in every retrospective (Phase 8):

1. **Run `ops/pathways.sh --since <last-retro-date>`** to get the period's communication patterns
2. **Highlight undeclared paths** — discuss with the team: innovation or bypass?
3. **Check density trend** — is it rising (more coordination needed) or falling (maturing)?
4. **Identify bottleneck agents** — any agent on every critical path needs relief
5. **Propose pathway declarations** for validated ad-hoc patterns
6. **Remove declared paths** that are consistently unused and no longer needed

## Using Pathway Analysis for Governance

The CO and COO use pathway analysis to verify governance integrity:

- **CO checks** that compliance-related handoffs flow through declared governance pathways. An undeclared path that bypasses the compliance-auditor is a governance concern.
- **COO checks** that operational patterns match the designed process. If agents are finding shortcuts around the standard lifecycle, the COO evaluates whether the process needs adjustment or the agents need coaching.
- **SM checks** that escalation paths are used appropriately — escalations should be rare at high pace. Frequent escalation at Run/Fly pace suggests the fleet isn't as autonomous as the pace implies.

## Example: Reading a Pathway Report

Here is a complete pathway report with analysis annotations:

```
╔══════════════════════════════════════════════════════════════╗
║              COMMUNICATION PATHWAYS                        ║
╚══════════════════════════════════════════════════════════════╝

  ACTUAL PATHWAYS (inferred from handoff-sent events)

  From                           To                           Count
  ----                           --                           -----
  backend-specialist             security-reviewer            42    ← Primary review channel
  frontend-specialist            ux-reviewer                  35    ← Primary review channel
  backend-specialist             compliance-auditor           28    ← Compliance review
  frontend-specialist            compliance-auditor           22    ← Compliance review
  infra-specialist               security-reviewer            18    ← Infra security checks
  e2e-test-engineer              product-owner                15    ← Test results to PO
  backend-specialist             frontend-specialist          8     ← ⚠️ Undeclared!

  DECLARED PATHWAYS (from fleet-config.json)

  Category     Pathway                                     Active?
  --------     -------                                     -------
  build        product-owner -> backend-specialist          yes
  build        backend-specialist -> security-reviewer      yes     ← Matches 42 handoffs above
  review       product-owner -> security-reviewer           yes
  escalation   * -> solution-architect                      no      ← OK: no escalations needed
  governance   ciso -> compliance-officer                   no      ← OK: no security floor changes
  governance   cko -> knowledge-ops                         yes     ← Knowledge distribution active

  PATHWAY DELTA

  Undeclared paths (1):
    ! backend-specialist -> frontend-specialist (8x)      ← Investigate this

  Analysis: The backend-specialist is handing work directly to the
  frontend-specialist 8 times. This bypasses the normal PO orchestration
  flow. Likely cause: API contract changes where the backend needs the
  frontend to update its integration. If this is a recurring pattern,
  declare it as a build pathway. If it's the backend trying to direct
  frontend work without PO prioritization, address it.

  FLEET DENSITY
    Active agents in handoffs: 7
    Unique communication paths: 7
    Density: 17% of possible paths (7/42)                ← Healthy

  TOP COMMUNICATORS

  Agent                          Sent       Received   Total
  -----                          ----       --------   -----
  backend-specialist             78         0          78      ← Heaviest communicator
  security-reviewer              0          60         60      ← Pure receiver (expected)
  compliance-auditor             0          50         50      ← Pure receiver (expected)
```

**Summary for retro:** The fleet is operating within designed boundaries except for one undeclared path (`backend → frontend`, 8x). Density is healthy at 17%. No escalations were needed. The backend-specialist is the heaviest communicator — verify this reflects appropriate workload distribution, not a bottleneck.
