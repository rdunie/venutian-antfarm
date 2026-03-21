# Compliance Floor — Fintech API

Non-negotiable rules that override all autonomy tiers, pace settings, and process decisions.

## Rules

1. **No plaintext financial data at rest.** Account numbers, routing numbers, balances, and transaction records are encrypted at rest. Key management uses a dedicated KMS, not application-level secrets.

2. **All API mutations are idempotent.** Financial operations (transfers, charges, refunds) must be idempotent with client-provided idempotency keys. No duplicate transactions from retries.

3. **Audit trail on all financial operations.** Every transaction, balance change, and account modification produces an immutable audit entry. Audit retention: 7 years.

4. **Plan before build.** Non-trivial work items must have an approved plan before implementation begins.

5. **No direct database writes.** All data mutations go through the application's service layer. No raw SQL in application code, no migration scripts that bypass the ORM for business data.

## Enforcement

- Rule 1: Integration tests verify encryption on all financial data storage paths
- Rule 2: Idempotency test suite verifies every mutation endpoint
- Rule 3: Audit middleware integration test on every write endpoint
- Rule 5: Code review checks for raw SQL outside of migrations
