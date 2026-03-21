#!/usr/bin/env bash
# Getting Started deploy stub — echoes what it would do.
set -euo pipefail

ENV="${1:-dev}"
COMPONENT="${2:-app}"

echo "=== Deploy ==="
echo "Environment: $ENV"
echo "Component:   $COMPONENT"
echo ""
echo "Would run:"
echo "  1. Build $COMPONENT"
echo "  2. Test $COMPONENT"
echo "  3. Deploy to $ENV"
echo ""
echo "deployment_id=gs-${ENV}-${COMPONENT}-$(date +%s)"
