import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

/// Keeps `profiles.last_seen` current for the signed-in user while the app
/// is in the foreground, via the `touch_presence` RPC (migration
/// 202608300005_profile_presence.sql). This is what "online" status
/// throughout the app (profile avatar dot, story rings) is actually based
/// on — there is no other presence signal.
class PresenceService {
  PresenceService(this._client);
  final SupabaseClient _client;

  Timer? _timer;
  static const _interval = Duration(seconds: 60);

  Future<void> _touch() async {
    if (_client.auth.currentUser == null) return;
    try {
      await _client.rpc('touch_presence');
    } catch (_) {
      // Best-effort — a missed heartbeat just means the next one (or the
      // last_seen threshold) covers it. Never worth surfacing to the user.
    }
  }

  /// Call on app start and every foreground resume.
  void start() {
    _touch();
    _timer?.cancel();
    _timer = Timer.periodic(_interval, (_) => _touch());
  }

  /// Call when the app goes to the background — no point heartbeating
  /// while the user can't actually be "using" it.
  void stop() {
    _timer?.cancel();
    _timer = null;
  }
}
