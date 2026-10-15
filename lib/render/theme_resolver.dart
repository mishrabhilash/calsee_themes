/// ThemeSpec → [CalcThemeData]: colours, key renderer, background, fonts
/// and motion springs from the integer tokens (docs/m3-theme-engine-design.md
/// "Layers": `theme_resolver.dart`).
///
/// The M2 plain theme is a ThemeSpec too ([plainThemeSpec], family
/// `plain`); resolving it returns the exact `PlainTheme` data, so nothing
/// regresses.
library;

import 'dart:collection';

import 'package:calsee_themes/accessible_text.dart';
import 'package:calsee_themes/calc_theme_data.dart';
import 'package:calsee_themes/chrome_style.dart';
import 'package:calsee_themes/engine/families.dart' show FontIds;
import 'package:calsee_themes/engine/liquid_glass.dart'
    show glassDiffuseColor;
import 'package:calsee_themes/engine/oklab.dart';
import 'package:calsee_themes/engine/theme_spec.dart';
import 'package:calsee_themes/plain_theme.dart';
import 'package:calsee_themes/render/background_painter.dart';
import 'package:calsee_themes/render/bauhaus/bauhaus_faces.dart';
import 'package:calsee_themes/render/claymorphism/claymorphism_faces.dart';
import 'package:calsee_themes/render/cyberpunk/cyberpunk_faces.dart';
import 'package:calsee_themes/render/fonts.dart';
import 'package:calsee_themes/render/glass/glass_faces.dart';
import 'package:calsee_themes/render/m3e/m3e_key_face.dart';
import 'package:calsee_themes/render/neo_brutalism/neo_brutal_display_face.dart';
import 'package:calsee_themes/render/neo_brutalism/neo_brutal_key_face.dart';
import 'package:calsee_themes/render/neopop/neopop_key_face.dart';
import 'package:calsee_themes/render/neumorphism/neumorphic_key_face.dart';
import 'package:calsee_themes/render/paper_ink/paper_ink_faces.dart';
import 'package:calsee_themes/render/retro/lcd_display_face.dart';
import 'package:calsee_themes/render/retro/retro_key_face.dart';
import 'package:calsee_themes/render/shapes.dart';
import 'package:calsee_themes/render/vaporwave/vaporwave_faces.dart';
import 'package:calsee_themes/render/y2k_aero/y2k_aero_faces.dart';
import 'package:flutter/widgets.dart';

/// A mass-1 spring from an integer token (motion brief §2.6).
SpringDescription springFromToken(SpringToken token) =>
    SpringDescription.withDampingRatio(
      mass: 1,
      stiffness: token.stiffness.toDouble(),
      ratio: token.dampingRatio,
    );

/// The key colour group of [role] (digit/decimal/sign → digit; operator;
/// equals; everything else → function).
KeyGroup keyGroupOf(KeyRole role) => switch (role) {
  KeyRole.digit || KeyRole.decimal || KeyRole.sign => KeyGroup.digit,
  KeyRole.operator => KeyGroup.operator,
  KeyRole.equals => KeyGroup.equals,
  _ => KeyGroup.function,
};

/// Resolves [ThemeSpec]s, memoising the last few so the same spec always
/// yields the identical [CalcThemeData] (cheap `==`, no rebuild churn).
abstract final class ThemeResolver {
  static final LinkedHashMap<(ThemeSpec, bool, GlassRendering), CalcThemeData>
  _memo = LinkedHashMap();

  /// Specs kept in the memo.
  static const int memoCapacity = 16;

  /// The [CalcThemeData] for [spec]. [highContrast] (platform setting)
  /// selects the plain theme's high-contrast variants; generated themes
  /// get their high-contrast treatment from the accessible lock instead.
  ///
  /// [glass] (glass mode and effects tier from `MotionPreferences`) is
  /// passed to the families in [renderedKeyFaceRegistry]: Liquid Glass's
  /// Reduce Transparency solid tint, frosted or full glass, and the other
  /// families' lite-tier artwork.
  static CalcThemeData resolve(
    ThemeSpec spec, {
    bool highContrast = false,
    GlassRendering glass = GlassRendering.standard,
  }) {
    // Only Liquid Glass is translucent, so only it reads the glass mode;
    // the other rendered families read the effects tier alone (one memo
    // entry whatever Reduce Transparency says).
    final rendering = switch (spec.family) {
      ThemeFamily.liquidGlass => glass,
      final f when renderedKeyFaceRegistry.containsKey(f) => GlassRendering(
        tier: glass.tier,
      ),
      _ => GlassRendering.standard,
    };
    final key = (spec, highContrast, rendering);
    final hit = _memo.remove(key);
    if (hit != null) return _memo[key] = hit;
    final data = _memo[key] = _resolve(
      spec,
      highContrast: highContrast,
      glass: rendering,
    );
    while (_memo.length > memoCapacity) {
      _memo.remove(_memo.keys.first);
    }
    return data;
  }

