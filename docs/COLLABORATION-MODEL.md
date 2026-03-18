# Agent Collaboration Model

Visual guide to how the agent fleet collaborates. Source of truth for collaboration rules: `.claude/COLLABORATION.md`. Source of truth for documentation style: `.claude/DOCUMENTATION-STYLE.md`.

---

## Fleet Structure

Four organizational layers with distinct responsibilities. Solid lines show primary work-product flow. Dotted lines show feedback and advisory flows.

```mermaid
flowchart TD
    S(["Strategic\nPO  SA  SM"])
    E(["Execution\nSpecialist agents\n(you define)"])
    R(["Reviewers\nsecurity  memory\n(you define)"])
    O(["Output\ndoc  training\n(you define)"])

    S -->|"context"| E
    S -.->|"arch/process"| R
    E -->|"work"| R
    R -.->|"findings"| E
    R -.->|"risk signals"| S
    E -->|"milestone"| O
    R -.->|"corrections"| O
    O -.->|"content"| R

    style S fill:#bbdefb,stroke:#1976D2
    style E fill:#e8f5e9,stroke:#4CAF50
    style R fill:#fce4ec,stroke:#C62828
    style O fill:#fff3e0,stroke:#F57C00
```

**Diamond layout**: Strategic at top feeds both Execution (context) and Reviewers (architecture/process). Execution and Reviewers interact laterally (work and findings). Both feed down to Output (milestones and corrections). Feedback flows back up (risk signals, content for review).

---

## Work Item Lifecycle

How a backlog item flows through the 9-phase lifecycle.

```mermaid
flowchart LR
    B["1. Groom\n(triad)"] -->|"passes DoR"| P["2. Promote\n(work item)"]
    P --> IP["3. Build\n(specialists)"]
    IP --> RV["4. Review\n(AC + specialists)"]
    RV -->|"rework"| FIX["5. Fix"]
    FIX --> RV
    RV -->|"all pass"| DEP["6. Deploy"]
    DEP -->|"validation fail"| FIX
    DEP -->|"all green"| ACC["7. Accept\n(Done)"]
    ACC --> RET["8. Retro\n(team reflects)"]
    RET --> CHK["9. Checkpoint\n(process health)"]
    CHK -->|"next item"| B

    style B fill:#bbdefb,stroke:#1976D2
    style P fill:#bbdefb,stroke:#1976D2
    style IP fill:#e8f5e9,stroke:#4CAF50
    style RV fill:#fff3e0,stroke:#F57C00
    style FIX fill:#fce4ec,stroke:#C62828
    style DEP fill:#e8f5e9,stroke:#4CAF50
    style ACC fill:#e8f5e9,stroke:#4CAF50
    style RET fill:#bbdefb,stroke:#1976D2
    style CHK fill:#f5f5f5,stroke:#666
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

    style CRAWL fill:#fce4ec,stroke:#C62828
    style WALK fill:#fff3e0,stroke:#F57C00
    style RUN fill:#bbdefb,stroke:#1976D2
    style FLY fill:#e8f5e9,stroke:#4CAF50
    style TRIAD fill:#bbdefb,stroke:#1976D2
    style AUTO fill:#e8f5e9,stroke:#4CAF50
    style REC fill:#e8f5e9,stroke:#4CAF50
    style ESC fill:#fff3e0,stroke:#F57C00
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

    style C_A fill:#bbdefb,stroke:#1976D2
    style C_P fill:#fff3e0,stroke:#F57C00
    style C_E fill:#fce4ec,stroke:#C62828
    style W_A fill:#bbdefb,stroke:#1976D2
    style W_P fill:#fff3e0,stroke:#F57C00
    style W_E fill:#fce4ec,stroke:#C62828
    style R_A fill:#bbdefb,stroke:#1976D2
    style R_P fill:#fff3e0,stroke:#F57C00
    style R_E fill:#fce4ec,stroke:#C62828
    style F_A fill:#bbdefb,stroke:#1976D2
    style F_P fill:#fff3e0,stroke:#F57C00
    style F_E fill:#fce4ec,stroke:#C62828
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

    style CHANGE fill:#e8f5e9,stroke:#4CAF50
    style DONE fill:#e8f5e9,stroke:#4CAF50
    style REWORK fill:#fff3e0,stroke:#F57C00
    style REJECT fill:#fce4ec,stroke:#C62828
    style COMP_REV fill:#fce4ec,stroke:#C62828
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

    style S1 fill:#fce4ec,stroke:#C62828
    style S2 fill:#fce4ec,stroke:#C62828
    style S3 fill:#fce4ec,stroke:#C62828
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
    APPLY -->|"memory-manager\ndistributes"| DISTRIBUTE["Update Agent\nMemories"]
    DISTRIBUTE --> WORK

    REVIEW -->|"deferred"| REG
    REVIEW -->|"dismissed"| ARCHIVE["Remove from\nactive register"]

    style WORK fill:#e8f5e9,stroke:#4CAF50
    style FINDING fill:#fff3e0,stroke:#F57C00
    style CURATE fill:#bbdefb,stroke:#1976D2
    style REVIEW fill:#bbdefb,stroke:#1976D2
    style APPLY fill:#e8f5e9,stroke:#4CAF50
    style DISTRIBUTE fill:#e8f5e9,stroke:#4CAF50
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

    style START fill:#fff3e0,stroke:#F57C00
    style Q1 fill:#fff3e0,stroke:#F57C00
    style Q2 fill:#fff3e0,stroke:#F57C00
    style Q3 fill:#fff3e0,stroke:#F57C00
    style OPUS fill:#e8f5e9,stroke:#4CAF50
    style SONNET fill:#e8f5e9,stroke:#4CAF50
    style HAIKU fill:#e8f5e9,stroke:#4CAF50
    style DONE fill:#e8f5e9,stroke:#4CAF50
    style CEILING fill:#fff3e0,stroke:#F57C00
    style FIND fill:#fce4ec,stroke:#C62828
    style RECLASS fill:#f5f5f5,stroke:#666
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

    style LOG fill:#e8f5e9,stroke:#4CAF50
    style JSONL fill:#f5f5f5,stroke:#666
    style DORA fill:#bbdefb,stroke:#1976D2
    style FLOW fill:#bbdefb,stroke:#1976D2
    style SM_PACE fill:#fff3e0,stroke:#F57C00
    style PO_PRI fill:#fff3e0,stroke:#F57C00
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

    style PO_T fill:#bbdefb,stroke:#1976D2
    style SA_T fill:#bbdefb,stroke:#1976D2
    style SM_T fill:#bbdefb,stroke:#1976D2
    style SUCCESS fill:#e8f5e9,stroke:#4CAF50
    style ENRICH fill:#fff3e0,stroke:#F57C00
```

| Activity           | PO Leads              | SA Contributes                 | SM Contributes                 |
| ------------------ | --------------------- | ------------------------------ | ------------------------------ |
| Grooming           | Business priority, AC | Architectural implications     | Right-sizing for pace          |
| Solution alignment | Validates business    | Proposes technical approach    | Checks process feasibility     |
| Work organization  | Prioritizes items     | Sequences by dependencies      | Coordinates execution mode     |
| Quality            | Functional correctness| Architectural soundness        | Process discipline             |
