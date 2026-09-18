# KONEX Architecture (Phase 1)

## Layers

```
lib/
├── main.dart / app.dart
├── core/           # shared, feature-agnostic
│   ├── config/     # AppConfig, env behavior, constants, DI
│   ├── errors/     # AppException hierarchy + Result + ErrorHandler
│   ├── network/    # BaseRepository, network info
│   ├── router/     # go_router + AuthGuard
│   ├── services/   # connectivity, (later: notifications, upload)
│   ├── storage/    # secure + local + SessionManager
│   ├── theme/
│   ├── utils/
│   └── widgets/    # KxButton, KxTextField, empty/error/loading
└── features/
    └── auth/       # data | domain | presentation | services
        ├── data/datasources + repositories
        ├── domain/entities + repositories + usecases
        ├── models/
        ├── presentation/providers + screens + widgets
        └── services/
```

Other features (`feed`, `communities`, `squads`, `chat`, …) follow the same layout as they are implemented.

## Auth flow

1. `AppConfig.initialize()` loads `.env` (anon key only).
2. `Supabase.initialize` with PKCE.
3. Splash → validate session via `SessionManager` → login or onboarding or home.
4. Sign-up writes `auth.users` + upserts `profiles` (trigger also creates profile).
5. Onboarding updates `profiles` + `user_games`.
6. Tokens stored in `FlutterSecureStorage`; cleared on sign-out.

## Security principles

- Mobile client is **untrusted**.
- RLS is the source of truth for authorization.
- Secrets stay on Edge Functions / server only.
- Prefer uniqueness constraints in Postgres (username, likes, follows, votes).

## Environments

| APP_ENV     | Supabase project | Logging | Pinning |
|-------------|------------------|---------|---------|
| development | DEV project      | on      | off     |
| staging     | STAGING project  | on      | on      |
| production  | PROD project     | off*    | on      |

\* Crash reporting still enabled in production when integrated.