  /// Resolves [spec] and builds its key-shape morphs for [cellSizes] ahead
  /// of a theme commit (call when the theme enters the prefetch queue).
  static CalcThemeData prepare(ThemeSpec spec, Iterable<Size> cellSizes) {
    final data = resolve(spec);
    data.keyFace.prepare(cellSizes);
    return data;
  }

  /// Clears the memo (tests).
  static void clearMemo() => _memo.clear();

  static CalcThemeData _resolve(
    ThemeSpec spec, {
    required bool highContrast,
    GlassRendering glass = GlassRendering.standard,
  }) {
    if (spec.family == ThemeFamily.plain) {
      return PlainTheme.of(
        spec.brightness == ThemeBrightness.dark
            ? Brightness.dark
            : Brightness.light,
        highContrast: highContrast || spec.accessible,
      );
    }
    final palette = spec.palette;
    final type = spec.type;
    final motion = spec.motion;
    final keyWeight = _weight(type.keyWeight);
    final opWeight = _weight(type.operatorWeight);
    final outlined =
        spec.keyStyle.kind == KeyStyleKind.outlined ||
        (spec.keyStyle.outlineWidthCdp > 0 &&
            spec.keyStyle.kind != KeyStyleKind.extruded);
    // Liquid Glass faces are translucent tints: the key style carries the
    // solid tint (the tint over the background's diffuse colour), which is
    // what per-frame label repair and Reduce Transparency use; the glass
    // renderer holds the tints themselves.
    final glassFamily = spec.family == ThemeFamily.liquidGlass;
    KeyStyle style(KeyColors c, FontWeight weight) => KeyStyle(
      fill: glassFamily
          ? glassSolidTint(c.face, glassDiffuseColor(spec.background))
          : Color(c.face),
      label: Color(c.label),
      labelWeight: weight,
      outline: outlined ? Color(c.edge) : null,
    );
    final face =
        renderedKeyFaceRegistry[spec.family]?.call(spec, rendering: glass) ??
        keyFaceFor(spec);
    final background = spec.background;
    final plainBackground =
        background.kind == BackgroundKind.solid &&
        background.pattern == BackgroundPattern.none;
    return CalcThemeData(
      brightness: spec.brightness == ThemeBrightness.dark
          ? Brightness.dark
          : Brightness.light,
      background: Color(palette.background),
      displayText: Color(palette.displayText),
      previewText: Color(palette.previewText),
      errorText: Color(palette.error),
      caret: Color(palette.caret),
      focusRing: Color(palette.focusRing),
      digitKey: style(palette.digit, keyWeight),
      operatorKey: style(palette.operator, opWeight),
      equalsKey: style(palette.equals, opWeight),
      functionKey: style(palette.function, keyWeight),
      keyCornerFraction: _focusCornerFraction(spec),
      displayFontFamily: BundledFont.fromId(type.displayFont).family,
      displayWeight: type.displayWeight,
      keyFontFamily: BundledFont.fromId(type.keyFont).family,
      pressIn: springFromToken(motion.pressIn),
      release: springFromToken(motion.release),
      releaseAlt: switch (motion.releaseAlt) {
        final token? => springFromToken(token),
        null => null,
      },
      pressScale: motion.scalePermille / 1000,
      pressedOverlayOpacity: spec.keyStyle.stateLayerPermille / 1000,
      keyFace: face,
      focusRingWidth: spec.accessible || highContrast ? 3 : 2,
      backdrop: plainBackground
          ? null
          : SpecBackdrop(spec: background, surface: Color(palette.surface)),
      displayEntry: displayEntryFor(motion),
      releaseHaptic: motion.releaseHaptic,
      displayFace: switch (renderedDisplayFaceRegistry[spec.family]) {
        final rendered? => rendered(spec, rendering: glass),
        null => displayFaceFor(spec),
      },
      accessiblePreviewText: accessiblePreviewTextFor(spec),
      chrome: chromeStyleFor(spec),
    );
  }

