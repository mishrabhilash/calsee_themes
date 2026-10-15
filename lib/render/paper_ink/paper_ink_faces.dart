/// Paper & ink renderer factories (registered in `theme_resolver.dart`):
/// [PaperKeyFace] keys and the [PaperDisplayFace] ledger / index card.
library;

import 'dart:ui';

import 'package:calsee_themes/display_face.dart';
import 'package:calsee_themes/engine/paper_ink.dart'
    show paperFaceGrainPermille, paperGrainOf;
import 'package:calsee_themes/engine/theme_spec.dart';
import 'package:calsee_themes/key_face.dart';
import 'package:calsee_themes/render/glass/glass_rendering.dart';
import 'package:calsee_themes/render/paper_ink/paper_display_face.dart';
import 'package:calsee_themes/render/paper_ink/paper_key_face.dart';

/// Grain opacity (0–1) of the slips and the panel: half the sheet's.
double _faceGrain(BackgroundSpec bg) => bg.kind == BackgroundKind.paperSheet
    ? paperGrainOf(bg) * paperFaceGrainPermille / 1000000
    : 0;

/// The key renderer for a [ThemeFamily.paperInk] spec: ink = palette
/// `shadow`, wash = palette `highlight`, the outline width and hatch
/// opacity from the key style, the 1 dp drop from the motion. Values a
/// foreign spec leaves at 0 fall back to the family's defaults.
///
/// [rendering]'s lite tier drops the retrace and the stamp speckles.
KeyFaceRenderer paperInkKeyFaceFor(
  ThemeSpec spec, {
  GlassRendering rendering = GlassRendering.standard,
}) {
  final style = spec.keyStyle;
  final p = spec.palette;
  return PaperKeyFace(
    ink: Color(p.shadow | 0xFF000000),
    wash: Color(p.highlight),
    slip: Color(p.digit.face | 0xFF000000),
    outlineWidth: style.outlineWidthCdp > 0 ? style.outlineWidthCdp / 100 : 1.5,
    hatchAlpha: style.edgeShadePermille > 0
        ? (style.edgeShadePermille / 1000).clamp(0.0, 1.0)
        : 0.65,
    depth: spec.motion.depthCdp > 0 ? spec.motion.depthCdp / 100 : 1,
    cornerFraction: spec.keyShape.cornerFraction.clamp(0.0, 0.5),
    grain: _faceGrain(spec.background),
    lite: rendering.tier == EffectsTier.lite,
    slashedZero: spec.type.slashedZero,
  );
}

/// The display face for a [ThemeFamily.paperInk] spec: a ledger on ruled
/// sheets (its feint rules at the sheet's pitch), a torn index card
/// otherwise; panel = surface, feint rules in the sheet's rule ink (none
/// under the Accessible lock), the margin in the red pen (palette
/// `error`).
DisplayFace? paperInkDisplayFaceFor(
  ThemeSpec spec, {
  GlassRendering rendering = GlassRendering.standard,
}) {
  final p = spec.palette;
  final bg = spec.background;
  final panel = Color(p.surface | 0xFF000000);
  final ink = Color(p.shadow | 0xFF000000);
  final ledger = bg.pattern == BackgroundPattern.stripes;
  return PaperDisplayFace(
    panel: panel,
    ink: ink,
    rule: bg.kind == BackgroundKind.paperSheet && bg.colors.length > 1
        ? Color(bg.colors[1] | 0xFF000000)
        : Color.lerp(ink, panel, 0.6)!,
    margin: Color(p.error | 0xFF000000),
    ledger: ledger,
    rules: !spec.accessible,
    rulePitch: ledger && bg.patternScaleCdp > 0
        ? bg.patternScaleCdp / 100
        : null,
    grain: _faceGrain(bg),
    dark: spec.isDark,
    accessible: spec.accessible,
    weight: spec.type.displayWeight,
    lite: rendering.tier == EffectsTier.lite,
  );
}
