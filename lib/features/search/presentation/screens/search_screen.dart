import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/config/dependency_injection.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/debounce.dart';
import '../../data/search_repository.dart';

final searchRepositoryProvider = Provider((ref) {
  return SearchRepository(ref.watch(supabaseClientProvider));
});

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen>
    with SingleTickerProviderStateMixin {
  final _query = TextEditingController();
  late final TabController _tabs;
  late final Debouncer _debouncer;

  Map<String, List<Map<String, dynamic>>> _results = {
    'users': [],
    'games': [],
    'squads': [],
    'posts': [],
    'lfg': [],
  };
  bool _loading = false;
  List<String> _recent = [];
  static const _recentKey = 'kx_search_recent';

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 6, vsync: this);
    _debouncer = Debouncer(milliseconds: 300);
    _loadRecent();
  }

  Future<void> _loadRecent() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() => _recent = prefs.getStringList(_recentKey) ?? []);
  }

  Future<void> _saveRecent(String q) async {
    final term = q.trim();
    if (term.length < 2) return;
    final list = [term, ..._recent.where((e) => e != term)].take(12).toList();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_recentKey, list);
    if (!mounted) return;
    setState(() => _recent = list);
  }

  Future<void> _clearRecent() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_recentKey);
    if (!mounted) return;
    setState(() => _recent = []);
  }

  @override
  void dispose() {
    _query.dispose();
    _tabs.dispose();
    _debouncer.dispose();
    super.dispose();
  }

  Future<void> _runSearch(String q) async {
    final term = q.trim();
    if (term.length < 2) {
      setState(() {
        _results = {
          'users': [],
          'games': [],
          'squads': [],
          'posts': [],
          'lfg': [],
        };
        _loading = false;
      });
      return;
    }
    setState(() => _loading = true);
    final r = await ref.read(searchRepositoryProvider).searchAll(term);
    if (!mounted) return;
    r.when(
      success: (data) {
        setState(() {
          _results = data;
          _loading = false;
        });
        _saveRecent(term);
      },
      failure: (e, _) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      },
    );
  }

  String? _gameFilter;
  String? _squadVisibility; // public only already

  void _showFilters() {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Filters', style: AppTextStyles.title),
              const SizedBox(height: 8),
              Text(
                'Category tabs already scope results.'
                '${_gameFilter != null ? " Game: $_gameFilter" : ""}'
                '${_squadVisibility != null ? " Visibility: $_squadVisibility" : ""}',
                style: AppTextStyles.caption,
              ),
              SwitchListTile(
                title: const Text('People only exact @username first'),
                value: _query.text.trim().startsWith('@'),
                onChanged: null,
                subtitle: const Text('Type @name for exact user match'),
              ),
              ListTile(
                title: const Text('Clear filters'),
                onTap: () {
                  setState(() {
                    _gameFilter = null;
                    _squadVisibility = null;
                  });
                  Navigator.pop(ctx);
                  _runSearch(_query.text);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {

    final hasQuery = _query.text.trim().length >= 2;

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _query,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Search users, games, squads…',
            border: InputBorder.none,
          ),
          onChanged: (v) => _debouncer.run(() => _runSearch(v)),
          onSubmitted: _runSearch,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune),
            tooltip: 'Filters',
            onPressed: _showFilters,
          ),
          if (_query.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () {
                _query.clear();
                _runSearch('');
              },
            ),
        ],
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          tabs: const [
            Tab(text: 'All'),
            Tab(text: 'People'),
            Tab(text: 'Games'),
            Tab(text: 'Squads'),
            Tab(text: 'Posts'),
            Tab(text: 'LFG'),
          ],
        ),
      ),
      body: hasQuery
          ? (_loading
              ? const Center(child: CircularProgressIndicator())
              : TabBarView(
                  controller: _tabs,
                  children: [
                    _AllTab(results: _results, queryController: _query, runSearch: _runSearch),
                    _UsersTab(rows: _results['users'] ?? [], queryController: _query, runSearch: _runSearch),
                    _GamesTab(rows: _results['games'] ?? [], queryController: _query, runSearch: _runSearch),
                    _SquadsTab(rows: _results['squads'] ?? [] , queryController: _query, runSearch: _runSearch),
                    _PostsTab(rows: _results['posts'] ?? [], queryController: _query, runSearch: _runSearch),
                    _LfgTab(rows: _results['lfg'] ?? [], queryController: _query, runSearch: _runSearch),
                  ],
                ))
          : _Idle(
              recent: _recent,
              onTap: (q) {
                _query.text = q;
                _runSearch(q);
              },
              onClear: _clearRecent,
              onRemove: (q) async {
                final list = _recent.where((e) => e != q).toList();
                final prefs = await SharedPreferences.getInstance();
                await prefs.setStringList(_recentKey, list);
                if (!mounted) return;
                setState(() => _recent = list);
              },
            ),
    );
  }
}