  static FontWeight _weight(int css) => FontWeight(css.clamp(100, 900));

  static double _focusCornerFraction(ThemeSpec spec) {
    final shape = spec.keyShape;
    // Bauhaus mixes blocks and discs on one keypad (`kind` is only the
    // digits' silhouette) and its painter ignores the corner fraction, so
    // the ring follows the blocks' corners around every key: a stadium
    // would cut through the block keys' corners.
    if (spec.family == ThemeFamily.bauhaus) {
      return shape.cornerFraction.clamp(0.0, 0.5);
    }
    return switch (shape.kind) {
      KeyShapeKind.circle || KeyShapeKind.pill => 0.5,
      KeyShapeKind.m3eMorph => switch (shape.m3eShape) {
        null || M3eShape.circle || M3eShape.pill => 0.5,
        M3eShape.square => 0.3,
        _ => 0.5,
      },
      _ => shape.cornerFraction.clamp(0.0, 0.5),
    };
  }
}

/// The display glyph entry for [motion] (motion brief §2.3).
DisplayEntry displayEntryFor(MotionSpec motion) {
  final spring = springFromToken(motion.entrySpring ?? motion.release);
  return switch (motion.entry) {
    EntryStyle.pop || EntryStyle.stamp => DisplayEntry(
      kind: DisplayEntryKind.pop,
      startScale: motion.entryScalePermille / 1000,
      spring: spring,
    ),
    EntryStyle.drop => DisplayEntry(
      kind: DisplayEntryKind.drop,
      startOffset: motion.entryOffsetCdp / 100,
      spring: spring,
    ),
    EntryStyle.rise => DisplayEntry(
      kind: DisplayEntryKind.rise,
      startOffset: motion.entryOffsetCdp / 100,
      spring: spring,
    ),
    EntryStyle.segments => const DisplayEntry(
      kind: DisplayEntryKind.segments,
      duration: LcdDisplayFace.segmentOn,
    ),
    // Paper & ink: ink soaks in over effectsDefault (150 ms) from 104 %.
    EntryStyle.bleed => const DisplayEntry(
      kind: DisplayEntryKind.bleed,
      startScale: 1.04,
      duration: Duration(milliseconds: 150),
    ),
    // Terminal / Cyberpunk: instant glyph plus a 60 ms bloom 115 % → 100 %.
    EntryStyle.glyph => const DisplayEntry(
      kind: DisplayEntryKind.glyph,
      startScale: 1.15,
      duration: Duration(milliseconds: 60),
    ),
    _ => DisplayEntry.none,
  };
}

/// The resting [KeyGeometry] of digit/function keys in [shape].
KeyGeometry restGeometry(KeyShapeSpec shape) => KeyGeometry(
  shape.kind,
  m3eShape: shape.m3eShape,
  cornerPermille: shape.cornerPermille,
);

/// The resting [KeyGeometry] of operator/`=` keys, or null when they use
/// [restGeometry].
KeyGeometry? operatorGeometry(KeyShapeSpec shape) {
  final kind = shape.operatorKind;
  if (kind == null) return null;
  return KeyGeometry(
    kind,
    m3eShape: shape.operatorM3eShape,
    cornerPermille: shape.cornerPermille,
  );
}

/// Builds the key renderer for a spec of one family.
typedef KeyFaceFactory = KeyFaceRenderer Function(ThemeSpec spec);

/// Family → key renderer (design doc: each new family is one generator
/// definition plus one entry here). Families without an entry are drawn
/// by [genericKeyFaceFor].
final Map<ThemeFamily, KeyFaceFactory> keyFaceRegistry = {
  ThemeFamily.plain: (_) => const PlainKeyFace(),
  ThemeFamily.m3Expressive: m3eFaceFor,
  ThemeFamily.neoPop: neoPopFaceFor,
  ThemeFamily.neumorphism: neumorphicFaceFor,
  ThemeFamily.retro: retroFaceFor,
  ThemeFamily.neoBrutalism: neoBrutalFaceFor,
  ThemeFamily.liquidGlass: glassKeyFaceFor,
  ThemeFamily.claymorphism: claymorphismKeyFaceFor,
  ThemeFamily.y2kChrome: y2kAeroKeyFaceFor,
  ThemeFamily.paperInk: paperInkKeyFaceFor,
  ThemeFamily.cyberpunk: cyberpunkKeyFaceFor,
  ThemeFamily.vaporwave: vaporwaveKeyFaceFor,
  ThemeFamily.bauhaus: bauhausKeyFaceFor,
};

