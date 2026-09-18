# Deep Links Integration — Konex App

Your Konex Flutter app is now fully wired to handle deep links from the auth-site and any other source using the `konex://` URL scheme.

## What's Changed

### 1. **Android Manifest** (`android/app/src/main/AndroidManifest.xml`)
✅ Updated the intent-filter to catch **all** `konex://` links (not just auth):
```xml
<intent-filter>
    <action android:name="android.intent.action.VIEW" />
    <category android:name="android.intent.category.DEFAULT" />
    <category android:name="android.intent.category.BROWSABLE" />
    <data android:scheme="konex" />
</intent-filter>
```

### 2. **iOS Config** (`ios/Runner/Info.plist`)
✅ Already registered—was already there:
```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleTypeRole</key>
        <string>Editor</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>konex</string>
        </array>
    </dict>
</array>
```

### 3. **App Deep Link Handler** (`lib/app.dart`)
✅ Updated `_openLink()` to handle all `konex://` URLs:
- Converts `konex://invite/abc123` → `https://konex-app-rho.vercel.app/invite/abc123`
- Parses through existing `DeepLinkParser` (already supports all link types)
- Routes to the appropriate screen based on link type

## How It Works

1. **User clicks a shareable link** from the auth-site (or anywhere)
   - Web: `https://konex-app-rho.vercel.app/invite/abc123`
   - Mobile in-app: `konex://invite/abc123`

2. **If app is installed**, the OS hands off `konex://invite/abc123` to Konex
3. **App receives it** in `_openLink()`, converts to https, and routes it
4. **Already-handled link types** (no code needed):
   - `/profile/:username` or `/u/:username`
   - `/game/:slug`
   - `/squad/:id` or `/squad/:slug`
   - `/post/:id`
   - `/lfg/:id`
   - `/tournament/:id` or `/event/:id`
   - `/invite/squad/:token`
   - `/invite/community/:token`

## To Add New Link Types

1. Add to `DeepLinkType` enum in `lib/core/deep_links/deep_link_models.dart`
2. Add routing logic in `DeepLinkTarget.routePath` getter
3. Add parser case in `lib/core/deep_links/deep_link_parser.dart`

Example: adding a "party" invite type:
```dart
// deep_link_models.dart
enum DeepLinkType {
  // ... existing types ...
  partyInvite,
}

// In routePath getter:
case DeepLinkType.partyInvite:
  return token != null ? '/invite/party/$token' : '/';

// deep_link_parser.dart, in parse():
case 'invite':
  if (b == 'party' && c != null) {
    return DeepLinkTarget(
      type: DeepLinkType.partyInvite,
      token: c,
      rawPath: uri.path,
    );
  }
```

## Testing

### Local Testing (iOS/Android)
1. Build and run the app
2. Open a terminal and test with:
   ```bash
   # iOS Simulator
   xcrun simctl openurl booted "konex://profile/shadow99"
   
   # Android Emulator
   adb shell am start -W -a android.intent.action.VIEW -d "konex://profile/shadow99"
   ```

### With Web (auth-site)
1. Deploy auth-site to Vercel
2. Share a link like `https://konex-app-rho.vercel.app/invite/abc123`
3. On mobile:
   - If Konex is installed, the link will hand off to the app
   - If not, it shows the fallback UI with App Store / Play Store buttons
4. On desktop, it shows manual action buttons

## Integration with auth-site

The [konex-auth-site](../konex-auth-site) provides:
- **DeepLink.jsx**: Catches shared links and attempts to hand off to app via `konex://` scheme
- **linkTypes.js**: Maps link types to user-friendly copy ("You're invited", "Opening a profile", etc.)
- **platform.js**: Detects iOS vs Android vs desktop

**No changes needed there**—it already works with your app's config.

## Future: Universal Links / App Links

Currently, the `konex://` scheme works but shows an OS prompt ("Open in Konex?").

To go **prompt-free**, configure:
- **iOS**: Universal Links (requires `.well-known/apple-app-site-association` on `https://konex-app-rho.vercel.app`)
- **Android**: App Links (requires `.well-known/assetlinks.json` on `https://konex-app-rho.vercel.app`)

This is app-side config only—**no Dart code changes needed**. The website just needs to serve the JSON files from `/.well-known/`.

---

**Status**: ✅ Deep links are fully wired and ready to test.
