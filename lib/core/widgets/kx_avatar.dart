import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Consistent avatar that always uses CachedNetworkImage.
class KxAvatar extends StatelessWidget {
  const KxAvatar({
    super.key,
    this.url,
    this.name,
    this.radius = 20,
    this.onTap,
    this.semanticLabel,
  });

  final String? url;
  final String? name;
  final double radius;
  final VoidCallback? onTap;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final initial = (name != null && name!.isNotEmpty)
        ? name![0].toUpperCase()
        : '?';

    Widget avatar;
    if (url != null && url!.isNotEmpty) {
      avatar = CachedNetworkImage(
        imageUrl: url!,
        imageBuilder: (context, imageProvider) => CircleAvatar(
          radius: radius,
          backgroundImage: imageProvider,
          backgroundColor: AppColors.surfaceElevated,
        ),
        placeholder: (_, __) => CircleAvatar(
          radius: radius,
          backgroundColor: AppColors.surfaceElevated,
          child: SizedBox(
            width: radius,
            height: radius,
            child: const CircularProgressIndicator(strokeWidth: 1.5),
          ),
        ),
        errorWidget: (_, __, ___) => CircleAvatar(
          radius: radius,
          backgroundColor: AppColors.surfaceElevated,
          child: Text(initial, style: TextStyle(fontSize: radius * 0.7)),
        ),
      );
    } else {
      avatar = CircleAvatar(
        radius: radius,
        backgroundColor: AppColors.surfaceElevated,
        child: Text(initial, style: TextStyle(fontSize: radius * 0.7)),
      );
    }

    return Semantics(
      label: semanticLabel ?? (name != null ? 'Avatar of $name' : 'User avatar'),
      button: onTap != null,
      child: GestureDetector(
        onTap: onTap,
        child: avatar,
      ),
    );
  }
}
