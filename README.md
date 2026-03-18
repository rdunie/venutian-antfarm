# Venutian Antfarm

[![License](https://img.shields.io/badge/License-Apache_2.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)

An agent fleet harness framework for structured multi-agent software delivery with progressive autonomy, evidence-based governance, and measurable quality control. Clone it, define your compliance floor, add your specialist agents, and start delivering with a governed fleet.

## Quick Start

```bash
# 1. Clone the template
git clone https://github.com/your-org/venutian-antfarm.git my-project
cd my-project

# 2. Define your compliance floor
cp templates/compliance-floor.md compliance-floor.md
# Edit compliance-floor.md with your domain's non-negotiable rules

# 3. Add your specialist agents
cp templates/agents/frontend-specialist.md .claude/agents/frontend-specialist.md
cp templates/agents/backend-specialist.md .claude/agents/backend-specialist.md
# Edit each to match your tech stack

# 4. Configure your fleet
cp templates/fleet-config.json fleet-config.json
# Edit fleet-config.json (metrics backend, deploy command, etc.)

# 5. Start working
# Open Claude Code in your project directory. The 5 core agents
# (product-owner, solution-architect, scrum-master, memory-manager,
# platform-ops) are ready. Your specialists extend them.
```

## Architecture

```
                    +------------------+
                    |  Human Operator  |
                    +--------+---------+
                             |
                    evidence-based oversight
                             |
              +--------------+--------------+
              |     Leadership Triad        |
              |  PO  +  SA  +  SM           |
              |  (value) (tech) (process)   |
              +--------------+--------------+
                     |               |
              context/coaching    risk signals
                     |               |
         +-----------+---+   +------+--------+
         | Execution     |   | Review        |
         | Specialists   |<->| Agents        |
         | (build)       |   | (validate)    |
         +-------+-------+   +------+--------+
                 |                    |
          +------+------+            |
          | Output      |<-----------+
          | Agents      | corrections/accuracy review
          | (publish)   +----------->+
          +-------------+  content for review

  Harness Layer (this framework):
    - Leadership triad (PO, SA, SM)
    - Memory manager, Platform ops
    - Collaboration protocol, pace control
    - Metrics pipeline (DORA + flow quality)
    - Enforcement hooks

  App Layer (you define):
    - Specialist agents (extends harness agents)
    - Compliance floor (your domain rules)
    - Deploy contract (your deployment logic)
    - Domain-specific review agents
```

## What You Get

**5 core agents** that govern any software project:

| Agent                  | Role                 | What It Does                                                        |
| ---------------------- | -------------------- | ------------------------------------------------------------------- |
| **product-owner**      | Business context     | Backlog management, prioritization (WSJF), acceptance, quality gate |
| **solution-architect** | Technical context    | NFRs, architecture decisions, cross-system coherence                |
| **scrum-master**       | Process facilitation | Pace control, findings reviews, conflict resolution, retros         |
| **memory-manager**     | Knowledge quality    | Memory consistency, learning distribution, stale detection          |
| **platform-ops**       | Dev platform         | DORA metrics, CI/CD, cross-environment visibility                   |

**Progressive autonomy** (Crawl / Walk / Run / Fly) with evidence-based transitions.

**DORA + flow quality metrics** out of the box, with a pluggable backend (JSONL default, webhook/StatsD/OpenTelemetry configurable).

**Agent inheritance** so your app-specific agents extend the harness agents, keeping the core protocol while adding domain knowledge.

## Key Concepts

- **Compliance Floor**: Non-negotiable rules that override all autonomy tiers and pace settings. Encompasses security, data governance, audit, regulatory, access control, and domain-specific controls. You define yours.
- **Progressive Autonomy**: Four pace levels (Crawl/Walk/Run/Fly) with evidence-based transitions. Every fleet starts at Crawl.
- **Findings Loop**: Structured learning where agents record notable events, the SM curates refinements, and the same finding type should decrease over time.
- **Agent Inheritance**: App agents `extend` harness agents. App fields override; unmentioned harness fields are preserved.

## Documentation

- **[Getting Started](docs/GETTING-STARTED.md)** -- Step-by-step onboarding guide
- **[Agent Fleet Pattern](docs/AGENT-FLEET-PATTERN.md)** -- The full pattern specification
- **[Collaboration Protocol](.claude/COLLABORATION.md)** -- How agents work together
- **[Collaboration Model](docs/COLLABORATION-MODEL.md)** -- Visual diagrams
- **[Example App](example/)** -- Working example with 2 specialist agents

## License

Apache 2.0. See [LICENSE](LICENSE).
