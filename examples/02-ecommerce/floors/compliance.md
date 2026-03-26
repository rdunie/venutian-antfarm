# Compliance Floor -- E-Commerce Platform

Non-negotiable rules that override all autonomy tiers, pace settings, and process decisions.

## Rules

1. **No credit card data in our systems.** All payment data flows through Stripe's hosted fields and API. We never see, store, or transmit raw card numbers, CVVs, or expiration dates. PCI DSS scope is minimized to SAQ A.

2. **Authentication on every endpoint.** No API endpoint is accessible without authentication. Admin operations require role-based authorization. No anonymous access to data-modifying operations.

3. **All data changes are auditable.** Every create, update, and delete operation on orders, inventory, and customer data must produce an audit log entry (who, what, when, from where). Audit logs are append-only.

4. **Personal data requires consent tracking.** Customer email, address, phone, and purchase history are personal data under GDPR. Collection and processing must be linked to a consent record. Marketing communications require separate opt-in consent.

5. **No sensitive data in logs or external services.** Customer PII, payment references, and session tokens must not appear in application logs, error messages, or data sent to analytics/monitoring services. Use structured logging with PII-safe field definitions.

## Enforcement

- Rule 1: PreToolUse hook blocks any code that imports raw Stripe card handling
- Rule 2: API test suite validates auth middleware on every endpoint
- Rule 3: Audit middleware integration test verifies log entries on all write operations
- Rule 5: Log format validation in CI pipeline scans for PII patterns