class _Idle extends ConsumerStatefulWidget {
  const _Idle({
    required this.recent,
    required this.onTap,
    required this.onClear,
    required this.onRemove,
  });
  final List<String> recent;
  final void Function(String) onTap;
  final VoidCallback onClear;
  final void Function(String) onRemove;

  @override
  ConsumerState<_Idle> createState() => _IdleState();
}

class _IdleState extends ConsumerState<_Idle> {
  List<Map<String, dynamic>> _trending = [];

  @override
  void initState() {
    super.initState();
    _loadTrending();
  }

  Future<void> _loadTrending() async {
    try {
      final client = ref.read(supabaseClientProvider);
      final rows = await client.rpc('trending_games', params: {'p_limit': 8});
      if (mounted) {
        setState(() {
          _trending = (rows as List)
              .map((r) => Map<String, dynamic>.from(r as Map))
              .toList();
        });
      }
    } catch (_) {}
  }



  @override
  Widget build(BuildContext context) {

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (widget.recent.isNotEmpty) ...[
          Row(
            children: [
              Text('Recent', style: AppTextStyles.title),
              const Spacer(),
              TextButton(onPressed: widget.onClear, child: const Text('Clear all')),
            ],
          ),
          ...widget.recent.map(
            (q) => ListTile(
              leading: const Icon(Icons.history),
              title: Text(q),
              trailing: IconButton(
                icon: const Icon(Icons.close, size: 18),
                onPressed: () => widget.onRemove(q),
              ),
              onTap: () => widget.onTap(q),
            ),
          ),
          const Divider(),
        ],
        if (_trending.isNotEmpty) ...[
          Text('Trending games', style: AppTextStyles.title),
          ..._trending.map(
            (g) => ListTile(
              leading: const Text('🔥'),
              title: Text(g['name'] as String? ?? ''),
              subtitle: Text('${g['member_count'] ?? 0} members'),
              onTap: () {
                final slug = g['slug'] as String?;
                if (slug != null) {
                  context.push('/game/$slug');
                } else {
                  context.push('/community/${g['id']}');
                }
              },
            ),
          ),
          const Divider(),
        ],
        Text('Tip', style: AppTextStyles.title),
        const SizedBox(height: 8),
        Text(
          'Search people, games, squads, posts and LFG. Use @username for exact users.',
          style: AppTextStyles.caption,
        ),
      ],
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.query, required this.queryController, required this.runSearch});
  final String query;
  final TextEditingController queryController;
  final void Function(String) runSearch;


  @override
  Widget build(BuildContext context) {

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          'No results for “$query"\nTry another spelling, @username, or a game name.',
          textAlign: TextAlign.center,
          style: AppTextStyles.caption,
        ),
      ),
    );
  }
}

class _AllTab extends StatelessWidget {
  const _AllTab({required this.results, required this.queryController, required this.runSearch});
  final Map<String, List<Map<String, dynamic>>> results;
  final TextEditingController queryController;
  final void Function(String) runSearch;



