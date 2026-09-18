# KONEX Technical Due Diligence Checklist (Batch 13)

## Security
- [ ] RLS enabled on **every** table; policies in git migrations
- [ ] No service-role / api.video / Stripe secret keys in client bundle
- [ ] Secrets scanning in CI (gitleaks) — `.github/workflows/ci.yml`
- [ ] Certificate pinning configured for production hosts
- [ ] Release builds obfuscated (`--obfuscate --split-debug-info=`)
- [ ] Biometric optional lock before payment/KYC actions
- [ ] Deep links sanitized (`DeepLinkSanitizer`)
- [ ] Rate limiting on auth, tournament entry, payout Edge Functions
- [ ] Third-party penetration test completed and remediated

## Data & backend
- [ ] Staging Supabase project fully separate from production
- [ ] Automated backups + **tested restore drill** documented
- [ ] Audit logs for admin/moderation actions
- [ ] Storage bucket policies reviewed (avatars, post-images)
- [ ] Realtime enabled only on required tables; connection limits understood

## Product / compliance
- [ ] Legal review for real-money tournaments in target markets
- [ ] Apple/Google policies on skill contests / gambling reviewed before store submit
- [ ] Tournaments are free — no KYC/payout required in current product model
- [ ] Incident response plan (`docs/INCIDENT_RESPONSE_STUB.md` expanded)

## Quality
- [ ] Meaningful tests on auth, payments, tournament entry paths
- [ ] Crash reporting (Sentry/Crashlytics) in production
- [ ] Load test: concurrent tournament traffic + Realtime channels
- [ ] Architecture + RLS policy docs available to buyer

## Ops rehearsal
- [ ] Staging → production deploy checklist executed
- [ ] Rollback plan tested
- [ ] Key rotation procedure practiced once

## Documents in this repo
- `docs/ARCHITECTURE.md`
- `docs/INCIDENT_RESPONSE_STUB.md`
- `docs/DUE_DILIGENCE.md` (this file)
- `docs/LOAD_TEST.md`
- `docs/STORE_COMPLIANCE.md`
