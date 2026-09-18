# Konex — landing + auth callback site

A small React + Vite site for **Konex**:

Deploy from the repository `main` branch with Vercel's Root Directory set to
`konex-auth-site`.

- `/` — landing page with the logo, a short pitch, Android APK download, and installation instructions
- `/about` — About Konex, its vision, features, and download links
- `/auth/callback` — the page Supabase redirects to after someone taps an
  email confirmation link. Shows **"Email verified successfully"** on
  success, a clear error state on a bad/expired link, and buttons to open
  the app or download it.
- everything else (`/invite/...`, `/profile/...`, `/post/...`, `/party/...`,
  or any other in-app link you share) — a generic deep-link handler that
  tries to hand the visitor off to the Konex app, and falls back to the
  App Store / Play Store if it isn't installed. See **"Deep links"** below.

## 1. Run it locally

You need [Node.js](https://nodejs.org) 18+.

```bash
npm install
cp .env.example .env   # then fill in your Supabase values (see below)
npm run dev
```

Open the printed `localhost` URL. Visit `/auth/callback` directly in dev to
see the pending/error states (it'll show an error until it has real
Supabase params in the URL, which is expected).

## 2. Connect it to your Supabase project

1. In the [Supabase dashboard](https://supabase.com/dashboard) → your
   project → **Project Settings → API**, copy the **Project URL** and
   **anon public key** into `.env`:

   ```
   VITE_SUPABASE_URL=https://YOUR-PROJECT-REF.supabase.co
   VITE_SUPABASE_ANON_KEY=your-anon-public-key
   ```

2. In **Authentication → URL Configuration**, set:
   - **Site URL** → `https://your-domain.com`
   - **Redirect URLs** → add `https://your-domain.com/auth/callback`
     (and `http://localhost:5173/auth/callback` while developing)

3. That's it — Supabase appends the confirmation token to that URL as
   either `?token_hash=...&type=signup`, `?code=...` (PKCE), or an
   `#access_token=...` fragment depending on your auth settings. The
   callback page in `src/pages/AuthCallback.jsx` already handles all
   three shapes.

If your mobile app should open automatically after verification, update
`APP_DEEP_LINK` near the top of `AuthCallback.jsx` to your app's real
URL scheme (and set up Universal Links / App Links if you want it to
happen without an OS prompt).

## 3. Deep links (invite / profile / post / party / etc.)

Any link that isn't `/` or `/auth/callback` is caught by
`src/pages/DeepLink.jsx`. When someone taps a link like

```
https://konex-app-rho.vercel.app/invite/abc123?ref=xyz
https://konex-app-rho.vercel.app/profile/shadow99
https://konex-app-rho.vercel.app/party/9f8s
```

the page:

1. Immediately tries `konex://invite/abc123?ref=xyz` (same path, custom
   scheme) to hand off to the app.
2. Watches whether the browser tab loses focus (a sign the OS switched to
   the app). If it doesn't within ~1.4s, and the visitor is on iOS/Android,
   it redirects to the App Store / Play Store instead.
3. On desktop (no app to open), it just shows "Open in Konex app" / store
   buttons rather than guessing.

The copy shown while redirecting ("You're invited", "Opening a profile",
etc.) is keyed off the first path segment in `src/utils/linkTypes.js` —
add an entry there any time you introduce a new kind of shareable link.

**For this to work, your app needs to register the `konex://` URL scheme:**
- iOS: add it under `CFBundleURLTypes` in `Info.plist`
- Android: add an `<intent-filter>` with `android:scheme="konex"` in the manifest

Custom URL schemes are the simplest option and are what this project uses
by default, but they show an OS "Open in Konex?" confirmation prompt and
don't work at all if the app isn't installed until the store fallback
kicks in. For a more polished, prompt-free experience later on, upgrade to
**Universal Links** (iOS) and **App Links** (Android) — they use your
actual `https://` domain instead of a custom scheme, so the same URLs in
this project would work without any code changes here, just app-side
configuration (an `apple-app-site-association` file and a Digital Asset
Links JSON file served from this domain).

## 4. Deploy over HTTPS

Any static host works since this builds to plain HTML/JS/CSS. Two easy,
free options that give you HTTPS automatically:

**Vercel** (a `vercel.json` rewrite is already included for client-side routing)
```bash
npm i -g vercel
vercel
```

**Netlify** (a `public/_redirects` file is already included)
```bash
npm i -g netlify-cli
netlify deploy --prod
```

For either, set the same `VITE_SUPABASE_URL` / `VITE_SUPABASE_ANON_KEY`
as environment variables in the host's dashboard, then point your
Supabase **Redirect URLs** at the live `https://.../auth/callback` URL.

To build manually for any other static host:

```bash
npm run build   # outputs to dist/
```

## Project structure

```
src/
  components/
    Logo.jsx               logo mark
    ConstellationField.jsx  background node/graph pattern
  pages/
    Landing.jsx             marketing/landing page
    AuthCallback.jsx        handles Supabase email confirmation
  supabaseClient.js         Supabase client (reads .env)
  App.jsx                   routes: "/" and "/auth/callback"
  styles.css                design tokens + all styling
```
