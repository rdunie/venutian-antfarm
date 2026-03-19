# Pull Requests and Branching Strategy

## Overview

Integrate pull requests and trunk-based branching into the work item lifecycle. Each work item gets a feature branch and draft PR at Promote (Phase 2), lives on that branch through Build/Review/Fix, and merges to main at Deploy (Phase 6). PRs serve as the canonical work item artifact and create a distinct feedback channel for code-level review separate from process feedback in the findings register.

## Branch Lifecycle Tied to Work Items

Each work item gets a branch and PR created at Promote, lived on through Build/Review/Fix, and merged at Deploy.

| Phase      | What Happens                                             | Branch/PR State                 |
| ---------- | -------------------------------------------------------- | ------------------------------- |
| 2. Promote | PO creates branch + draft PR                             | Branch created, draft PR opened |
| 3. Build   | Specialist works on the branch, pushes commits           | Commits on branch               |
| 4. Review  | PO dispatches reviewers → findings posted as PR comments | PR in review                    |
| 5. Fix     | Specialist pushes fixes to the same branch               | More commits on branch          |
| 6. Deploy  | PO marks PR ready, merges to main, triggers deploy       | PR merged, branch deleted       |
| 7. Accept  | PO verifies on main/deployed environment                 | --                              |

### Branch Naming Convention

`<type>/<item-id>-<slug>` where type is `feat`, `fix`, `chore`, `docs`.

Examples: `feat/42-user-auth`, `fix/47-session-timeout`, `chore/50-dependency-update`.

### PR Title Format

`<type>: <description> (#<item-id>)`.

Example: `feat: add user authentication (#42)`.

### Draft PR

Created at Promote as a draft. The PR body includes the work item's story, acceptance criteria, and NFR flags. Converted to "ready for review" when the specialist signals build is complete. This prevents premature merge while keeping the PR visible as a tracking artifact.

### Branch Health

Branches that exist for more than 2 accepted items without merging are flagged by the SM as a finding with category "process" and urgency "normal". This aligns with trunk-based development -- short-lived branches are a health signal.

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

### Review Workflow

1. Specialist signals build complete → PO converts draft PR to "ready for review"
2. PO dispatches relevant reviewers (compliance-auditor always, others based on the work item's domain)
3. Each reviewer reads the PR diff, posts findings as PR comments via GitHub MCP
4. If blocking findings exist → PR stays in review, specialist fixes on the branch, pushes
5. Reviewers re-review (only the changed files or unresolved comments)
6. When all reviewers approve → PO proceeds to Deploy

### Two Feedback Channels

| Feedback Type            | Where It Lives                                          | Example                                                                        |
| ------------------------ | ------------------------------------------------------- | ------------------------------------------------------------------------------ |
| Code-specific issue      | PR comment (line-level)                                 | "This SQL query is vulnerable to injection"                                    |
| Code-general observation | PR comment (general)                                    | "Test coverage for auth module is insufficient"                                |
| Process observation      | Findings register                                       | "Backend specialist consistently misses input validation -- refinement needed" |
| Compliance violation     | Both -- PR comment for the fix, finding for the pattern | "Hardcoded API key" → PR comment + finding if recurring                        |

The compliance-auditor still copies all findings to the CO (per the governance layer design), and now the code-level findings are also visible on the PR for the specialist to act on.

## Environment Discipline

**The rule:** All code changes happen on feature branches in the dev environment only. Agents may read/diagnose in other environments (test, staging, prod), but fixes must flow through the deployment chain.

### What This Means

- **Build phase:** Specialist works on a feature branch. All code changes, test runs, and validation happen against the dev environment.
- **Diagnose in any environment:** Agents may read logs, query databases, inspect configuration, and run diagnostic commands in test/staging/prod. This is read-only investigation.
- **No hotfix shortcuts:** Even urgent production fixes follow the chain: create a branch, fix on the branch, PR review, merge, deploy through environments. The `/deploy` skill supports `--type hotfix` -- a hotfix follows the same chain but may skip non-blocking review steps at the PO's discretion.
- **No direct environment patching:** No agent may modify code, configuration, or data directly in test/staging/prod. If a deploy reveals an issue, the fix goes back to a branch.

### Enforcement

- The `/deploy` skill validates that the source is a merged PR on main (not a raw branch push to a non-dev environment)
- The SA coaches any agent observed making direct environment changes -- this is an architecture violation
- Direct environment modifications are a critical finding (same severity as compliance floor violations)

### Promotion Order

Each environment is deployed in order. You can't skip environments. You can't push code to an environment without it first passing through the prior environment.

```json
"deploy": {
  "environments": ["dev", "test", "prod"],
  "promotion_order": ["dev", "test", "prod"]
}
```

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
Issue discovered in test/staging/prod
  → Infrastructure/platform agent diagnoses (read-only in affected env)
  → Handoff to original author specialist:
    "What was found, where, root cause, suggested fix approach"
  → Specialist fixes on a branch in dev
  → Normal PR → merge → deploy chain
```

## Framework Changes

### Updated Skills

- **`/po promote`** -- Creates feature branch and draft PR when promoting an item. PR body includes story, AC, and NFR flags.
- **`/deploy`** -- Merges the PR to main (validates PR has all approvals). Triggers deploy through promotion order.
- **`/retro`** -- Can pull PR data (comment count, review rounds, time-to-merge) as supplementary metrics.

### Updated Agents

- **Reviewer agents** (compliance-auditor, security-reviewer, SA) -- Updated dispatch pattern to post findings as PR comments via GitHub MCP. They still send a handoff completion to the PO summarizing findings, but code-level detail lives on the PR.

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

### New Metrics Opportunities (optional, not required for v1)

- Time-to-merge (branch created → PR merged) as a lead time supplement
- Review rounds per PR (correlates with first-pass yield)
- Stale branch count (SM health signal)

## What Does NOT Change

- The **9-phase work item lifecycle** -- same phases, same owners, same gates
- The **findings register** -- still used for process feedback
- The **compliance floor mechanism** -- hooks enforce on the branch, PR merge adds a second gate
- The **agent autonomy model** -- unchanged
- The **metrics pipeline** -- same events, PR data is supplementary