/// A family key renderer that honours the device's [GlassRendering]
/// (Reduce Transparency, the lite effects tier).
typedef RenderedKeyFaceFactory = KeyFaceRenderer Function(
  ThemeSpec spec, {
  GlassRendering rendering,
});

/// Families whose key renderers take the device [GlassRendering]; the
/// resolver memoises them per rendering. Everyone else is resolved with
/// [GlassRendering.standard].
final Map<ThemeFamily, RenderedKeyFaceFactory> renderedKeyFaceRegistry = {
  ThemeFamily.liquidGlass: glassKeyFaceFor,
  ThemeFamily.claymorphism: claymorphismKeyFaceFor,
  ThemeFamily.y2kChrome: y2kAeroKeyFaceFor,
  ThemeFamily.paperInk: paperInkKeyFaceFor,
  ThemeFamily.cyberpunk: cyberpunkKeyFaceFor,
  ThemeFamily.vaporwave: vaporwaveKeyFaceFor,
  ThemeFamily.bauhaus: bauhausKeyFaceFor,
};

/// A family display face that honours the device's [GlassRendering].
typedef RenderedDisplayFaceFactory = DisplayFace? Function(
  ThemeSpec spec, {
  GlassRendering rendering,
});

/// Families whose display faces take the device [GlassRendering].
final Map<ThemeFamily, RenderedDisplayFaceFactory> renderedDisplayFaceRegistry =
    {
      ThemeFamily.liquidGlass: glassDisplayFaceFor,
      ThemeFamily.claymorphism: claymorphismDisplayFaceFor,
      ThemeFamily.y2kChrome: y2kAeroDisplayFaceFor,
      ThemeFamily.paperInk: paperInkDisplayFaceFor,
      ThemeFamily.cyberpunk: cyberpunkDisplayFaceFor,
      ThemeFamily.vaporwave: vaporwaveDisplayFaceFor,
      ThemeFamily.bauhaus: bauhausDisplayFaceFor,
    };

/// The key renderer for [spec]: chosen by family only, never by style
/// fields.
KeyFaceRenderer keyFaceFor(ThemeSpec spec) =>
    (keyFaceRegistry[spec.family] ?? genericKeyFaceFor)(spec);

/// Builds the display face for a spec of one family.
typedef DisplayFaceFactory = DisplayFace? Function(ThemeSpec spec);

/// Family → display face (the display-style hook, docs/m4-design.md §B).
/// Families without an entry draw the display with their font
/// (`CalcThemeData.displayFace == null`).
final Map<ThemeFamily, DisplayFaceFactory> displayFaceRegistry = {
  ThemeFamily.retro: lcdDisplayFaceFor,
  ThemeFamily.neoBrutalism: neoBrutalDisplayFaceFor,
  ThemeFamily.liquidGlass: glassDisplayFaceFor,
  ThemeFamily.claymorphism: claymorphismDisplayFaceFor,
  ThemeFamily.y2kChrome: y2kAeroDisplayFaceFor,
  ThemeFamily.paperInk: paperInkDisplayFaceFor,
  ThemeFamily.cyberpunk: cyberpunkDisplayFaceFor,
  ThemeFamily.vaporwave: vaporwaveDisplayFaceFor,
  ThemeFamily.bauhaus: bauhausDisplayFaceFor,
};

/// The display face for [spec], chosen by family.
DisplayFace? displayFaceFor(ThemeSpec spec) =>
    displayFaceRegistry[spec.family]?.call(spec);

/// Neo-brutalism keys for [spec]: shadow offset = the press depth
/// (seeded 3–5 dp), outline width from the key style, ink = the hard
/// shadow colour (outlines come from each group's `KeyColors.edge`).
NeoBrutalKeyFace neoBrutalFaceFor(ThemeSpec spec) {
  final style = spec.keyStyle;
  final depthCdp = spec.motion.depthCdp > 0
      ? spec.motion.depthCdp
      : style.shadowOffsetCdp;
  return NeoBrutalKeyFace(
    shadowOffset: depthCdp / 100,
    outlineWidth: style.outlineWidthCdp / 100,
    ink: Color(spec.palette.shadow),
    cornerFraction: spec.keyShape.cornerFraction.clamp(0.0, 0.5),
    widthPermille: spec.type.widthPermille,
    slashedZero: spec.type.slashedZero,
  );
}

