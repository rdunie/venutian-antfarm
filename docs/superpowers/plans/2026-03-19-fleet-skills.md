# Fleet Skills Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add 6 new skills (`/handoff`, `/deploy`, `/findings`, `/audit`, `/pace`, `/memory`) to the harness framework, covering the recurring tasks that agent fleet personas need across the work item lifecycle.

**Architecture:** Each skill is a standalone SKILL.md in `.claude/skills/<name>/`. Skills follow the same pattern as existing `/po`, `/retro`, and `/onboard` — frontmatter with metadata, usage docs, subcommand routing, model tiering where appropriate, and step-by-step workflow. All skills delegate to existing agents and `ops/` tooling. Skills are overridable by implementers who create the same skill name in their project.

**Tech Stack:** Markdown (SKILL.md files), Bash (ops/ scripts for event logging), existing agent definitions.

**Design Principles:**

- Skills are thin orchestration layers — they dispatch agents and call `ops/` scripts, not implement logic directly
- Each skill logs metrics events via `ops/metrics-log.sh` where applicable
- Skills reference COLLABORATION.md protocol sections rather than duplicating them
- Implementers override by creating `.claude/skills/<name>/SKILL.md` in their project (Claude Code resolves project-level skills first)

**Note on skill file format:** Each SKILL.md uses YAML frontmatter (`name`, `description`, `argument-hint`) followed by markdown content. Study `.claude/skills/po/SKILL.md` and `.claude/skills/retro/SKILL.md` for the exact pattern before writing any new skill.

---

## File Structure

| File                               | Responsibility                                               |
| ---------------------------------- | ------------------------------------------------------------ |
| `.claude/skills/handoff/SKILL.md`  | Structured agent-to-agent handoff orchestration              |
| `.claude/skills/deploy/SKILL.md`   | Deployment workflow with pre/post validation                 |
| `.claude/skills/findings/SKILL.md` | Findings register management (log, review, triage, patterns) |
| `.claude/skills/audit/SKILL.md`    | Compliance audit dispatch                                    |
| `.claude/skills/pace/SKILL.md`     | Pace control dashboard and transitions                       |
| `.claude/skills/memory/SKILL.md`   | Memory management operations                                 |
| `README.md`                        | Updated documentation section listing new skills             |

No new agents, scripts, or config files are created. All skills compose existing infrastructure.

---

## Task 1: `/handoff` Skill

**Files:**

- Create: `.claude/skills/handoff/SKILL.md`

This is the highest-impact skill. It standardizes the governance backbone — the handoff protocol from COLLABORATION.md § Handoff Protocol.

- [ ] **Step 1: Read existing skill patterns**

Read `.claude/skills/po/SKILL.md` and `.claude/skills/retro/SKILL.md` to understand the frontmatter and body structure.

- [ ] **Step 2: Create the skill directory**

Run: `mkdir -p .claude/skills/handoff`

- [ ] **Step 3: Write the skill file**

Create `.claude/skills/handoff/SKILL.md` with the following structure:

**Frontmatter:**

- `name: handoff`
- `description: "Structured agent-to-agent handoff. Validates artifact, logs metrics event, dispatches receiving agent."`
- `argument-hint: "<item> --from <agent> --to <agent> [--urgency blocking|non-blocking]"`

**Body — heading:** `# Handoff`

**Body — intro:** Reference `.claude/COLLABORATION.md` § Handoff Protocol.

**Body — Usage section** with three examples:

- `/handoff 42 --from backend-specialist --to security-reviewer` -- Send a handoff
- `/handoff 42 --from backend-specialist --to security-reviewer --urgency blocking` -- Blocking handoff
- `/handoff complete 42 --from security-reviewer --to backend-specialist` -- Complete a handoff

**Body — Workflow: Send** (6 steps):

1. **Parse arguments.** Extract item ID, from-agent, to-agent, and urgency (default: non-blocking).
2. **Build the handoff artifact.** Prompt the sending agent (--from) to produce a handoff using the COLLABORATION.md format with fields: Handoff header, What was done, What's needed, Context, Artifacts, Urgency.
3. **Validate the artifact.** Check that all required fields are present. If any are missing, prompt the sending agent to fill them in. A handoff where the receiving agent would need to ask for clarification is a finding.
4. **Log the event.** Run: `ops/metrics-log.sh handoff-sent <item> --from <from-agent> --to <to-agent>`
5. **Dispatch the receiving agent.** Send the handoff artifact to the receiving agent (--to) with instructions to act on the request.
6. **Capture outcome.** After the receiving agent completes, determine: accepted or rejected. If rejected, log: `ops/metrics-log.sh handoff-rejected <item> --from <from-agent> --to <to-agent>`. Record the rejection reason as a finding if it indicates a pattern.

