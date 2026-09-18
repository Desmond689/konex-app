# QA: "Looks done but isn't wired" pass

## Security / RLS
- [x] Migration 17 + 18 applied (WITH CHECK + triggers + admin RPCs)
- [x] Profile report → showReportDialog → reports table
- [x] Admin set role / ban via admin_set_role / admin_set_ban RPCs

## Profile
- [x] Followers / Following lists
- [x] Privacy settings
- [x] Squad tag → /squad/:id
- [x] Games chips (3 + more)
- [x] Share profile → KonexLinks

## Home
- [x] For You / Following / Latest
- [x] My Games filter bar
- [x] Create post FAB

## Search
- [x] All tabs + debounce + recent history
- [x] Trending games RPC
- [x] Results navigate to real routes

## Share / Deep links
- [x] ShareService sheet (copy / OS / Send on KONEX)
- [x] Parser + routes: /u /game /squad /post /invite/squad
- [x] OG edge function og-preview
- [ ] Production: host assetlinks + AASA + proxy crawlers to og-preview

## Squads
- [x] One membership rule
- [x] Invite token create/redeem
- [x] Share squad

## Known residual (not fake UI)
- Certificate pins empty (intentional until release certs)
- rate-limit-check in-memory only
- Send on KONEX requires existing chats
- Tournament brackets still staff-manual
