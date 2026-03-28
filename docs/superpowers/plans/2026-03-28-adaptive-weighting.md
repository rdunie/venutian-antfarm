# Adaptive Weighting Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add configurable three-axis weighting (tier, type, domain) with step-function decay to behavioral feedback, surfaced via `score` subcommand and `profile` extension.

**Architecture:** A shared `compute_weighted_score()` bash function reads weighting config from fleet-config.json, builds an accepted-items timeline from the metrics log, and computes weighted scores for each R/K ledger entry. The `score` subcommand outputs machine-parseable key=value pairs. The `profile` subcommand appends a one-line weighted summary.

**Tech Stack:** Bash, jq, awk (existing toolchain)

**Spec:** `docs/superpowers/specs/2026-03-28-adaptive-weighting-design.md`

---

### Task 1: Add weighting configuration to fleet-config template

**Files:**

- Modify: `templates/fleet-config.json`

- [ ] **Step 1: Add weighting section to rewards**

In `templates/fleet-config.json`, replace the `rewards` line:

```json
"rewards": { "escalation_deadline_days": 7 },
```

With:

```json
"rewards": {
  "escalation_deadline_days": 7,
  "weighting": {
    "tier_multipliers": {
      "governance": 1.0,
      "core": 0.8,
      "specialist": 0.5
    },
    "type_multipliers": {
      "reprimand": 1.5,
      "kudo": 1.0
    },
    "domain_multipliers": {
      "security": { "security-reviewer": 1.5, "_default": 1.0 },
      "delivery": { "product-owner": 1.5, "_default": 1.0 },
      "_default": 1.0
    },
    "decay": {
      "model": "step",
      "cliff_items": 10,
      "post_cliff_multiplier": 0.25
    }
  }
},
```

Update the `rewards_note`:

```json
"rewards_note": "escalation_deadline_days: days before unacted specialist proposals auto-escalate. weighting: three-axis multipliers (tier, type, domain) with step-function decay based on accepted item count.",
```

- [ ] **Step 2: Commit**

```bash
git add templates/fleet-config.json
git commit -m "feat(#25): add weighting configuration to fleet-config template"
```

---

### Task 2: Implement `compute_weighted_score` function

**Files:**

- Modify: `ops/feedback-log.sh`
- Modify: `ops/tests/test-feedback-log.sh`

- [ ] **Step 1: Write failing tests for weighted scoring**

Add a new section `=== Weighted Score ===` to the test file. Setup: create a fleet-config with weighting in TMPDIR (reuse existing fleet-config or extend it), add some ledger entries with known tiers/domains, add some `item-accepted` events to the metrics log, then test score output.