**Body — Workflow: Complete** (3 steps):

1. **Parse arguments.** Extract item ID, from-agent (the agent completing the handoff), to-agent (the original sender).
2. **Build the completion artifact.** Prompt the completing agent to produce a Handoff Complete artifact using the COLLABORATION.md § Handoff Completion format with fields: Handoff Complete header, What was done, Result (success/partial/blocked), Artifacts, Follow-up needed. **Note:** No metrics event type currently exists for handoff completion. Log the completion as a finding with category "learning" so the event can be tracked. If `ops/metrics-log.sh` gains a `handoff-completed` event type in the future, log it here.
3. **Present to user.** Show the completion summary. If follow-up is needed, recommend the next action.

**Body — Model Tiering** table:
| Subcommand | Model | Rationale |
|---|---|---|
| `/handoff` (send) | Sonnet | Structured artifact generation |
| `/handoff complete` | Sonnet | Structured artifact generation |

**Body — Extensibility section:** Implementers can override this skill to add domain-specific handoff checklists (e.g., schema diffs for database handoffs, security scan results for deployment handoffs). Override by creating `.claude/skills/handoff/SKILL.md` in your project.

- [ ] **Step 4: Verify the skill file**

Run: `head -5 .claude/skills/handoff/SKILL.md`
Expected: YAML frontmatter starting with `---` and containing `name: handoff`

- [ ] **Step 5: Commit**

```bash
git add .claude/skills/handoff/SKILL.md
git commit -m "feat: add /handoff skill for structured agent-to-agent handoffs"
```

---

## Task 2: `/deploy` Skill

**Files:**

- Create: `.claude/skills/deploy/SKILL.md`

Wraps `ops/deploy.sh` with pre/post validation and metrics logging.

- [ ] **Step 1: Create the skill directory**

Run: `mkdir -p .claude/skills/deploy`

- [ ] **Step 2: Write the skill file**

Create `.claude/skills/deploy/SKILL.md` with the following structure:

**Frontmatter:**

- `name: deploy`
- `description: "Deploy to an environment. Runs pre-deploy validation, ops/deploy.sh, post-deploy health check, and logs metrics."`
- `argument-hint: "<env> [component] [--type planned|hotfix]"`

**Body — heading:** `# Deploy`

**Body — intro:** Reference `.claude/COLLABORATION.md` § Work Item Lifecycle (Phase 6 — Deploy).

**Body — Usage section** with three examples:

- `/deploy dev` -- Deploy to dev environment
- `/deploy prod api --type planned` -- Deploy API to production (planned)
- `/deploy prod api --type hotfix` -- Hotfix deployment

**Body — Workflow** (7 steps):

1. **Parse arguments.** Extract environment, component (optional), and type (default: planned).
2. **Pre-deploy checks.** Dispatch the compliance-auditor agent to verify the compliance floor is satisfied. If any blocking violations exist, halt and report.
3. **Confirm with user.** Show what will be deployed, to which environment, and the deploy type. Wait for user confirmation. At Fly pace, confirm only for production deployments.
4. **Execute deployment.** Run: `ops/deploy.sh <env> <component> --type <type>`. The deploy script's exit code determines success (0) or failure (non-zero).
5. **Log the event.** On success, run: `ops/metrics-log.sh ext-deployed <item> --env <env> --type <type>` where `<item>` is the current work item ID (from PO context or user input).
6. **Post-deploy validation.** Report the deployment result. If the deploy script output includes a URL or identifier, surface it. Recommend running regression tests for production deployments.
7. **On failure.** Report the error output. Do not retry automatically. Log a finding if the failure indicates a systemic issue.

**Body — Model Tiering** table:
| Subcommand | Model | Rationale |
|---|---|---|
| `/deploy` | Sonnet | Orchestration with structured checks |

**Body — Extensibility section:** Implementers replace `ops/deploy.sh` with their deployment logic (contract: exit 0 = success, exit 1 = failure). The skill workflow stays the same. Override the full skill by creating `.claude/skills/deploy/SKILL.md` to add environment-specific checks (e.g., k8s health probes, Vercel status).

