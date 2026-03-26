---
name: floor
description: "Generic floor management. Routes to the declared guardian for any governance floor. Use /floor propose <floor-name> <change> to propose changes to any active floor."
argument-hint: "[list|propose <floor-name> <change>|status <floor-name>]"
---

# Floor Management

Generic skill for managing any governance floor. Routes proposals to the declared guardian in `fleet-config.json`.

## Usage

- `/floor list` -- List all active floors and their guardians
- `/floor status <name>` -- Status report for a specific floor
- `/floor propose <name> "<change>"` -- Submit a change proposal to a floor's guardian

## Workflow: List

1. Read `fleet-config.json` floors section.
2. For each floor: name, file path, guardian, compilation status (check if compiled dir exists and manifest is current).
3. Present as a table.

## Workflow: Status

1. Resolve the floor name to its config entry in `fleet-config.json`.
2. Read the floor file, count rules.
3. Check compiled artifacts: last compile, manifest freshness.
4. Present structured report.

## Workflow: Propose

1. Resolve the floor name to its guardian from `fleet-config.json`.
2. If the guardian has a dedicated skill (e.g., `/compliance`, `/behavioral`), route there.
3. Otherwise, dispatch the guardian agent with the proposal.
4. The guardian dispatches CRO for cross-floor risk consultation.
5. Present results to user.

## Floor Discovery

```bash
jq -r '.floors | to_entries[] | "\(.key): \(.value.file) (guardian: \(.value.guardian))"' fleet-config.json
```

## Adding New Floors

Adding a floor is configuration, not code:

1. Create the floor file in `floors/<name>.md`
2. Declare it in `fleet-config.json` under the `floors` section
3. Assign a Cx officer as guardian
4. Run `ops/compile-floor.sh --all` to compile

No code changes needed.
