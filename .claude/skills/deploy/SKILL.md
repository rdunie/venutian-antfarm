---
name: deploy
description: "Deploy to an environment. Runs pre-deploy validation, ops/deploy.sh, post-deploy health check, and logs metrics."
argument-hint: "<env> [component] [--type planned|hotfix]"
---

# Deploy

Orchestrate a deployment as defined in `.claude/COLLABORATION.md` § Work Item Lifecycle (Phase 6 — Deploy).

## Usage

- `/deploy dev` -- Deploy to dev environment
- `/deploy prod api --type planned` -- Deploy API to production (planned)
- `/deploy prod api --type hotfix` -- Hotfix deployment

## Workflow

1. **Parse arguments.** Extract environment, component (optional), and type (default: planned).

2. **Pre-deploy checks.** Dispatch the compliance-auditor agent to verify the compliance floor is satisfied for the work being deployed. If any blocking violations exist, halt and report.

3. **Confirm with user.** Show what will be deployed, to which environment, and the deploy type. Wait for user confirmation before proceeding. At Fly pace, confirm only for production deployments.

4. **Execute deployment.** Run:

   ```bash
   ops/deploy.sh <env> <component> --type <type>
   ```

   The deploy script's exit code determines success (0) or failure (non-zero).

5. **Log the event.** On success, run:

   ```bash
   ops/metrics-log.sh ext-deployed <item> --env <env> --type <type>
   ```

   Where `<item>` is the current work item ID (from PO context or user input).

6. **Post-deploy validation.** Report the deployment result. If the deploy script output includes a URL or identifier, surface it. Recommend running regression tests for production deployments.

7. **On failure.** Report the error output. Do not retry automatically. Log a finding if the failure indicates a systemic issue.

## Model Tiering

| Subcommand | Model  | Rationale                            |
| ---------- | ------ | ------------------------------------ |
| `/deploy`  | Sonnet | Orchestration with structured checks |

## Extensibility

Implementers replace `ops/deploy.sh` with their deployment logic (contract: exit 0 = success, exit 1 = failure). The skill workflow stays the same. Override the full skill by creating `.claude/skills/deploy/SKILL.md` in your project to add environment-specific checks (e.g., k8s health probes, Vercel status).