- [ ] **Step 3: Verify the skill file**

Run: `head -5 .claude/skills/deploy/SKILL.md`
Expected: YAML frontmatter with `name: deploy`

- [ ] **Step 4: Commit**

```bash
git add .claude/skills/deploy/SKILL.md
git commit -m "feat: add /deploy skill for deployment orchestration with validation"
```

---

## Task 3: `/findings` Skill

**Files:**

- Create: `.claude/skills/findings/SKILL.md`

Manages the findings register — the learning loop backbone. Multiple subcommands for different operations.

- [ ] **Step 1: Create the skill directory**

Run: `mkdir -p .claude/skills/findings`

- [ ] **Step 2: Write the skill file**

Create `.claude/skills/findings/SKILL.md` with the following structure:

**Frontmatter:**

- `name: findings`
- `description: "Manage the findings register. Log findings, review patterns, triage open items, track refinement effectiveness."`
- `argument-hint: "[log <text>|review|patterns|triage]"`

**Body — heading:** `# Findings`

**Body — intro:** Reference `.claude/COLLABORATION.md` § Learning Through Findings.

**Body — Usage section** with five examples:

- `/findings log "Handoff from backend lacked schema diff"` -- Log a new finding
- `/findings log "Handoff from backend lacked schema diff" --urgency high --category boundary-tension` -- Log with metadata
- `/findings review` -- SM reviews open findings
- `/findings patterns` -- Analyze recurring finding types
- `/findings triage` -- Route unprocessed findings

**Body — Workflow: Log** (4 steps):

1. **Parse arguments.** Extract the finding description, urgency (default: normal), and category (default: infer from description).
2. **Format the finding.** Create an entry using the register format from `.claude/findings/register.md`: date, urgency, title, found-by, category (surprise/pattern/boundary-tension/learning/success), description, proposed action, status (open).
3. **Append to register.** Add the entry under "## Active Findings" in `.claude/findings/register.md`.
4. **Acknowledge.** Confirm the finding was logged with its urgency. If urgency is critical, alert: "Critical finding logged. Escalate immediately per protocol."

**Body — Workflow: Review** (4 steps):

1. **Read the register.** Load `.claude/findings/register.md`.
2. **Dispatch SM agent.** The scrum-master reviews open findings: group by category, identify patterns (same category recurring = refinement not landing), propose refinements for each pattern (specific, measurable, scoped), recommend status changes (accepted/deferred/dismissed with rationale).
3. **Present to user.** Show grouped findings with SM's proposals. Wait for user to approve, modify, or defer each proposal.
4. **Apply approved changes.** Update finding statuses in the register. If a refinement changes agent behavior, note which agent definition or memory needs updating.

**Body — Workflow: Patterns** (3 steps):

1. **Read the register.** Load `.claude/findings/register.md`.
2. **Analyze.** Count findings by category, by urgency, by status. Identify: categories with rising counts, categories with declining counts, agents that generate the most findings, time-to-resolution for accepted findings.
3. **Report.** Present a structured summary with trend indicators.

**Body — Workflow: Triage** (3 steps):

1. **Read the register.** Filter for `Status: open` findings.
2. **Route each finding.** Based on category and content: boundary-tension → SM, surprise (technical) → SA, surprise (business) → PO, pattern → SM for review, success → SM for distribution.
3. **Present routing recommendations.** User confirms or adjusts.

**Body — Model Tiering** table:
| Subcommand | Model | Rationale |
|---|---|---|
| `/findings log` | Sonnet | Structured formatting, minimal judgment |
| `/findings review` | Opus | Judgment: pattern analysis, refinement proposals |
| `/findings patterns` | Sonnet | Data aggregation, structured reporting |
| `/findings triage` | Sonnet | Routing logic, structured output |

**Body — Extensibility section:** Implementers can override to add domain-specific finding categories (e.g., "compliance-gap", "performance-regression") or integrate with external issue trackers.

- [ ] **Step 3: Verify the skill file**

Run: `head -5 .claude/skills/findings/SKILL.md`
Expected: YAML frontmatter with `name: findings`

- [ ] **Step 4: Commit**

```bash
git add .claude/skills/findings/SKILL.md
git commit -m "feat: add /findings skill for findings register management"
```

---

## Task 4: `/audit` Skill

**Files:**

- Create: `.claude/skills/audit/SKILL.md`

