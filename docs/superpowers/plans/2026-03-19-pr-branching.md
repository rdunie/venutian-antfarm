# PR and Branching Strategy Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Integrate trunk-based branching and PR-native code review into the work item lifecycle, with environment discipline enforcing dev-only changes and fix ownership for learning.

**Architecture:** Update `/po promote` to create branch + draft PR, update `/deploy` to merge PR + deploy through promotion order, update reviewer agents to post findings as PR comments via GitHub MCP, add branching/environment/fix-ownership sections to COLLABORATION.md, add PR metrics events to metrics-log.sh.

**Tech Stack:** Markdown (skills, agents, protocol), Bash (metrics-log.sh), JSON (fleet-config.json), GitHub MCP (PR operations).

**Spec:** `docs/superpowers/specs/2026-03-19-pr-branching-design.md`

---

## File Structure

| File                                   | Responsibility                                                                               |
| -------------------------------------- | -------------------------------------------------------------------------------------------- |
| `.claude/skills/po/SKILL.md`           | Update `/po promote` to create branch + draft PR                                             |
| `.claude/skills/deploy/SKILL.md`       | Rewrite: two-step merge + deploy with environment discipline                                 |
| `.claude/skills/retro/SKILL.md`        | Add PR data to retro metrics                                                                 |
| `.claude/agents/compliance-auditor.md` | Add PR-native review dispatch pattern                                                        |
| `.claude/COLLABORATION.md`             | Add Branching and Pull Requests section, update lifecycle table, update Coordination section |
| `ops/metrics-log.sh`                   | Add branch-created, pr-opened, pr-merged event types                                         |
| `templates/fleet-config.json`          | Add promotion_order to deploy section                                                        |

---

## Task 1: Add PR Metrics Event Types

**Files:**

- Modify: `ops/metrics-log.sh`

- [ ] **Step 1: Read the current metrics-log.sh**

Read `ops/metrics-log.sh` to find the flag parsing section (around line 43), variable initialization (around line 39-41), the case statement for event handlers (around line 103), and the error message listing valid types (around line 230).

- [ ] **Step 2: Add new flag parsing**

In the variable initialization section (around line 41), add:

```bash
BRANCH="" PR=""
```

In the flag parsing `case` block (around line 44-62), add:

```bash
    --branch) BRANCH="$2"; shift 2 ;;
    --pr)     PR="$2";     shift 2 ;;
```

- [ ] **Step 3: Add event handlers**

Before the `*)` catch-all case, add:

```bash
  branch-created)
    emit_event "$(jq -cn --arg ts "$TS" --arg event "$EVENT_TYPE" \
       --arg item "$ITEM" --arg branch "$BRANCH" --arg agent "$AGENT" \
       '{"ts":$ts,"event":$event,"item":$item,"branch":$branch,"agent":$agent}')"
    ;;

  pr-opened|pr-merged)
    emit_event "$(jq -cn --arg ts "$TS" --arg event "$EVENT_TYPE" \
       --arg item "$ITEM" --arg pr "$PR" --arg agent "$AGENT" \
       '{"ts":$ts,"event":$event,"item":$item,"pr":$pr,"agent":$agent}')"
    ;;
```

- [ ] **Step 4: Update the valid types error message**

Add to the valid types listing:

```bash
    echo "             branch-created pr-opened pr-merged" >&2
```

- [ ] **Step 5: Verify syntax**

Run: `bash -n ops/metrics-log.sh`
Expected: No errors

- [ ] **Step 6: Commit**

```bash
git add ops/metrics-log.sh
git commit -m "feat: add PR lifecycle event types to metrics-log.sh"
```

---

## Task 2: Update `/po promote` Skill

**Files:**

- Modify: `.claude/skills/po/SKILL.md`

- [ ] **Step 1: Read the current po skill**

Read `.claude/skills/po/SKILL.md`.

- [ ] **Step 2: Update the `/po promote` usage description**

Change the `/po promote <item>` usage line from:

```
- `/po promote <item>` -- Expand a tier file item into a full work item with story + AC
```

to:

```
- `/po promote <item>` -- Expand a tier file item into a full work item with story + AC, create feature branch and draft PR
```

- [ ] **Step 3: Add branching steps to the Steps section**

After existing step 5 ("If the agent proposes changes..."), append a new section at the end of the file. Do NOT insert inside the numbered list — add it as a separate section after the Steps list:

