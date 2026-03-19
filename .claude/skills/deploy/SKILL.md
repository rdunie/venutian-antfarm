---
name: deploy
description: "Two-step deploy: merge approved PR to main, then deploy through promotion order. Enforces environment discipline."
argument-hint: "<env> [component] [--type planned|hotfix] [--merge <pr-number>]"
---

# Deploy

Two-step deployment as defined in `.claude/COLLABORATION.md` § Work Item Lifecycle (Phase 6) and § Branching and Pull Requests. The PO owns the merge decision; platform-ops owns the deployment execution.

## Usage

- `/deploy dev` -- Deploy merged changes to dev environment
- `/deploy prod api --type planned` -- Deploy API to production (planned)
- `/deploy prod api --type hotfix` -- Hotfix deployment
- `/deploy --merge 42` -- Merge approved PR #42 to main, then deploy

## Workflow

1. **Parse arguments.** Extract environment, component (optional), type (default: planned), and PR number (optional via `--merge`).

2. **Validate source.** If `--merge` specified, verify the PR has all reviewer approvals via GitHub MCP `pull_request_read`. If any reviews are pending or changes requested, halt with: "PR #X has unresolved reviews. Fix before merging."

3. **Merge PR.** If `--merge` specified, merge via GitHub MCP `merge_pull_request`. Log: `ops/metrics-log.sh pr-merged <item> --pr <pr-number>`. Delete the remote branch: `git push origin --delete <branch-name>`.

4. **Switch to main.** Run: `git checkout main && git pull`.

5. **Environment discipline check.** Verify the target environment is the next in the `promotion_order` from `fleet-config.json`. You cannot skip environments. If the previous environment hasn't been deployed to, halt with: "Deploy to <prev-env> first."

6. **Pre-deploy checks.** Dispatch the compliance-auditor agent to verify the compliance floor is satisfied for the work being deployed. If any blocking violations exist, halt and report.

7. **Confirm with user.** Show what will be deployed, to which environment, and the deploy type. Wait for user confirmation before proceeding. At Fly pace, confirm only for production deployments.

8. **Execute deployment.** Run:

   ```bash
   ops/deploy.sh <env> <component> --type <type>
   ```

   The deploy script's exit code determines success (0) or failure (non-zero).

9. **Log and report.** On success, run:

   ```bash
   ops/metrics-log.sh ext-deployed <item> --env <env> --type <type>
   ```

   Report the deployment result. If the deploy script output includes a URL or identifier, surface it. Recommend running regression tests for production deployments. On failure: report the error output, do not retry automatically, log a finding if the failure indicates a systemic issue.

## Model Tiering

| Subcommand | Model  | Rationale                            |
| ---------- | ------ | ------------------------------------ |
| `/deploy`  | Sonnet | Orchestration with structured checks |

## Extensibility

Implementers replace `ops/deploy.sh` with their deployment logic (contract: exit 0 = success, exit 1 = failure). The skill workflow stays the same. Override the full skill by creating `.claude/skills/deploy/SKILL.md` in your project to add environment-specific checks (e.g., k8s health probes, Vercel status) or custom merge validation.