Dispatches the compliance-auditor agent. Simple skill — mostly a convenience wrapper.

- [ ] **Step 1: Create the skill directory**

Run: `mkdir -p .claude/skills/audit`

- [ ] **Step 2: Write the skill file**

Create `.claude/skills/audit/SKILL.md` with the following structure:

**Frontmatter:**

- `name: audit`
- `description: "Run a compliance audit against the compliance floor. Dispatches the compliance-auditor agent."`
- `argument-hint: "[item-id] [--scope full|diff]"`

**Body — heading:** `# Audit`

**Body — intro:** Dispatch a compliance audit against the rules in `compliance-floor.md`. The compliance-auditor agent is dispatched during Review (Phase 4) of the work item lifecycle, but this skill allows on-demand auditing at any point. See `.claude/agents/compliance-auditor.md` for the agent's mandate.

**Body — Usage section** with four examples:

- `/audit` -- Audit current changes against the compliance floor
- `/audit 42` -- Audit a specific work item
- `/audit --scope diff` -- Audit only changed files (faster)
- `/audit --scope full` -- Full compliance floor audit

**Body — Workflow** (5 steps):

1. **Parse arguments.** Extract item ID (optional) and scope (default: diff).
2. **Determine scope.** `diff`: Identify files changed since the last commit (or since item was promoted, if item ID provided). `full`: Audit the entire codebase against the compliance floor.
3. **Dispatch compliance-auditor agent.** Send the agent with: the compliance floor rules from `compliance-floor.md`, the scope (file list for diff, or "full codebase"), and the item ID if provided.
4. **Present results.** Show the audit output in the compliance-auditor's standard format: Rules Checked table (rule, status, notes), Violations section (blocking/warning with location and fix), Summary (rules checked, passed, violations count, verdict).
5. **If violations found.** For each blocking violation, recommend which domain owner should fix it. Log findings for patterns (e.g., the same rule violated repeatedly).

**Body — Model Tiering** table:
| Subcommand | Model | Rationale |
|---|---|---|
| `/audit` | Sonnet | The compliance-auditor agent is already Sonnet; this skill dispatches it |

**Body — Extensibility section:** Implementers add domain-specific audit rules by defining them in `compliance-floor.md`. For deeper integration (e.g., automated SAST scans, policy-as-code), override this skill to run additional checks alongside the compliance-auditor agent.

- [ ] **Step 3: Verify the skill file**

Run: `head -5 .claude/skills/audit/SKILL.md`
Expected: YAML frontmatter with `name: audit`

- [ ] **Step 4: Commit**

```bash
git add .claude/skills/audit/SKILL.md
git commit -m "feat: add /audit skill for compliance audit dispatch"
```

---

## Task 5: `/pace` Skill

**Files:**

- Create: `.claude/skills/pace/SKILL.md`

Packages the SM's pace control responsibility into a skill with status, evaluation, and transition subcommands.

- [ ] **Step 1: Create the skill directory**

Run: `mkdir -p .claude/skills/pace`

- [ ] **Step 2: Write the skill file**

Create `.claude/skills/pace/SKILL.md` with the following structure:

**Frontmatter:**

- `name: pace`
- `description: "Pace control. Show current pace, evaluate readiness for promotion/demotion, apply pace changes."`
- `argument-hint: "[status|evaluate|change <pace>]"`

**Body — heading:** `# Pace`

**Body — intro:** Reference `.claude/COLLABORATION.md` § Pace Control.

**Body — Usage section** with three examples:

- `/pace` -- Show current pace and quick health summary
- `/pace evaluate` -- Full evaluation with DORA + flow signals and SM recommendation
- `/pace change walk` -- Apply a pace change (with confirmation)

**Body — Workflow: Status** (default, 3 steps):

1. **Read current pace.** Parse from `.claude/COLLABORATION.md` (the `Current Pace: **X**` line).
2. **Quick health check.** Run `ops/dora.sh --sm` and extract the key signals: CFR (change failure rate), FPY (first-pass yield), current recommendation.
3. **Report.** One-screen summary showing: Current pace, CFR with threshold context, FPY with threshold context, Recommendation.

**Body — Workflow: Evaluate** (3 steps):