```bash
echo ""
echo "=== Weighted Score ==="
setup_ledger

# Extend fleet-config with weighting
cat > "${TMPDIR}/fleet-config.json" <<'FLEET'
{
  "agents": {
    "governance": ["cro", "ciso", "ceo", "cto", "cfo", "coo", "cko"],
    "core": ["product-owner", "solution-architect", "scrum-master", "knowledge-ops", "platform-ops", "compliance-auditor"]
  },
  "rewards": {
    "escalation_deadline_days": 7,
    "weighting": {
      "tier_multipliers": { "governance": 1.0, "core": 0.8, "specialist": 0.5 },
      "type_multipliers": { "reprimand": 1.5, "kudo": 1.0 },
      "domain_multipliers": {
        "security": { "security-reviewer": 1.5, "_default": 1.0 },
        "_default": 1.0
      },
      "decay": { "model": "step", "cliff_items": 3, "post_cliff_multiplier": 0.25 }
    }
  },
  "pathways": {
    "declared": {
      "feedback": ["security-reviewer -> ciso"],
      "escalation": ["* -> solution-architect"],
      "governance": ["ciso -> cro", "* -> ceo"]
    }
  }
}
FLEET

LEDGER="$TMPDIR/rewards/ledger.md"
CHECKSUM="$TMPDIR/rewards/ledger-checksum.sha256"
FINDINGS_REG="$TMPDIR/findings/register.md"
METRICS_FILE="$TMPDIR/metrics/events.jsonl"

# Create a governance kudo (tier=1.0, type=1.0, domain=1.0, decay=1.0 → weight=1.0)
FEEDBACK_LEDGER="$LEDGER" FEEDBACK_CHECKSUM="$CHECKSUM" \
FINDINGS_REGISTER="$FINDINGS_REG" METRICS_LOG_FILE="$METRICS_FILE" \
REPO_ROOT="${TMPDIR}" \
  "${FEEDBACK_LOG}" kudo --issuer ciso --subject backend-specialist \
  --domain security --description "Good work" --evidence "test"

# Create a governance reprimand (tier=1.0, type=1.5, domain=1.0, decay=1.0 → weight=1.5)
FEEDBACK_LEDGER="$LEDGER" FEEDBACK_CHECKSUM="$CHECKSUM" \
FINDINGS_REGISTER="$FINDINGS_REG" METRICS_LOG_FILE="$METRICS_FILE" \
REPO_ROOT="${TMPDIR}" \
  "${FEEDBACK_LOG}" reprimand --issuer ciso --subject backend-specialist \
  --domain security --severity high --description "Bad work" --evidence "test"

# Test: score subcommand exists and outputs key=value
score_output=$(FEEDBACK_LEDGER="$LEDGER" FEEDBACK_CHECKSUM="$CHECKSUM" \
  METRICS_LOG_FILE="$METRICS_FILE" REPO_ROOT="${TMPDIR}" \
  "${FEEDBACK_LOG}" score backend-specialist)
score_exit=$?
assert_exit "score exits 0" 0 "${score_exit}"

echo "$score_output" > "$TMPDIR/score-output.txt"
assert_contains "score has net field" "$TMPDIR/score-output.txt" "^net="
assert_contains "score has kudos field" "$TMPDIR/score-output.txt" "^kudos="
assert_contains "score has reprimands field" "$TMPDIR/score-output.txt" "^reprimands="
assert_contains "score has signals field" "$TMPDIR/score-output.txt" "^signals=2"
assert_contains "score has recent field" "$TMPDIR/score-output.txt" "^recent="

# Test: domain multiplier exact-match (security-reviewer in security domain gets 1.5x)
FEEDBACK_LEDGER="$LEDGER" FEEDBACK_CHECKSUM="$CHECKSUM" \
FINDINGS_REGISTER="$FINDINGS_REG" METRICS_LOG_FILE="$METRICS_FILE" \
REPO_ROOT="${TMPDIR}" \
  "${FEEDBACK_LOG}" kudo --issuer ciso --subject security-reviewer \
  --domain security --description "Domain match test" --evidence "test"
domain_output=$(FEEDBACK_LEDGER="$LEDGER" FEEDBACK_CHECKSUM="$CHECKSUM" \
  METRICS_LOG_FILE="$METRICS_FILE" REPO_ROOT="${TMPDIR}" \
  "${FEEDBACK_LOG}" score security-reviewer)
echo "$domain_output" > "$TMPDIR/domain-output.txt"
# Weight: tier=1.0 (governance) * type=1.0 (kudo) * domain=1.5 (security-reviewer in security) * decay=1.0 = 1.5
assert_contains "domain multiplier applied" "$TMPDIR/domain-output.txt" "^kudos=1.5"

# Test: score for unknown agent shows zeros
unknown_output=$(FEEDBACK_LEDGER="$LEDGER" FEEDBACK_CHECKSUM="$CHECKSUM" \
  METRICS_LOG_FILE="$METRICS_FILE" REPO_ROOT="${TMPDIR}" \
  "${FEEDBACK_LOG}" score nonexistent-agent)
echo "$unknown_output" > "$TMPDIR/unknown-score.txt"
assert_contains "unknown agent net is 0" "$TMPDIR/unknown-score.txt" "^net=0"
assert_contains "unknown agent signals is 0" "$TMPDIR/unknown-score.txt" "^signals=0"
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `bash ops/tests/test-feedback-log.sh`
Expected: New score tests FAIL (unknown subcommand)

- [ ] **Step 3: Implement `compute_weighted_score` function**

Add after the `check_tension()` function in `ops/feedback-log.sh`. This is a proper function (so `local` is fine):

```bash
# Compute weighted score for an agent
# Reads weighting config from fleet-config.json, builds accepted-items timeline,
# scores each R/K entry. Outputs key=value pairs to stdout.
compute_weighted_score() {
  local agent="$1"
  local config="$REPO_ROOT/fleet-config.json"

  # --- Load weighting config (defaults if absent) ---
  local tier_gov=1.0 tier_core=0.8 tier_spec=0.5
  local type_reprimand=1.5 type_kudo=1.0
  local decay_cliff=10 decay_post=0.25

  if [[ -f "$config" ]] && command -v jq &>/dev/null; then
    local w
    w=$(jq -r '.rewards.weighting // empty' "$config" 2>/dev/null)
    if [[ -n "$w" ]]; then
      tier_gov=$(jq -r '.rewards.weighting.tier_multipliers.governance // 1.0' "$config" 2>/dev/null)
      tier_core=$(jq -r '.rewards.weighting.tier_multipliers.core // 0.8' "$config" 2>/dev/null)
      tier_spec=$(jq -r '.rewards.weighting.tier_multipliers.specialist // 0.5' "$config" 2>/dev/null)
      type_reprimand=$(jq -r '.rewards.weighting.type_multipliers.reprimand // 1.5' "$config" 2>/dev/null)
      type_kudo=$(jq -r '.rewards.weighting.type_multipliers.kudo // 1.0' "$config" 2>/dev/null)
      decay_cliff=$(jq -r '.rewards.weighting.decay.cliff_items // 10' "$config" 2>/dev/null)
      decay_post=$(jq -r '.rewards.weighting.decay.post_cliff_multiplier // 0.25' "$config" 2>/dev/null)
    fi
  fi

  # Validate cliff_items >= 1
  if [[ "$decay_cliff" -lt 1 ]] 2>/dev/null; then
    echo "WARNING: cliff_items must be >= 1, got ${decay_cliff}. Using 1." >&2
    decay_cliff=1
  fi

  # --- Build accepted-items timeline from metrics log ---
  # Maps date -> cumulative accepted count. Single jq pass (O(m), one process spawn).
  declare -A accepted_by_date
  local total_accepted=0
  if [[ -f "$METRICS_LOG_FILE" ]] && command -v jq &>/dev/null; then
    while IFS= read -r evt_date; do
      [[ -z "$evt_date" ]] && continue
      total_accepted=$((total_accepted + 1))
      accepted_by_date["$evt_date"]=$total_accepted
    done < <(jq -r 'select(.event == "item-accepted") | .ts[:10]' "$METRICS_LOG_FILE" 2>/dev/null)
  fi

  # Helper: get accepted count at or before a given date
  # Walks backward through sorted dates (O(d) where d = unique dates, typically small)
  local sorted_dates
  sorted_dates=$(printf '%s\n' "${!accepted_by_date[@]}" | sort)

  lookup_accepted_at() {
    local signal_date="$1"
    local result=0
    local d
    while IFS= read -r d; do
      [[ -z "$d" ]] && continue
      if [[ "$d" <= "$signal_date" ]]; then
        result=${accepted_by_date["$d"]}
      else
        break
      fi
    done <<< "$sorted_dates"
    echo "$result"
  }

  # --- Score each R/K entry for this agent ---
  local kudos_sum=0 reprimands_sum=0 signal_count=0 recent_count=0

  if grep -q "^## ${agent}$" "$LEDGER" 2>/dev/null; then
    local section
    section=$(sed -n "/^## ${agent}$/,/^## [^#]/p" "$LEDGER")

    # Parse entries: ### R-001 [reprimand] 2026-03-28 — ciso / security
    while IFS= read -r header; do
      [[ -z "$header" ]] && continue

      local entry_type entry_date entry_issuer entry_domain entry_tier
      # Extract type: [kudo] or [reprimand]
      if [[ "$header" =~ \[(kudo|reprimand)\] ]]; then
        entry_type="${BASH_REMATCH[1]}"
      else
        continue  # skip proposals, tensions
      fi
      # Extract date
      if [[ "$header" =~ \]\ ([0-9]{4}-[0-9]{2}-[0-9]{2})\ ]]; then
        entry_date="${BASH_REMATCH[1]}"
      else
        continue
      fi
      # Extract domain (after " / ")
      if [[ "$header" =~ /\ ([a-zA-Z_-]+)$ ]]; then
        entry_domain="${BASH_REMATCH[1]}"
      else
        entry_domain="unknown"
      fi

      # Get origin tier from entry body
      local entry_id=""
      if [[ "$header" =~ ^###\ ([RK]-[0-9]+) ]]; then
        entry_id="${BASH_REMATCH[1]}"
      fi
      [[ -z "$entry_id" ]] && continue
      entry_tier=$(sed -n "/^### ${entry_id} /,/^### /p" "$LEDGER" | grep '^\*\*Origin tier:\*\*' | head -1 | sed 's/.*\*\* //')
      [[ -z "$entry_tier" ]] && entry_tier="unknown"

      # --- Compute multipliers ---
      # Tier multiplier
      local tm=1.0
      case "$entry_tier" in
        governance) tm=$tier_gov ;;
        core) tm=$tier_core ;;
        specialist) tm=$tier_spec ;;
      esac

      # Type multiplier
      local tpm=1.0
      case "$entry_type" in
        reprimand) tpm=$type_reprimand ;;
        kudo) tpm=$type_kudo ;;
      esac

      # Domain multiplier (nested lookup)
      local dm=1.0
      if [[ -f "$config" ]] && command -v jq &>/dev/null; then
        local dm_lookup
        # Try exact: domain_multipliers.<domain>.<agent>
        dm_lookup=$(jq -r --arg d "$entry_domain" --arg a "$agent" \
          '.rewards.weighting.domain_multipliers[$d] | if type == "object" then .[$a] // ._default // null else . // null end // null' \
          "$config" 2>/dev/null)
        if [[ "$dm_lookup" != "null" && -n "$dm_lookup" ]]; then
          dm=$dm_lookup
        else
          # Try global _default
          dm_lookup=$(jq -r '.rewards.weighting.domain_multipliers._default // 1.0' "$config" 2>/dev/null)
          dm=$dm_lookup
        fi
      fi

      # Decay multiplier
      local decay=1.0
      local accepted_at
      accepted_at=$(lookup_accepted_at "$entry_date")
      local signal_age=$((total_accepted - accepted_at))
      if [[ "$signal_age" -gt "$decay_cliff" ]]; then
        decay=$decay_post
      fi

      # --- Compute final weight ---
      local weight
      weight=$(awk "BEGIN { printf \"%.1f\", $tm * $tpm * $dm * $decay }")

      signal_count=$((signal_count + 1))
      if [[ "$signal_age" -le "$decay_cliff" ]]; then
        recent_count=$((recent_count + 1))
      fi

      if [[ "$entry_type" == "kudo" ]]; then
        kudos_sum=$(awk "BEGIN { printf \"%.1f\", $kudos_sum + $weight }")
      else
        reprimands_sum=$(awk "BEGIN { printf \"%.1f\", $reprimands_sum - $weight }")
      fi

    done <<< "$(echo "$section" | grep '^### [RK]-')"
  fi

  local net
  net=$(awk "BEGIN { printf \"%.1f\", $kudos_sum + $reprimands_sum }")

  echo "net=${net}"
  echo "kudos=${kudos_sum}"
  echo "reprimands=${reprimands_sum}"
  echo "signals=${signal_count}"
  echo "recent=${recent_count}"
}
```

- [ ] **Step 4: Add `score` subcommand**

Add before the `*)` default case:

```bash
  score)
    [[ -z "$SUBJECT" ]] && echo "Usage: ops/feedback-log.sh score <agent>" >&2 && exit 1
    compute_weighted_score "$SUBJECT"
    ;;
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `bash ops/tests/test-feedback-log.sh`
Expected: All tests pass including new score tests

