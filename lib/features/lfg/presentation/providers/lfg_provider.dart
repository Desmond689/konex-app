import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/dependency_injection.dart';
import '../../data/lfg_repository.dart';
import '../../domain/lfg_entity.dart';

final lfgRepositoryProvider = Provider((ref) {
  return LfgRepository(ref.watch(supabaseClientProvider));
});

final openLfgProvider = FutureProvider.family<List<LfgEntity>, String?>((ref, game) async {
  final r = await ref.watch(lfgRepositoryProvider).listOpenLfg(gameName: game);
  return r.valueOrNull ?? [];
});
