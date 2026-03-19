# Pull Requests and Branching Strategy

## Overview

Integrate pull requests and trunk-based branching into the work item lifecycle. Each work item gets a feature branch and draft PR at Promote (Phase 2), lives on that branch through Build/Review/Fix, and merges to main at Deploy (Phase 6). PRs serve as the canonical work item artifact and create a distinct feedback channel for code-level review separate from process feedback in the findings register.

**Backward compatibility:** PRs are the standard mechanism for all projects using this framework. Projects that cannot use GitHub PRs (e.g., no GitHub remote) continue with the pre-PR workflow -- the lifecycle phases remain the same, only the merge gate is absent.

## Branch Lifecycle Tied to Work Items

Each work item gets a branch and PR created at Promote, lived on through Build/Review/Fix, and merged at Deploy.

| Phase      | What Happens                                                       | Who               | Branch/PR State                 |
| ---------- | ------------------------------------------------------------------ | ----------------- | ------------------------------- |
| 2. Promote | PO creates branch + draft PR                                       | PO                | Branch created, draft PR opened |
| 3. Build   | Specialist works on the branch, pushes commits                     | Specialist        | Commits on branch               |
| 4. Review  | PO dispatches reviewers → findings posted as PR comments           | PO + reviewers    | PR in review                    |
| 5. Fix     | Specialist pushes fixes to the same branch                         | Specialist        | More commits on branch          |
| 6. Deploy  | PO merges PR to main; platform-ops deploys through promotion order | PO + platform-ops | PR merged, branch deleted       |
| 7. Accept  | PO verifies on main/deployed environment                           | PO                | --                              |

**Deploy phase clarification:** The PO owns the merge decision (PR has all approvals → merge to main). Platform-ops owns the deployment execution (run `ops/deploy.sh` through the promotion order). These are two distinct steps within Phase 6.

### Branch Naming Convention

`<type>/<item-id>-<slug>` where type is `feat`, `fix`, `chore`, `docs`.

Examples: `feat/42-user-auth`, `fix/47-session-timeout`, `chore/50-dependency-update`.

### PR Title Format

`<type>: <description> (#<item-id>)`.

Example: `feat: add user authentication (#42)`.

### Draft PR

Created at Promote as a draft. The PR body includes the work item's story, acceptance criteria, and NFR flags. Converted to "ready for review" when the specialist signals build is complete (via a handoff to the PO with `handoff-sent` event). This prevents premature merge while keeping the PR visible as a tracking artifact.

### Branch and PR Operations

Branch creation and switching uses local git commands. PR management uses the GitHub MCP.

- **Branch creation:** `git checkout -b <branch-name>` + `git push -u origin <branch-name>` (local git)
- **PR creation:** GitHub MCP `create_pull_request` (with `draft: true`)
- **Draft → ready:** GitHub MCP `update_pull_request` (remove draft status)
- **PR merge:** GitHub MCP `merge_pull_request`
- **Branch deletion:** `git push origin --delete <branch-name>` after merge (local git)

### Branch Health

Branches that exist for more than 2 accepted items without merging are flagged by the SM as a finding with category "process" and urgency "normal". Detection: the SM checks open branches against the accepted item count during the Checkpoint phase (Phase 9) using `git branch -r --no-merged main` and comparing against item-accepted events.

## PR-Native Code Review

During Review (Phase 4), the PO dispatches review agents who post findings directly to the PR via the GitHub MCP.

### Comment Types

**Line-level comments** for specific code issues:

- Security vulnerabilities (CISO/security-reviewer)
- Compliance floor violations (compliance-auditor)
- Architecture concerns (SA)
- Bug risks, test gaps (domain specialists)

**General PR comments** for broader observations:

- Overall assessment (pass/fail/needs-work)
- Summary of findings count and severity

### GitHub MCP Tool Mapping for Reviews

