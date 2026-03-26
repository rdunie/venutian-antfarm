# Governance Floors Guide

Governance floors define non-negotiable rules for agent behavior. Each floor is owned by a Cx officer (guardian) with sole write authority. All floors share the same enforcement machinery: a compiler that generates hook scripts, checksum-based integrity verification, and sentinel-gated writes.

## Overview

A governance floor is a Markdown file containing rules that no agent may violate, regardless of autonomy tier, pace, or process decisions. Rules can be prose-only (enforced by judgment) or include enforcement blocks (enforced by automated hooks).

```
floors/
├── compliance.md    # Risk, regulatory, data governance (CRO guardian)
└── behavioral.md    # Process quality, delivery standards (COO guardian)
```

## How Floors Work

### The Floor Pattern

Each floor follows the same lifecycle:

1. **Define** — Write rules in `floors/<name>.md`
2. **Declare** — Register in `fleet-config.json` with a guardian
3. **Compile** — Run `ops/compile-floor.sh` to generate enforcement artifacts
4. **Protect** — Hooks block unauthorized edits; checksums detect tampering
5. **Evolve** — Changes go through the guardian via `/floor propose <name>`

### V1 Floors

| Floor      | File                   | Guardian | Domain                                                   |
| ---------- | ---------------------- | -------- | -------------------------------------------------------- |
| Compliance | `floors/compliance.md` | CRO      | Risk, regulatory, data governance                        |
| Behavioral | `floors/behavioral.md` | COO      | Process quality, delivery standards, collaboration norms |

### Three Tiers Per Floor

Each governance domain has three tiers with different authority levels:

| Tier                        | Authority                                               | Enforcement            | Example                                                  |
| --------------------------- | ------------------------------------------------------- | ---------------------- | -------------------------------------------------------- |
| **Floor (MUST)**            | User approval required                                  | Hooks block violations | "We MUST NEVER store secrets in code"                    |
| **Targets (SHOULD)**        | Risk-reducing: guardian approves. Others: user approves | Findings, not blockers | "Should maintain 85% first-pass yield"                   |
| **Guidance (NICE TO HAVE)** | Cx roles publish autonomously                           | Informational          | "Prefer parameterized queries over string concatenation" |

Targets must be above the floor — never weaker.

## Adding a New Floor

Adding a floor is configuration, not code. Three steps:

### 1. Create the Floor File

```bash
mkdir -p floors
```

Write `floors/<name>.md`:

```markdown
# <Domain> Floor

> This file is guarded by the <GUARDIAN>. Changes go through `/floor propose <name>`.

## <Section>

### Rule 1

**We MUST ALWAYS** <rule text>.

### Rule 2

**We MUST NEVER** <rule text>.
```

Optionally add enforcement blocks (see `docs/COMPILER-GUIDE.md`).

### 2. Declare in fleet-config.json

Add to the `floors` section:

```json
"floors": {
  "compliance": {
    "file": "floors/compliance.md",
    "guardian": "cro",
    "compiled_dir": ".claude/floors/compliance/compiled"
  },
  "your-new-floor": {
    "file": "floors/your-new-floor.md",
    "guardian": "<cx-agent-name>",
    "compiled_dir": ".claude/floors/your-new-floor/compiled"
  }
}
```

### 3. Compile

```bash
ops/compile-floor.sh --all
```

Or compile just the new floor:

```bash
ops/compile-floor.sh floors/your-new-floor.md .claude/floors/your-new-floor/compiled
```

That's it. The hooks and checksums automatically cover the new floor.

## Guardianship

### What a Guardian Does

Each floor has exactly one guardian — a Cx officer with sole write authority to the floor file. The guardian:

- **Receives proposals** for changes via `/floor propose <name>` or the floor-specific skill
- **Classifies** proposals: Type 1 (risk-reducing), Type 2 (other), Type 3 (new rule)
- **Requests cross-floor risk assessment** by dispatching the CRO as a subagent
- **Presents** the proposal to the user with the CRO's risk assessment
- **Applies** approved changes via sentinel file bypass
- **Monitors integrity** — verifies checksum on session start, reverts unauthorized changes
- **Produces conformance reports** at retros

### Current Guardians

| Guardian                 | Floor      | Agent File              |
| ------------------------ | ---------- | ----------------------- |
| CRO (Chief Risk Officer) | Compliance | `.claude/agents/cro.md` |
| COO                      | Behavioral | `.claude/agents/coo.md` |

### Future Candidates

The pattern supports any number of floors. Candidates:

| Floor     | Guardian | Domain                                   |
| --------- | -------- | ---------------------------------------- |
| Security  | CISO     | Security controls, threat posture        |
| Technical | CTO      | Architecture constraints, tech standards |
| Cost      | CFO      | Budget controls, efficiency requirements |

## Change Process

### Proposing a Change

```
/floor propose compliance "We MUST ALWAYS encrypt PII at rest"
/behavioral propose "We MUST NEVER skip the findings loop"
/compliance propose "We MUST ALWAYS sign commits"
```

