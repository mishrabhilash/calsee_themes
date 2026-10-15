/// Claymorphism renderer factories (registered in `theme_resolver.dart`).
library;

import 'package:calsee_themes/display_face.dart';
import 'package:calsee_themes/engine/claymorphism.dart';
import 'package:calsee_themes/engine/contrast.dart';
import 'package:calsee_themes/engine/theme_spec.dart';
import 'package:calsee_themes/key_face.dart';
import 'package:calsee_themes/render/claymorphism/clay_display_face.dart';
import 'package:calsee_themes/render/claymorphism/clay_key_face.dart';
import 'package:calsee_themes/render/glass/glass_rendering.dart';
import 'package:flutter/painting.dart';

export 'package:calsee_themes/render/claymorphism/clay_display_face.dart';
export 'package:calsee_themes/render/claymorphism/clay_key_face.dart';

/// The key renderer for a [ThemeFamily.claymorphism] spec.
///
/// [rendering] carries the device effects tier: lite draws no blurs.
/// Reduce Motion (`EffectsTier.off`) keeps the full static artwork, and
/// the glass mode is ignored (clay is opaque). Zero or foreign style
/// values fall back to the family defaults (5 dp depth, 12 dp blur, 0.09
/// shade), so every spec paints.
KeyFaceRenderer claymorphismKeyFaceFor(
  ThemeSpec spec, {
  GlassRendering rendering = GlassRendering.standard,
}) {
  final p = spec.palette;
  final style = spec.keyStyle;
  final depth = spec.motion.depthCdp > 0 ? spec.motion.depthCdp : 500;
  final blur = style.shadowBlurCdp > 0 ? style.shadowBlurCdp : 1200;
  final shade = style.edgeShadePermille > 0 ? style.edgeShadePermille : 90;
  return ClayKeyFace(
    digitShadow: Color(p.digit.edge),
    operatorShadow: Color(p.operator.edge),
    equalsShadow: Color(p.equals.edge),
    functionShadow: Color(p.function.edge),
    highlight: Color(p.highlight),
    depth: depth / 100,
    blur: blur / 100,
    shadeDepth: shade.clamp(40, 140) / 1000,
    cornerFraction: spec.keyShape.cornerFraction.clamp(0.0, 0.5),
    pressScale: spec.motion.scalePermille / 1000,
    labelFloor: spec.accessible ? ratioAccessible : ratioText,
    lite: rendering.tier == EffectsTier.lite,
    slashedZero: spec.type.slashedZero,
  );
}

/// The display face for a [ThemeFamily.claymorphism] spec: the pillow
/// card in the surface colour (a foreign surface darker than the body is
/// drawn as a pillow too; the recessed tray is retired).
DisplayFace? claymorphismDisplayFaceFor(
  ThemeSpec spec, {
  GlassRendering rendering = GlassRendering.standard,
}) {
  final p = spec.palette;
  final surface = p.surface | 0xFF000000;
  return ClayDisplayFace(
    panel: Color(surface),
    shade: Color(clayInnerShade(surface, clayPanelShadePermille)),
    highlight: Color(p.highlight),
    shadow: Color(p.shadow),
    weight: spec.type.displayWeight,
    lite: rendering.tier == EffectsTier.lite,
  );
}
