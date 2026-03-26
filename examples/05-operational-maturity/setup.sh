#!/usr/bin/env bash
# Seeds metrics events to simulate a project with history.
# This gives ops/dora.sh something meaningful to display.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Find metrics-log.sh relative to the worktree root
WORKTREE_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
METRICS_LOG="$WORKTREE_ROOT/ops/metrics-log.sh"

if [[ ! -x "$METRICS_LOG" ]]; then
  echo "Warning: ops/metrics-log.sh not found or not executable at $METRICS_LOG" >&2
  echo "Metrics seeding skipped. The example is still usable." >&2
  exit 0
fi

mkdir -p "$WORKTREE_ROOT/.claude/metrics"

cd "$WORKTREE_ROOT"

# Simulate 8 completed items with realistic event sequence
for i in $(seq 1 8); do
  "$METRICS_LOG" item-promoted "$i"
  "$METRICS_LOG" item-accepted "$i"
done

# A couple of bugs found and fixed (items 3 and 6)
"$METRICS_LOG" bug-found 3 --severity medium --source review
"$METRICS_LOG" bug-fixed 3
"$METRICS_LOG" bug-found 6 --severity low --source testing
"$METRICS_LOG" bug-fixed 6

# Cross-specialist handoffs
"$METRICS_LOG" handoff-sent 4 --from backend-specialist --to e2e-test-engineer
"$METRICS_LOG" handoff-sent 5 --from frontend-specialist --to backend-specialist
"$METRICS_LOG" handoff-sent 7 --from backend-specialist --to frontend-specialist

echo ""
echo "Seeded: 8 completed items, 2 bug cycles, 3 handoffs"

# Compile governance floors
if command -v gomplate &>/dev/null; then
  echo "Compiling governance floors..."
  bash "$WORKTREE_ROOT/ops/compile-floor.sh" \
    "examples/05-operational-maturity/floors/compliance.md" \
    ".claude/floors/compliance/compiled"
  bash "$WORKTREE_ROOT/ops/compile-floor.sh" \
    "examples/05-operational-maturity/floors/behavioral.md" \
    ".claude/floors/behavioral/compiled"
  echo "Compiled: compliance + behavioral floors"
else
  echo "Note: gomplate not installed — skipping floor compilation"
fi

echo "Run: ops/dora.sh to see the dashboard"