- [ ] **Step 6: Commit**

```bash
git add ops/feedback-log.sh ops/tests/test-feedback-log.sh
git commit -m "feat(#25): add compute_weighted_score function and score subcommand"
```

---

### Task 3: Add decay tests with item-accepted events

**Files:**

- Modify: `ops/tests/test-feedback-log.sh`

- [ ] **Step 1: Write tests for decay behavior**

Add a new section `=== Decay ===` after the Weighted Score section. This tests that signals beyond the cliff get reduced weight.

```bash
echo ""
echo "=== Decay ==="
setup_ledger

# Manually inject an "old" kudo with a past date (bypassing script to control date)
# This kudo is dated 2025-01-01 — well before any accepted items.
cat >> "$LEDGER" <<'OLDKUDO'

## backend-specialist

### K-001 [kudo] 2025-01-01 — ciso / security

**Description:** Old kudo
**Evidence:** test
**Origin tier:** governance
OLDKUDO
sha256sum "$LEDGER" > "$CHECKSUM"

# Add 4 item-accepted events AFTER the old kudo date (cliff_items=3, so 4 items = beyond cliff)
for i in 1 2 3 4; do
  echo "{\"ts\":\"2025-06-0${i}T12:00:00Z\",\"event\":\"item-accepted\",\"item\":\"${i}\"}" >> "$METRICS_FILE"
done

# Create a fresh kudo (today's date — after all accepted items, so signal_age=0)
FEEDBACK_LEDGER="$LEDGER" FEEDBACK_CHECKSUM="$CHECKSUM" \
FINDINGS_REGISTER="$FINDINGS_REG" METRICS_LOG_FILE="$METRICS_FILE" \
REPO_ROOT="${TMPDIR}" \
  "${FEEDBACK_LOG}" kudo --issuer ciso --subject backend-specialist \
  --domain security --description "New kudo" --evidence "test"

# Old kudo: accepted_at=0, signal_age=4-0=4 > cliff=3, decay=0.25
#   weight = 1.0 (gov) * 1.0 (kudo) * 1.0 (domain) * 0.25 (decayed) = 0.25
# New kudo: accepted_at=4, signal_age=4-4=0 <= cliff=3, decay=1.0
#   weight = 1.0 (gov) * 1.0 (kudo) * 1.0 (domain) * 1.0 (recent) = 1.0
# Net = 0.25 + 1.0 = 1.2, signals=2, recent=1
decay_output=$(FEEDBACK_LEDGER="$LEDGER" FEEDBACK_CHECKSUM="$CHECKSUM" \
  METRICS_LOG_FILE="$METRICS_FILE" REPO_ROOT="${TMPDIR}" \
  "${FEEDBACK_LOG}" score backend-specialist)
echo "$decay_output" > "$TMPDIR/decay-output.txt"
assert_contains "decay: 2 signals" "$TMPDIR/decay-output.txt" "^signals=2"
assert_contains "decay: 1 recent" "$TMPDIR/decay-output.txt" "^recent=1"
assert_contains "decay: net includes decay" "$TMPDIR/decay-output.txt" "^net=1.2"
```

