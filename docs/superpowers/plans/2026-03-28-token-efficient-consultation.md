# Token-Efficient Consultation Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Optimize the CRO's cross-floor consultation protocol with tiered triage, guided response templates, early abort on consensus, and budget observability.

**Architecture:** All changes are to agent definitions, skill prompts, and fleet-config. No new scripts. The CRO agent definition gets the core protocol changes (triage, template, abort logic). Skills get `--domains` flag support. Fleet-config gets consultation budget config.

**Tech Stack:** Markdown (agent definitions, skills), JSON (fleet-config)

**Spec:** `docs/superpowers/specs/2026-03-28-token-efficient-consultation-design.md`

---

### Task 1: Update CRO agent definition with efficient consultation protocol

**Files:**

- Modify: `.claude/agents/cro.md`

- [ ] **Step 1: Replace § Cross-Floor Risk Facilitation**

In `.claude/agents/cro.md`, find the section `### 2. Cross-Floor Risk Facilitation` (starts around line 36). Replace the entire section content (lines 38-49) with:

```markdown
When a floor guardian (including yourself for compliance) receives a change proposal:

1. **Triage:** Read the proposal text and any `--domains` tags provided by the proposer. Apply your own judgment to select which peer Cx agents to consult. Domain tags are hints, not constraints — you may add agents the proposer didn't tag and skip agents they did. You have broader cross-cutting visibility than individual agents or proposers.
   - For floor-level (Type 3) changes: consult at least 2 Cx agents.
   - For target-level changes: a single-agent consultation is acceptable.
   - If no Cx domain is impacted: issue a solo assessment noting "No Cx agents consulted -- CRO solo assessment."
2. **Dispatch** each selected agent with the guided assessment template:
```

## Floor Change Assessment — [agent-name]

**Proposal:** [brief summary]
**Floor:** [compliance|behavioral]

### Your Assessment

**Impact:** [impacted | not-impacted | abstain]
**Rationale:** [1-2 sentences]
**Conditions:** [optional — conditions under which your position changes]
**Risk level:** [none | low | medium | high]

```

Agents fill in the template fields as their minimum response. They may add free-text below for substantive concerns.

3. **Synthesize Round 1:** Parse the structured Impact and Risk Level fields from each response. Apply early abort:
- All not-impacted/abstain → abort: "no concerns raised, recommend approval"
- All impacted, no conditions, same risk level → abort: consolidated position
- Any disagreement, conditions, or high risk → proceed to round 2 with only the agents who raised concerns
- Single agent consulted with concerns → synthesize directly (no round 2 — no additional perspective to gather)
4. **Round 2 (if needed):** Dispatch only concerned agents. Maximum 2 total rounds. If positions still diverge, synthesize and flag the disagreement — the user decides.
5. **Return:** Consolidated risk assessment, each Cx position (consulted and not-consulted), abort/proceed rationale, recommendation.

Record non-consulted agents as "not consulted (triaged out by CRO)" in the assessment for audit trail.

**Special case (compliance floor):** You are both guardian and risk facilitator. Because of this conflict of interest, triage is disabled for your own floor — you MUST consult all 6 peer Cx agents. Provide your compliance position as input alongside the proposal, then dispatch all peers with the guided template. Full consensus required.

**Context efficiency:** The entire consultation is a single subagent dispatch. The main context sees only one dispatch + one result.
```

- [ ] **Step 2: Verify the file is valid markdown**

Read the file back and confirm the new section is coherent and doesn't break surrounding sections.

- [ ] **Step 3: Commit**

```bash
git add .claude/agents/cro.md
git commit -m "feat(#30): update CRO with tiered triage, guided template, early abort protocol"
```

---

### Task 2: Add --domains flag to proposal skills

**Files:**

- Modify: `.claude/skills/floor/SKILL.md`
- Modify: `.claude/skills/compliance/SKILL.md`
- Modify: `.claude/skills/behavioral/SKILL.md`

- [ ] **Step 1: Update floor skill**

In `.claude/skills/floor/SKILL.md`, find the `argument-hint` in the frontmatter. Update it to include `--domains`:

```yaml
argument-hint: "[list|propose <floor-name> <change> [--domains <d1,d2>]|status <floor-name>]"
```

In the `## Workflow: Propose` section, after step 3 ("Otherwise, dispatch the guardian agent with the proposal"), add:

```markdown
- If `--domains` was provided, pass the domain tags to the guardian/CRO as advisory hints for triage. Valid tags: `security`, `strategy`, `technology`, `cost`, `process`, `knowledge`.
```

- [ ] **Step 2: Update compliance skill**

In `.claude/skills/compliance/SKILL.md`, find the `argument-hint` in the frontmatter. Add `[--domains <d1,d2>]` to the propose usage.

