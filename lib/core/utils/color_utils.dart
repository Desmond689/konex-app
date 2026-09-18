import 'package:flutter/material.dart';

/// Parses a `#RRGGBB` hex string into a [Color]. Falls back to
/// [fallback] instead of throwing if the string is missing, malformed, or
/// otherwise not exactly 6 hex digits — protects any screen that renders a
/// stored (DB-sourced) color value from crashing on bad/legacy data.
Color safeHexColor(String? hex, {Color fallback = const Color(0xFF7C3AED)}) {
  if (hex == null) return fallback;
  final cleaned = hex.trim().replaceFirst('#', '');
  if (cleaned.length != 6) return fallback;
  final parsed = int.tryParse('FF$cleaned', radix: 16);
  return parsed != null ? Color(parsed) : fallback;
}
