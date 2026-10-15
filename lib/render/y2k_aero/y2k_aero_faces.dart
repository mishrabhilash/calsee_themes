/// Y2K / Frutiger Aero renderer factories (registered in
/// `theme_resolver.dart`): ThemeSpec → [Y2kAeroKeyFace] /
/// [Y2kChromeKeyFace] keys and the [Y2kDisplayFace] panel.
///
/// The factories never throw on foreign specs (the resolver test resolves
/// every family's style on an M3 Expressive palette): fewer than four
/// scene colours read as AERO, and translucent colours are made opaque.
library;

import 'dart:ui' show Color;

import 'package:calsee_themes/display_face.dart';
import 'package:calsee_themes/engine/oklab.dart';
import 'package:calsee_themes/engine/theme_spec.dart';
import 'package:calsee_themes/engine/y2k_aero.dart';
import 'package:calsee_themes/key_face.dart';
import 'package:calsee_themes/render/glass/glass_rendering.dart';
import 'package:calsee_themes/render/y2k_aero/y2k_display_face.dart';
import 'package:calsee_themes/render/y2k_aero/y2k_key_face.dart';

export 'package:calsee_themes/render/y2k_aero/y2k_display_face.dart';
export 'package:calsee_themes/render/y2k_aero/y2k_key_face.dart';

/// Whether [spec] is a CHROME theme (satin metal keys in chrome bezels).
bool y2kIsChrome(ThemeSpec spec) =>
    spec.background.kind == BackgroundKind.chromeHolo &&
    spec.background.colors.length >= 4;

/// The CHROME bezel's three light stops: holo colours 1–3 lightened to
/// L 0.96, C 0.035 (a pearly, foil-tinted chrome).
List<Color> y2kBezelTints(BackgroundSpec bg) => [
  for (var i = 1; i <= 3; i++)
    Color(
      oklchToArgb(
        0.96,
        0.035,
        argbToOklch(
          (i < bg.colors.length ? bg.colors[i] : 0xFFF2F2F2) | 0xFF000000,
        ).h,
      ),
    ),
];

int _hue(int argb) => (argbToOklch(argb | 0xFF000000).h * 10).round() % 3600;

/// The key renderer for a [ThemeFamily.y2kChrome] spec.
///
/// [rendering] carries the device effects tier: on the lite tier the
/// faces are flat (no gradients, no shadow blur).
KeyFaceRenderer y2kAeroKeyFaceFor(
  ThemeSpec spec, {
  GlassRendering rendering = GlassRendering.standard,
}) {
  final p = spec.palette;
  final style = spec.keyStyle;
  final kind = spec.keyShape.kind;
  final round = kind == KeyShapeKind.pill || kind == KeyShapeKind.circle;
  final corner = round ? 0.5 : spec.keyShape.cornerFraction.clamp(0.0, 0.5);
  final lite = !rendering.gradients;
  final accent = y2kAccentHueTenths(p);
  final floor = y2kDeepFloorFor(accessible: spec.accessible);
  final shadow = Color(p.shadow);
  final rim = style.outlineWidthCdp / 100;
  final offset = style.shadowOffsetCdp / 100;
  final blur = style.shadowBlurCdp / 100;
  // Dark scenes keep a strong cap (≥ 0.8) so the keys read as solid,
  // glossy gel rather than a glow (the style stream cannot see the
  // brightness, which is a palette draw).
  final cap = (style.highlightPermille / 1000).clamp(
    spec.isDark ? 0.8 : 0.0,
    1.0,
  );
  final caustic = (style.refractionPermille / 1000).clamp(0.0, 1.0);
  if (y2kIsChrome(spec)) {
    return Y2kChromeKeyFace(
      accentHueTenths: accent,
      shadow: shadow,
      bezelTints: y2kBezelTints(spec.background),
      liteBezel: Color(oklchToArgb(0.80, 0.01, _hue(p.digit.face) / 10)),
      capPeak: cap,
      caustic: caustic,
      depthMilli: style.edgeShadePermille,
      deepFloorMilli: floor,
      rimWidth: rim,
      shadowOffset: offset,
      shadowBlur: blur,
      cornerFraction: corner,
      lite: lite,
      slashedZero: spec.type.slashedZero,
    );
  }
  return Y2kAeroKeyFace(
    accentHueTenths: accent,
    shadow: shadow,
    capPeak: cap,
    caustic: caustic,
    depthMilli: style.edgeShadePermille,
    deepFloorMilli: floor,
    rimWidth: rim,
    shadowOffset: offset,
    shadowBlur: blur,
    cornerFraction: corner,
    lite: lite,
    slashedZero: spec.type.slashedZero,
  );
}

/// The display face for a [ThemeFamily.y2kChrome] spec: the glossy panel
/// in the palette `surface`.
DisplayFace? y2kAeroDisplayFaceFor(
  ThemeSpec spec, {
  GlassRendering rendering = GlassRendering.standard,
}) {
  final surface = spec.palette.surface | 0xFF000000;
  final x = argbToOklch(surface);
  final dark = y2kPanelGlossAlpha(surface) == y2kDarkPanelGloss;
  final rim = dark
      ? oklchToArgb(0.55, 0.06, x.h)
      : oklchToArgb((x.l - 0.30).clamp(0.0, 1.0), 0.05, x.h);
  return Y2kDisplayFace(
    surface: Color(surface),
    rim: Color(rim),
    bezelTints: y2kBezelTints(spec.background),
    liteBezel: Color(oklchToArgb(0.80, 0.01, x.h)),
    chrome: y2kIsChrome(spec),
    lite: !rendering.gradients,
    weight: spec.type.displayWeight,
  );
}
