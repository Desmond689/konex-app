import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/dependency_injection.dart';
import '../../data/notification_repository.dart';
import '../../domain/notification_entity.dart';

final notificationRepositoryProvider = Provider((ref) {
  return NotificationRepository(ref.watch(supabaseClientProvider));
});

final notificationsListProvider =
    FutureProvider<List<NotificationEntity>>((ref) async {
  final r = await ref.watch(notificationRepositoryProvider).list();
  return r.valueOrNull ?? [];
});

final unreadNotificationsProvider = FutureProvider<int>((ref) async {
  final r = await ref.watch(notificationRepositoryProvider).unreadCount();
  return r.valueOrNull ?? 0;
});

final notificationPrefsProvider =
    FutureProvider<NotificationPreferences>((ref) async {
  final r = await ref.watch(notificationRepositoryProvider).getPreferences();
  return r.valueOrNull ?? const NotificationPreferences();
});