- [ ] **Step 2: Run tests to verify they pass**

Run: `bash ops/tests/test-feedback-log.sh`
Expected: All tests pass including decay tests

- [ ] **Step 3: Commit**

```bash
git add ops/tests/test-feedback-log.sh
git commit -m "test(#25): add decay behavior tests with item-accepted events"
```

---

### Task 4: Add default fallback tests (no weighting config)

**Files:**

- Modify: `ops/tests/test-feedback-log.sh`

- [ ] **Step 1: Write tests for default behavior without weighting config**

Add a section `=== Weighting Defaults ===`. Use a fleet-config WITHOUT the weighting section to verify fallback to defaults.

```bash
echo ""
echo "=== Weighting Defaults ==="
setup_ledger

# Fleet-config with NO weighting section
cat > "${TMPDIR}/fleet-config.json" <<'FLEET'
{
  "agents": { "governance": ["ciso"], "core": ["product-owner"] },
  "rewards": { "escalation_deadline_days": 7 },
  "pathways": { "declared": { "escalation": ["* -> product-owner"], "governance": ["* -> ceo"] } }
}
FLEET

FEEDBACK_LEDGER="$LEDGER" FEEDBACK_CHECKSUM="$CHECKSUM" \
FINDINGS_REGISTER="$FINDINGS_REG" METRICS_LOG_FILE="$METRICS_FILE" \
REPO_ROOT="${TMPDIR}" \
  "${FEEDBACK_LOG}" kudo --issuer ciso --subject backend-specialist \
  --domain security --description "Default test" --evidence "test"

# With no weighting config, all multipliers should be 1.0 → kudo weight = 1.0
default_output=$(FEEDBACK_LEDGER="$LEDGER" FEEDBACK_CHECKSUM="$CHECKSUM" \
  METRICS_LOG_FILE="$METRICS_FILE" REPO_ROOT="${TMPDIR}" \
  "${FEEDBACK_LOG}" score backend-specialist)
echo "$default_output" > "$TMPDIR/default-output.txt"
assert_contains "default: net is 1.0" "$TMPDIR/default-output.txt" "^net=1.0"
assert_contains "default: kudos is 1.0" "$TMPDIR/default-output.txt" "^kudos=1.0"
```