/// Neo-brutalism's outlined display card for [spec]: panel = surface, ink
/// = the hard shadow colour, the heavy wide display cut from the type.
NeoBrutalDisplayFace neoBrutalDisplayFaceFor(ThemeSpec spec) {
  final style = spec.keyStyle;
  return NeoBrutalDisplayFace(
    panel: Color(spec.palette.surface | 0xFF000000),
    ink: Color(spec.palette.shadow),
    outlineWidth: style.outlineWidthCdp / 100,
    shadowOffset:
        (spec.motion.depthCdp > 0
            ? spec.motion.depthCdp
            : style.shadowOffsetCdp) /
        100,
    cornerFraction: spec.keyShape.cornerFraction.clamp(0.0, 0.5),
    weight: spec.type.displayWeight,
    widthPermille: spec.type.widthPermille,
  );
}

/// Retro's 7-segment panel for [spec] (only for 7-segment specs:
/// `TypeSpec.lcd`): panel = surface, ghost segments = `lcdGhost`, a VFD
/// when the panel is darker than its segments; the bezel is the body a
/// step darker (desk) or lighter (pocket).
LcdDisplayFace? lcdDisplayFaceFor(ThemeSpec spec) {
  if (!spec.type.lcd) return null;
  final palette = spec.palette;
  final panel = Color(palette.surface);
  final segment = Color(palette.displayText);
  final vfd = panel.computeLuminance() < segment.computeLuminance();
  final body = palette.background;
  final bodyL = argbToOklch(body).l;
  final bezel = bodyL < 0.5 ? darkenArgb(body, -0.035) : darkenArgb(body, 0.16);
  return LcdDisplayFace(
    panel: panel,
    bezel: Color(bezel | 0xFF000000),
    ghost: switch (palette.lcdGhost) {
      final g? => Color(g),
      null => null,
    },
    vfd: vfd,
    widthPermille: spec.type.widthPermille,
  );
}

/// Retro keycaps for [spec]: travel from the motion token (seeded 2–3 dp),
/// skirts = palette edges, bevel and contact shadow from the palette's
/// highlight / shadow.
RetroKeyFace retroFaceFor(ThemeSpec spec) {
  final palette = spec.palette;
  final depthCdp = spec.motion.depthCdp > 0
      ? spec.motion.depthCdp
      : spec.keyStyle.extrudeDepthCdp;
  final shadow = Color(palette.shadow);
  return RetroKeyFace(
    travel: depthCdp / 100,
    digitSkirt: Color(palette.digit.edge),
    operatorSkirt: Color(palette.operator.edge),
    equalsSkirt: Color(palette.equals.edge),
    functionSkirt: Color(palette.function.edge),
    cornerFraction: spec.keyShape.cornerFraction.clamp(0.0, 0.5),
    highlight: Color(palette.highlight),
    shade: shadow,
    shadowColor: shadow,
    slashedZero: spec.type.slashedZero,
  );
}

/// M3 Expressive renderer: rest shape → pressed rounded rect at the motion
/// token's corner (30 % of the short side by default).
M3eKeyFace m3eFaceFor(ThemeSpec spec) {
  final shape = spec.keyShape;
  return M3eKeyFace(
    restShape: restGeometry(shape),
    operatorShape: operatorGeometry(shape),
    pressedCornerPermille: spec.motion.cornerPermille > 0
        ? spec.motion.cornerPermille
        : shape.morphCornerPermille ?? 300,
    slashedZero: spec.type.slashedZero,
  );
}

/// The generic fallback for families without a renderer of their own:
/// flat faces in the spec's shapes (no family-specific artwork).
M3eKeyFace genericKeyFaceFor(ThemeSpec spec) {
  final shape = spec.keyShape;
  return M3eKeyFace(
    restShape: restGeometry(shape),
    operatorShape: operatorGeometry(shape),
    pressedCornerPermille: shape.morphCornerPermille ?? shape.cornerPermille,
    slashedZero: spec.type.slashedZero,
  );
}

