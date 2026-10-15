/// ThemeSpec → Cyberpunk renderers (registered in `theme_resolver.dart`).
library;

import 'dart:math' as math;
import 'dart:ui' show Color;

import 'package:calsee_themes/display_face.dart';
import 'package:calsee_themes/engine/cyberpunk.dart'
    show cyberPanelScanMaxAlpha;
import 'package:calsee_themes/engine/theme_spec.dart';
import 'package:calsee_themes/key_face.dart';
import 'package:calsee_themes/render/cyberpunk/cyber_display_face.dart';
import 'package:calsee_themes/render/cyberpunk/cyber_key_face.dart';
import 'package:calsee_themes/render/glass/glass_rendering.dart';

export 'package:calsee_themes/render/cyberpunk/cyber_display_face.dart';
export 'package:calsee_themes/render/cyberpunk/cyber_key_face.dart';

/// The key renderer for a [ThemeFamily.cyberpunk] spec.
///
/// [rendering] carries the device effects tier: the lite tier draws the
/// halo as one ring and the bloom flat (no blur, no gradient). Faces are
/// opaque, so Reduce Transparency changes nothing. Foreign specs (any
/// family's style values) resolve without throwing: lengths are clamped to
/// ≥ 0 and the chamfer to the family's range.
KeyFaceRenderer cyberpunkKeyFaceFor(
  ThemeSpec spec, {
  GlassRendering rendering = GlassRendering.standard,
}) {
  final light = spec.brightness == ThemeBrightness.light;
  final style = spec.keyStyle;
  return CyberKeyFace(
    plunge: math.max(0, spec.motion.depthCdp / 100),
    edgeWidth: math.max(0, style.outlineWidthCdp / 100),
    haloSigma: math.max(0, style.shadowBlurCdp / 200),
    // Hazard has no halo; under the Accessible lock the glow appears only
    // while pressed, so key boundaries stay crisp.
    haloRest: light || spec.accessible ? 0 : CyberKeyFace.restHalo,
    haloPeak: light ? 0 : CyberKeyFace.peakHalo,
    chamfer: spec.keyShape.cornerFraction.clamp(0.0, 0.3),
    lightBody: light,
    lite: rendering.tier == EffectsTier.lite,
    slashedZero: spec.type.slashedZero,
  );
}

/// The HUD display panel for a [ThemeFamily.cyberpunk] spec.
DisplayFace? cyberpunkDisplayFaceFor(
  ThemeSpec spec, {
  GlassRendering rendering = GlassRendering.standard,
}) {
  final p = spec.palette;
  final dark = spec.brightness == ThemeBrightness.dark;
  final scanAlpha = math.min((p.shadow >>> 24) & 0xFF, cyberPanelScanMaxAlpha);
  return CyberHudDisplayFace(
    panel: Color(p.surface | 0xFF000000),
    scanInk: Color((p.shadow & 0x00FFFFFF) | (scanAlpha << 24)),
    // The frame is the digit edge neon (cyan on Hazard); the brackets and
    // status rule the operator neon (dark) or the yellow digit label
    // (Hazard), both on the black screen.
    edge: Color(p.digit.edge | 0xFF000000),
    bracket: Color((dark ? p.operator.face : p.digit.label) | 0xFF000000),
    chamfer: spec.keyShape.cornerFraction.clamp(0.0, 0.3),
    glow: dark && rendering.tier != EffectsTier.lite ? 0.6 : 0,
    weight: spec.type.displayWeight,
    slashedZero: spec.type.slashedZero,
    hazard: !dark,
  );
}
