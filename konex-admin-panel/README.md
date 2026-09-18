# Konex Admin Panel

A standalone React + Vite web app for Konex staff — dashboard, report
queue, user management, game/community management, and audit log. Same
Supabase backend and `profiles.app_role` permission model as the Flutter
mobile app; no Flutter toolchain needed to build or deploy this.

## 1. Run it locally

```bash
npm install
cp .env.example .env   # fill in your Supabase project values
npm run dev
```

## 2. Apply the required database migration

This panel calls three RPCs that the mobile app's admin screens also call:
`admin_set_role`, `admin_set_ban`, and `admin_create_game`. Without them,
role changes, direct bans, and "Create game" fail with a Postgres
"function not found" error. They now ship as a migration — run

```
supabase/migrations/202608310002_admin_missing_rpcs.sql
```

(e.g. `supabase db push`, or paste it into the SQL editor) against your
project before using this panel or the mobile app's admin screens.

It also adds the P0 role-tiering the moderation review called for,
enforced server-side inside the RPC (both clients additionally hide
actions a given role can't perform, but the RPC is the real boundary):
- `moderator` can resolve reports, ban/restrict via the report flow, and
  manage games, but can't change anyone's role.
- `admin` can promote/demote between `user` and `moderator`, but not grant
  `admin`.
- `super_admin` can additionally grant `admin`.
- **`super_admin` itself can never be set or changed through the app**, by
  anyone — that has to be a direct database edit. Nobody can change their
  own role.

## 3. Give yourself access

```sql
update profiles set app_role = 'admin' where username = 'your_username';
```

Staff roles: `moderator`, `admin`, `super_admin`.

## 4. Deploy to Vercel

```bash
npm i -g vercel
vercel
```

Set `VITE_SUPABASE_URL` and `VITE_SUPABASE_ANON_KEY` as environment
variables in the Vercel project settings (Project Settings → Environment
Variables), matching your `.env`. The included `vercel.json` handles
client-side routing so refreshing `/reports` or `/games/:id` doesn't 404.

## What's included (parity with the Flutter admin app)

- **Login** — staff-only email/password sign-in, same Supabase auth.
- **Dashboard** — user/report/post/squad counts, quick links.
- **Report queue** — evidence shown inline (reporter, reason, details),
  action sheet (dismiss / remove content / warn / restrict / suspend /
  ban).
- **Users** — search by username or gamer name; change role, verify,
  ban/restore.
- **Games** — search/list all communities; create and edit (name,
  description, rules, category, logo upload, privacy, approval).
- **Audit log** — every staff action, filterable by action type, paginated.

## What's added beyond the Flutter app

- **Confirmation dialogs with a required reason** on ban, suspend,
  restrict, and remove-content — these were one-tap actions before. The
  reason is stored on both the `moderation_actions` and `audit_logs` rows.
- **Sidebar badge** showing the open-report count from anywhere in the app.
- **Client-side permission gating** (`src/lib/AuthContext.jsx`, the `can()`
  helper) so a moderator never even sees a "make admin" option — though as
  always, the real boundary is enforced in the database functions, not the
  UI.

## Known gaps carried over from the current backend

These were flagged in the moderation review and are backend work, not
something a frontend rewrite can fix on its own:

- **No single transaction for `resolveReport`.** It's still several
  sequential writes (update report → insert moderation_actions → insert
  audit_logs → update the target). A failure partway through can leave
  inconsistent state (e.g. a ban recorded with no audit entry). The fix is
  a `resolve_report(report_id, action, reason)` Postgres RPC that does the
  whole thing server-side in one transaction — same recommendation as the
  review notes. This app is built to swap in that RPC with a one-line
  change in `src/lib/hooks.js` (`resolveReport`) once it exists.
- **Audit logs are not append-only** — nothing stops staff with an
  authenticated Supabase session from calling `.update()`/`.delete()` on
  `audit_logs` directly if RLS allows it. Worth locking down at the
  database level (RLS: insert-only for staff, no update/delete grants).
- **No appeals flow, no per-user moderation history view, no soft-delete
  restore UI** — all P1/P2 items from the review; straightforward to add
  as new pages once you want them.

## Project structure

```
src/
  components/       Layout, ActionSheet, ConfirmDialog, Toast, RequireStaff
  lib/
    AuthContext.jsx  session + role + permission checks
    hooks.js         all Supabase reads/writes (mirrors admin_repository.dart)
  pages/
    Login, Dashboard, Reports, Users, Games, GameForm, Audit
  supabaseClient.js
  styles.css         design tokens shared with the konex-auth-site project
```
