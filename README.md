# KONEX — complete roadmap batches 1–13

Gaming-first social for gamers (Cameroon → global).

This branch is synced for GitHub Actions APK builds. The workflow is configured to build a release APK on push and to upload it as an artifact.

### APK build configuration

The `Build APK` workflow requires these GitHub repository secrets:

- `SUPABASE_URL`
- `SUPABASE_ANON_KEY` (the client-safe anon/public or publishable key, never a `service_role` key)

Configure them in **Repository Settings → Secrets and variables → Actions**. The workflow intentionally fails when either secret is missing or still a placeholder; it must not produce an APK with invalid Supabase configuration.

## Batches summary

| # | Name | Highlights |
|---|------|------------|
| 1 | Foundation | Auth, env, RLS profiles |
| 2 | Social core | Posts, feed, communities |
| 3 | Discovery | Search, report, saved, nav |
| 4 | Squads | Create, approve, members |
| 5 | Messaging | Inbox, DMs, Realtime |
| 6 | LFG / polls / badges | Structured LFG, polls |
| 7 | Video | Edge Function + player |
| 8 | Notifications | In-app + prefs + triggers |
| 9 | Admin | Reports, users, audit |
| 10 | Performance | Compression, Data Saver, video pool |
| **11** | **Security** | Pinning hooks, biometric, deep-link sanitize, CI (gitleaks), rate-limit FN, obfuscation docs |
| **12** | **Tournaments** | Free-only events, entries, brackets schema — **no payments/wallet** |
| **13** | **Due diligence** | Checklists, load test notes, store compliance |

## Migrations

Apply all files in `supabase/migrations/` in order (01 → 11).

## Edge Functions

- `create-video-upload`
- `rate-limit-check`

## Critical production rules

- **Never** ship service-role, api.video, or Stripe secret keys in the app
- Tournaments are free community events
- Pen test before serious handover

## Setup

```bash
cp .env.example .env
flutter create .
flutter pub get
flutter run
```

Staff: `update profiles set app_role = 'admin' where username = '...'`

See `docs/DUE_DILIGENCE.md` for the buyer checklist.
