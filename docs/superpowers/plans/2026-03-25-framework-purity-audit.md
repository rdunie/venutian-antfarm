# Framework Purity Audit Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Move 18 implementer artifacts from `.claude/` to `templates/` + onboarding, so the framework repo contains only framework files.

**Architecture:** Move 6 content files to `templates/`, delete 12 scaffolding stubs, expand the onboarding skill to create all runtime artifacts, update CLAUDE.md references.

**Tech Stack:** Git (file moves), Bash (onboarding script), Markdown.

**Spec:** `docs/superpowers/specs/2026-03-25-framework-purity-audit-design.md`

**Framework purity:** All work in a worktree. No runtime artifacts created in the repo.

---

### Task 1: Move compliance artifacts to templates

**Files:**
- Create: `templates/compliance/change-log.md` (moved from `.claude/compliance/change-log.md`)
- Create: `templates/compliance/targets.md` (moved from `.claude/compliance/targets.md`)
- Delete: `.claude/compliance/change-log.md`
- Delete: `.claude/compliance/targets.md`

- [ ] **Step 1: Create templates/compliance/ directory**

```bash
mkdir -p templates/compliance
```

- [ ] **Step 2: Move the files**

```bash
git mv .claude/compliance/change-log.md templates/compliance/change-log.md
git mv .claude/compliance/targets.md templates/compliance/targets.md
```

- [ ] **Step 3: Verify files exist at new location**

```bash
cat templates/compliance/change-log.md
cat templates/compliance/targets.md
```

Expected: Content of both files displayed (change log header, targets header).

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "refactor: move compliance artifacts to templates/

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>"
```

---

### Task 2: Move governance artifacts to templates

**Files:**
- Create: `templates/governance/executive-brief.md` (moved from `.claude/governance/executive-brief.md`)
- Create: `templates/governance/guidance-registry.md` (moved from `.claude/governance/guidance-registry.md`)
- Delete: `.claude/governance/executive-brief.md`
- Delete: `.claude/governance/guidance-registry.md`

- [ ] **Step 1: Create templates/governance/ directory**

```bash
mkdir -p templates/governance
```

- [ ] **Step 2: Move the files**

```bash
git mv .claude/governance/executive-brief.md templates/governance/executive-brief.md
git mv .claude/governance/guidance-registry.md templates/governance/guidance-registry.md
```

- [ ] **Step 3: Verify files exist at new location**

```bash
cat templates/governance/executive-brief.md
cat templates/governance/guidance-registry.md
```

Expected: Content of both files displayed.

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "refactor: move governance artifacts to templates/

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>"
```

---

### Task 3: Move findings artifacts to templates

**Files:**
- Create: `templates/findings/register.md` (moved from `.claude/findings/register.md`)
- Create: `templates/findings/information-needs.md` (moved from `.claude/findings/information-needs.md`)
- Delete: `.claude/findings/register.md`
- Delete: `.claude/findings/information-needs.md`

- [ ] **Step 1: Create templates/findings/ directory**

```bash
mkdir -p templates/findings
```

- [ ] **Step 2: Move the files**

```bash
git mv .claude/findings/register.md templates/findings/register.md
git mv .claude/findings/information-needs.md templates/findings/information-needs.md
```

- [ ] **Step 3: Verify files exist at new location**

```bash
cat templates/findings/register.md
cat templates/findings/information-needs.md
```

Expected: Content of both files displayed.

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "refactor: move findings artifacts to templates/

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>"
```

---

### Task 4: Delete scaffolding stubs and empty files

**Files to delete:**
- `.claude/compliance/proposals/.gitkeep`
- `.claude/compliance/compiled/.gitkeep`
- `.claude/compliance/eslint/no-eval.json`
- `.claude/compliance/semgrep/no-hardcoded-secrets.yaml`
- `.claude/governance/guidance/ceo/.gitkeep`
- `.claude/governance/guidance/cfo/.gitkeep`
- `.claude/governance/guidance/ciso/.gitkeep`
- `.claude/governance/guidance/cko/.gitkeep`
- `.claude/governance/guidance/coo/.gitkeep`
- `.claude/governance/guidance/cto/.gitkeep`
- `.claude/governance/decisions/.gitkeep`
- `.claude/metrics/events.jsonl`

- [ ] **Step 1: Remove all scaffolding stubs**

```bash
git rm .claude/compliance/proposals/.gitkeep
git rm .claude/compliance/compiled/.gitkeep
git rm .claude/compliance/eslint/no-eval.json
git rm .claude/compliance/semgrep/no-hardcoded-secrets.yaml
git rm .claude/governance/guidance/ceo/.gitkeep
git rm .claude/governance/guidance/cfo/.gitkeep
git rm .claude/governance/guidance/ciso/.gitkeep
git rm .claude/governance/guidance/cko/.gitkeep
git rm .claude/governance/guidance/coo/.gitkeep
git rm .claude/governance/guidance/cto/.gitkeep
git rm .claude/governance/decisions/.gitkeep
git rm .claude/metrics/events.jsonl
```

- [ ] **Step 2: Verify .claude/ only contains framework files**

```bash
find .claude/ -type f | sort
```

Expected: Only `settings.json`, `COLLABORATION.md`, `DOCUMENTATION-STYLE.md`, files under `agents/`, and files under `skills/`. No compliance/, governance/, findings/, or metrics/ files.

- [ ] **Step 3: Commit**

```bash
git add -A
git commit -m "refactor: delete scaffolding stubs and empty runtime files

