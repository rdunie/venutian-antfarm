# Harness Collaboration Learnings

## Progressive Autonomy

- Start every fleet at Crawl. The visibility at Crawl teaches you more about your process than any other pace.
- Evidence-based transitions only. "Things feel good" is not evidence. Use DORA metrics.
- Pace goes both directions. Slowing down is discipline, not failure.
- New agents always start at Crawl regardless of fleet pace.

## Agent Design

- The leadership triad (PO, SA, SM) is constant regardless of fleet size. Start there.
- Add specialist agents when a domain gets large enough that generalist agents make recurring mistakes.
- Each specialist should own a clear domain boundary with its own codebase area, test suite, and docs.
- Review agents emerge from compliance needs. Start without them and add as requirements crystallize.

## Findings Loop

- The same type of finding should decrease over time. If it does not, the refinement did not work.
- SM curates findings into refinements. The key metric is declining recurrence.
- Critical findings halt work. Normal findings accumulate for batch review.

## Metrics

- Agents log events via the metrics helper, never by writing JSON directly.
- FPY by boundary pair is the most actionable metric. It reveals which handoff boundaries need improvement.
- Cost per item trends down as context enrichment matures and model tiering is refined.

## Compliance Floor

- The compliance floor overrides all autonomy tiers, pace settings, and process decisions.
- Keep compliance floor rules short (3-5), absolute, and enforced by hooks where possible.
- "Compliance floor" encompasses security, data governance, audit, regulatory, access control, and domain-specific rules.
