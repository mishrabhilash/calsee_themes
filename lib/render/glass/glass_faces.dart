/// ThemeSpec → Liquid Glass renderers (the resolver's family entries).
library;

import 'dart:ui' show Color;

import 'package:calsee_themes/engine/liquid_glass.dart' show glassDiffuseColor;
import 'package:calsee_themes/engine/oklab.dart' show compositeOver;
import 'package:calsee_themes/engine/theme_spec.dart';
import 'package:calsee_themes/render/glass/glass_display_face.dart';
import 'package:calsee_themes/render/glass/glass_key_face.dart';
import 'package:calsee_themes/render/glass/glass_rendering.dart';

export 'package:calsee_themes/render/glass/glass_display_face.dart';
export 'package:calsee_themes/render/glass/glass_key_face.dart';
export 'package:calsee_themes/render/glass/glass_rendering.dart';

/// The solid tint of a glass [face]: the tint composited over the
/// background's diffuse colour [base] (`glassDiffuseColor`, a hull sample
/// the guardrails checked). It
/// is the key's `KeyStyle.fill`, what Reduce Transparency paints and what
/// per-frame label repair measures against.
Color glassSolidTint(int face, int base) =>
    Color(compositeOver(face, base | 0xFF000000));

/// Liquid Glass keys for [spec] under [rendering].
GlassKeyFace glassKeyFaceFor(
  ThemeSpec spec, {
  GlassRendering rendering = GlassRendering.standard,
}) {
  final p = spec.palette;
  final style = spec.keyStyle;
  GlassTint tint(KeyColors k) =>
      GlassTint(tint: Color(k.face), rim: Color(k.edge));
  final kind = spec.keyShape.kind;
  return GlassKeyFace(
    digit: tint(p.digit),
    operator: tint(p.operator),
    equals: tint(p.equals),
    function: tint(p.function),
    frostColor: Color(glassDiffuseColor(spec.background)),
    frost: style.frostPermille / 1000,
    glow: Color(p.highlight),
    shadow: Color(p.shadow),
    highlight: style.highlightPermille / 1000,
    refraction: style.refractionPermille / 1000,
    shadowOffset: style.shadowOffsetCdp / 100,
    shadowBlur: style.shadowBlurCdp / 100,
    rimWidth: style.outlineWidthCdp / 100,
    solidRim: spec.accessible,
    cornerFraction: spec.keyShape.cornerFraction.clamp(0.0, 0.5),
    round: kind == KeyShapeKind.circle || kind == KeyShapeKind.pill,
    pressScale: spec.motion.scalePermille / 1000,
    rendering: rendering,
    slashedZero: spec.type.slashedZero,
  );
}

/// Liquid Glass's display backing for [spec] under [rendering].
GlassDisplayFace glassDisplayFaceFor(
  ThemeSpec spec, {
  GlassRendering rendering = GlassRendering.standard,
}) {
  final p = spec.palette;
  final base = glassDiffuseColor(spec.background);
  return GlassDisplayFace(
    panel: Color(p.surface),
    solid: glassSolidTint(p.surface, base),
    frostColor: Color(base),
    frost: spec.keyStyle.frostPermille / 1000,
    rim: Color(
      p.digit.edge,
    ).withValues(alpha: spec.accessible ? 1 : Color(p.digit.edge).a * 0.8),
    rendering: rendering,
  );
}
