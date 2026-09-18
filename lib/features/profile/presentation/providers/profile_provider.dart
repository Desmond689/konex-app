import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/dependency_injection.dart';
import '../../data/datasources/profile_remote_data_source.dart';
import '../../data/repositories/profile_repository_impl.dart';
import '../../domain/entities/profile_entity.dart';
import '../../domain/repositories/profile_repository.dart';

final profileRemoteProvider = Provider<ProfileRemoteDataSource>((ref) {
  return ProfileRemoteDataSource(ref.watch(supabaseClientProvider));
});

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepositoryImpl(ref.watch(profileRemoteProvider));
});

final myProfileProvider = FutureProvider<ProfileEntity?>((ref) async {
  final r = await ref.watch(profileRepositoryProvider).getMyProfile();
  return r.valueOrNull;
});

final profileByIdProvider =
    FutureProvider.family<ProfileEntity?, String>((ref, userId) async {
  final r = await ref.watch(profileRepositoryProvider).getProfile(userId);
  return r.valueOrNull;
});
