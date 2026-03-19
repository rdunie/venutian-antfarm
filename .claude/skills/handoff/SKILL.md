---
name: handoff
description: "Structured agent-to-agent handoff. Validates artifact, logs metrics event, dispatches receiving agent."
argument-hint: "<item> --from <agent> --to <agent> [--urgency blocking|non-blocking]"
---

# Handoff

Orchestrate a structured handoff between agents as defined in `.claude/COLLABORATION.md` § Handoff Protocol.

## Usage

- `/handoff 42 --from backend-specialist --to security-reviewer` -- Send a handoff
- `/handoff 42 --from backend-specialist --to security-reviewer --urgency blocking` -- Blocking handoff
- `/handoff complete 42 --from security-reviewer --to backend-specialist` -- Complete a handoff

## Workflow: Send

1. **Parse arguments.** Extract item ID, from-agent, to-agent, and urgency (default: non-blocking).

2. **Build the handoff artifact.** Prompt the sending agent (--from) to produce a handoff using the COLLABORATION.md format:

   ```
   **Handoff: [from-agent] -> [to-agent]**
   **What was done:** [brief summary of completed work]
   **What's needed:** [specific request for the receiving agent]
   **Context:** [relevant background the receiving agent needs]
   **Artifacts:** [files changed, test results, error logs]
   **Urgency:** [blocking / non-blocking]
   ```

3. **Validate the artifact.** Check that all required fields are present. If any are missing, prompt the sending agent to fill them in. A handoff where the receiving agent would need to ask for clarification is a finding.

4. **Log the event.** Run:

   ```bash
   ops/metrics-log.sh handoff-sent <item> --from <from-agent> --to <to-agent>
   ```

5. **Dispatch the receiving agent.** Send the handoff artifact to the receiving agent (--to) with instructions to act on the request.

6. **Capture outcome.** After the receiving agent completes, determine: accepted or rejected.
   - If **rejected**, log: `ops/metrics-log.sh handoff-rejected <item> --from <from-agent> --to <to-agent>`
   - Record the rejection reason as a finding if it indicates a pattern.

## Workflow: Complete

1. **Parse arguments.** Extract item ID, from-agent (the agent completing the handoff), to-agent (the original sender).

2. **Build the completion artifact.** Prompt the completing agent to produce a Handoff Complete artifact using the COLLABORATION.md § Handoff Completion format:

   ```
   **Handoff Complete: [to-agent] -> [from-agent]**
   **What was done:** [brief summary of work completed]
   **Result:** [success / partial / blocked -- with details]
   **Artifacts:** [files changed, test results]
   **Follow-up needed:** [yes/no -- what remains]
   ```

   **Note:** No metrics event type currently exists for handoff completion. Log the completion as a finding with category "learning" so the event can be tracked. If `ops/metrics-log.sh` gains a `handoff-completed` event type in the future, log it here.

3. **Present to user.** Show the completion summary. If follow-up is needed, recommend the next action.

## Model Tiering

| Subcommand          | Model  | Rationale                      |
| ------------------- | ------ | ------------------------------ |
| `/handoff` (send)   | Sonnet | Structured artifact generation |
| `/handoff complete` | Sonnet | Structured artifact generation |

## Extensibility

Implementers can override this skill to add domain-specific handoff checklists. For example, a project might require schema diffs for database handoffs or security scan results for deployment handoffs. Override by creating `.claude/skills/handoff/SKILL.md` in your project.