- [ ] **Step 2: Run tests to verify they pass**

Run: `bash ops/tests/test-feedback-log.sh`
Expected: All tests pass

- [ ] **Step 3: Commit**

```bash
git add ops/tests/test-feedback-log.sh
git commit -m "test(#25): add default fallback tests for weighting without config"
```

---

### Task 5: Extend profile with weighted summary line

**Files:**

- Modify: `ops/feedback-log.sh`
- Modify: `ops/tests/test-feedback-log.sh`

- [ ] **Step 1: Write failing test for profile weighted line**

Add to the existing `=== Profile Extensions ===` section or create a new `=== Profile Weighted ===` section:

```bash
echo ""
echo "=== Profile Weighted ==="
setup_ledger

FEEDBACK_LEDGER="$LEDGER" FEEDBACK_CHECKSUM="$CHECKSUM" \
FINDINGS_REGISTER="$FINDINGS_REG" METRICS_LOG_FILE="$METRICS_FILE" \
REPO_ROOT="${TMPDIR}" \
  "${FEEDBACK_LOG}" kudo --issuer ciso --subject backend-specialist \
  --domain security --description "Profile weighted test" --evidence "test"

profile_weighted=$(FEEDBACK_LEDGER="$LEDGER" FEEDBACK_CHECKSUM="$CHECKSUM" \
  METRICS_LOG_FILE="$METRICS_FILE" REPO_ROOT="${TMPDIR}" \
  "${FEEDBACK_LOG}" profile backend-specialist)
echo "$profile_weighted" > "$TMPDIR/profile-weighted.txt"
assert_contains "profile has weighted line" "$TMPDIR/profile-weighted.txt" "^Weighted: net="
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `bash ops/tests/test-feedback-log.sh`
Expected: New profile weighted test FAILS

- [ ] **Step 3: Add weighted summary to profile**

In `ops/feedback-log.sh`, in the `profile)` case, after the "By tier:" section (after the `done` on the for loop, before the `;;`), add:

```bash
    # Weighted summary
    weighted_output=$(compute_weighted_score "$SUBJECT")
    w_net=$(echo "$weighted_output" | grep '^net=' | cut -d= -f2)
    w_kudos=$(echo "$weighted_output" | grep '^kudos=' | cut -d= -f2)
    w_reprimands=$(echo "$weighted_output" | grep '^reprimands=' | cut -d= -f2)
    w_recent=$(echo "$weighted_output" | grep '^recent=' | cut -d= -f2)
    w_signals=$(echo "$weighted_output" | grep '^signals=' | cut -d= -f2)
    echo "Weighted: net=${w_net} (kudos=${w_kudos}, reprimands=${w_reprimands}, ${w_recent} of ${w_signals} recent)"
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `bash ops/tests/test-feedback-log.sh`
Expected: All tests pass