1. **Run full metrics.** Execute `ops/dora.sh` (full dashboard) to get DORA + flow quality data.
2. **Dispatch SM agent.** The scrum-master evaluates pace readiness using Opus model: review all DORA signals against thresholds in `fleet-config.json`, review flow quality signals (FPY by boundary, rework cycles, blocked time), consider qualitative signals (findings trends, handoff clarity, specialist autonomy), produce a recommendation with evidence.
3. **Present evaluation.** Show the SM's full analysis and recommendation. Include the evidence that supports or argues against a pace change.

**Body — Workflow: Change** (6 steps):

1. **Parse target pace.** Must be one of: Crawl, Walk, Run, Fly.
2. **Validate the change.** Pace can only move one step at a time (Crawl→Walk, Walk→Run, Run→Fly, or reverse). Exception: any pace can drop to Crawl immediately (emergency slowdown).
3. **Confirm with user.** Show current pace, target pace, and the SM's most recent evaluation. Wait for explicit confirmation.
4. **Apply the change.** Update the `Current Pace: **X**` line in `.claude/COLLABORATION.md`.
5. **Log the event.** Record the pace change in the findings register as a "learning" category finding with the rationale. Also log via `ops/metrics-log.sh` if a `pace-changed` event type is available; otherwise, note this gap as a finding for the platform-ops agent to address.
6. **Announce.** Confirm the pace change and summarize what autonomy behaviors change at the new pace.

**Body — Model Tiering** table:
| Subcommand | Model | Rationale |
|---|---|---|
| `/pace` (status) | Sonnet | Data lookup, structured reporting |
| `/pace evaluate` | Opus | Judgment: interpreting signals, qualitative assessment |
| `/pace change` | Sonnet | Validation and file update |

**Body — Extensibility section:** Implementers can override to add custom pace signals (e.g., test coverage thresholds, deployment success rates from CI/CD). The thresholds themselves are already configurable in `fleet-config.json`.

- [ ] **Step 3: Verify the skill file**

Run: `head -5 .claude/skills/pace/SKILL.md`
Expected: YAML frontmatter with `name: pace`

- [ ] **Step 4: Commit**

```bash
git add .claude/skills/pace/SKILL.md
git commit -m "feat: add /pace skill for pace control and transitions"
```

---

## Task 6: `/memory` Skill

**Files:**

- Create: `.claude/skills/memory/SKILL.md`

Exposes memory-manager operations as a skill. Delegates entirely to the memory-manager agent.

- [ ] **Step 1: Create the skill directory**

Run: `mkdir -p .claude/skills/memory`

- [ ] **Step 2: Write the skill file**

Create `.claude/skills/memory/SKILL.md` with the following structure:

**Frontmatter:**

- `name: memory`
- `description: "Memory management. Audit consistency, distribute learnings, optimize memory files, detect knowledge gaps."`
- `argument-hint: "[audit|distribute|optimize|gaps]"`

**Body — heading:** `# Memory`

**Body — intro:** Dispatch memory management operations to the memory-manager agent. See `.claude/agents/memory-manager.md` for the agent's full responsibilities.

**Body — Usage section** with four examples:

- `/memory audit` -- Cross-agent consistency audit
- `/memory distribute` -- Distribute recent learnings across agents
- `/memory optimize` -- Optimize memory files for token efficiency
- `/memory gaps` -- Detect knowledge gaps in agent memories

**Body — Workflow: Audit** (3 steps):

1. **Dispatch memory-manager agent.** The agent performs a consistency audit: cross-agent consistency (contradictions between agent memories), memory-vs-docs consistency (contradicts CLAUDE.md or docs/), memory-vs-code consistency (patterns the code no longer follows), DRY compliance (memories that duplicate doc content).
2. **Present report.** Show inconsistencies found, with source references and recommended fixes.
3. **Confirm fixes.** For each inconsistency, user approves or defers the fix. Agent applies approved fixes.

**Body — Workflow: Distribute** (4 steps):

1. **Gather recent learnings.** Read the findings register for recently accepted findings with refinements.
2. **Dispatch memory-manager agent.** The agent: identifies which learnings are cross-cutting, translates each learning for the relevant agent's domain context, proposes memory writes for each target agent.
3. **Present distribution plan.** Show what will be written to which agent's memory. User confirms.
4. **Apply.** Write approved memory entries.

**Body — Workflow: Optimize** (3 steps):

1. **Dispatch memory-manager agent.** The agent scans all memory files: identify oversized entries that should be references, identify stale entries, identify duplicates, check MEMORY.md index sizes (should stay under 200 lines).
2. **Present optimization plan.** Show proposed changes (consolidate, prune, convert to references).
3. **Confirm and apply.** User approves changes. Agent applies them.

