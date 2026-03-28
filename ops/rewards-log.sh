#!/usr/bin/env bash
# DEPRECATED: Use ops/feedback-log.sh instead. This shim will be removed in a future version.
echo "WARNING: ops/rewards-log.sh is deprecated. Use ops/feedback-log.sh instead." >&2
exec "$(cd "$(dirname "$0")" && pwd)/feedback-log.sh" "$@"
