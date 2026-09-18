import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/config/dependency_injection.dart';
import '../../../../core/theme/app_text_styles.dart';

/// Canonical /game/{slug} → community detail.
class GameBySlugScreen extends ConsumerStatefulWidget {
  const GameBySlugScreen({super.key, required this.slug});
  final String slug;

  @override
  ConsumerState<GameBySlugScreen> createState() => _GameBySlugScreenState();
}

class _GameBySlugScreenState extends ConsumerState<GameBySlugScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _resolve());
  }

  Future<void> _resolve() async {
    final client = ref.read(supabaseClientProvider);
    final row = await client
        .from('communities')
        .select('id')
        .eq('slug', widget.slug)
        .eq('is_archived', false)
        .maybeSingle();
    if (!mounted) return;
    if (row == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Game not found')),
      );
      context.go('/communities');
      return;
    }
    context.go('/community/${row['id']}');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 12),
            Text('Opening game…', style: AppTextStyles.caption),
          ],
        ),
      ),
    );
  }
}