/// NeoPOP renderer for [spec]: depth from the motion token (seeded 3–5 dp),
/// side tone = palette edge, bottom tone = the edge darkened by half of
/// `edgeShadePermille` in OKLCH lightness.
NeoPopKeyFace neoPopFaceFor(ThemeSpec spec) {
  final palette = spec.palette;
  final keyStyle = spec.keyStyle;
  final shade =
      (keyStyle.edgeShadePermille > 0 ? keyStyle.edgeShadePermille : 180) /
      2000;
  NeoPopEdges edges(KeyColors c) => NeoPopEdges(
    side: Color(c.edge),
    bottom: Color(darkenArgb(c.edge, shade)),
  );
  NeoPopShape shapeOf(KeyShapeKind kind) => switch (kind) {
    KeyShapeKind.circle || KeyShapeKind.pill => NeoPopShape.round,
    _ => NeoPopShape.roundedRect,
  };
  final depthCdp = spec.motion.depthCdp > 0
      ? spec.motion.depthCdp
      : keyStyle.extrudeDepthCdp;
  final opKind = spec.keyShape.operatorKind;
  return NeoPopKeyFace(
    depth: depthCdp / 100,
    digitEdges: edges(palette.digit),
    operatorEdges: edges(palette.operator),
    equalsEdges: edges(palette.equals),
    functionEdges: edges(palette.function),
    cornerFraction: spec.keyShape.cornerFraction,
    shape: shapeOf(spec.keyShape.kind),
    operatorShape: opKind == null ? null : shapeOf(opKind),
    shadowOffset: keyStyle.shadowOffsetCdp / 100,
    shadowColor: Color(palette.shadow),
    slashedZero: spec.type.slashedZero,
  );
}

/// [argb] with its OKLCH lightness lowered by [amount] (0–1), gamut
/// mapped, alpha kept.
int darkenArgb(int argb, double amount) {
  final lch = argbToOklch(argb);
  final l = (lch.l - amount).clamp(0.0, 1.0);
  final rgb = oklchToArgb(l, lch.c, lch.h) & 0x00FFFFFF;
  return (argb & 0xFF000000) | rgb;
}

/// The M2 plain theme as a [ThemeSpec] (family `plain`, id 0). Resolving
/// it returns exactly `PlainTheme.of(brightness)`.
ThemeSpec plainThemeSpec(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final t = PlainTheme.of(brightness);
  int c(Color color) => color.toARGB32();
  KeyColors k(KeyStyle s) => KeyColors(
    face: c(s.fill),
    label: c(s.label),
    edge: c(s.outline ?? s.fill),
  );
  return ThemeSpec(
    seed: 0,
    family: ThemeFamily.plain,
    engineVersion: 1,
    variant: ThemeVariant.hero,
    brightness: dark ? ThemeBrightness.dark : ThemeBrightness.light,
    palette: Palette(
      background: c(t.background),
      surface: c(t.background),
      displayText: c(t.displayText),
      previewText: c(t.previewText),
      error: c(t.errorText),
      caret: c(t.caret),
      focusRing: c(t.focusRing),
      accent: c(t.equalsKey.fill),
      digit: k(t.digitKey),
      operator: k(t.operatorKey),
      equals: k(t.equalsKey),
      function: k(t.functionKey),
      shadow: 0x00000000,
      highlight: 0x00000000,
      seedColor: c(t.equalsKey.fill),
    ),
    keyShape: const KeyShapeSpec(kind: KeyShapeKind.roundedRect),
    keyStyle: const KeyStyleSpec(
      kind: KeyStyleKind.flat,
      stateLayerPermille: 120,
    ),
    type: const TypeSpec(
      displayFont: FontIds.platform,
      keyFont: FontIds.platform,
      keyWeight: 400,
      operatorWeight: 600,
    ),
    background: BackgroundSpec(
      kind: BackgroundKind.solid,
      colors: List.unmodifiable([c(t.background)]),
    ),
    motion: const MotionSpec(
      verb: PressVerb.morph,
      scheme: MotionScheme.standard,
      pressIn: SpringTokens.effectsFast,
      release: SpringTokens.effectsDefault,
      scalePermille: 950,
      entry: EntryStyle.pop,
      impact: ImpactStyle.light,
    ),
    sound: SoundPackId.softTap,
    name: 'Plain',
    nonColourOperatorCue: OperatorCue.weight,
  );
}