  @override
  Widget build(BuildContext context) {

    final empty = results.values.every((e) => e.isEmpty);
    if (empty) return _Empty(query: 'your search', queryController: queryController, runSearch: runSearch);
    return ListView(
      children: [
        if ((results['games'] ?? []).isNotEmpty) ...[
          _Section('Games', queryController: queryController, runSearch: runSearch),
          ...results['games']!.map((r) => _GameTile(r, queryController: queryController, runSearch: runSearch)),
        ],
        if ((results['users'] ?? []).isNotEmpty) ...[
          _Section('People', queryController: queryController, runSearch: runSearch),
          ...results['users']!.map((r) => _UserTile(r, queryController: queryController, runSearch: runSearch)),
        ],
        if ((results['squads'] ?? []).isNotEmpty) ...[
          _Section('Squads', queryController: queryController, runSearch: runSearch),
          ...results['squads']!.map((r) => _SquadTile(r, queryController: queryController, runSearch: runSearch)),
        ],
        if ((results['posts'] ?? []).isNotEmpty) ...[
          _Section('Posts', queryController: queryController, runSearch: runSearch),
          ...results['posts']!.map((r) => _PostTile(r, queryController: queryController, runSearch: runSearch)),
        ],
        if ((results['lfg'] ?? []).isNotEmpty) ...[
          _Section('LFG', queryController: queryController, runSearch: runSearch),
          ...results['lfg']!.map((r) => _LfgTile(r, queryController: queryController, runSearch: runSearch)),
        ],
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.title, {required this.queryController, required this.runSearch});
  final String title;
  final TextEditingController queryController;
  final void Function(String) runSearch;


  @override
  Widget build(BuildContext context) {

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(title, style: AppTextStyles.title),
    );
  }
}

class _UsersTab extends StatelessWidget {
  const _UsersTab({required this.rows, required this.queryController, required this.runSearch});
  final List<Map<String, dynamic>> rows;
  final TextEditingController queryController;
  final void Function(String) runSearch;


  @override
  Widget build(BuildContext context) {

    if (rows.isEmpty) return _Empty(query: 'people', queryController: queryController, runSearch: runSearch);
    return ListView(children: rows.map((r) => _UserTile(r, queryController: queryController, runSearch: runSearch)).toList());
  }
}

class _GamesTab extends StatelessWidget {
  const _GamesTab({required this.rows, required this.queryController, required this.runSearch});
  final List<Map<String, dynamic>> rows;
  final TextEditingController queryController;
  final void Function(String) runSearch;


  @override
  Widget build(BuildContext context) {

    if (rows.isEmpty) return _Empty(query: 'games', queryController: queryController, runSearch: runSearch);
    return ListView(children: rows.map((r) => _GameTile(r, queryController: queryController, runSearch: runSearch)).toList());
  }
}

class _SquadsTab extends StatelessWidget {
  const _SquadsTab({required this.rows, required this.queryController, required this.runSearch});
  final List<Map<String, dynamic>> rows;
  final TextEditingController queryController;
  final void Function(String) runSearch;


  @override
  Widget build(BuildContext context) {

    if (rows.isEmpty) return _Empty(query: 'squads', queryController: queryController, runSearch: runSearch);
    return ListView(children: rows.map((r) => _SquadTile(r, queryController: queryController, runSearch: runSearch)).toList());
  }
}

class _PostsTab extends StatelessWidget {
  const _PostsTab({required this.rows, required this.queryController, required this.runSearch});
  final List<Map<String, dynamic>> rows;
  final TextEditingController queryController;
  final void Function(String) runSearch;


  @override
  Widget build(BuildContext context) {

    if (rows.isEmpty) return _Empty(query: 'posts', queryController: queryController, runSearch: runSearch);
    return ListView(children: rows.map((r) => _PostTile(r, queryController: queryController, runSearch: runSearch)).toList());
  }
}

class _LfgTab extends StatelessWidget {
  const _LfgTab({required this.rows, required this.queryController, required this.runSearch});
  final List<Map<String, dynamic>> rows;
  final TextEditingController queryController;
  final void Function(String) runSearch;


  @override
  Widget build(BuildContext context) {

    if (rows.isEmpty) return _Empty(query: 'LFG', queryController: queryController, runSearch: runSearch);
    return ListView(children: rows.map((r) => _LfgTile(r, queryController: queryController, runSearch: runSearch)).toList());
  }
}

class _UserTile extends StatelessWidget {
  const _UserTile(this.r, {required this.queryController, required this.runSearch});
  final Map<String, dynamic> r;
  final TextEditingController queryController;
  final void Function(String) runSearch;

