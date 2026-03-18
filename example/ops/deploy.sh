#!/usr/bin/env bash
# Example deploy script for the e-commerce platform.
# This is a stub that echoes what it would do.
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

echo "=== E-Commerce Deploy ==="
echo "Environment: $ENV"
echo "Component:   $COMPONENT"
echo "Type:        $DEPLOY_TYPE"
echo ""
echo "Would run:"
echo "  1. npm run build ($COMPONENT)"
echo "  2. npm run test ($COMPONENT)"
echo "  3. docker build -t ecommerce-$COMPONENT:latest ."
echo "  4. kubectl apply -f k8s/$ENV/$COMPONENT.yaml"
echo "  5. kubectl rollout status deployment/$COMPONENT -n $ENV"
echo ""
echo "deployment_id=ecom-${ENV}-${COMPONENT}-$(date +%s)"
