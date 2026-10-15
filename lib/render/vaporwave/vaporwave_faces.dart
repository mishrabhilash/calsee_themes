/// Vaporwave renderer factories (registered in `theme_resolver.dart`).
library;

import 'package:calsee_themes/display_face.dart';
import 'package:calsee_themes/engine/theme_spec.dart';
import 'package:calsee_themes/key_face.dart';
import 'package:calsee_themes/render/glass/glass_rendering.dart';
import 'package:calsee_themes/render/vaporwave/vaporwave_display_face.dart';
import 'package:calsee_themes/render/vaporwave/vaporwave_key_face.dart';
import 'package:flutter/painting.dart';

/// Bevel defaults for foreign specs (style fields 0).
const double _defaultBevel = 2.5;
const double _defaultShade = 0.30;
const double _defaultHighlight = 0.85;

double _shadeOf(KeyStyleSpec style) => style.edgeShadePermille > 0
    ? style.edgeShadePermille / 1000
    : _defaultShade;

double _highlightOf(KeyStyleSpec style) => style.highlightPermille > 0
    ? style.highlightPermille / 1000
    : _defaultHighlight;

/// The key renderer for a [ThemeFamily.vaporwave] spec: ink = the
/// palette's shadow, the 1 dp line and 2–3 dp bevel from the key style,
/// label travel = the press depth (1–2 dp). The face has no gradients,
/// blurs or shaders, so the lite effects tier ([rendering]) draws it the
/// same. Never throws on another family's spec.
KeyFaceRenderer vaporwaveKeyFaceFor(
  ThemeSpec spec, {
  GlassRendering rendering = GlassRendering.standard,
}) {
  final style = spec.keyStyle;
  final depthCdp = spec.motion.depthCdp > 0
      ? spec.motion.depthCdp
      : style.shadowOffsetCdp;
  return VaporwaveKeyFace(
    ink: Color(spec.palette.shadow | 0xFF000000),
    outlineWidth: style.outlineWidthCdp > 0 ? style.outlineWidthCdp / 100 : 1,
    bevelWidth: style.extrudeDepthCdp > 0
        ? style.extrudeDepthCdp / 100
        : _defaultBevel,
    travel: (depthCdp > 0 ? depthCdp : 100) / 100,
    shadeDepth: _shadeOf(style),
    highlightMix: _highlightOf(style),
    cornerFraction: spec.keyShape.cornerFraction.clamp(0.0, 0.5),
    widthPermille: spec.type.widthPermille,
    slashedZero: spec.type.slashedZero,
  );
}

/// The display window for a [ThemeFamily.vaporwave] spec: client = the
/// surface, body = the digit face, title bar = highlight → accent, the
/// mini sun from the scene's sun colours (the accents when the scene is
/// malformed). The lite tier ([rendering]) draws a solid Windows-95
/// title bar instead of the gradient.
DisplayFace? vaporwaveDisplayFaceFor(
  ThemeSpec spec, {
  GlassRendering rendering = GlassRendering.standard,
}) {
  final p = spec.palette;
  final colors = spec.background.colors;
  final full = colors.length >= 10;
  Color opaque(int argb) => Color(argb | 0xFF000000);
  return VaporwaveDisplayFace(
    panel: opaque(p.surface),
    chrome: opaque(p.digit.face),
    ink: opaque(p.shadow),
    titleStart: opaque(p.highlight),
    titleEnd: opaque(p.accent),
    sunTop: opaque(full ? colors[3] : p.operator.face),
    sunBottom: opaque(full ? colors[5] : p.equals.face),
    shadeDepth: _shadeOf(spec.keyStyle),
    highlightMix: _highlightOf(spec.keyStyle),
    weight: spec.type.displayWeight,
    widthPermille: spec.type.widthPermille > 1300
        ? 1300
        : spec.type.widthPermille,
    slashedZero: spec.type.slashedZero,
    gradients: rendering.gradients,
  );
}