- [ ] **Step 5: Commit**

```bash
git add ops/feedback-log.sh ops/tests/test-feedback-log.sh
git commit -m "feat(#25): extend profile with weighted summary line"
```

---

### Task 6: Update CLAUDE.md and usage header

**Files:**

- Modify: `CLAUDE.md`
- Modify: `ops/feedback-log.sh` (header comment and usage message)

- [ ] **Step 1: Add score to CLAUDE.md Feedback commands**

In CLAUDE.md, find the `### Feedback` section. Add after the existing `ops/feedback-log.sh tensions` line:

```bash
# Weighted behavioral score (machine-parseable)
ops/feedback-log.sh score <agent>
```

- [ ] **Step 2: Update feedback-log.sh header and usage**

In the header comment block, add:

```
#   ops/feedback-log.sh score <agent>
```

Update the usage message (the echo on error) to include `score`:

```bash
echo "Usage: ops/feedback-log.sh <reprimand|kudo|recommend|formalize|reject|check-escalations|profile|score|tensions> [args...]" >&2
```

- [ ] **Step 3: Commit**

```bash
git add CLAUDE.md ops/feedback-log.sh
git commit -m "docs(#25): document score subcommand in CLAUDE.md and usage header"
```

---

### Task 7: Run full test suite and verify

**Files:** None (verification only)

- [ ] **Step 1: Run feedback tests**

Run: `bash ops/tests/test-feedback-log.sh`
Expected: All tests pass (51 original + new weighting/decay/default/profile tests)

- [ ] **Step 2: Run compiler tests**

Run: `bash ops/tests/test-compile-floor.sh`
Expected: `146/146 passed, 0 failed`

- [ ] **Step 3: Syntax check all scripts**

Run: `bash -n ops/feedback-log.sh && bash -n ops/metrics-log.sh && echo "All OK"`
Expected: `All OK`

- [ ] **Step 4: Verify score output end-to-end**

Create a quick manual test:

```bash
# In a temp dir, verify score works with the template fleet-config
bash ops/feedback-log.sh score nonexistent-agent
```

Expected: `net=0.0 kudos=0.0 reprimands=0.0 signals=0 recent=0`

- [ ] **Step 5: Final commit if any fixups needed**

Only if previous steps required changes.