  @override
  Widget build(BuildContext context) {

    final name = (r['gamer_name'] as String?)?.isNotEmpty == true
        ? r['gamer_name'] as String
        : r['username'] as String? ?? 'User';
    final verified = r['is_verified'] == true;
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: AppColors.surfaceElevated,
        backgroundImage:
            r['avatar_url'] != null ? NetworkImage(r['avatar_url'] as String) : null,
        child: r['avatar_url'] == null
            ? Text(name.isNotEmpty ? name[0].toUpperCase() : '?')
            : null,
      ),
      title: Row(
        children: [
          Flexible(child: Text(name)),
          if (verified) ...[
            const SizedBox(width: 4),
            const Icon(Icons.verified, size: 16, color: Colors.lightBlueAccent),
          ],
        ],
      ),
      subtitle: Text('@${r['username'] ?? ''}'),
      onTap: () => context.push('/user/${r['id']}'),
    );
  }
}

class _GameTile extends StatelessWidget {
  const _GameTile(this.r, {required this.queryController, required this.runSearch});
  final Map<String, dynamic> r;
  final TextEditingController queryController;
  final void Function(String) runSearch;

  @override
  Widget build(BuildContext context) {

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: AppColors.surfaceElevated,
        backgroundImage:
            r['avatar_url'] != null ? NetworkImage(r['avatar_url'] as String) : null,
        child: r['avatar_url'] == null ? const Text('🎮') : null,
      ),
      title: Text(r['name'] as String? ?? ''),
      subtitle: Text(
        [
          if (r['is_official'] == true) 'Official',
          '${r['member_count'] ?? 0} members',
        ].join(' · '),
      ),
      onTap: () {
        final slug = r['slug'] as String?;
        if (slug != null) {
          context.push('/game/$slug');
        } else {
          context.push('/community/${r['id']}');
        }
      },
    );
  }
}

class _SquadTile extends StatelessWidget {
  const _SquadTile(this.r, {required this.queryController, required this.runSearch});
  final Map<String, dynamic> r;
  final TextEditingController queryController;
  final void Function(String) runSearch;

  @override
  Widget build(BuildContext context) {

    return ListTile(
      leading: const Text('🔥', style: TextStyle(fontSize: 22)),
      title: Text(r['name'] as String? ?? ''),
      subtitle: Text(
        [
          if (r['primary_game'] != null) r['primary_game'],
          '${r['member_count'] ?? 0} members',
          r['is_public'] == true ? 'Public' : 'Private',
        ].join(' · '),
      ),
      onTap: () => context.push('/squad/${r['id']}'),
    );
  }
}

class _PostTile extends StatelessWidget {
  const _PostTile(this.r, {required this.queryController, required this.runSearch});
  final Map<String, dynamic> r;
  final TextEditingController queryController;
  final void Function(String) runSearch;

  @override
  Widget build(BuildContext context) {

    final profile = r['profiles'] as Map<String, dynamic>?;
    final community = r['communities'] as Map<String, dynamic>?;
    final author = (profile?['gamer_name'] as String?)?.isNotEmpty == true
        ? profile!['gamer_name']
        : profile?['username'] ?? 'User';
    return ListTile(
      title: Text('$author', maxLines: 1),
      subtitle: Text(
        [
          if (community?['name'] != null) '🎮 ${community!['name']}',
          r['body'] as String? ?? '',
        ].join('\n'),
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
      ),
      onTap: () => context.push('/post/${r['id']}'),
    );
  }
}

class _LfgTile extends StatelessWidget {
  const _LfgTile(this.r, {required this.queryController, required this.runSearch});
  final Map<String, dynamic> r;
  final TextEditingController queryController;
  final void Function(String) runSearch;

  @override
  Widget build(BuildContext context) {

    return ListTile(
      leading: const Text('🎯', style: TextStyle(fontSize: 22)),
      title: Text(r['game_name'] as String? ?? 'LFG'),
      subtitle: Text(
        [
          if (r['game_name'] != null) r['game_name'],
          if (r['mode'] != null) r['mode'],
          if (r['players_needed'] != null) 'Need ${r['players_needed']}',
        ].join(' · '),
      ),
      onTap: () => context.push('/post/${r['post_id']}'),
    );
  }
}
