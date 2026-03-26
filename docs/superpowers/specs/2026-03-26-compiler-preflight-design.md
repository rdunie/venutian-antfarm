# Compiler Pre-Flight Validation — Expected vs Unexpected Remediation

**Issue:** [#31](https://github.com/rdunie/venutian-antfarm/issues/31)
**Date:** 2026-03-26
**Status:** Draft

## Problem

The compiler has no pre-flight validation of the floor environment. It checks dependencies (yq, gomplate) but doesn't verify that the floor's compiled directory, artifacts, checksums, and sentinel files are in a healthy state before compiling. When something is missing, it creates it silently — making "first compile of a new floor" look identical in the logs to "someone deleted your enforce.sh." These are fundamentally different situations that warrant different responses.

## Goals

1. **Verify floor environment health** before compilation — directories, manifest, artifacts, checksums, sentinels.
2. **Distinguish expected from unexpected remediation** using the manifest as the signal: no manifest = first compile (expected), manifest present but environment broken = unexpected.
3. **Log unexpected remediation as warnings** with findings and metrics events.
4. **Leave an audit trail in git** — remediation actions are included in the compile commit.

## Non-Goals

- Recovery automation (auto-restoring deleted artifacts from git) — follow-up issue
- Integration testing of drift detection and recovery scenarios — follow-up issue
- Pre-flight for diagnostic modes (`--dry-run`, `--verify`, `--extract-only`, etc.)
- Hook or agent configuration validation (different concern)

## Design

### When Pre-Flight Runs

Only in `compile` and `compile-all` modes — before extraction. Diagnostic modes (`--dry-run`, `--verify`, `--extract-only`, `--validate-only`, `--prose-only`, `--generate-enforce`) skip pre-flight to stay fast and low-friction.

### Pre-Flight Checks

The `preflight_check` function runs these checks in order:

1. **Floor file exists** — if missing: error in single compile (exit 1), warning + skip in compile-all
2. **Compiled directory exists** — create if missing
3. **Manifest exists** — its presence/absence determines the expected/unexpected classification for all subsequent checks
4. **Manifest source hash matches floor file** — detects floor edits without recompilation
5. **Key artifacts present** (any `.sh` or `.md` files in compiled dir) — detects deleted artifacts

Note: The `/compliance apply` and `/behavioral apply` skills create sentinel files (`.claude/floors/<name>/.applying`) during floor changes. Stale sentinel detection is deferred to the follow-up drift testing issue, since the sentinel mechanism lives in the skills layer, not the compiler.

### Expected vs Unexpected Classification

The manifest is the signal. If `manifest.sha256` exists in the compiled directory, the floor has been compiled before — any missing infrastructure is unexpected.

| Condition                             | Manifest exists? | Classification                | Action                                 |
| ------------------------------------- | ---------------- | ----------------------------- | -------------------------------------- |
| Compiled dir missing                  | No               | Expected (first compile)      | Create dir, log info                   |
| Manifest missing                      | No               | Expected (first compile)      | Proceed normally, log info             |
| Manifest missing, but artifacts exist | No               | Unexpected (manifest deleted) | Log warning, log metrics event         |
| Source hash mismatch                  | Yes              | Expected (floor edited)       | Log info, proceed (recompile will fix) |
| Artifacts missing                     | Yes              | Unexpected (files deleted)    | Log warning, log metrics event         |

### Output Format

**Info (expected remediation):**

```
[preflight] Floor 'compliance': first compile — creating .claude/floors/compliance/compiled/
[preflight] Floor 'compliance': source has changed since last compile — will recompile
```

**Warning (unexpected remediation):**

```
[preflight] WARNING: Floor 'compliance': enforce.sh missing but manifest exists — artifacts may have been deleted
[preflight] WARNING: Floor 'compliance': manifest.sha256 missing but artifacts exist — manifest may have been deleted
```

All output goes to stderr (consistent with existing compiler error output).

### Audit Trail

Unexpected remediations produce three signals:

1. **stderr message** — visible in the session immediately
2. **Metrics event** — `ops/metrics-log.sh preflight-remediation` with floor name, type (expected/unexpected), and detail
3. **Git audit trail** — remediation actions (directory creation, sentinel removal) are included in the artifacts when the compile step commits. The commit message or the metrics log provides the forensic record.

Findings are not written directly by the compiler (the compiler doesn't own the findings register). Instead, the `preflight-remediation` metric event with `--type unexpected` serves as the signal. The compliance auditor or CRO picks up unexpected remediation events during audit cycles.

### New Metric Event

Add `preflight-remediation` to `ops/metrics-log.sh`:

```bash
ops/metrics-log.sh preflight-remediation --floor compliance --type expected --detail "created compiled directory"
ops/metrics-log.sh preflight-remediation --floor compliance --type unexpected --detail "enforce.sh missing but manifest exists"
```

Arguments:

- `--floor <name>` — which floor (required)
- `--type expected|unexpected` — remediation classification (required)
- `--detail <text>` — human-readable description (required)

### Implementation

**`preflight_check` function** (~60-80 lines) added to `ops/compile-floor.sh`:

```
preflight_check(floor_name, floor_file, compiled_dir)
  → returns 0 (healthy or remediated, proceed)
  → returns 1 (fatal, cannot proceed)
  → prints info/warning to stderr
  → logs unexpected events via ops/metrics-log.sh
```

**Call site:**

- `compile)` mode: called once before extraction with the resolved floor file and compiled dir
- `compile-all)` does NOT call pre-flight directly — it re-invokes the script as a subprocess per floor, which enters the `compile)` path and runs pre-flight automatically

**Integration with existing flow:**

```
preflight_check  ← NEW
    │
    ▼
extract_blocks
    │
    ▼
validate (ops/compiler/validate.sh)
    │
    ▼
prepare_context
    │
    ▼
gomplate templates → artifacts
```

## File Inventory

### Modified Files

| File                              | Change                                                                     |
| --------------------------------- | -------------------------------------------------------------------------- |
| `ops/compile-floor.sh`            | Add `preflight_check` function, call in compile/compile-all modes          |
| `ops/metrics-log.sh`              | Add `preflight-remediation` event type with --floor, --type, --detail args |
| `ops/tests/test-compile-floor.sh` | Add pre-flight tests (expected/unexpected scenarios)                       |
| `docs/COMPILER-GUIDE.md`          | Document pre-flight behavior, expected vs unexpected                       |

### Not Changed

| File                       | Reason                                       |
| -------------------------- | -------------------------------------------- |
| `ops/compiler/validate.sh` | Pre-flight is separate from block validation |
| `ops/compiler/templates/*` | Generated artifacts unchanged                |
| `ops/compiler/schema.yaml` | Schema unchanged                             |

## Follow-Up Issues

1. **Drift detection and recovery testing** — integration tests that simulate drift scenarios (delete artifacts, corrupt checksums, leave stale sentinels) and verify the full detection → remediation → audit trail cycle. Separate issue because it requires test infrastructure for simulating environmental failures.

2. **Auto-recovery from git** — when unexpected remediation detects missing artifacts, attempt `git checkout` to restore them before recompiling. Builds on this pre-flight foundation.

## Related Issues

- [#22](https://github.com/rdunie/venutian-antfarm/issues/22) — Compiler simplification (pre-flight builds on simplified compiler)
- [#29](https://github.com/rdunie/venutian-antfarm/issues/29) — Multi-floor governance (pre-flight validates per-floor environment)
- [#21](https://github.com/rdunie/venutian-antfarm/issues/21) — Multi-context orchestration (startup validation overlaps)
