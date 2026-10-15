import 'dart:ui' show Color;

import 'package:calsee_themes/engine/contrast.dart' show ratioAccessible;
import 'package:calsee_themes/engine/guardrails.dart'
    show displayBackdrops, solveOnAll;
import 'package:calsee_themes/engine/theme_spec.dart';

/// `CalcThemeData.accessiblePreviewText` for [spec] (M5; m4 open issue
/// "Amount line under the Accessible lock").
///
/// The Accessible lock promises 7:1 for display text, but the generator
/// holds the preview colour to 4.5:1 (guardrails: preview text 3 (4.5)),
/// and the live preview and the amount in words are drawn in it. Raising
/// that floor in the generator would change every accessible theme (an
/// engine bump), so the boost happens here, at resolve time, on the same
/// backdrops the guardrails use ([displayBackdrops]: the display surface
/// and every background sample, or only the LCD panel for Retro): the
/// preview colour's OKLCH lightness moves until it is ≥ 7:1 on all of
/// them, falling back to the display text colour (≥ 7:1 by the
/// guardrails) when no lightness reaches it.
///
/// Null when the lock is off or the preview colour already passes.
Color? accessiblePreviewTextFor(ThemeSpec spec) {
  if (!spec.accessible) return null;
  final p = spec.palette;
  final backdrops = displayBackdrops(spec);
  final solved =
      solveOnAll(p.previewText, backdrops, ratioAccessible) ?? p.displayText;
  return solved == p.previewText ? null : Color(solved);
}