**Body — Workflow: Gaps** (3 steps):

1. **Dispatch memory-manager agent.** The agent identifies missing knowledge: new agents without critical project knowledge, existing agents with outdated memories, missing cross-references, patterns observed in code that no agent has documented.
2. **Present gap report.** Show gaps ranked by impact.
3. **Propose fills.** For each gap, suggest what content should be added and where.

**Body — Model Tiering** table:
| Subcommand | Model | Rationale |
|---|---|---|
| `/memory audit` | Sonnet | Systematic comparison, structured reporting |
| `/memory distribute` | Sonnet | Translation and routing |
| `/memory optimize` | Sonnet | File analysis, structured reporting |
| `/memory gaps` | Sonnet | Analysis and reporting |

**Body — Extensibility section:** Implementers can override to add domain-specific memory categories, custom staleness rules, or integration with external knowledge bases.

- [ ] **Step 3: Verify the skill file**

Run: `head -5 .claude/skills/memory/SKILL.md`
Expected: YAML frontmatter with `name: memory`

- [ ] **Step 4: Commit**

```bash
git add .claude/skills/memory/SKILL.md
git commit -m "feat: add /memory skill for memory management operations"
```

---

## Task 7: Update README Documentation

**Files:**

- Modify: `README.md` (between "## Key Concepts" and "## Documentation" sections)

Add the new skills to the project's documentation.

- [ ] **Step 1: Read the README around the Key Concepts and Documentation sections**

Run: `grep -n '## Key Concepts\|## Documentation' README.md`
Expected: Two line numbers — use these as insertion boundaries.

- [ ] **Step 2: Add a Skills section to README.md**

Insert a new `## Skills` section (h2, same level as Key Concepts and Documentation) between those two sections. Content:

A table listing all 9 skills (3 existing + 6 new):

| Skill       | What It Does                                           | Primary Agent      |
| ----------- | ------------------------------------------------------ | ------------------ |
| `/po`       | Backlog management, prioritization, grooming, review   | product-owner      |
| `/retro`    | Run a retrospective for a completed work item          | scrum-master       |
| `/onboard`  | Interactive project setup                              | --                 |
| `/handoff`  | Structured agent-to-agent handoff with metrics logging | all agents         |
| `/deploy`   | Deployment orchestration with pre/post validation      | platform-ops       |
| `/findings` | Findings register: log, review, triage, patterns       | scrum-master       |
| `/audit`    | Compliance audit against the compliance floor          | compliance-auditor |
| `/pace`     | Pace control: status, evaluation, transitions          | scrum-master       |
| `/memory`   | Memory management: audit, distribute, optimize, gaps   | memory-manager     |

Followed by: "All skills can be overridden by implementers. Create `.claude/skills/<name>/SKILL.md` in your project to replace the harness default."

- [ ] **Step 3: Verify the change**

Run: `grep -A 15 '## Skills' README.md`
Expected: The skills table

- [ ] **Step 4: Commit**

```bash
git add README.md
git commit -m "docs: add skills reference table to README"
```

---

## Task 8: Final Validation

- [ ] **Step 1: Verify all skill files exist and have valid frontmatter**

Run: `for skill in handoff deploy findings audit pace memory; do echo "=== $skill ===" && head -5 .claude/skills/$skill/SKILL.md; done`
Expected: All 6 skills with valid YAML frontmatter

- [ ] **Step 2: Verify no duplicate skill names**

Run: `grep -r '^name:' .claude/skills/*/SKILL.md | sort`
Expected: 9 unique skill names (audit, deploy, findings, handoff, memory, onboard, pace, po, retro)

- [ ] **Step 3: Verify README includes all skills**

Run: `grep -c '/handoff\|/deploy\|/findings\|/audit\|/pace\|/memory' README.md`
Expected: At least 6 matches

- [ ] **Step 4: Run bash syntax check on all ops scripts (unchanged, but verify nothing broke)**

Run: `bash -n ops/*.sh`
Expected: No errors

- [ ] **Step 5: Verify existing skills still parse**

Run: `head -5 .claude/skills/po/SKILL.md .claude/skills/retro/SKILL.md .claude/skills/onboard/SKILL.md`
Expected: All 3 existing skills unchanged with valid frontmatter