| Action                  | MCP Tool                    | Notes                                           |
| ----------------------- | --------------------------- | ----------------------------------------------- |
| Read PR diff            | `pull_request_read`         | Get the full diff for review                    |
| Post line-level comment | `pull_request_review_write` | With `event: "COMMENT"` and line-level position |
| Post general comment    | `add_issue_comment`         | PR-level summary                                |
| Approve PR              | `pull_request_review_write` | With `event: "APPROVE"`                         |
| Request changes         | `pull_request_review_write` | With `event: "REQUEST_CHANGES"`                 |

### Review Workflow

1. Specialist signals build complete via handoff to PO → PO converts draft PR to "ready for review" using `update_pull_request`
2. PO dispatches relevant reviewers: compliance-auditor always, others based on `pathways.declared.review` in fleet-config.json
3. Each reviewer reads the PR diff via `pull_request_read`, posts findings as PR comments via GitHub MCP
4. If blocking findings exist → reviewer uses `pull_request_review_write` with `REQUEST_CHANGES`, specialist fixes on the branch, pushes
5. Reviewers re-review (only the changed files or unresolved comments)
6. When all reviewers approve via `pull_request_review_write` with `APPROVE` → PO proceeds to Deploy

### Two Feedback Channels

| Feedback Type            | Where It Lives                                          | Example                                                                        |
| ------------------------ | ------------------------------------------------------- | ------------------------------------------------------------------------------ |
| Code-specific issue      | PR comment (line-level)                                 | "This SQL query is vulnerable to injection"                                    |
| Code-general observation | PR comment (general)                                    | "Test coverage for auth module is insufficient"                                |
| Process observation      | Findings register                                       | "Backend specialist consistently misses input validation -- refinement needed" |
| Compliance violation     | Both -- PR comment for the fix, finding for the pattern | "Hardcoded API key" → PR comment + finding if recurring                        |

The compliance-auditor still copies all findings to the CO (per the governance layer design), and now the code-level findings are also visible on the PR for the specialist to act on.

## Environment Discipline

**The rule:** All code changes happen on feature branches in the dev environment only. Agents may read/diagnose in other environments, but fixes must flow through the deployment chain.

### What This Means

- **Build phase:** Specialist works on a feature branch. All code changes, test runs, and validation happen against the dev environment.
- **Diagnose in any environment:** Agents may read logs, query databases, inspect configuration, and run diagnostic commands in any non-dev environment. This is read-only investigation.
- **No hotfix shortcuts:** Even urgent production fixes follow the chain: create a branch, fix on the branch, PR review, merge, deploy through environments. The `/deploy` skill supports `--type hotfix` -- a hotfix follows the same chain but may skip non-blocking review steps at the PO's discretion.
- **No direct environment patching:** No agent may modify code, configuration, or data directly in non-dev environments. If a deploy reveals an issue, the fix goes back to a branch.

### Enforcement

- The `/deploy` skill validates that the source is a merged PR on main (not a raw branch push to a non-dev environment)
- The SA coaches any agent observed making direct environment changes -- this is an architecture violation
- Direct environment modifications are a critical finding (same severity as compliance floor violations)

### Promotion Order

Each environment is deployed in order. You can't skip environments. You can't push code to an environment without it first passing through the prior environment. Environment names are project-specific (configured in fleet-config.json).

```json
"deploy": {
  "command": "ops/deploy.sh",
  "environments": ["dev", "test", "prod"],
  "promotion_order": ["dev", "test", "prod"]
}
```

Projects with additional environments (e.g., staging between test and prod) add them to both arrays.

## Fix Ownership and Learning

**The rule:** The agent that authored the code is responsible for fixing issues found in that code, regardless of which environment the issue was discovered in or which agent diagnosed it.

### Why

The author agent builds understanding of what went wrong and how to prevent it. This feeds into their agent memory and improves future work. If a different agent fixes it, the learning is lost to the agent that needs it most.

### How It Works

1. **Diagnosis is collaborative.** Any agent can help diagnose -- infrastructure-ops can check environment health, platform-ops can review deploy logs, the SA can assess architectural root causes. Diagnosis happens where the problem is visible (any environment, read-only).

