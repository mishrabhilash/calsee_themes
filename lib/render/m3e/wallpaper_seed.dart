/// "Match my wallpaper" (M3 Expressive variant; spec §5.3 #1): reads the
/// Android 12+ wallpaper colour through `dynamic_color` and hands it to the
/// generator as the seed hue; the generator re-runs every guardrail.
///
/// Android only (packages.md §7): `dynamic_color` has no iOS
/// implementation, and its own error handling misses iOS's
/// `MissingPluginException`, so the plugin is called directly, guarded by
/// platform, and every failure reads as "no wallpaper colour". The option
/// is hidden wherever [wallpaperSeedSupported] is false.
library;

import 'package:calsee_themes/engine/oklab.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/foundation.dart';

/// Whether "Match my wallpaper" can be offered on this platform (Android;
/// the plugin itself returns null below Android 12).
bool get wallpaperSeedSupported =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

/// Reads the wallpaper's primary colour as opaque ARGB (tone 40 of the
/// primary tonal palette), or null when unsupported or unavailable.
/// Never throws.
Future<int?> readWallpaperSeedArgb() async {
  if (!wallpaperSeedSupported) return null;
  try {
    final palette = await DynamicColorPlugin.getCorePalette();
    final argb = palette?.primary.get(40);
    return argb == null ? null : (argb | 0xFF000000) & 0xFFFFFFFF;
  } on Object catch (_) {
    return null;
  }
}

/// The OKLCH hue of [argb] in tenths of a degree (0–3599): the seed hue
/// the M3E generator uses for the wallpaper variant.
int wallpaperHueTenths(int argb) {
  final lch = argbToOklch(argb);
  return (lch.h * 10).round() % 3600;
}