```markdown
## Promote Branching Workflow

When the subcommand is `promote`, after the PO agent expands the item into a full work item:

1. **Create feature branch.** Run: `git checkout -b <type>/<item-id>-<slug>` where type is `feat`, `fix`, `chore`, or `docs` based on the item category. Push: `git push -u origin <branch-name>`.
2. **Create draft PR.** Use GitHub MCP `create_pull_request` with `draft: true`. PR body includes the work item's story, acceptance criteria, and NFR flags. PR title format: `<type>: <description> (#<item-id>)`.
3. **Log events.** Run: `ops/metrics-log.sh branch-created <item-id> --branch <branch-name>` and `ops/metrics-log.sh pr-opened <item-id> --pr <pr-number>`.
4. **Report.** Present the branch name and PR URL to the user.
```

- [ ] **Step 4: Verify the skill file**

Run: `grep -c 'draft PR' .claude/skills/po/SKILL.md`
Expected: At least 1

- [ ] **Step 5: Commit**

```bash
git add .claude/skills/po/SKILL.md
git commit -m "feat: update /po promote to create feature branch and draft PR"
```

---

## Task 3: Rewrite `/deploy` Skill

**Files:**

- Modify: `.claude/skills/deploy/SKILL.md`

The deploy skill changes significantly — it becomes a two-step process (merge + deploy) with environment discipline enforcement.

- [ ] **Step 1: Read the current deploy skill**

Read `.claude/skills/deploy/SKILL.md`.

- [ ] **Step 2: Rewrite the skill**

Use the Write tool to replace the entire content of `.claude/skills/deploy/SKILL.md`. Compose the full markdown file from the following specification:

**Frontmatter:** Same name and argument-hint. Updated description:

- `description: "Two-step deploy: merge approved PR to main, then deploy through promotion order. Enforces environment discipline."`

**Body — heading:** `# Deploy`

**Body — intro:** Two-step deployment as defined in `.claude/COLLABORATION.md` § Work Item Lifecycle (Phase 6) and § Branching and Pull Requests. The PO owns the merge decision; platform-ops owns the deployment execution.

**Body — Usage section:**

- `/deploy dev` -- Deploy merged changes to dev environment
- `/deploy prod api --type planned` -- Deploy API to production (planned)
- `/deploy prod api --type hotfix` -- Hotfix deployment
- `/deploy --merge <pr-number>` -- Merge an approved PR to main, then deploy

**Body — Workflow** (9 steps):

1. **Parse arguments.** Extract environment, component (optional), type (default: planned), and PR number (optional).
2. **Validate source.** If `--merge` specified, verify the PR has all reviewer approvals via GitHub MCP `pull_request_read`. If any reviews are pending or changes requested, halt with: "PR #X has unresolved reviews. Fix before merging."
3. **Merge PR.** If `--merge` specified, merge via GitHub MCP `merge_pull_request`. Log: `ops/metrics-log.sh pr-merged <item> --pr <pr-number>`. Delete the remote branch: `git push origin --delete <branch-name>`.
4. **Switch to main.** Run: `git checkout main && git pull`.
5. **Environment discipline check.** Verify the target environment is the next in the `promotion_order` from `fleet-config.json`. You cannot skip environments. If the previous environment hasn't been deployed to, halt with: "Deploy to <prev-env> first."
6. **Pre-deploy checks.** Dispatch the compliance-auditor to verify the compliance floor is satisfied. If blocking violations exist, halt.
7. **Confirm with user.** Show what will be deployed, to which environment, and the deploy type. Wait for confirmation. At Fly pace, confirm only for production.
8. **Execute deployment.** Run: `ops/deploy.sh <env> <component> --type <type>`. Exit 0 = success, non-zero = failure.
9. **Log and report.** On success: `ops/metrics-log.sh ext-deployed <item> --env <env> --type <type>`. Report the result. On failure: report error, do not retry, log finding if systemic.

**Body — Model Tiering:**
| Subcommand | Model | Rationale |
|---|---|---|
| `/deploy` | Sonnet | Orchestration with structured checks |

**Body — Extensibility:** Same as current — implementers replace `ops/deploy.sh`. Override the full skill for custom merge or environment checks.

- [ ] **Step 3: Verify the skill file**

Run: `head -5 .claude/skills/deploy/SKILL.md`
Expected: Valid frontmatter with `name: deploy`

- [ ] **Step 4: Commit**

```bash
git add .claude/skills/deploy/SKILL.md
git commit -m "feat: rewrite /deploy skill for two-step merge + deploy with environment discipline"
```

---

## Task 4: Update `/retro` Skill

**Files:**

- Modify: `.claude/skills/retro/SKILL.md`

- [ ] **Step 1: Read the current retro skill**

Read `.claude/skills/retro/SKILL.md`.

- [ ] **Step 2: Add PR data to the metrics gathering step**

In step 2 ("Summarize the flow"), add after the existing bullet list:

```markdown
- PR metrics: review rounds, time-to-merge (branch created → PR merged), PR comment count
```

- [ ] **Step 3: Add PR metrics to the output format**

In the output format template, add after "Rework loops: X":

```markdown
- PR review rounds: X
- Time-to-merge: X
- PR comments: X
```

- [ ] **Step 4: Commit**

```bash
git add .claude/skills/retro/SKILL.md
git commit -m "feat: add PR metrics to /retro output"
```

---

## Task 5: Update Compliance Auditor for PR-Native Review

**Files:**

- Modify: `.claude/agents/compliance-auditor.md`

- [ ] **Step 1: Read the current compliance-auditor**

Read `.claude/agents/compliance-auditor.md`.

- [ ] **Step 2: Add PR review dispatch pattern**

After the existing "## Boundaries" section, add:

```markdown
## PR-Native Review

When dispatched to review a PR (rather than local changes):

1. Read the PR diff via GitHub MCP `pull_request_read`
2. For each compliance floor violation found, post a line-level comment via `pull_request_review_write`
3. Post a general summary comment via `add_issue_comment` with the standard audit format (Rules Checked table + Summary)
4. If blocking violations exist, use `pull_request_review_write` with `event: "REQUEST_CHANGES"`
5. If all rules pass, use `pull_request_review_write` with `event: "APPROVE"`
6. Copy all findings to the compliance-officer regardless of who dispatched the review
```

- [ ] **Step 3: Commit**

```bash
git add .claude/agents/compliance-auditor.md
git commit -m "feat: add PR-native review dispatch pattern to compliance-auditor"
```

---

## Task 6: Update COLLABORATION.md

**Files:**

- Modify: `.claude/COLLABORATION.md`

Three changes: update the lifecycle table, add branching section, update coordination section.

- [ ] **Step 1: Read the target sections**

Read `.claude/COLLABORATION.md` lines 405-420 (Work Item Lifecycle table), lines 395-403 (Coordination section).

- [ ] **Step 2: Update the Work Item Lifecycle table**

Update Phase 2, 4, and 6 in the lifecycle table:

Phase 2 (Promote): Change "What Happens" to: `Expand to full work item with story, AC, NFRs. Create feature branch + draft PR. Log \`item-promoted\`, \`branch-created\`, \`pr-opened\`.`

Phase 4 (Review): Change "What Happens" to: `PO verifies AC. Dispatches reviewers who post findings as PR comments. DoD gate.`

Phase 6 (Deploy): Change "What Happens" to: `PO merges approved PR to main. Platform-ops deploys through promotion order. Log \`pr-merged\`, \`ext-deployed\`.`Change "Who Leads" to:`PO merges, platform-ops deploys`

- [ ] **Step 3: Add Branching and Pull Requests section**

Insert after the Coordination section (after line 403) and before the Work Item Lifecycle section:

```markdown
## Branching and Pull Requests

### Branch Lifecycle

Each work item gets a feature branch and draft PR at Promote (Phase 2). The PR is the canonical work item artifact — it tracks progress, collects review feedback, and gates deployment.

- **Branch naming:** `<type>/<item-id>-<slug>` (feat, fix, chore, docs)
- **PR title:** `<type>: <description> (#<item-id>)`
- **Draft PR** created at Promote, converted to "ready for review" when specialist signals build complete via handoff to PO
- **Branch operations** use local git; **PR operations** use GitHub MCP

### PR-Native Code Review

During Review (Phase 4), reviewers post findings directly to the PR:

- **Line-level comments** via `pull_request_review_write` for specific code issues
- **General comments** via `add_issue_comment` for overall assessment
- **Approve** via `pull_request_review_write` with `event: "APPROVE"`
- **Request changes** via `pull_request_review_write` with `event: "REQUEST_CHANGES"`
- Compliance-auditor is always dispatched; other reviewers per `pathways.declared.review`

Code feedback lives on the PR. Process feedback lives in the findings register.

### Environment Discipline

All code changes happen on feature branches in the dev environment only. Agents may diagnose in any environment (read-only), but fixes must flow through the deployment chain: branch → PR → merge to main → deploy through promotion order.

- No hotfix shortcuts — even urgent fixes follow the chain (PO may skip non-blocking review steps)
- No direct environment patching — direct modifications are a critical finding
- Promotion order is defined in `fleet-config.json` under `deploy.promotion_order`

### Fix Ownership and Learning

The agent that authored the code is responsible for fixing issues, regardless of where discovered. Diagnosis is collaborative (any agent, any environment, read-only). The fix returns to the author so the learning stays with the agent that needs it.

When ownership is ambiguous: triad reaches consensus → if weak alignment, escalate to Cx stakeholders → if unresolved, user decides.

### Branch Health

Branches existing for more than 2 accepted items without merging are flagged by SM during Checkpoint (Phase 9) as a "process" finding using `git branch -r --no-merged main`.
```

- [ ] **Step 4: Commit**

```bash
git add .claude/COLLABORATION.md
git commit -m "feat: add branching, PR review, environment discipline to collaboration protocol"
```

---

## Task 7: Update fleet-config Template

**Files:**

- Modify: `templates/fleet-config.json`

- [ ] **Step 1: Read the current template**

Read `templates/fleet-config.json`.

- [ ] **Step 2: Add promotion_order to deploy section**

Change the `deploy` section from:

```json
"deploy": {
  "command": "ops/deploy.sh",
  "environments": ["dev", "test", "prod"]
},
```

to:

```json
"deploy": {
  "command": "ops/deploy.sh",
  "environments": ["dev", "test", "prod"],
  "promotion_order": ["dev", "test", "prod"]
},
```

- [ ] **Step 3: Verify JSON**

Run: `python3 -c "import json; d=json.load(open('templates/fleet-config.json')); print(d['deploy']['promotion_order'])"`
Expected: `['dev', 'test', 'prod']`

- [ ] **Step 4: Commit**

```bash
git add templates/fleet-config.json
git commit -m "feat: add promotion_order to fleet-config deploy section"
```

---

## Task 8: Final Validation

- [ ] **Step 1: Verify all modified skills have valid frontmatter**

Run: `head -5 .claude/skills/po/SKILL.md .claude/skills/deploy/SKILL.md .claude/skills/retro/SKILL.md`
Expected: All 3 with valid YAML frontmatter

- [ ] **Step 2: Verify compliance-auditor has PR review section**

Run: `grep -c 'PR-Native Review' .claude/agents/compliance-auditor.md`
Expected: 1

- [ ] **Step 3: Verify COLLABORATION.md has branching section**

Run: `grep -c 'Branching and Pull Requests' .claude/COLLABORATION.md`
Expected: 1

- [ ] **Step 4: Verify metrics-log has PR events**

Run: `grep -c 'branch-created\|pr-opened\|pr-merged' ops/metrics-log.sh`
Expected: At least 3

- [ ] **Step 5: Verify fleet-config has promotion_order**

Run: `python3 -c "import json; d=json.load(open('templates/fleet-config.json')); print(d['deploy']['promotion_order'])"`
Expected: `['dev', 'test', 'prod']`

- [ ] **Step 6: Bash syntax check on ops scripts**

Run: `bash -n ops/*.sh`
Expected: No errors

- [ ] **Step 7: Verify existing agents unchanged (except auditor)**

Run: `git diff HEAD -- .claude/agents/product-owner.md .claude/agents/scrum-master.md .claude/agents/solution-architect.md .claude/agents/memory-manager.md .claude/agents/platform-ops.md .claude/agents/ciso.md .claude/agents/compliance-officer.md`
Expected: No changes

**Note on template agents:** The spec mentions updating reviewer agents (security-reviewer, SA) for PR-native review. Template agents under `templates/agents/` are intentionally unchanged — implementers add PR review behavior when they customize them for their project. Only the core compliance-auditor (`.claude/agents/`) gets the PR dispatch pattern because it's a core agent dispatched on every review.
