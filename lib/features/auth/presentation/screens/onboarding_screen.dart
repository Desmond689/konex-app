import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/config/constants.dart';
import '../../../../core/config/dependency_injection.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/kx_button.dart';
import '../../../communities/domain/community_entity.dart';
import '../../../communities/presentation/providers/community_provider.dart';

/// Onboarding: platform → multi-game select → auto-join those game communities.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  int _step = 0;
  String? _platform;
  final Set<String> _selectedCommunityIds = {};
  final Map<String, String> _idToName = {};
  bool _saving = false;

  Future<void> _finish() async {
    setState(() => _saving = true);
    final client = ref.read(supabaseClientProvider);
    final user = client.auth.currentUser;
    try {
      if (user != null) {
        // The completion flag is the critical write — it's what both this
        // screen and the router's onboarding gate key off of. Let a failure
        // here surface (below) so the user can retry rather than silently
        // treating onboarding as done.
        await client.from('profiles').update({
          'player_type': _platform,
          'onboarding_completed': true,
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', user.id);

        // Auto-join each selected game community — best-effort. This used
        // to run unguarded before the completion flag was ever considered
        // "done" locally: one failed join (network blip, a since-deleted
        // game id) threw, which skipped marking onboarding complete
        // entirely and left the Continue button spinning forever with no
        // way out except force-quitting the app. A join failing shouldn't
        // block someone from finishing setup — they can add games anytime
        // from Manage Games.
        try {
          await ref
              .read(communityRepositoryProvider)
              .joinMany(_selectedCommunityIds.toList());
        } catch (_) {
          // Non-fatal — proceed to completion regardless.
        }
      }

      await ref.read(localStorageProvider).setOnboardingDone(true);
      if (!mounted) return;
      context.go(Routes.home);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not finish setup: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final gamesAsync = ref.watch(officialGamesProvider);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0F0F12), Color(0xFF15122A)],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'SETUP ${_step + 1}/3',
                  style: AppTextStyles.brandSmall.copyWith(fontSize: 12),
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: (_step + 1) / 3,
                  backgroundColor: AppColors.surfaceElevated,
                  color: AppColors.secondary,
                  borderRadius: BorderRadius.circular(4),
                ),
                const SizedBox(height: 20),
                Expanded(child: _buildStep(gamesAsync)),
                KxButton(
                  label: _step < 2 ? 'Continue' : 'Enter KONEX',
                  loading: _saving,
                  onPressed: () {
                    if (_step == 0 && _platform == null) return;
                    if (_step == 1 && _selectedCommunityIds.isEmpty) return;
                    if (_step < 2) {
                      setState(() => _step++);
                    } else {
                      _finish();
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStep(AsyncValue<List<CommunityEntity>> gamesAsync) {
    switch (_step) {
      case 0:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Choose your platform', style: AppTextStyles.headline),
            const SizedBox(height: 24),
            RadioGroup<String>(
              groupValue: _platform,
              onChanged: (v) => setState(() => _platform = v),
              child: Column(
                children: [
                  ...AppConstants.playerTypes.map(
                    (p) => RadioListTile<String>(
                      title: Text(p),
                      value: p,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      case 1:
        return gamesAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Text('Could not load games: $e'),
          data: (games) {
            if (games.isEmpty) {
              return Text(
                'No official games available yet. Ask an admin to add games, or skip after they are created.',
                style: AppTextStyles.bodySecondary,
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('What games do you play?', style: AppTextStyles.headline),
                const SizedBox(height: 8),
                Text(
                  'Select any number. You will automatically join each game community.',
                  style: AppTextStyles.bodySecondary,
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: ListView(
                    children: games.map((g) {
                      _idToName[g.id] = g.name;
                      return CheckboxListTile(
                        title: Text(g.name),
                        subtitle: g.category != null ? Text(g.category!) : null,
                        value: _selectedCommunityIds.contains(g.id),
                        onChanged: (v) {
                          setState(() {
                            if (v == true) {
                              _selectedCommunityIds.add(g.id);
                            } else {
                              _selectedCommunityIds.remove(g.id);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                ),
              ],
            );
          },
        );
      default:
        final names = _selectedCommunityIds
            .map((id) => _idToName[id] ?? id)
            .join(', ');
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('You are set', style: AppTextStyles.headline),
            const SizedBox(height: 16),
            Text('Platform: ${_platform ?? '-'}', style: AppTextStyles.body),
            const SizedBox(height: 8),
            Text('Games: $names', style: AppTextStyles.body),
            const SizedBox(height: 24),
            Text(
              'KONEX will join you to each selected game community automatically.',
              style: AppTextStyles.bodySecondary,
            ),
          ],
        );
    }
  }
}
