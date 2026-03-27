# Examples Refresh — Update to Current Framework Baseline

**Issue:** [#14](https://github.com/rdunie/venutian-antfarm/issues/14)
**Date:** 2026-03-26
**Status:** Draft

## Problem

The 5 progressive examples in `examples/` are stale. They reference `compliance-floor.md` at root (not `floors/`), use `compliance-officer` (not `cro`), lack `floors` and `prioritize_cadence` and `rewards` sections in fleet-config, and have no enforcement blocks in their compliance floors. After #13 (rewards) and #29 (multi-floor governance), the examples no longer represent the framework's current state.

## Goals

1. **Update all examples to the current baseline** — `floors/` directory, CRO rename, fleet-config floors section, `prioritize_cadence`, rewards placeholder.
2. **Progressively introduce enforcement blocks** — prose-only in 01-02, simple blocks in 03, full spread in 04-05.
3. **Demonstrate the behavioral floor** — 05-operational-maturity gets a behavioral floor alongside compliance.

## Non-Goals

- Adding new examples beyond the existing 5
- Changing the domain/scenario of any example (e-commerce stays e-commerce, healthcare stays healthcare)
- Modifying `ops/test-example.sh` unless the new paths break it
- Adding real implementation code to examples (they remain configuration-only)

## Design

### Baseline Changes (All Examples)

Every example gets these structural updates:

1. **Floor migration:** `compliance-floor.md` at root → `floors/compliance.md`
2. **Fleet-config updates:**
   - `compliance-officer` → `cro` in `agents.governance` array
   - `compliance-officer` → `cro` in `pathways.declared.governance` array
   - Add `floors` section declaring compliance floor with CRO guardian
   - Add `prioritize_cadence` field (default: `"per-iteration"`)
   - Add `rewards` section placeholder: `"rewards": { "ledger": ".claude/rewards/ledger.jsonl" }`
3. **README updated** to reference `floors/compliance.md` instead of `compliance-floor.md`

### Per-Example Details

#### 01-getting-started

Minimum useful setup. Teaches the framework lifecycle with the simplest possible configuration.

**Floor:** `floors/compliance.md` — 3 prose-only rules (no enforcement blocks). Same rules as today: no secrets in code, all changes tested, plan before build.

**Fleet-config additions:**

```json
"floors": {
  "compliance": {
    "file": "floors/compliance.md",
    "guardian": "cro",
    "compiled_dir": ".claude/floors/compliance/compiled"
  }
},
"prioritize_cadence": "per-iteration",
"rewards": { "ledger": ".claude/rewards/ledger.jsonl" }
```

**No other changes.** 1 specialist (developer), 3 rules, Crawl pace.

#### 02-ecommerce

Multi-specialist with inheritance and overrides. Teaches agent customization.

**Floor:** `floors/compliance.md` — 5 prose-only rules. Same rules as today (e-commerce domain: PCI, customer data).

**Fleet-config:** Same baseline additions as 01. 2 specialists (frontend + backend), Crawl.

**No other changes.**

#### 03-multi-team

Review gates and cross-team pathways. **Introduces enforcement blocks.**

**Floor:** `floors/compliance.md` — 4 rules. 1-2 simple enforcement blocks added:

Block 1 (file-pattern): Block edits to `.env` and secrets files.

```yaml
version: 1
id: no-secrets-in-code
severity: blocking
enforce:
  pre-tool-use:
    type: file-pattern
    action: block
    patterns:
      - '\\.env$'
      - 'secrets?\\.yaml$'
      - "credentials"
```

Block 2 (file-pattern): Block direct writes to metrics log.

```yaml
version: 1
id: no-direct-metrics
severity: blocking
enforce:
  pre-tool-use:
    type: file-pattern
    action: block
    patterns:
      - 'events\\.jsonl$'
```

**Fleet-config:** Baseline additions. 2 specialists + 1 reviewer, Crawl.

**README:** Notes that this example introduces enforcement blocks and explains what they do.

#### 04-compliance-heavy

Regulated domain (healthcare), thick compliance floor. **Full enforcement block coverage.**

**Floor:** `floors/compliance.md` — 7 rules (same healthcare/HIPAA domain). 3-4 enforcement blocks:

Block 1 (file-pattern): Block edits to `.env`, secrets, PHI config.

```yaml
version: 1
id: no-phi-in-config
severity: blocking
enforce:
  pre-tool-use:
    type: file-pattern
    action: block
    patterns:
      - '\\.env$'
      - 'secrets?\\.yaml$'
      - "phi-config"
```

Block 2 (content-pattern): Block PHI patterns in source files.

```yaml
version: 1
id: no-phi-in-source
severity: blocking
enforce:
  post-tool-use:
    type: content-pattern
    action: block
    patterns:
      - 'SSN[:=]\\s*\\d{3}-\\d{2}-\\d{4}'
      - 'DOB[:=]\\s*\\d{4}-\\d{2}-\\d{2}'
```

Block 3 (custom-script): Audit log integrity check.

```yaml
version: 1
id: audit-log-integrity
severity: warning
enforce:
  post-tool-use:
    type: custom-script
    action: warn
    script: ops/checks/verify-audit-log.sh
```

**Agent override rename:** `.claude/overrides/compliance-officer.md` → `.claude/overrides/cro.md`

**setup.sh:** Updated to use `floors/compliance.md` path, `cro` references, and run `compile-floor.sh floors/compliance.md .claude/floors/compliance/compiled` after seeding.

**Custom script:** Add `ops/checks/verify-audit-log.sh` — a minimal placeholder script (exits 0, prints "audit log OK") so the enforcement block validates.

**Fleet-config:** Baseline additions. 1 specialist + 1 reviewer, Crawl.

#### 05-operational-maturity

Mature fleet with tuned cadences and metrics history. **Demonstrates the full multi-floor pattern with behavioral floor.**

**Compliance floor:** `floors/compliance.md` — 5 rules (fintech domain). 3-4 enforcement blocks spanning file-pattern, content-pattern, and custom-script types.

Block 1 (file-pattern): Block edits to secrets and credentials.

```yaml
version: 1
id: no-secrets-in-code
severity: blocking
enforce:
  pre-tool-use:
    type: file-pattern
    action: block
    patterns:
      - '\\.env$'
      - "credentials"
      - 'secrets?\\.yaml$'
```

Block 2 (content-pattern): Block hardcoded API keys.

```yaml
version: 1
id: no-hardcoded-keys
severity: blocking
enforce:
  post-tool-use:
    type: content-pattern
    action: block
    patterns:
      - 'api[_-]?key\\s*[:=]\\s*["\u0027][A-Za-z0-9]{20,}'
      - 'secret\\s*[:=]\\s*["\u0027][A-Za-z0-9]{20,}'
```

Block 3 (custom-script): Transaction validation check.

```yaml
version: 1
id: transaction-validation
severity: warning
enforce:
  post-tool-use:
    type: custom-script
    action: warn
    script: ops/checks/verify-transactions.sh
```

**Behavioral floor (NEW):** `floors/behavioral.md` — 2-3 process quality rules with 1-2 enforcement blocks.

Rules:

1. **Full validation before handoff.** All work must pass the complete validation cycle (test, typecheck, build) before handoff to the next agent.
2. **No untracked work.** Every task must have a corresponding backlog item before implementation begins.

Block 1 (content-pattern): Warn on TODO/FIXME/HACK comments left in committed code.

```yaml
version: 1
id: no-deferred-fixes
severity: warning
enforce:
  post-tool-use:
    type: content-pattern
    action: warn
    patterns:
      - "TODO|FIXME|HACK|XXX"
```

**Fleet-config:** Declares both floors:

```json
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
```

Also: `prioritize_cadence: "per-session"` (mature team triages per session, not per iteration), `retro.cadence: 3`, `knowledge.cadence` with wider Walk cadence.

**Custom scripts:** Add `ops/checks/verify-transactions.sh` — minimal placeholder (exits 0).

**setup.sh:** Updated to compile both floors via `compile-floor.sh --all`, seed metrics events, use CRO references.

### README Updates

**`examples/README.md` progression table** gains two new columns:

| Example                 | Focus                           | Specialists                  | Compliance Rules | Enforcement Blocks | Floors                  | Pace  | Setup Hook                     |
| ----------------------- | ------------------------------- | ---------------------------- | ---------------- | ------------------ | ----------------------- | ----- | ------------------------------ |
| 01-getting-started      | Full lifecycle, minimum config  | 1 (developer)                | 3                | 0                  | compliance              | Crawl | —                              |
| 02-ecommerce            | Multi-specialist, inheritance   | 2 (frontend + backend)       | 5                | 0                  | compliance              | Crawl | —                              |
| 03-multi-team           | Review gates, enforcement intro | 2 + 1 reviewer               | 4                | 2                  | compliance              | Crawl | —                              |
| 04-compliance-heavy     | Regulated domain, thick floor   | 1 + 1 reviewer               | 7                | 3-4                | compliance              | Crawl | Seeds proposals                |
| 05-operational-maturity | Mature fleet, multi-floor       | 3 (frontend + backend + e2e) | 5+2              | 4-5                | compliance + behavioral | Walk  | Seeds metrics, compiles floors |

Each example's README also updated with what's new in this example vs. the previous one.

## File Inventory

### Moved Files (All Examples)

| From                             | To                                |
| -------------------------------- | --------------------------------- |
| `examples/*/compliance-floor.md` | `examples/*/floors/compliance.md` |

### Renamed Files

| From                                                                   | To                                                      |
| ---------------------------------------------------------------------- | ------------------------------------------------------- |
| `examples/04-compliance-heavy/.claude/overrides/compliance-officer.md` | `examples/04-compliance-heavy/.claude/overrides/cro.md` |

### New Files

| File                                                                 | Purpose                                                          |
| -------------------------------------------------------------------- | ---------------------------------------------------------------- |
| `examples/05-operational-maturity/floors/behavioral.md`              | Behavioral floor with process quality rules + enforcement blocks |
| `examples/04-compliance-heavy/ops/checks/verify-audit-log.sh`        | Placeholder custom-script for audit log enforcement block        |
| `examples/05-operational-maturity/ops/checks/verify-transactions.sh` | Placeholder custom-script for transaction enforcement block      |

### Modified Files (All Examples)

| File                           | Change                                                                  |
| ------------------------------ | ----------------------------------------------------------------------- |
| `examples/*/fleet-config.json` | Add floors section, CRO rename, prioritize_cadence, rewards placeholder |
| `examples/*/README.md`         | Update paths, describe new features                                     |

### Modified Files (Selective)

| File                                        | Change                                              |
| ------------------------------------------- | --------------------------------------------------- |
| `examples/04-compliance-heavy/setup.sh`     | Update paths, CRO references, compile floor         |
| `examples/05-operational-maturity/setup.sh` | Update paths, compile both floors, CRO references   |
| `examples/README.md`                        | New progression table columns, updated descriptions |

### Not Changed

- `ops/deploy.sh` in any example
- Specialist agent definitions (`.claude/agents/*.md`) — domain-specific, not affected
- `.claude/overrides/scrum-master.md` — process overrides unaffected
- `.claude/overrides/cko.md` — knowledge overrides unaffected
- `ops/test-example.sh` — should work with new paths (verify during implementation)

## Related Issues

- [#13](https://github.com/rdunie/venutian-antfarm/issues/13) — Rewards system (examples get rewards config)
- [#29](https://github.com/rdunie/venutian-antfarm/issues/29) — Multi-floor governance (examples migrate to floors/)