These are created during onboarding, not shipped in the repo.

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>"
```

---

### Task 5: Expand onboarding skill with Step 2c

**Files:**
- Modify: `.claude/skills/onboard/SKILL.md`

- [ ] **Step 1: Read the current onboarding skill**

Read `.claude/skills/onboard/SKILL.md` to confirm the insertion point (after Step 2b: Governance Activation).

- [ ] **Step 2: Add Step 2c: Scaffold Runtime Artifacts**

Insert after the Step 2b section (after the CISO security review and proposal processing), before Step 3 (Fleet Configuration):

```markdown
### Step 2c: Scaffold Runtime Artifacts

Create the runtime directory structure and copy templates:

```bash
# Compliance
mkdir -p .claude/compliance/proposals
mkdir -p .claude/compliance/compiled
cp templates/compliance/change-log.md .claude/compliance/change-log.md
cp templates/compliance/targets.md .claude/compliance/targets.md

# Governance
mkdir -p .claude/governance/decisions
mkdir -p .claude/governance/guidance/{ceo,cfo,ciso,cko,coo,cto}
cp templates/governance/executive-brief.md .claude/governance/executive-brief.md
cp templates/governance/guidance-registry.md .claude/governance/guidance-registry.md

# Findings
mkdir -p .claude/findings
cp templates/findings/register.md .claude/findings/register.md
cp templates/findings/information-needs.md .claude/findings/information-needs.md

# Metrics
mkdir -p .claude/metrics
touch .claude/metrics/events.jsonl

# Rewards (if templates exist)
if [ -d templates/rewards ]; then
  mkdir -p .claude/rewards
  cp templates/rewards/ledger.md .claude/rewards/ledger.md
  sha256sum .claude/rewards/ledger.md > .claude/rewards/ledger-checksum.sha256
fi
```
```

- [ ] **Step 3: Update the onboarding summary checklist**

In Step 7 (Summary), add a new checklist item after `- [x] Compliance floor guardianship activated`:

```markdown
- [x] Runtime artifacts scaffolded (compliance, governance, findings, metrics)
```

- [ ] **Step 4: Commit**

```bash
git add .claude/skills/onboard/SKILL.md
git commit -m "feat: expand onboarding to scaffold runtime artifacts

Adds Step 2c that creates all compliance, governance, findings, and
metrics directories and copies templates into .claude/.

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>"
```

---

### Task 6: Update CLAUDE.md

**Files:**
- Modify: `CLAUDE.md`

- [ ] **Step 1: Read relevant sections of CLAUDE.md**

Read the Directory Structure section, Quick Start section, and any references to the templates/ directory.

- [ ] **Step 2: Update Directory Structure tree**

Add "(created at onboarding)" comments to the runtime directories:

```
├── .claude/
│   ├── settings.json                # Hook configuration
│   ├── COLLABORATION.md             # Collaboration protocol (source of truth)
│   ├── DOCUMENTATION-STYLE.md       # Documentation style guide
│   ├── agents/                      # Core agent definitions (13)
│   ├── governance/                  # Governance infrastructure (created at onboarding)
│   ├── skills/                      # Slash command skills (/po, /retro, /onboard)
│   ├── compliance/                  # Compliance governance (created at onboarding)
│   ├── findings/                    # Findings register (created at onboarding)
│   └── metrics/                     # Event log (created at onboarding)
```

- [ ] **Step 3: Update Quick Start**

Add onboarding reference after the existing cp commands:

```bash
cp templates/fleet-config.json fleet-config.json   # configure your fleet
cp templates/compliance-floor.md compliance-floor.md # define non-negotiable rules
# Or run /onboard for guided setup including all runtime artifacts
# See examples/ for progressive working references
```

- [ ] **Step 4: Update templates/ in Directory Structure**

Update the templates tree to show the new subdirectories:

```
├── templates/
│   ├── compliance-floor.md          # Starter compliance floor
│   ├── fleet-config.json            # Fleet configuration template
│   ├── agents/                      # Specialist agent templates (5)
│   ├── compliance/                  # Compliance runtime templates
│   ├── governance/                  # Governance runtime templates
│   ├── findings/                    # Findings runtime templates
│   └── rewards/                     # Rewards runtime templates
```

- [ ] **Step 5: Commit**

```bash
git add CLAUDE.md
git commit -m "docs: update CLAUDE.md for framework purity changes

Add onboarding comments to directory tree, add /onboard reference to
quick start, update templates/ tree with new subdirectories.

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>"
```

---

### Task 7: Validation

**Files:** None modified — validation only.

- [ ] **Step 1: Verify .claude/ contains only framework files**

```bash
find .claude/ -type f | sort
```

Expected: Only agents/, skills/, settings.json, COLLABORATION.md, DOCUMENTATION-STYLE.md. No compliance/, governance/, findings/, or metrics/ files or directories.

- [ ] **Step 2: Verify all templates exist**

```bash
ls templates/compliance/change-log.md templates/compliance/targets.md
ls templates/governance/executive-brief.md templates/governance/guidance-registry.md
ls templates/findings/register.md templates/findings/information-needs.md
```

Expected: All 6 files listed.

- [ ] **Step 3: Verify onboarding skill has Step 2c**

```bash
grep -c "Step 2c" .claude/skills/onboard/SKILL.md
```

Expected: At least 1 match.

- [ ] **Step 4: Verify CLAUDE.md references onboarding**

```bash
grep "onboard" CLAUDE.md
```

Expected: References to `/onboard` and "created at onboarding".

- [ ] **Step 5: Syntax-check all scripts**

```bash
bash -n ops/*.sh
```

Expected: clean parse (no scripts were modified, but verify nothing broke).

- [ ] **Step 6: Verify no broken references in agent definitions**

Spot-check that agent definitions still reference correct runtime paths:

```bash
grep -l "findings/register" .claude/agents/*.md
grep -l "governance/executive-brief" .claude/agents/*.md
```

Expected: CO and CEO agents reference these paths (unchanged — they point to runtime locations).