2. **Fix responsibility returns to the author.** Once the issue is understood, the fix is handed back to the original building specialist via a handoff. The handoff includes the diagnosis, the root cause, and the environmental context -- but the specialist writes the fix on their branch in dev.

3. **The learning is the point.** The diagnosis handoff must include enough context for the assigned agent to understand _why_ the issue occurred, not just _what_ to fix.

### Ambiguous Ownership Resolution

When fix ownership is unclear (spans multiple domains, shared code, original author unavailable):

1. **Triad consensus.** PO, SA, and SM collaboratively determine the best agent to own the fix. PO considers business priority and item context, SA considers technical domain boundaries and dependencies, SM considers process health and learning distribution.
2. **Strong alignment → proceed.** Triad assigns the fix and informs the user.
3. **Weak alignment → escalate.** First to appropriate Cx executive stakeholders (e.g., CISO for security fix ownership, CO for compliance implications). If Cx roles can't resolve: to the user with each perspective presented.

### Exception

If the original specialist no longer exists (e.g., removed template agent) or the fix spans multiple domains requiring joint ownership, the PO assigns the fix to the most appropriate specialist and logs a finding noting the learning gap.

### Handoff Pattern for Production Issues

```
Issue discovered in test/prod
  → Infrastructure/platform agent diagnoses (read-only in affected env)
  → Handoff to original author specialist:
    "What was found, where, root cause, suggested fix approach"
  → Specialist fixes on a branch in dev
  → Normal PR → merge → deploy chain
```

## Metrics Integration

### Required Event Types

New event types for `ops/metrics-log.sh`:

| Event            | When                                 | Args                          |
| ---------------- | ------------------------------------ | ----------------------------- |
| `branch-created` | PO creates feature branch at Promote | `--item <id> --branch <name>` |
| `pr-opened`      | Draft PR created                     | `--item <id> --pr <number>`   |
| `pr-merged`      | PR merged to main at Deploy          | `--item <id> --pr <number>`   |

### Optional Metrics (not required for v1)

- Time-to-merge (branch created → PR merged) as a lead time supplement
- Review rounds per PR (correlates with first-pass yield)
- Stale branch count (SM health signal)

## Framework Changes

### Updated Skills

- **`/po promote`** -- Creates feature branch (local git) and draft PR (GitHub MCP `create_pull_request`) when promoting an item. PR body includes story, AC, and NFR flags. Logs `branch-created` and `pr-opened` events.
- **`/deploy`** -- Two-step: (1) PO merges PR via `merge_pull_request` (validates all reviewer approvals), logs `pr-merged`; (2) platform-ops deploys through promotion order via `ops/deploy.sh`. The skill validates that the source is a merged PR on main.
- **`/retro`** -- Can pull PR data (comment count, review rounds, time-to-merge) as supplementary metrics.

### Updated Agents

- **Reviewer agents** (compliance-auditor, security-reviewer, SA) -- Updated dispatch pattern to post findings as PR comments via GitHub MCP (`pull_request_review_write` for line-level, `add_issue_comment` for summaries). They still send a handoff completion to the PO summarizing findings, but code-level detail lives on the PR.

### COLLABORATION.md

Add a "Branching and Pull Requests" section documenting:

- Branch lifecycle tied to work items
- Naming conventions
- PR-native review pattern
- Environment discipline
- Fix ownership and learning

### fleet-config.json

Add `promotion_order` to the existing `deploy` section:

```json
"deploy": {
  "command": "ops/deploy.sh",
  "environments": ["dev", "test", "prod"],
  "promotion_order": ["dev", "test", "prod"]
}
```

## What Does NOT Change

- The **9-phase work item lifecycle** -- same phases, same owners, same gates
- The **findings register** -- still used for process feedback
- The **compliance floor mechanism** -- hooks enforce on the branch, PR merge adds a second gate
- The **agent autonomy model** -- unchanged
- The **existing metrics pipeline** -- same events, PR events are supplementary