In the `## Workflow: Propose` section, after step 3 (create proposal file), add:

```markdown
4. If `--domains` was provided, include domain tags in the proposal file frontmatter as `domains: [d1, d2]`. These are passed to the CRO as advisory triage hints.
```

Renumber subsequent steps accordingly.

- [ ] **Step 3: Update behavioral skill**

In `.claude/skills/behavioral/SKILL.md`, find the `argument-hint` in the frontmatter. Add `[--domains <d1,d2>]` to the propose usage.

In the `## Workflow: Propose` section, after step 3 (create proposal file), add:

```markdown
4. If `--domains` was provided, include domain tags in the proposal file frontmatter as `domains: [d1, d2]`. These are passed to the CRO via COO as advisory triage hints.
```

Renumber subsequent steps accordingly.

- [ ] **Step 4: Commit**

```bash
git add .claude/skills/floor/SKILL.md .claude/skills/compliance/SKILL.md .claude/skills/behavioral/SKILL.md
git commit -m "feat(#30): add --domains flag to floor/compliance/behavioral propose skills"
```

---

### Task 3: Add consultation config to fleet-config template

**Files:**

- Modify: `templates/fleet-config.json`

- [ ] **Step 1: Add consultation section**

In `templates/fleet-config.json`, add after the `rewards_note` line (and before `prioritize_cadence`):

```json
"consultation": {
  "max_rounds": 2,
  "budget_tokens_hint": 50000
},
"consultation_note": "max_rounds: cap on consultation rounds. budget_tokens_hint: advisory token target per consultation (CFO monitors, not enforced).",
```

- [ ] **Step 2: Verify JSON validity**

Run: `cat templates/fleet-config.json | jq .`
Expected: Valid JSON output

- [ ] **Step 3: Commit**

```bash
git add templates/fleet-config.json
git commit -m "feat(#30): add consultation config to fleet-config template"
```

---

### Task 4: Update governance floors documentation

**Files:**

- Modify: `docs/GOVERNANCE-FLOORS.md`

- [ ] **Step 1: Add efficient consultation section**

In `docs/GOVERNANCE-FLOORS.md`, find the section that describes cross-floor risk consultation. Add a new subsection (or update existing) documenting the efficient protocol:

```markdown
## Efficient Consultation Protocol

When a floor change is proposed, the CRO facilitates cross-floor risk assessment using a tiered consultation protocol designed to minimize token usage:

### Triage

The CRO reads the proposal and any `--domains` tags, then selects which peer Cx agents to consult. Domain tags are advisory hints — the CRO has final discretion. Non-consulted agents are recorded for audit trail.

### Guided Template

Consulted agents respond using a structured template (Impact, Rationale, Conditions, Risk Level) keeping responses to ~50-100 tokens. Free-text is allowed for substantive concerns.

### Early Abort

If round 1 produces unanimous consensus (all not-impacted, or all aligned), the CRO aborts further rounds. Maximum 2 rounds total.

### Domain Tags

Proposers can hint which domains are affected:
```

/floor propose behavioral "change" --domains process,cost

```

Valid tags: `security` (CISO), `strategy` (CEO), `technology` (CTO), `cost` (CFO), `process` (COO), `knowledge` (CKO).

### Budget Observability

The `consultation` section in `fleet-config.json` sets advisory targets (`max_rounds`, `budget_tokens_hint`). The CFO monitors actual costs via `ops/dora.sh --cost`. No hard enforcement.
```

- [ ] **Step 2: Commit**

```bash
git add docs/GOVERNANCE-FLOORS.md
git commit -m "docs(#30): document efficient consultation protocol in governance floors guide"
```

---

### Task 5: Verify all changes

**Files:** None (verification only)

- [ ] **Step 1: Verify JSON**

Run: `cat templates/fleet-config.json | jq . > /dev/null && echo "valid"`
Expected: `valid`

- [ ] **Step 2: Verify no syntax issues in modified files**

Read back each modified file and confirm coherence:

- `.claude/agents/cro.md` — new triage/template/abort section reads correctly
- `.claude/skills/floor/SKILL.md` — --domains flag documented
- `.claude/skills/compliance/SKILL.md` — --domains flag documented
- `.claude/skills/behavioral/SKILL.md` — --domains flag documented

- [ ] **Step 3: Run existing test suites to verify no regressions**

Run: `bash ops/tests/test-compile-floor.sh 2>&1 | grep Results:`
Expected: 146/146 passed (no changes to compiler)

Run: `bash ops/tests/test-feedback-log.sh 2>&1 | tail -3`
Expected: 65/65 passed (no changes to feedback system)

- [ ] **Step 4: Final commit if any fixups needed**

Only if previous steps required changes.
