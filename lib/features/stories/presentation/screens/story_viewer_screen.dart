import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/color_utils.dart';
import '../../domain/entities/story_entity.dart';
import '../providers/story_provider.dart';

class StoryViewerScreen extends ConsumerStatefulWidget {
  const StoryViewerScreen({
    super.key,
    required this.rings,
    this.initialRingIndex = 0,
  });

  final List<StoryRing> rings;
  final int initialRingIndex;

  @override
  ConsumerState<StoryViewerScreen> createState() => _StoryViewerScreenState();
}

class _StoryViewerScreenState extends ConsumerState<StoryViewerScreen>
    with SingleTickerProviderStateMixin {
  late int _ringIndex;
  late int _storyIndex;
  late AnimationController _progress;
  bool _paused = false;

  // Guards against a controller from a superseded story finishing init
  // after the user has already swiped away (fast-swipe race condition).
  int _loadToken = 0;
  VideoPlayerController? _videoController;
  bool _videoBuffering = false;

  StoryRing get _ring => widget.rings[_ringIndex];
  StoryEntity get _story => _ring.stories[_storyIndex];

  @override
  void initState() {
    super.initState();
    _progress = AnimationController(vsync: this, duration: const Duration(seconds: 5))
      ..addStatusListener((s) {
        if (s == AnimationStatus.completed) _next();
      });
    // Defensive: every current call site filters to non-empty rings before
    // navigating here, but this guards against a future caller (or a stale
    // list) passing an empty list, which would otherwise crash immediately
    // — clamp(0, -1) throws, and _ring/_story index into an empty list.
    if (widget.rings.isEmpty) {
      _ringIndex = 0;
      _storyIndex = 0;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).maybePop();
      });
      return;
    }
    _ringIndex = widget.initialRingIndex.clamp(0, widget.rings.length - 1);
    _storyIndex = 0;
    _start();
  }

  void _start() {
    _progress.stop();
    _disposeVideo();

    final story = _story;
    if (story.mediaType == 'video' && story.mediaUrl != null) {
      _startVideo(story.mediaUrl!);
    } else {
      _progress.duration = const Duration(seconds: 5);
      _progress
        ..reset()
        ..forward();
    }
    ref.read(storyRepositoryProvider).markViewed(story.id);
  }

  Future<void> _startVideo(String url) async {
    final token = ++_loadToken;
    final controller = VideoPlayerController.networkUrl(Uri.parse(url));
    try {
      await controller.initialize();
      // The user may have swiped to a different story while this awaited.
      if (!mounted || token != _loadToken) {
        await controller.dispose();
        return;
      }
      controller.addListener(_onVideoTick);
      setState(() {
        _videoController = controller;
        _videoBuffering = false;
      });
      // Match the progress bar's duration to the video's real length instead
      // of the hardcoded 5s used for photo/text stories.
      final duration = controller.value.duration;
      _progress.duration = duration > Duration.zero ? duration : const Duration(seconds: 5);
      _progress
        ..reset()
        ..forward();
      if (!_paused) {
        await controller.play();
      }
    } catch (_) {
      if (!mounted || token != _loadToken) return;
      await controller.dispose();
      // Fall back to a timed advance so playback doesn't get stuck on a
      // story whose video failed to load.
      setState(() {
        _videoController = null;
        _videoBuffering = false;
      });
      _progress.duration = const Duration(seconds: 5);
      _progress
        ..reset()
        ..forward();
    }
  }

  void _onVideoTick() {
    final controller = _videoController;
    if (controller == null || !controller.value.isInitialized) return;
    final isBuffering = controller.value.isBuffering;
    if (isBuffering != _videoBuffering) {
      _onVideoBuffering(isBuffering);
    }
  }

  void _onVideoBuffering(bool buffering) {
    setState(() => _videoBuffering = buffering);
    if (_paused) return;
    // Pause the progress-bar animation while the video rebuffers so the
    // bar doesn't race ahead of the frozen picture, and resume once ready.
    if (buffering) {
      _progress.stop();
    } else {
      _progress.forward();
    }
  }

  void _disposeVideo() {
    _loadToken++;
    final controller = _videoController;
    _videoController = null;
    _videoBuffering = false;
    if (controller != null) {
      controller.removeListener(_onVideoTick);
      controller.dispose();
    }
  }

  void _next() {
    if (_storyIndex < _ring.stories.length - 1) {
      setState(() => _storyIndex++);
      _start();
    } else if (_ringIndex < widget.rings.length - 1) {
      setState(() {
        _ringIndex++;
        _storyIndex = 0;
      });
      _start();
    } else {
      Navigator.of(context).pop();
    }
  }

  void _prev() {
    if (_storyIndex > 0) {
      setState(() => _storyIndex--);
      _start();
    } else if (_ringIndex > 0) {
      setState(() {
        _ringIndex--;
        _storyIndex = widget.rings[_ringIndex].stories.length - 1;
      });
      _start();
    }
  }

  void _togglePause() {
    setState(() {
      _paused = !_paused;
      if (_paused) {
        _progress.stop();
        _videoController?.pause();
      } else {
        if (!_videoBuffering) _progress.forward();
        _videoController?.play();
      }
    });
  }

  @override
  void dispose() {
    _disposeVideo();
    _progress.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.rings.isEmpty) {
      // initState already scheduled a pop; render an empty black frame for
      // the one tick before that runs instead of indexing into nothing.
      return const Scaffold(backgroundColor: Colors.black);
    }
    final story = _story;
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTapDown: (d) {
          final w = MediaQuery.of(context).size.width;
          if (d.localPosition.dx < w * 0.3) {
            _prev();
          } else if (d.localPosition.dx > w * 0.7) {
            _next();
          } else {
            _togglePause();
          }
        },
        onLongPressStart: (_) {
          _progress.stop();
          _videoController?.pause();
          setState(() => _paused = true);
        },
        onLongPressEnd: (_) {
          if (!_videoBuffering) _progress.forward();
          _videoController?.play();
          setState(() => _paused = false);
        },
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Content
            if (story.mediaType == 'photo' && story.mediaUrl != null)
              Image.network(
                story.mediaUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const Center(
                  child: Icon(Icons.broken_image, color: Colors.white54, size: 64),
                ),
              )
            else if (story.mediaType == 'video' && story.mediaUrl != null)
              _StoryVideoContent(
                controller: _videoController,
                buffering: _videoBuffering,
              )
            else
              Container(
                color: safeHexColor(story.backgroundColor),
                alignment: Alignment.center,
                padding: const EdgeInsets.all(32),
                child: Text(
                  story.textContent ?? '',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    height: 1.3,
                  ),
                ),
              ),

            // Top gradient + progress + header
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                child: Column(
                  children: [
                    // Progress bars
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                      child: Row(
                        children: List.generate(_ring.stories.length, (i) {
                          return Expanded(
                            child: Container(
                              height: 2.5,
                              margin: const EdgeInsets.symmetric(horizontal: 2),
                              decoration: BoxDecoration(
                                color: Colors.white24,
                                borderRadius: BorderRadius.circular(2),
                              ),
                              child: i == _storyIndex
                                  ? AnimatedBuilder(
                                      animation: _progress,
                                      builder: (_, __) => FractionallySizedBox(
                                        alignment: Alignment.centerLeft,
                                        widthFactor: _progress.value,
                                        child: Container(
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius: BorderRadius.circular(2),
                                          ),
                                        ),
                                      ),
                                    )
                                  : i < _storyIndex
                                      ? Container(
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius: BorderRadius.circular(2),
                                          ),
                                        )
                                      : null,
                            ),
                          );
                        }),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 12, 8, 0),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 16,
                            backgroundImage: _ring.avatarUrl != null
                                ? NetworkImage(_ring.avatarUrl!)
                                : null,
                            child: _ring.avatarUrl == null
                                ? Text(_ring.displayName[0])
                                : null,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _ring.displayName,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                                Text(
                                  story.timeAgo,
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.white),
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Bottom actions
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _action(Icons.favorite_border, 'Like'),
                      _action(Icons.chat_bubble_outline, 'Reply'),
                      _action(Icons.send_outlined, 'Share'),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _action(IconData icon, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.white, size: 28),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
      ],
    );
  }
}

/// Renders the real video for a video story, with a spinner while the
/// controller is still initializing and a subtle buffering overlay once
/// playback has started but the player has run dry on data.
class _StoryVideoContent extends StatelessWidget {
  const _StoryVideoContent({required this.controller, required this.buffering});

  final VideoPlayerController? controller;
  final bool buffering;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    if (c == null || !c.value.isInitialized) {
      return Container(
        color: Colors.black,
        child: const Center(
          child: CircularProgressIndicator(color: Colors.white70),
        ),
      );
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: c.value.size.width,
            height: c.value.size.height,
            child: VideoPlayer(c),
          ),
        ),
        if (buffering)
          const Center(
            child: CircularProgressIndicator(color: Colors.white70),
          ),
      ],
    );
  }
}
