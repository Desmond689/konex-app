import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_text_styles.dart';
import '../../../communities/presentation/providers/community_provider.dart';
import '../providers/profile_provider.dart';

/// Add/remove games (= join/leave official communities).
class ManageGamesScreen extends ConsumerWidget {
  const ManageGamesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final official = ref.watch(officialGamesProvider);
    final mine = ref.watch(myProfileProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('My games')),
      body: official.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (games) {
          final myIds = <String>{};
          final profile = mine.valueOrNull;
          if (profile != null) {
            myIds.addAll(profile.gameCommunityIds.values);
            // also match by name if community_id missing
          }
          final myNames = profile?.games.toSet() ?? {};

          return ListView.builder(
            itemCount: games.length,
            itemBuilder: (_, i) {
              final g = games[i];
              final joined =
                  myIds.contains(g.id) || myNames.contains(g.name) || myNames.contains(g.gameName);
              return SwitchListTile(
                title: Text(g.name),
                subtitle: Text(
                  joined ? 'Member of community' : 'Tap to join',
                  style: AppTextStyles.caption,
                ),
                value: joined,
                onChanged: (v) async {
                  final repo = ref.read(communityRepositoryProvider);
                  if (v) {
                    await repo.join(g.id);
                  } else {
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: Text('Remove ${g.name}?'),
                        content: Text(
                          'This removes the game from your profile and leaves the ${g.name} community.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('Remove'),
                          ),
                        ],
                      ),
                    );
                    if (ok != true) return;
                    await repo.leave(g.id);
                  }
                  ref.invalidate(myProfileProvider);
                  ref.invalidate(myCommunitiesProvider);
                  ref.invalidate(officialGamesProvider);
                },
              );
            },
          );
        },
      ),
    );
  }
}
