#!/usr/bin/env bash
# Seeds a sample compliance proposal for the healthcare platform.
set -euo pipefail

mkdir -p .claude/compliance/proposals

cat > .claude/compliance/proposals/001-add-analytics.md << 'PROPOSAL'
# Proposal: Add Usage Analytics

**Proposed by:** backend-specialist
**Status:** Under Review

## Change

Add PostHog analytics to track feature usage patterns across the platform.

## Compliance Impact

- **Rule 4 (No PHI in external services):** PostHog would receive event data. Must ensure zero PHI leakage in event properties. All event payloads must use tokenized identifiers only.
- **Rule 7 (BAA required):** PostHog offers a BAA for their enterprise plan — must be signed before integration proceeds.

## Risk Assessment

- **Medium risk:** Event properties could accidentally include PHI if not carefully scoped
- **Mitigation:** Allowlist-only approach for event properties (no dynamic fields), automated PHI pattern scanning on outbound events

## Recommendation

Pending CISO and CO review. Recommend proceeding only after BAA is signed and event property allowlist is defined and reviewed.
PROPOSAL

echo "Seeded compliance proposal: .claude/compliance/proposals/001-add-analytics.md"
echo "Try: /compliance to interact with the proposal"
