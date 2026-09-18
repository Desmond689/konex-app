import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:postgrest/postgrest.dart';

import '../errors/result.dart';
import '../errors/error_handler.dart';

/// Base helpers for repositories that talk to Supabase.
mixin BaseRepository {
  Future<Result<T>> guard<T>(Future<T> Function() action) async {
    try {
      final value = await action();
      return Success(value);
    } catch (e, st) {
      return Failure(ErrorHandler.map(e, st), st);
    }
  }

  PostgrestTransformBuilder applyPagination(
    PostgrestFilterBuilder query, {
    required int page,
    required int pageSize,
  }) {
    final from = page * pageSize;
    final to = from + pageSize - 1;
    return query.range(from, to);
  }
}
