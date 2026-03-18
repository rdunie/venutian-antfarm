#!/usr/bin/env bash
# Deploy contract -- implementers replace this with their deployment logic.
# Usage: deploy.sh <env> <component> [--type planned|hotfix]
# Exit 0 = success, exit 1 = failure
# stdout should include deployment URL or identifier
set -euo pipefail

if [ $# -lt 2 ]; then
  echo "Usage: deploy.sh <env> <component> [--type planned|hotfix]" >&2
  exit 1
fi

ENV="$1"
COMPONENT="$2"
DEPLOY_TYPE="planned"

shift 2
while [[ $# -gt 0 ]]; do
  case "$1" in
    --type) DEPLOY_TYPE="$2"; shift 2 ;;
    *) echo "Unknown flag: $1" >&2; exit 1 ;;
  esac
done

echo "DEPLOY STUB: Would deploy '$COMPONENT' to '$ENV' (type: $DEPLOY_TYPE)"
echo "Replace this script with your actual deployment logic."
echo ""
echo "Contract:"
echo "  - Exit 0 = success"
echo "  - Exit 1 = failure"
echo "  - stdout = deployment URL or identifier"
echo ""
echo "deployment_id=stub-$(date +%s)"
