import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/dependency_injection.dart';
import '../data/social_repository_impl.dart';
import '../domain/social_repository.dart';

final socialRepositoryProvider = Provider<SocialRepository>((ref) {
  return SocialRepositoryImpl(ref.watch(supabaseClientProvider));
});
