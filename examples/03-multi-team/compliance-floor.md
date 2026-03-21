# Compliance Floor — SaaS Platform

Non-negotiable rules that override all autonomy tiers, pace settings, and process decisions.

## Rules

1. **Tenant data isolation.** Every database query must be scoped to the requesting tenant. No cross-tenant data leakage.

2. **No secrets in code.** API keys, passwords, and tokens must use environment variables, never hardcoded values.

3. **Security review before staging.** No code reaches staging or prod without passing security-reviewer assessment.

4. **Plan before build.** Non-trivial work items must have an approved plan before implementation begins.

## Enforcement

- Rule 1: Integration tests validate tenant scoping on every query path
- Rule 3: Deploy script checks for security-reviewer approval before staging/prod
