import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'deep_link_models.dart';
import 'deep_link_parser.dart';

/// Single entry: parse URL → navigate. Auth/permission handled by destination screens.
class DeepLinkRouter {
  /// Pending destination after login (deferred deep link).
  static String? pendingPath;

  static Future<void> handle(BuildContext context, Uri? uri, {bool isLoggedIn = true}) async {
    final target = DeepLinkParser.parse(uri);
    if (target == null || target.type == DeepLinkType.unknown) {
      return;
    }
    final path = target.routePath;
    if (!isLoggedIn) {
      pendingPath = path;
      if (context.mounted) context.go('/login');
      return;
    }
    if (context.mounted) context.push(path);
  }

  /// Call after successful login/onboarding.
  static void consumePending(BuildContext context) {
    final p = pendingPath;
    pendingPath = null;
    if (p != null && p.isNotEmpty && context.mounted) {
      context.go(p);
    }
  }

  static DeepLinkTarget? parsePath(String path) {
    return DeepLinkParser.parse(Uri.parse('https://konex-app-rho.vercel.app$path'));
  }
}
