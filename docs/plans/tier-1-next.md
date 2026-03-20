# Tier 1: Next Up

Items ready for near-term work. These emerged from v0.2.x development and are tracked here for prioritization.

## Open Items

- [ ] **Targeted guidance delivery** — Role-specific guidance with layered depth (summary for most, detail for specialists). The CKO owns design. Fleet-wide registry (Tier 3) is implemented; targeted delivery is the next step. See `docs/superpowers/specs/2026-03-19-cx-governance-framework-design.md` § Targeted Guidance.

- [ ] **Instrumentation dashboard** — Scalable way to surface all metrics through a dashboard. Design how to collect, aggregate, and display DORA, flow quality, compliance, governance, and pathway metrics in one view. CFO + platform-ops collaboration.

- [ ] **StatsD backend implementation** — `ops/metrics-log.sh` supports the backend config but falls back to JSONL. Implement actual StatsD dispatch. See `docs/METRICS-GUIDE.md` § Configuring the Backend.

- [ ] **OpenTelemetry backend implementation** — Same as StatsD — implement actual OTEL span/metric export.

- [ ] **Sentinel file bypass improvement** — Replace sentinel file mechanism with direct caller check if Claude Code adds `$CLAUDE_AGENT_NAME` or `$CLAUDE_SKILL_NAME` to hook context. See `docs/superpowers/specs/2026-03-19-governance-layer-design.md` § Deferred Concerns.

- [ ] **Real-world validation** — Replace simulated example data in Metrics Guide, Pathway Analysis Guide, and README with real data from production fleet usage. Remove _(simulated)_ indicators once validated.

- [ ] **COLLABORATION.md length** — File is approaching readability limits (now ~700 lines with governance additions). Evaluate splitting into focused sub-documents while maintaining cross-references. Tracked as deferred concern #3 in COLLABORATION.md.
