# Compliance Floor — Health Data Platform

Non-negotiable rules that override all autonomy tiers, pace settings, and process decisions.

## Rules

1. **All PHI is encrypted.** Protected Health Information must be encrypted at rest (AES-256) and in transit (TLS 1.2+). No plaintext PHI in any storage layer, message queue, or API response.

2. **Minimum necessary access.** Every data access must be scoped to the minimum data required for the operation. No bulk PHI exports without explicit authorization and audit trail.

3. **Audit every PHI access.** Every read, write, or delete of PHI produces an immutable audit log entry: who, what, when, why, from where. Audit logs are retained for 6 years minimum.

4. **No PHI in logs or external services.** PHI must not appear in application logs, error messages, monitoring dashboards, or data sent to third-party services. Use tokenized identifiers.

5. **Plan before build.** All work items must have an approved plan before implementation. No exceptions in a regulated domain.

6. **Security review on every change.** All code changes require security-reviewer assessment before merging. No fast-track bypasses.

7. **BAA required for third-party services.** No PHI may be processed by or transmitted to any third-party service without a signed Business Associate Agreement on file.

## Enforcement

- Rule 1: Integration tests verify encryption on all PHI storage and transmission paths
- Rule 3: Audit middleware integration test on every write endpoint
- Rule 4: Log format validation scans for PHI patterns in CI
- Rule 6: Deploy script checks for security-reviewer approval
- Rule 7: Third-party integration checklist includes BAA verification
