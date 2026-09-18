package com.example.konex

import io.flutter.embedding.android.FlutterFragmentActivity

// local_auth's Android implementation needs a FragmentActivity to host the
// biometric prompt (it calls FragmentActivity.getSupportFragmentManager()
// under the hood). A plain FlutterActivity doesn't provide that, so every
// authenticate() call fails silently on this device.
class MainActivity : FlutterFragmentActivity()
