import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp();
  } catch (_) {}
}

class PushNotificationService {
  PushNotificationService(this._client);

  final SupabaseClient _client;
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  bool _started = false;

  Future<void> start({
    required void Function(String route) onOpenRoute,
    required void Function(String callId) onIncomingCall,
  }) async {
    if (kIsWeb || _started) return;

    try {
      await Firebase.initializeApp();
    } catch (e) {
      debugPrint('Firebase init skipped: $e');
      return;
    }

    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    final token = await _messaging.getToken();
    if (token != null) {
      await _saveToken(token);
    }
    _messaging.onTokenRefresh.listen(_saveToken);

    FirebaseMessaging.onMessage.listen((message) {
      final data = message.data;
      if (data['type'] == 'call_incoming') {
        final callId = data['call_id']?.toString();
        if (callId != null && callId.isNotEmpty) {
          onIncomingCall(callId);
        }
      }
    });

    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      final data = message.data;
      if (data['type'] == 'call_incoming') {
        final callId = data['call_id']?.toString();
        if (callId != null && callId.isNotEmpty) {
          onIncomingCall(callId);
          return;
        }
      }
      final route = data['route']?.toString();
      if (route != null && route.isNotEmpty) {
        onOpenRoute(route);
      }
    });

    _started = true;
  }

  Future<void> clearToken() async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) return;
      await _client.from('device_tokens').delete().eq('user_id', userId);
    } catch (e) {
      debugPrint('clearToken failed: $e');
    }
  }

  Future<void> _saveToken(String token) async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) return;
      await _client.from('device_tokens').upsert({
        'user_id': userId,
        'token': token,
        'platform': (!kIsWeb && Platform.isIOS) ? 'ios' : 'android',
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });
    } catch (e) {
      debugPrint('save FCM token failed: $e');
    }
  }
}