### Consultation Flow

When a floor change is proposed:

```
User or Agent
    │
    ▼
Floor Guardian receives proposal
    │
    ├── Classifies: Type 1/2/3
    │
    ▼
Guardian dispatches CRO as subagent
    │
    ▼
CRO runs multi-round Cx consultation:
    ├── Round 1: Each Cx agent advocates domain impact
    ├── CRO synthesizes conflicts and open questions
    ├── Round N: Further rounds until positions stabilize
    └── Returns: risk assessment, Cx positions, recommendation
    │
    ▼
Guardian presents to user with full context
    │
    ├── Accept → Guardian applies change
    ├── Modify → Goes back to CRO for re-assessment
    └── Decline → Logged as signal for future consideration
```

**Context efficiency:** The entire multi-round consultation runs as a single subagent dispatch. Only the compact result enters the main conversation context.

**Special case (compliance floor):** The CRO is both guardian and risk facilitator. The CRO dispatches the consultation as a generic subagent, providing its own compliance position as input.

### Applying a Change

1. Guardian creates sentinel file (`.claude/floors/<name>/.applying`)
2. Edits the floor file (sentinel bypasses the protection hook)
3. Runs the compiler to regenerate artifacts
4. Updates the checksum
5. Logs the change to the change log
6. Removes the sentinel

If compilation fails, the change is reverted via `git checkout`.

## Protection Mechanisms

### Hook Protection

A PreToolUse hook blocks edits to any `floors/*.md` file unless the appropriate sentinel file exists:

```
.claude/floors/<floor-name>/.applying
```

The sentinel must be less than 1 minute old (prevents stale sentinels from permanently bypassing protection).

### Checksum Verification

On SessionStart, a hook verifies each floor's compiled artifacts against its manifest:

```bash
# For each floor declared in fleet-config.json:
EXPECTED=$(grep '^source:' "${compiled_dir}/manifest.sha256" | cut -d' ' -f2)
ACTUAL=$(sha256sum "${floor_file}" | cut -d' ' -f1)
```

If a mismatch is detected: `[CRO] WARNING: Floor '<name>' changed but artifacts not recompiled.`

### Unauthorized Change Response

If a floor file is modified without going through the guardian:

1. Guardian restores via `git checkout <commit> -- floors/<name>.md`
2. Issues a reprimand (logged to findings register)
3. Logs `compliance-violation` and `compliance-reverted` events

## Skills

| Skill                   | Guardian           | Purpose                                                                  |
| ----------------------- | ------------------ | ------------------------------------------------------------------------ |
| `/compliance`           | CRO                | Compliance floor management (status, propose, review, apply, audit, log) |
| `/behavioral`           | COO                | Behavioral floor management (status, propose, review, apply, log)        |
| `/floor list`           | —                  | List all active floors and their guardians                               |
| `/floor status <name>`  | —                  | Status report for a specific floor                                       |
| `/floor propose <name>` | Routes to guardian | Submit a change proposal to any floor                                    |

## Compiled Artifacts

After compilation, each floor's artifacts live in its compiled directory:

```
.claude/floors/compliance/
├── compiled/
│   ├── enforce.sh              # Hook enforcement dispatcher
│   ├── compliance.prose.md     # Floor without enforcement blocks
│   ├── manifest.sha256         # Integrity checksums
│   ├── semgrep-rules.yaml      # Merged semgrep rules
│   ├── eslint-rules.json       # Merged eslint rules
│   └── block-NNN.yaml          # Extracted enforcement blocks
└── floor-checksum.sha256       # Floor file integrity hash
```

See `docs/COMPILER-GUIDE.md` for details on enforcement blocks and the compilation pipeline.

## Configuration

### fleet-config.json

```json
{
  "floors": {
    "compliance": {
      "file": "floors/compliance.md",
      "guardian": "cro",
      "compiled_dir": ".claude/floors/compliance/compiled"
    },
    "behavioral": {
      "file": "floors/behavioral.md",
      "guardian": "coo",
      "compiled_dir": ".claude/floors/behavioral/compiled"
    }
  }
}
```

| Field          | Description                                        |
| -------------- | -------------------------------------------------- |
| `file`         | Path to the floor Markdown file                    |
| `guardian`     | Agent name of the Cx officer who guards this floor |
| `compiled_dir` | Directory for compiled artifacts                   |

## Migration from Single Floor

If your project uses the legacy `compliance-floor.md` at the project root:

1. Create the `floors/` directory: `mkdir -p floors`
2. Move the floor: `git mv compliance-floor.md floors/compliance.md`
3. Add the `floors` section to `fleet-config.json`
4. Update `settings.json` hooks (the harness templates already use the new paths)
5. Recompile: `ops/compile-floor.sh floors/compliance.md .claude/floors/compliance/compiled`

The compiler has backward compatibility — if `floors/compliance.md` doesn't exist but `compliance-floor.md` does, it falls back to the legacy path.
