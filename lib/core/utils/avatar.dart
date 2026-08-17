import 'package:flutter/material.dart';

import '../../theme/kena_colors.dart';

Color avatarColorFor(String name) =>
    KenaColors.avatarPalette[name.hashCode.abs() % KenaColors.avatarPalette.length];

String initialsFor(String name) {
  final trimmed = name.trim();
  return trimmed.isEmpty ? '?' : String.fromCharCode(trimmed.runes.first).toUpperCase();
}
