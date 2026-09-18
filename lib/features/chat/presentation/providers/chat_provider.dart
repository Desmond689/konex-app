import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/dependency_injection.dart';
import '../../data/datasources/chat_remote_data_source.dart';
import '../../data/repositories/chat_repository_impl.dart';
import '../../domain/entities/chat_entity.dart';

final chatRemoteProvider = Provider((ref) {
  return ChatRemoteDataSource(ref.watch(supabaseClientProvider));
});

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  return ChatRepositoryImpl(ref.watch(chatRemoteProvider));
});

final inboxProvider = FutureProvider<List<ConversationEntity>>((ref) async {
  final r = await ref.watch(chatRepositoryProvider).listInbox();
  return r.valueOrNull ?? [];
});
