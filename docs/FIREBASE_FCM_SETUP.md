# KONEX — Firebase Cloud Messaging (FCM HTTP v1) setup

## What the code already does

- Flutter: `Firebase.initializeApp`, permission, token → `device_tokens`, tap → deep link
- Edge Function: `supabase/functions/send-push` (FCM HTTP v1 + service account JWT)
- DB: trigger on `notifications` INSERT → calls `send-push` via `pg_net` (when URL configured)

## You must do in Firebase Console (cannot be automated)

### 1. Create project
1. Open https://console.firebase.google.com
2. **Add project** → name e.g. `konex-app`
3. Disable Google Analytics if you don’t need it (optional)

### 2. Add Android app
1. Project settings → **Add app** → Android
2. Android package name: must match `applicationId` in `android/app/build.gradle`  
   (often `com.konex.app` or similar — set this when you generate the Android folder with `flutter create .`)
3. Download **`google-services.json`**
4. Place at: `android/app/google-services.json`
5. In root `android/build.gradle` / settings, apply Google services plugin (FlutterFire docs)

### 3. Add iOS app
1. Add iOS app with your bundle id
2. Download **`GoogleService-Info.plist`** → `ios/Runner/`
3. Apple Developer: create **APNs key** (.p8) → Firebase → Project settings → Cloud Messaging → upload APNs key

### 4. Service account for Edge Function (HTTP v1)
1. Firebase / Google Cloud Console → **IAM & Admin** → **Service accounts**
2. Use the Firebase Admin SDK service account (or create one with role **Firebase Cloud Messaging Admin**)
3. **Keys** → Add key → JSON → download
4. Never commit this file to git

```bash
supabase secrets set FIREBASE_PROJECT_ID=your-project-id
supabase secrets set FIREBASE_SERVICE_ACCOUNT="$(cat path/to/service-account.json)"
supabase functions deploy send-push
```

### 5. Point DB trigger at your project
In Supabase SQL (as postgres):

```sql
alter database postgres set app.settings.supabase_url = 'https://YOUR_REF.supabase.co';
alter database postgres set app.settings.service_role_key = 'YOUR_SERVICE_ROLE_KEY';
```

Or use Supabase **Database Webhooks** (Dashboard → Database → Webhooks)  
on table `notifications` INSERT → URL `https://YOUR_REF.supabase.co/functions/v1/send-push`  
with service role Authorization header — often easier than `pg_net` settings.

### 6. FlutterFire (optional but recommended)
```bash
dart pub global activate flutterfire_cli
flutterfire configure
```
This generates `lib/firebase_options.dart` and wires platforms.

Then in `main.dart`:
```dart
await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
```

### 7. Test
1. Install app on a **real device** (emulators often weak for FCM)
2. Log in → allow notifications
3. Check row in `device_tokens`
4. Insert a test notification for that user, or:

```bash
curl -X POST 'https://YOUR_REF.supabase.co/functions/v1/send-push' \
  -H "Authorization: Bearer YOUR_SERVICE_ROLE_KEY_HERE" \
  -H "Content-Type: application/json" \
  -d '{"user_id":"USER_UUID","title":"Test","body":"Hello from KONEX","data":{"type":"system","route":"/notifications"}}'
```

## Push types (product)

Always / high: message, security, moderation, squad invite/request/approve/remove, reply, mention  
Pref-gated: like, comment, follow, repost, announcements, LFG  
Marketing: only if opted in

## Incoming calls (app killed / background)

When `call_participants` is inserted with status `ringing` or `invited`, migration `000025` POSTs to `send-push` with:

- `data.type` = `call_incoming`
- Android channel `konex_calls` (max importance + fullScreenIntent via local notification)
- Payload includes `call_id`

Flutter:
1. Background FCM handler shows a **call-category** local notification (`fullScreenIntent: true` on Android)
2. Tap / open app → `CallController.handleIncomingFromPush(callId)` → Incoming Call screen
3. Accept → same WebRTC flow as in-app

### Honest limits vs WhatsApp

| Capability | KONEX (this setup) | WhatsApp |
|------------|--------------------|----------|
| Notify when app killed | Yes (FCM + local notif) | Yes |
| Android full-screen over lock | Often yes (OEM-dependent) | Yes |
| iOS native CallKit green bar / lock screen call UI | **Not yet** (needs PushKit + CallKit) | Yes |
| Ring if user disabled notifications | No | Limited |

**iOS true CallKit** is a separate native module (VoIP push certificate, `flutter_callkit_incoming` or similar). Ship Android + FCM alert first; add CallKit before App Store positioning as “phone-like calls”.

### Required for calls to work outside the app

1. Firebase + `device_tokens` working (same as other pushes)
2. `supabase db push` including migration **25**
3. `app.settings.supabase_url` + service role **or** Database Webhook on `call_participants` INSERT
4. Real device test with app **force-stopped**, then place a DM call from another account
