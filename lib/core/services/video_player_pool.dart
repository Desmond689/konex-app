import 'package:video_player/video_player.dart';

/// Limits concurrent [VideoPlayerController] instances (Batch 10).
class VideoPlayerPool {
  VideoPlayerPool({this.maxActive = 2});

  final int maxActive;
  final Map<String, VideoPlayerController> _active = {};
  final List<String> _order = [];

  Future<VideoPlayerController> acquire(String url) async {
    if (_active.containsKey(url)) {
      _order.remove(url);
      _order.add(url);
      return _active[url]!;
    }

    while (_active.length >= maxActive && _order.isNotEmpty) {
      final oldest = _order.removeAt(0);
      final c = _active.remove(oldest);
      await c?.dispose();
    }

    final controller = VideoPlayerController.networkUrl(Uri.parse(url));
    await controller.initialize();
    controller.setLooping(true);
    _active[url] = controller;
    _order.add(url);
    return controller;
  }

  Future<void> release(String url) async {
    final c = _active.remove(url);
    _order.remove(url);
    await c?.dispose();
  }

  Future<void> releaseAll() async {
    for (final c in _active.values) {
      await c.dispose();
    }
    _active.clear();
    _order.clear();
  }
}

final globalVideoPool = VideoPlayerPool(maxActive: 2);
