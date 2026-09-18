import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../domain/entities/story_entity.dart';
import '../providers/story_provider.dart';
import '../screens/create_story_screen.dart';
import '../screens/story_viewer_screen.dart';

class StoriesRow extends ConsumerWidget {
  const StoriesRow({super.key, this.showWatchAll = true});

  final bool showWatchAll;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(homeStoryRingsProvider);

    return async.when(
      loading: () => const SizedBox(
        height: 110,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      error: (e, _) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            const Icon(Icons.error_outline, size: 18, color: AppColors.textMuted),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Stories unavailable',
                style: AppTextStyles.caption,
              ),
            ),
            TextButton(
              onPressed: () => ref.invalidate(homeStoryRingsProvider),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
      data: (rings) {
        if (rings.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Row(
                children: [
                  Text('Stories', style: AppTextStyles.title.copyWith(fontSize: 16)),
                  const Spacer(),
                  if (showWatchAll)
                    GestureDetector(
                      onTap: () {
                        // Open first non-empty ring
                        final viewable = rings.where((r) => r.hasStories).toList();
                        if (viewable.isNotEmpty) {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => StoryViewerScreen(
                                rings: viewable,
                                initialRingIndex: 0,
                              ),
                            ),
                          );
                        }
                      },
                      child: Text(
                        'Watch All',
                        style: AppTextStyles.caption.copyWith(color: AppColors.primary),
                      ),
                    ),
                ],
              ),
            ),
            SizedBox(
              height: 108,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: rings.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, i) {
                  final ring = rings[i];
                  return _StoryRingAvatar(
                    ring: ring,
                    onTap: () {
                      if (ring.isMe && !ring.hasStories) {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const CreateStoryScreen(),
                          ),
                        );
                        return;
                      }
                      if (!ring.hasStories) return;
                      final viewable = rings.where((r) => r.hasStories).toList();
                      final idx = viewable.indexWhere((r) => r.userId == ring.userId);
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => StoryViewerScreen(
                            rings: viewable,
                            initialRingIndex: idx < 0 ? 0 : idx,
                          ),
                        ),
                      );
                    },
                    onAdd: ring.isMe
                        ? () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const CreateStoryScreen(),
                              ),
                            );
                          }
                        : null,
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class _StoryRingAvatar extends StatelessWidget {
  const _StoryRingAvatar({
    required this.ring,
    required this.onTap,
    this.onAdd,
  });

  final StoryRing ring;
  final VoidCallback onTap;
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    final hasUnseen = ring.hasUnseen || (ring.isMe && !ring.hasStories);
    final ringColor = hasUnseen ? AppColors.primary : AppColors.textMuted.withValues(alpha: 0.4);

    return Semantics(
      button: true,
      label: ring.isMe
          ? (ring.hasStories ? 'Your story' : 'Add your story')
          : '${ring.displayName} story${ring.hasUnseen ? ', new' : ''}',
      child: GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 76,
        child: Column(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 68,
                  height: 68,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: hasUnseen
                        ? LinearGradient(
                            colors: [
                              AppColors.primary,
                              AppColors.primary.withValues(alpha: 0.6),
                              const Color(0xFFEC4899),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                        : null,
                    border: hasUnseen
                        ? null
                        : Border.all(color: ringColor, width: 2),
                  ),
                  padding: const EdgeInsets.all(3),
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.surface,
                      border: Border.all(color: AppColors.surface, width: 2),
                    ),
                    child: CircleAvatar(
                      radius: 28,
                      backgroundColor: AppColors.surfaceElevated,
                      backgroundImage: ring.avatarUrl != null
                          ? NetworkImage(ring.avatarUrl!)
                          : null,
                      child: ring.avatarUrl == null
                          ? Text(
                              ring.displayName.isNotEmpty
                                  ? ring.displayName[0].toUpperCase()
                                  : '?',
                              style: const TextStyle(fontSize: 20),
                            )
                          : null,
                    ),
                  ),
                ),
                if (ring.isMe)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: GestureDetector(
                      onTap: onAdd,
                      child: Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.surface, width: 2),
                        ),
                        child: const Icon(Icons.add, size: 14, color: Colors.white),
                      ),
                    ),
                  ),
                if (ring.isOnline && !ring.isMe)
                  Positioned(
                    right: 4,
                    bottom: 4,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: const Color(0xFF22C55E),
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.surface, width: 2),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              ring.displayName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: AppTextStyles.caption.copyWith(fontSize: 11),
            ),
          ],
        ),
      ),
    ),
    );
  }
}
