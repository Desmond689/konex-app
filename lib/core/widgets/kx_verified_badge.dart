import 'package:flutter/material.dart';

/// Small blue checkmark used to mark official / staff-created communities.
/// Matches the verified badge style already used on user profiles.
class KxVerifiedBadge extends StatelessWidget {
  const KxVerifiedBadge({super.key, this.size = 16});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Icon(Icons.verified, color: Colors.lightBlueAccent, size: size);
  }
}
