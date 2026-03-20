<img src="assets/venutian-antfarm-icon.jpg" alt="Venutian Antfarm" width="80" align="right">

# Agent Collaboration Model

_Part of [Venutian Antfarm](../README.md) by [RD Digital Consulting Services, LLC](https://robdunie.com/)._

Visual guide to how the agent fleet collaborates. Source of truth for collaboration rules: `.claude/COLLABORATION.md`. Source of truth for documentation style: `.claude/DOCUMENTATION-STYLE.md`.

## Table of Contents

- [Fleet Structure](#fleet-structure)
- [Governance Tier Detail](#governance-tier-detail)
- [Leadership + Operational Tier Detail](#leadership--operational-tier-detail)
- [Governance ↔ Operational Bridge](#governance--operational-bridge)
- [Worktree Isolation](#worktree-isolation)
- [Work Item Lifecycle](#work-item-lifecycle)
- [Pace Control](#pace-control)
- [Review Dispatch](#review-dispatch)
- [Compliance Floor](#compliance-floor)
- [Learning Loop](#learning-loop)
- [Model Selection Decision Tree](#model-selection-decision-tree)
- [Delivery Metrics (DORA + Flow Quality)](#delivery-metrics-dora--flow-quality)
- [Leadership Triad](#leadership-triad)
- [Agent Inheritance](#agent-inheritance)
- [Memory Architecture](#memory-architecture)
- [Handoff Protocol](#handoff-protocol)
- [Coordination Layers](#coordination-layers)
- [Enforcement Layers](#enforcement-layers)
- [Conflict Resolution](#conflict-resolution)
- [Regression Testing](#regression-testing)
- [Budget & Resource Flow](#budget--resource-flow)
- [Milestone Release](#milestone-release)

---

## Fleet Structure

The fleet has three tiers: governance (sets policy), leadership (orchestrates delivery), and execution (builds and reviews). Authority flows down; data flows up.

```mermaid
flowchart TD
    USER(["User"])

    subgraph Gov ["Governance Layer"]
        GOV(["CO  CISO  CEO\nCTO  CFO  COO  CKO"])
    end

    S(["Strategic\nPO  SA  SM"])
    E(["Execution\nSpecialist agents\n(you define)"])
    R(["Reviewers\nsecurity\n(you define)"])
    O(["Output\ndoc  training\n(you define)"])

    USER -->|"approvals +\noversight"| Gov
    Gov -->|"controls +\ncompliance"| S
    S -->|"context"| E
    S -.->|"arch/process"| R
    E -->|"work"| R
    R -.->|"findings"| E
    R -.->|"risk signals"| S
    E -->|"milestone"| O
    R -.->|"corrections"| O
    O -.->|"content"| R

    style USER fill:#90caf9,stroke:#1565c0,color:#1a1a1a
    style GOV fill:#ce93d8,stroke:#6a1b9a,color:#1a1a1a
    style S fill:#90caf9,stroke:#1565c0,color:#1a1a1a
    style E fill:#a5d6a7,stroke:#2e7d32,color:#1a1a1a
    style R fill:#ef9a9a,stroke:#b71c1c,color:#1a1a1a
    style O fill:#ffcc80,stroke:#e65100,color:#1a1a1a
```

**Diamond layout**: Strategic at top feeds both Execution (context) and Reviewers (architecture/process). Execution and Reviewers interact laterally (work and findings). Both feed down to Output (milestones and corrections). Feedback flows back up (risk signals, content for review). The Governance layer sets policy above Strategic.

---

## Governance Tier Detail

The governance tier sets policy and standards. The CO is the compliance floor guardian -- all floor changes require user approval. Each Cx role proposes controls to the CO and participates in consensus when consulted. The CEO is the user's proxy and operates on an independent trust-based pace.

```mermaid
flowchart TD
    USER(["User"])
    CO["CO"]
    CISO["CISO"]
    CEO["CEO"]
    CTO["CTO"]
    CFO["CFO"]
    COO["COO"]
    CKO["CKO"]

    USER -.->|"floor approvals"| CO
    USER <-->|"executive brief"| CEO
    CISO -->|"security controls"| CO
    CTO -->|"tech standards"| CO
    CFO -->|"cost controls"| CO
    COO -->|"operational controls"| CO
    CKO -->|"knowledge controls"| CO
    CO -.->|"monitors\nautonomy"| CEO

    style USER fill:#90caf9,stroke:#1565c0,color:#1a1a1a
    style CO fill:#ce93d8,stroke:#6a1b9a,color:#1a1a1a
    style CISO fill:#ce93d8,stroke:#6a1b9a,color:#1a1a1a
    style CEO fill:#ce93d8,stroke:#6a1b9a,color:#1a1a1a
    style CTO fill:#ce93d8,stroke:#6a1b9a,color:#1a1a1a
    style CFO fill:#ce93d8,stroke:#6a1b9a,color:#1a1a1a
    style COO fill:#ce93d8,stroke:#6a1b9a,color:#1a1a1a
    style CKO fill:#ce93d8,stroke:#6a1b9a,color:#1a1a1a
```

---

## Leadership + Operational Tier Detail

The leadership triad orchestrates day-to-day delivery. Operational agents execute within the standards set by governance. Specialists are defined per-project.

```mermaid
flowchart TD
    PO["PO"]
    SA["SA"]
    SM["SM"]
    KO["Knowledge Ops"]
    POPS["Platform Ops"]
    CA["Compliance\nAuditor"]
    SPEC(["Specialists\n(you define)"])

    PO -->|"orchestrates"| SPEC
    SA -->|"architecture\nguidance"| SPEC
    SM -->|"triggers\ndistribution"| KO
    PO -->|"dispatches"| CA
    POPS -->|"metrics +\nCI/CD"| SM

    style PO fill:#90caf9,stroke:#1565c0,color:#1a1a1a
    style SA fill:#90caf9,stroke:#1565c0,color:#1a1a1a
    style SM fill:#90caf9,stroke:#1565c0,color:#1a1a1a
    style KO fill:#90caf9,stroke:#1565c0,color:#1a1a1a
    style POPS fill:#90caf9,stroke:#1565c0,color:#1a1a1a
    style CA fill:#ef9a9a,stroke:#b71c1c,color:#1a1a1a
    style SPEC fill:#a5d6a7,stroke:#2e7d32,color:#1a1a1a
```

---

## Governance ↔ Operational Bridge

Governance sets the rules; operations follows them. Data flows up to inform governance decisions. The CO and CKO are the primary bridges.

```mermaid
flowchart LR
    subgraph Gov ["Governance"]
        CX(["Cx Roles"])
    end

    subgraph Bridge ["Bridges"]
        CO_B["CO\n(floor/targets)"]
        CKO_B["CKO\n(knowledge)"]
    end

    subgraph Ops ["Operations"]
        TRIAD(["PO  SA  SM"])
        AGENTS(["Specialists +\nReviewers"])
    end

    CX -->|"floor rules\ntargets\nguidance"| CO_B
    CX -->|"knowledge\nstandards"| CKO_B
    CO_B -->|"controls"| TRIAD
    CKO_B -->|"learnings"| AGENTS
    AGENTS -->|"metrics\nfindings"| CX
    TRIAD -->|"conformance\nreports"| CX

    style CX fill:#ce93d8,stroke:#6a1b9a,color:#1a1a1a
    style CO_B fill:#ce93d8,stroke:#6a1b9a,color:#1a1a1a
    style CKO_B fill:#ce93d8,stroke:#6a1b9a,color:#1a1a1a
    style TRIAD fill:#90caf9,stroke:#1565c0,color:#1a1a1a
    style AGENTS fill:#a5d6a7,stroke:#2e7d32,color:#1a1a1a
```

---

## Worktree Isolation

How agents access code depending on whether the task frontmatter specifies worktree isolation.

```mermaid
flowchart TD
    DISPATCH["Agent Dispatched"] --> CHECK{"isolation: worktree\nin frontmatter?"}

    CHECK -->|"Yes"| WORKTREE["Temp Worktree\n(assess committed code)"]
    CHECK -->|"No"| LIVE["Live Working Tree\n(current state)"]

    WORKTREE --> ASSESS["Agent reads\ncommitted state only"]
    LIVE --> WORK["Agent reads\ncurrent working state"]

    ASSESS --> DONE["Task Runs"]
    WORK --> DONE

    style DISPATCH fill:#bdbdbd,stroke:#424242,color:#1a1a1a
    style CHECK fill:#bdbdbd,stroke:#424242,color:#1a1a1a
    style WORKTREE fill:#90caf9,stroke:#1565c0,color:#1a1a1a
    style LIVE fill:#a5d6a7,stroke:#2e7d32,color:#1a1a1a
    style ASSESS fill:#90caf9,stroke:#1565c0,color:#1a1a1a
    style WORK fill:#a5d6a7,stroke:#2e7d32,color:#1a1a1a
    style DONE fill:#bdbdbd,stroke:#424242,color:#1a1a1a
```

Use worktree isolation when you want a reviewer or auditor agent to assess only committed (stable) code rather than any in-flight edits. Set `isolation: worktree` in the agent task frontmatter.

---

## Work Item Lifecycle

How a backlog item flows through the 9-phase lifecycle.

```mermaid
flowchart LR
    B["1. Groom\n(triad)"] -->|"passes DoR"| P["2. Promote\n(work item)"]
    P --> IP["3. Build\n(specialists)"]
    IP --> RV["4. Review\n(AC + specialists)"]
    RV -->|"rework"| FIX["5. Fix"]
    FIX -->|"re-validate"| IP
    RV -->|"all pass"| DEP["6. Deploy\n(per environment)"]
    DEP -->|"code problem"| FIX
    DEP -->|"env problem"| ENVFIX["Env Fix\n(infra resolves)"]
    ENVFIX -->|"resume"| DEP
    DEP -->|"all envs pass"| ACC["7. Accept"]
    ACC -->|"rejection"| FIX
    ACC --> RET["8. Retro\n(team reflects)"]
    RET --> CHK["9. Checkpoint\n(process health)"]
    CHK -->|"next item"| B

    style B fill:#90caf9,stroke:#1565c0,color:#1a1a1a
    style P fill:#90caf9,stroke:#1565c0,color:#1a1a1a
    style IP fill:#a5d6a7,stroke:#2e7d32,color:#1a1a1a
    style RV fill:#ffcc80,stroke:#e65100,color:#1a1a1a
    style FIX fill:#ef9a9a,stroke:#b71c1c,color:#1a1a1a
    style ENVFIX fill:#ffcc80,stroke:#e65100,color:#1a1a1a
    style DEP fill:#a5d6a7,stroke:#2e7d32,color:#1a1a1a
    style ACC fill:#a5d6a7,stroke:#2e7d32,color:#1a1a1a
    style RET fill:#90caf9,stroke:#1565c0,color:#1a1a1a
    style CHK fill:#bdbdbd,stroke:#424242,color:#1a1a1a
```

Key design decisions:

- **Phase 3: always-working software** -- builders run tests, typecheck, deploy, and validate before handing off
- **Phase 3: no bugs left behind** -- bugs found during build are fixed immediately
- **Phase 3: stop and reassess** -- if a task turns out larger or riskier than scoped, stop and flag it
- **Phase 8 (Retro)** -- all agents reflect; triad evaluates collectively before presenting to user

---

## Pace Control

The fleet operates at a dynamic pace. The scrum master monitors performance and recommends changes.

```mermaid
flowchart LR
    CRAWL["Crawl\nPropose everything\nUser reviews all"] -->|"evidence:\nfew findings,\nclean handoffs"| WALK["Walk\nStandard autonomy\nMilestone reviews"]
    WALK -->|"evidence:\nlow rework,\ngood judgment"| RUN["Run\nExpanded autonomy\nBatch oversight"]
    RUN -->|"evidence:\nproven track record,\nmature memories"| FLY["Fly\nFull autonomy\nFindings-based oversight"]

    FLY -->|"significant\nproblem"| TRIAD
    RUN -->|"significant\nproblem"| TRIAD
    WALK -->|"significant\nmistake"| CRAWL

    TRIAD{"Triad\nconsults"} -->|"high consensus\npace <= current"| AUTO["Inform user\nproceed at pace"]
    TRIAD -->|"high consensus\npace increase"| REC["Unified recommendation\nto user"]
    TRIAD -->|"low consensus"| ESC["Each perspective\nto user decides"]

    style CRAWL fill:#ef9a9a,stroke:#b71c1c,color:#1a1a1a
    style WALK fill:#ffcc80,stroke:#e65100,color:#1a1a1a
    style RUN fill:#90caf9,stroke:#1565c0,color:#1a1a1a
    style FLY fill:#a5d6a7,stroke:#2e7d32,color:#1a1a1a
    style TRIAD fill:#90caf9,stroke:#1565c0,color:#1a1a1a
    style AUTO fill:#a5d6a7,stroke:#2e7d32,color:#1a1a1a
    style REC fill:#a5d6a7,stroke:#2e7d32,color:#1a1a1a
    style ESC fill:#ffcc80,stroke:#e65100,color:#1a1a1a
```

### Autonomy x Pace

How the three autonomy tiers shift as the fleet moves from Crawl to Fly.

```mermaid
flowchart TD
    subgraph CRAWL ["Crawl"]
        C_A["Autonomous\nRead, diagnose,\nresearch"]
        C_P["Propose\nAll builds, edits,\ndeploys, handoffs"]
        C_E["Escalate\nCompliance floor,\narchitectural"]
    end

    subgraph WALK ["Walk"]
        W_A["Autonomous\nWithin-domain routine"]
        W_P["Propose\nCross-domain work,\njudgment calls"]
        W_E["Escalate\nCompliance floor,\nstrategic decisions"]
    end

    subgraph RUN ["Run"]
        R_A["Autonomous\nChains across items,\nroutine deploys"]
        R_P["Propose\nArchitectural changes,\nstrategic direction"]
        R_E["Escalate\nCompliance floor\n(always)"]
    end

    subgraph FLY ["Fly"]
        F_A["Autonomous\nNearly everything,\nbatch oversight"]
        F_P["Propose\nOnly genuinely\nblocked items"]
        F_E["Escalate\nCompliance floor\n(always)"]
    end

    CRAWL -->|"evidence:\nfew findings"| WALK
    WALK -->|"evidence:\nlow rework"| RUN
    RUN -->|"evidence:\nproven record"| FLY

    style C_A fill:#90caf9,stroke:#1565c0,color:#1a1a1a
    style C_P fill:#ffcc80,stroke:#e65100,color:#1a1a1a
    style C_E fill:#ef9a9a,stroke:#b71c1c,color:#1a1a1a
    style W_A fill:#90caf9,stroke:#1565c0,color:#1a1a1a
    style W_P fill:#ffcc80,stroke:#e65100,color:#1a1a1a
    style W_E fill:#ef9a9a,stroke:#b71c1c,color:#1a1a1a
    style R_A fill:#90caf9,stroke:#1565c0,color:#1a1a1a
    style R_P fill:#ffcc80,stroke:#e65100,color:#1a1a1a
    style R_E fill:#ef9a9a,stroke:#b71c1c,color:#1a1a1a
    style F_A fill:#90caf9,stroke:#1565c0,color:#1a1a1a
    style F_P fill:#ffcc80,stroke:#e65100,color:#1a1a1a
    style F_E fill:#ef9a9a,stroke:#b71c1c,color:#1a1a1a
```

**Key insight:** Compliance floor escalation never relaxes regardless of pace. The expanding blue (Autonomous) zone is the primary indicator of trust growth.

---

## Review Dispatch

The PO selectively dispatches reviewers based on what changed.

```mermaid
flowchart TD
    CHANGE["Completed Work"] --> CLASSIFY{"What changed?"}

    CLASSIFY -->|"Backend API,\ndata model"| BACK_REV["backend-specialist\nreviews patterns"]
    CLASSIFY -->|"Compliance-adjacent\ncode"| COMP_REV["security-reviewer\n+ compliance review"]
    CLASSIFY -->|"Frontend UI"| FRONT_REV["frontend-specialist\nreviews patterns"]
    CLASSIFY -->|"Docs changed"| DOC_REV["doc review"]
    CLASSIFY -->|"Small bug fix,\nno compliance surface"| PO_ONLY["PO reviews\ndirectly"]

    BACK_REV --> SYNTH["PO Synthesizes"]
    COMP_REV --> SYNTH
    FRONT_REV --> SYNTH
    DOC_REV --> SYNTH
    PO_ONLY --> SYNTH

    SYNTH --> DECIDE{"Accept?"}
    DECIDE -->|"Yes"| DONE["Done"]
    DECIDE -->|"Revise"| REWORK["Back to specialist"]
    DECIDE -->|"Reject"| REJECT["Requirements mismatch"]

    style CHANGE fill:#a5d6a7,stroke:#2e7d32,color:#1a1a1a
    style DONE fill:#a5d6a7,stroke:#2e7d32,color:#1a1a1a
    style REWORK fill:#ffcc80,stroke:#e65100,color:#1a1a1a
    style REJECT fill:#ef9a9a,stroke:#b71c1c,color:#1a1a1a
    style COMP_REV fill:#ef9a9a,stroke:#b71c1c,color:#1a1a1a
```

---

## Compliance Floor

The compliance floor overrides all other protocol elements. Visualized as a foundation that everything rests on.

```mermaid
flowchart TD
    subgraph Floor ["COMPLIANCE FLOOR (non-negotiable)"]
        S1["Rule 1\n(your domain rule)"]
        S2["Rule 2\n(your domain rule)"]
        S3["Rule 3\n(your domain rule)"]
    end

    PACE["Pace Control"] -.->|"overridden by"| Floor
    AUTO["Autonomy Tiers"] -.->|"overridden by"| Floor
    PRIO["Priority Decisions"] -.->|"overridden by"| Floor

    style S1 fill:#ef9a9a,stroke:#b71c1c,color:#1a1a1a
    style S2 fill:#ef9a9a,stroke:#b71c1c,color:#1a1a1a
    style S3 fill:#ef9a9a,stroke:#b71c1c,color:#1a1a1a
```

Define your compliance floor in `compliance-floor.md` at the project root. See `templates/compliance-floor.md` for a starting template.

---

## Learning Loop

How the fleet improves over time through evidence-based refinement.

```mermaid
flowchart TD
    WORK["Agents Work"] -->|"encounter\nnotable event"| FINDING["Write Finding\nto register"]
    FINDING --> REG[".claude/findings/register.md"]
    REG -->|"SM review"| CURATE["SM Curates\ngroups + proposes"]
    CURATE --> REVIEW["User Reviews\nAccept / Modify / Defer"]
    REVIEW -->|"accepted"| APPLY["Apply Refinement\nprompt, memory, or protocol"]
    APPLY -->|"knowledge-ops\ndistributes"| DISTRIBUTE["Update Agent\nMemories"]
    DISTRIBUTE --> WORK

    REVIEW -->|"deferred"| REG
    REVIEW -->|"dismissed"| ARCHIVE["Remove from\nactive register"]

    style WORK fill:#a5d6a7,stroke:#2e7d32,color:#1a1a1a
    style FINDING fill:#ffcc80,stroke:#e65100,color:#1a1a1a
    style CURATE fill:#90caf9,stroke:#1565c0,color:#1a1a1a
    style REVIEW fill:#90caf9,stroke:#1565c0,color:#1a1a1a
    style APPLY fill:#a5d6a7,stroke:#2e7d32,color:#1a1a1a
    style DISTRIBUTE fill:#a5d6a7,stroke:#2e7d32,color:#1a1a1a
```

---

## Model Selection Decision Tree

Decision tree for choosing the right model tier and thinking budget.

```mermaid
flowchart TD
    START["New Task"] --> Q1{"Requires synthesis,\ntradeoff, or judgment?"}
    Q1 -->|"Yes"| OPUS["Expensive model\n(medium thinking)"]
    Q1 -->|"No"| Q2{"Structured work\nwith clear patterns?"}
    Q2 -->|"Yes"| SONNET["Mid-tier model\n(low thinking)"]
    Q2 -->|"No"| Q3{"Mechanical check?"}
    Q3 -->|"Yes"| HAIKU["Cheap model\n(no thinking)"]
    Q3 -->|"No"| RECLASS["Re-examine task scope"]
    RECLASS --> Q1

    OPUS --> CEILING{"Hit thinking\nceiling?"}
    SONNET --> CEILING
    CEILING -->|"Yes"| FIND["Finding:\ntask mis-classified or\ncontext needs enriching"]
    CEILING -->|"No"| DONE["Proceed"]

    style START fill:#ffcc80,stroke:#e65100,color:#1a1a1a
    style Q1 fill:#ffcc80,stroke:#e65100,color:#1a1a1a
    style Q2 fill:#ffcc80,stroke:#e65100,color:#1a1a1a
    style Q3 fill:#ffcc80,stroke:#e65100,color:#1a1a1a
    style OPUS fill:#a5d6a7,stroke:#2e7d32,color:#1a1a1a
    style SONNET fill:#a5d6a7,stroke:#2e7d32,color:#1a1a1a
    style HAIKU fill:#a5d6a7,stroke:#2e7d32,color:#1a1a1a
    style DONE fill:#a5d6a7,stroke:#2e7d32,color:#1a1a1a
    style CEILING fill:#ffcc80,stroke:#e65100,color:#1a1a1a
    style FIND fill:#ef9a9a,stroke:#b71c1c,color:#1a1a1a
    style RECLASS fill:#bdbdbd,stroke:#424242,color:#1a1a1a
```

---

## Delivery Metrics (DORA + Flow Quality)

How the fleet measures and improves delivery performance.

```mermaid
flowchart LR
    subgraph Events ["Event Logging"]
        LOG["ops/metrics-log.sh\n(agents log events)"]
        JSONL[".claude/metrics/events.jsonl\n(append-only)"]
    end

    subgraph Dashboard ["Dashboard"]
        DORA["ops/dora.sh\nDORA metrics"]
        FLOW["ops/dora.sh --flow\nFlow quality"]
    end

    subgraph Decisions ["Decisions"]
        SM_PACE["SM recommends\npace change"]
        PO_PRI["PO adjusts\npriorities"]
    end

    LOG --> JSONL
    JSONL --> DORA
    JSONL --> FLOW
    DORA -->|"CFR, lead time,\ndeploy frequency"| SM_PACE
    FLOW -->|"FPY, handoff quality,\nrework rate"| SM_PACE
    FLOW -->|"bug severity trends,\nbottlenecks"| PO_PRI

    style LOG fill:#a5d6a7,stroke:#2e7d32,color:#1a1a1a
    style JSONL fill:#bdbdbd,stroke:#424242,color:#1a1a1a
    style DORA fill:#90caf9,stroke:#1565c0,color:#1a1a1a
    style FLOW fill:#90caf9,stroke:#1565c0,color:#1a1a1a
    style SM_PACE fill:#ffcc80,stroke:#e65100,color:#1a1a1a
    style PO_PRI fill:#ffcc80,stroke:#e65100,color:#1a1a1a
```

Key events tracked: `item-promoted`, `item-accepted`, `ext-deployed`, `bug-found`, `bug-fixed`, `handoff-sent`, `handoff-rejected`, `task-restarted`, `task-blocked`, `task-unblocked`, `regression-run`. Pace thresholds: CFR < 10% to Walk; < 5% to Run.

---

## Leadership Triad

The PO, SA, and SM form a servant leadership triad.

```mermaid
flowchart TD
    subgraph Triad ["Leadership Triad (Servant Leaders)"]
        PO_T(["PO\nBusiness priority\nAC, WSJF"])
        SA_T(["SA\nTechnical approach\nNFRs, constraints"])
        SM_T(["SM\nProcess flow\nPace, coordination"])

        PO_T <-->|"groom\nalign"| SA_T
        SA_T <-->|"sequence\nvalidate"| SM_T
        PO_T <-->|"prioritize\nright-size"| SM_T
    end

    subgraph Team ["Specialists (Empowered to Decide)"]
        SP1["specialist-1"]
        SP2["specialist-2"]
        SP3["specialist-N"]
    end

    Triad -->|"rich context:\nbusiness + technical\n+ process"| Team
    Team -->|"good autonomous\ndecisions"| SUCCESS["SUCCESS:\nServant leadership working"]
    Team -->|"frequent questions"| ENRICH["SIGNAL:\nEnrich the context"]
    ENRICH --> Triad

    style PO_T fill:#90caf9,stroke:#1565c0,color:#1a1a1a
    style SA_T fill:#90caf9,stroke:#1565c0,color:#1a1a1a
    style SM_T fill:#90caf9,stroke:#1565c0,color:#1a1a1a
    style SUCCESS fill:#a5d6a7,stroke:#2e7d32,color:#1a1a1a
    style ENRICH fill:#ffcc80,stroke:#e65100,color:#1a1a1a
```

| Activity           | PO Leads               | SA Contributes              | SM Contributes             |
| ------------------ | ---------------------- | --------------------------- | -------------------------- |
| Grooming           | Business priority, AC  | Architectural implications  | Right-sizing for pace      |
| Solution alignment | Validates business     | Proposes technical approach | Checks process feasibility |
| Work organization  | Prioritizes items      | Sequences by dependencies   | Coordinates execution mode |
| Quality            | Functional correctness | Architectural soundness     | Process discipline         |

---

## Agent Inheritance

How app-level agents extend harness agents. The merge produces the runtime agent definition.

```mermaid
flowchart LR
    subgraph Harness ["Harness Agent"]
        H_NAME["name: scrum-master"]
        H_MODEL["model: opus"]
        H_PROTO["protocol: full"]
        H_AUTO["autonomy: default"]
    end

    subgraph App ["App Agent (extends)"]
        A_RETRO["retro cadence: 2"]
        A_AUTO["autonomy: override"]
    end

    subgraph Merged ["Runtime Agent"]
        M_NAME["name: scrum-master"]
        M_MODEL["model: opus"]
        M_PROTO["protocol: full"]
        M_RETRO["retro cadence: 2"]
        M_AUTO["autonomy: override"]
    end

    Harness -->|"base fields\npreserved"| Merged
    App -->|"app fields\noverride"| Merged

    style H_NAME fill:#90caf9,stroke:#1565c0,color:#1a1a1a
    style H_MODEL fill:#90caf9,stroke:#1565c0,color:#1a1a1a
    style H_PROTO fill:#90caf9,stroke:#1565c0,color:#1a1a1a
    style H_AUTO fill:#90caf9,stroke:#1565c0,color:#1a1a1a
    style A_RETRO fill:#ffcc80,stroke:#e65100,color:#1a1a1a
    style A_AUTO fill:#ffcc80,stroke:#e65100,color:#1a1a1a
    style M_NAME fill:#90caf9,stroke:#1565c0,color:#1a1a1a
    style M_MODEL fill:#90caf9,stroke:#1565c0,color:#1a1a1a
    style M_PROTO fill:#90caf9,stroke:#1565c0,color:#1a1a1a
    style M_RETRO fill:#a5d6a7,stroke:#2e7d32,color:#1a1a1a
    style M_AUTO fill:#a5d6a7,stroke:#2e7d32,color:#1a1a1a
```

**Merge rules:** App fields (orange) override matching harness fields. Harness fields (blue) not mentioned in the app definition are preserved. Green fields in the merged result show where overrides landed.

---

## Memory Architecture

Two memory layers with distinct ownership. Knowledge-ops curates both (under CKO direction) and bridges them.

```mermaid
flowchart TD
    subgraph HarnessLayer ["memory/harness/ (read-only)"]
        HL["Framework learnings\nCollaboration patterns\nTool usage insights"]
    end

    subgraph AppLayer ["memory/app/ (read-write)"]
        AL["Domain learnings\nProject decisions\nEnvironment quirks"]
    end

    AGENTS(["Any Agent"]) -->|"write during work"| AppLayer
    KO(["Knowledge Ops"]) -->|"curate, dedupe,\nresolve conflicts"| AppLayer
    KO -->|"curate on\nharness upgrade"| HarnessLayer

    AppLayer -.->|"generic pattern?\nflag for promotion"| HarnessLayer

    AGENTS -->|"read"| HarnessLayer
    AGENTS -->|"read"| AppLayer

    style HL fill:#90caf9,stroke:#1565c0,color:#1a1a1a
    style AL fill:#a5d6a7,stroke:#2e7d32,color:#1a1a1a
    style AGENTS fill:#bdbdbd,stroke:#424242,color:#1a1a1a
    style KO fill:#90caf9,stroke:#1565c0,color:#1a1a1a
```

**Key constraint:** harness/ is read-only during normal operation. Only updated on harness version changes. app/ is where active learning accumulates.

---

## Handoff Protocol

How work transfers between agents with quality tracking.

```mermaid
sequenceDiagram
    participant A as Agent A
    participant H as Handoff Artifact
    participant B as Agent B
    participant M as Metrics

    A->>H: What done, what needed,<br/>context, artifacts, urgency
    A->>M: log handoff-sent
    H->>B: Receive handoff

    alt Clear enough to act
        B->>B: Execute work
        B->>A: Handoff Complete<br/>(result, artifacts, follow-up)
        B->>M: log handoff-accepted
    else Unclear handoff
        B->>A: Reject with reason
        B->>M: log handoff-rejected
        Note over A,B: Finding: unclear handoff<br/>FPY decreases
    end
```

The receiving agent should be able to act without asking for clarification. FPY (first-pass yield) by boundary pair is the most actionable metric for handoff quality.

---

## Coordination Layers

Working state (ephemeral) and published view (version-controlled) serve different purposes.

```mermaid
flowchart TD
    subgraph Working ["Working State (Tasks)"]
        FIND["Findings"]
        HAND["Handoffs"]
        WIP["WIP Status"]
        BLOCK["Blockers"]
    end

    subgraph Published ["Published View (Files)"]
        PROG["User-facing progress"]
        DECS["Documented decisions"]
        ROAD["Roadmap / backlog"]
        GOV["Governance records"]
    end

    Working -->|"at checkpoints,\nagent publishes"| Published

    USER(["Human Operator"]) -->|"reads"| Published
    USER -.->|"rarely needs"| Working

    style FIND fill:#ffcc80,stroke:#e65100,color:#1a1a1a
    style HAND fill:#ffcc80,stroke:#e65100,color:#1a1a1a
    style WIP fill:#ffcc80,stroke:#e65100,color:#1a1a1a
    style BLOCK fill:#ffcc80,stroke:#e65100,color:#1a1a1a
    style PROG fill:#a5d6a7,stroke:#2e7d32,color:#1a1a1a
    style DECS fill:#a5d6a7,stroke:#2e7d32,color:#1a1a1a
    style ROAD fill:#a5d6a7,stroke:#2e7d32,color:#1a1a1a
    style GOV fill:#a5d6a7,stroke:#2e7d32,color:#1a1a1a
    style USER fill:#90caf9,stroke:#1565c0,color:#1a1a1a
```

**Why this split:** Tasks handle concurrent work without write contention. Files stay clean and curated. The user sees checkpointed progress, not coordination noise.

---

## Enforcement Layers

Three enforcement mechanisms from cheapest to most thorough.

```mermaid
flowchart TD
    subgraph Hooks ["Layer 1: Hooks"]
        HK["Shell scripts\non tool events"]
        HK_C["Cost: zero tokens"]
        HK_R["Reliability: deterministic"]
    end

    subgraph Memory ["Layer 2: Memory"]
        MEM["Persisted behavioral\nrules + context"]
        MEM_C["Cost: tokens on recall"]
        MEM_R["Reliability: probabilistic"]
    end

    subgraph Skills ["Layer 3: Skills"]
        SK["Loaded prompts with\nmandatory steps"]
        SK_C["Cost: tokens on load"]
        SK_R["Reliability: high"]
    end

    EVENT["Tool Event"] --> Hooks
    Hooks -->|"pass"| Memory
    Memory -->|"guides"| Skills

    style HK fill:#a5d6a7,stroke:#2e7d32,color:#1a1a1a
    style HK_C fill:#a5d6a7,stroke:#2e7d32,color:#1a1a1a
    style HK_R fill:#a5d6a7,stroke:#2e7d32,color:#1a1a1a
    style MEM fill:#ffcc80,stroke:#e65100,color:#1a1a1a
    style MEM_C fill:#ffcc80,stroke:#e65100,color:#1a1a1a
    style MEM_R fill:#ffcc80,stroke:#e65100,color:#1a1a1a
    style SK fill:#90caf9,stroke:#1565c0,color:#1a1a1a
    style SK_C fill:#90caf9,stroke:#1565c0,color:#1a1a1a
    style SK_R fill:#90caf9,stroke:#1565c0,color:#1a1a1a
    style EVENT fill:#bdbdbd,stroke:#424242,color:#1a1a1a
```

**When to use each:** Hooks for file-level guards and formatting (deterministic, free). Memory for cross-session behavioral guidance (probabilistic, cheap). Skills for complex multi-step workflows (reliable, most expensive).

---

## Conflict Resolution

How disagreements are routed to the right mediator.

```mermaid
flowchart TD
    CONFLICT{"Agents\ndisagree"} -->|"technical"| SA["SA mediates"]
    CONFLICT -->|"priority"| PO["PO decides"]
    CONFLICT -->|"process"| SM["SM mediates"]
    CONFLICT -->|"compliance"| FLOOR["Compliance floor\nwins (always)"]
    CONFLICT -->|"cross-domain"| JOINT["SA + PO\njointly"]

    SA -->|"unresolved"| USER(["User decides"])
    PO -->|"unresolved"| USER
    SM -->|"unresolved"| USER
    JOINT -->|"unresolved"| USER

    style CONFLICT fill:#ffcc80,stroke:#e65100,color:#1a1a1a
    style SA fill:#90caf9,stroke:#1565c0,color:#1a1a1a
    style PO fill:#90caf9,stroke:#1565c0,color:#1a1a1a
    style SM fill:#90caf9,stroke:#1565c0,color:#1a1a1a
    style FLOOR fill:#ef9a9a,stroke:#b71c1c,color:#1a1a1a
    style JOINT fill:#90caf9,stroke:#1565c0,color:#1a1a1a
    style USER fill:#90caf9,stroke:#1565c0,color:#1a1a1a
```

No agent overrides another agent's domain authority. Compliance floor takes precedence over all other disagreements without escalation.

---

## Regression Testing

Periodic validation cycle with cadence tuning.

```mermaid
flowchart LR
    COUNT["SM tracks\naccepted items"] -->|"every 3\n(tunable)"| TRIGGER["Trigger\nregression run"]

    TRIGGER --> BACK["Backend\nAPI, data, schema"]
    TRIGGER --> FRONT["Frontend\nUI, state, render"]
    TRIGGER --> E2E["Browser E2E\nAll roles, screenshots"]

    BACK --> FINDINGS["Regression\nfindings"]
    FRONT --> FINDINGS
    E2E --> FINDINGS

    FINDINGS -->|"add to backlog\n(do NOT fix inline)"| BACKLOG["PO prioritizes\nfixes"]
    FINDINGS -.->|"data informs"| TUNE{"Adjust\ncadence?"}
    TUNE -->|"regressions rare"| LESS["Extend to 5"]
    TUNE -->|"regressions frequent"| MORE["Tighten to 2"]

    style COUNT fill:#90caf9,stroke:#1565c0,color:#1a1a1a
    style TRIGGER fill:#ffcc80,stroke:#e65100,color:#1a1a1a
    style BACK fill:#a5d6a7,stroke:#2e7d32,color:#1a1a1a
    style FRONT fill:#a5d6a7,stroke:#2e7d32,color:#1a1a1a
    style E2E fill:#a5d6a7,stroke:#2e7d32,color:#1a1a1a
    style FINDINGS fill:#ef9a9a,stroke:#b71c1c,color:#1a1a1a
    style BACKLOG fill:#90caf9,stroke:#1565c0,color:#1a1a1a
    style TUNE fill:#ffcc80,stroke:#e65100,color:#1a1a1a
    style LESS fill:#bdbdbd,stroke:#424242,color:#1a1a1a
    style MORE fill:#bdbdbd,stroke:#424242,color:#1a1a1a
```

**Fix discipline:** Do not fix issues inline during regression testing. Record them as findings. Only fix roadblocks that prevent completing remaining tests.

---

## Budget & Resource Flow

How cost responsibility flows through the fleet.

```mermaid
flowchart LR
    PO_B(["Platform-ops\nmeasures costs"]) -->|"per item,\nper agent"| ALERT["Alert at\nthresholds"]
    SA_B(["SA estimates\nper-item budget"]) -->|"during grooming"| BUDGET["Item budget\n(NFR)"]
    ALERT -->|"push to"| SM_B(["SM decides\non overruns"])
    BUDGET --> SM_B
    SM_B -->|"pause, shift\nmodels, extend"| ACTION["Adjustment"]
    USER_B(["User sets\nbudget envelope"]) -.->|"total\ninvestment"| SM_B

    style PO_B fill:#90caf9,stroke:#1565c0,color:#1a1a1a
    style SA_B fill:#90caf9,stroke:#1565c0,color:#1a1a1a
    style SM_B fill:#ffcc80,stroke:#e65100,color:#1a1a1a
    style ALERT fill:#ef9a9a,stroke:#b71c1c,color:#1a1a1a
    style BUDGET fill:#bdbdbd,stroke:#424242,color:#1a1a1a
    style ACTION fill:#a5d6a7,stroke:#2e7d32,color:#1a1a1a
    style USER_B fill:#90caf9,stroke:#1565c0,color:#1a1a1a
```

**Monitoring rule:** If expensive model usage exceeds 40% of total dispatches, investigate whether some judgment tasks could be downgraded with better context enrichment.

---

## Milestone Release

Parallel dispatch to output agents when a batch of items reaches acceptance.

```mermaid
flowchart TD
    DECLARE["PO declares milestone\nversion tag + scope"] --> DISPATCH

    subgraph DISPATCH ["Parallel Dispatch (no dependencies)"]
        DOC["doc-quality\nChangelog, release notes"]
        TRAIN["training-enablement\nUser guides, walkthroughs"]
        COMMS["stakeholder-comms\nAnnouncements, demos"]
    end

    DOC --> TRACK["PO tracks\ncompletion"]
    TRAIN --> TRACK
    COMMS --> TRACK

    TRACK --> TAG["Version archive\ngit tag"]

    style DECLARE fill:#90caf9,stroke:#1565c0,color:#1a1a1a
    style DOC fill:#a5d6a7,stroke:#2e7d32,color:#1a1a1a
    style TRAIN fill:#a5d6a7,stroke:#2e7d32,color:#1a1a1a
    style COMMS fill:#a5d6a7,stroke:#2e7d32,color:#1a1a1a
    style TRACK fill:#ffcc80,stroke:#e65100,color:#1a1a1a
    style TAG fill:#bdbdbd,stroke:#424242,color:#1a1a1a
```

Output agents work independently from accepted items and current documentation. If one is blocked, the others continue.
