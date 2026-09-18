# KONEX App Links / Universal Links

## Canonical hosts
- https://konex-app-rho.vercel.app
- https://konex-app-rho.vercel.app

## Android App Links
1. Host Digital Asset Links at:
   `https://konex-app-rho.vercel.app/.well-known/assetlinks.json`
2. In `AndroidManifest.xml` activity add intent-filters (see `docs/android_intent_filters.xml`).
3. Package name must match your release signing cert SHA-256.

## iOS Universal Links
1. Host Apple App Site Association at:
   `https://konex-app-rho.vercel.app/.well-known/apple-app-site-association`
2. Enable Associated Domains: `applinks:konex-app-rho.vercel.app`
3. See `docs/apple_app_site_association.json`

## Open Graph (web fallback)
Landing pages for `/u/*`, `/game/*`, `/squad/*`, `/post/*` should emit:
- og:title, og:description, og:image, og:url
Never include private content in OG tags.

## In-app
`DeepLinkParser` + `DeepLinkRouter` handle paths after OS hands off the URL.
