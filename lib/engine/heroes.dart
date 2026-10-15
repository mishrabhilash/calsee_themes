/// Hand-crafted hero themes (spec §5.2: "every ~8–12 swipes, inject a
/// hand-crafted hero theme"; design doc: ≥ 3 per enabled family).
///
/// Heroes are literal [ThemeSpec]s: hand-picked ARGB palettes plus
/// hand-tuned shape, type and motion. They never depend on the generator,
/// so they cannot change when the generator does. Each one passes the same
/// guardrails as generated themes (test/themes/engine/heroes_test.dart),
/// and [heroForAccessible] repairs them for the Accessible lock.
///
/// Hero ids are stable (share codes carry them in the seed field with
/// family 31); never reuse or renumber one.
library;

import 'package:calsee_themes/engine/bauhaus_heroes.dart';
import 'package:calsee_themes/engine/claymorphism_heroes.dart';
import 'package:calsee_themes/engine/cyberpunk_heroes.dart';
import 'package:calsee_themes/engine/families.dart' show FontIds;
import 'package:calsee_themes/engine/guardrails.dart';
import 'package:calsee_themes/engine/liquid_glass_heroes.dart';
import 'package:calsee_themes/engine/neo_brutalism_heroes.dart';
import 'package:calsee_themes/engine/neumorphism_heroes.dart';
import 'package:calsee_themes/engine/paper_ink_heroes.dart';
import 'package:calsee_themes/engine/retro_heroes.dart';
import 'package:calsee_themes/engine/theme_spec.dart';
import 'package:calsee_themes/engine/vaporwave_heroes.dart';
import 'package:calsee_themes/engine/y2k_aero_heroes.dart';

// ------------------------------------------------------------ shared bits --

const KeyStyleSpec _m3eStyle = KeyStyleSpec(kind: KeyStyleKind.flat);

const KeyStyleSpec _neoPopStyle4 = KeyStyleSpec(
  kind: KeyStyleKind.extruded,
  extrudeDepthCdp: 400,
  edgeShadePermille: 180,
  stateLayerPermille: 0,
);

const KeyStyleSpec _neoPopStyle5 = KeyStyleSpec(
  kind: KeyStyleKind.extruded,
  extrudeDepthCdp: 500,
  edgeShadePermille: 180,
  stateLayerPermille: 0,
);

const KeyStyleSpec _neoPopStyle3 = KeyStyleSpec(
  kind: KeyStyleKind.extruded,
  extrudeDepthCdp: 300,
  edgeShadePermille: 180,
  stateLayerPermille: 0,
);

/// M3E motion (motion brief §2.3 row 1) with a hand-tuned release.
const MotionSpec _m3eMotionSoft = MotionSpec(
  verb: PressVerb.morph,
  scheme: MotionScheme.expressive,
  pressIn: SpringTokens.effectsFast,
  release: SpringToken(720, 640),
  releaseAlt: SpringTokens.effectsDefault,
  scalePermille: 970,
  cornerPermille: 300,
  squishPermille: 100,
  stateLayerSnap: true,
  entry: EntryStyle.pop,
  entryScalePermille: 850,
  entrySpring: SpringTokens.expressiveFast,
  impact: ImpactStyle.light,
);

const MotionSpec _m3eMotionBouncy = MotionSpec(
  verb: PressVerb.morph,
  scheme: MotionScheme.expressive,
  pressIn: SpringTokens.effectsFast,
  release: SpringToken(880, 600),
  releaseAlt: SpringTokens.effectsDefault,
  scalePermille: 970,
  cornerPermille: 300,
  squishPermille: 100,
  stateLayerSnap: true,
  entry: EntryStyle.pop,
  entryScalePermille: 850,
  entrySpring: SpringTokens.expressiveFast,
  impact: ImpactStyle.light,
);

/// NeoPOP motion (motion brief §2.3 row 3) at 4 dp depth.
const MotionSpec _neoPopMotion4 = MotionSpec(
  verb: PressVerb.plunge,
  scheme: MotionScheme.standard,
  pressIn: SpringTokens.hardPress,
  release: SpringTokens.effectsDefault,
  depthCdp: 400,
  entry: EntryStyle.drop,
  entryOffsetCdp: -600,
  entrySpring: SpringTokens.hardPress,
  impact: ImpactStyle.rigid,
  impactPermille: 900,
  releaseHaptic: true,
  releaseImpactPermille: 400,
);

const MotionSpec _neoPopMotion5 = MotionSpec(
  verb: PressVerb.plunge,
  scheme: MotionScheme.standard,
  pressIn: SpringTokens.hardPress,
  release: SpringToken(1440, 1000),
  depthCdp: 500,
  entry: EntryStyle.drop,
  entryOffsetCdp: -600,
  entrySpring: SpringTokens.hardPress,
  impact: ImpactStyle.rigid,
  impactPermille: 1000,
  releaseHaptic: true,
  releaseImpactPermille: 450,
);

const MotionSpec _neoPopMotion3 = MotionSpec(
  verb: PressVerb.plunge,
  scheme: MotionScheme.standard,
  pressIn: SpringTokens.hardPress,
  release: SpringToken(1760, 1000),
  depthCdp: 300,
  entry: EntryStyle.drop,
  entryOffsetCdp: -600,
  entrySpring: SpringTokens.hardPress,
  impact: ImpactStyle.rigid,
  impactPermille: 900,
  releaseHaptic: true,
  releaseImpactPermille: 400,
);

const TypeSpec _robotoFlex = TypeSpec(
  displayFont: FontIds.robotoFlex,
  keyFont: FontIds.robotoFlex,
  keyWeight: 550,
  operatorWeight: 700,
);

const TypeSpec _spaceGrotesk = TypeSpec(
  displayFont: FontIds.spaceGrotesk,
  keyFont: FontIds.spaceGrotesk,
  displayWeight: 600,
  keyWeight: 650,
  operatorWeight: 700,
);

// ----------------------------------------------------------------- heroes --

/// Every hero, in id order. Ids 1–4: Material 3 Expressive; 5–7: NeoPOP;
/// 20–22: Liquid Glass; 40–42: Neumorphism; 50–52: Retro hardware;
/// 60–62: Neo-brutalism; 70–72: Claymorphism; 100–102: Y2K / Frutiger
/// Aero; 110–112: Paper & ink; 130–132: Cyberpunk; 140–142: Vaporwave;
/// 150–152: Bauhaus.
const List<ThemeSpec> heroThemes = [
  // 1 — a soft violet night: lavender operators, rose `=`, cookie keys.
  ThemeSpec(
    seed: 1,
    family: ThemeFamily.m3Expressive,
    engineVersion: 1,
    variant: ThemeVariant.hero,
    heroId: 1,
    brightness: ThemeBrightness.dark,
    palette: Palette(
      background: 0xFF1C1A22,
      surface: 0xFF25222D,
      displayText: 0xFFF4EFFF,
      previewText: 0xFFC9C2D8,
      error: 0xFFFFB4AB,
      caret: 0xFFD0BCFF,
      focusRing: 0xFFD0BCFF,
      accent: 0xFFD0BCFF,
      digit: KeyColors(face: 0xFF332E3D, label: 0xFFF4EFFF, edge: 0xFF474351),
      operator: KeyColors(
        face: 0xFFD0BCFF,
        label: 0xFF24005A,
        edge: 0xFFE6DDFF,
      ),
      equals: KeyColors(face: 0xFFFFB0CF, label: 0xFF3E0021, edge: 0xFFFFD9E7),
      function: KeyColors(
        face: 0xFF4A4358,
        label: 0xFFFFFFFF,
        edge: 0xFF60596C,
      ),
      shadow: 0x52000000,
      highlight: 0x14FFFFFF,
      seedColor: 0xFFD0BCFF,
    ),
    keyShape: KeyShapeSpec(
      kind: KeyShapeKind.m3eMorph,
      cornerPermille: 500,
      m3eShape: M3eShape.cookie4Sided,
      morphTo: KeyShapeKind.roundedRect,
      morphCornerPermille: 300,
      operatorKind: KeyShapeKind.m3eMorph,
      operatorM3eShape: M3eShape.circle,
    ),
    keyStyle: _m3eStyle,
    type: _robotoFlex,
    background: BackgroundSpec(
      kind: BackgroundKind.linearGradient,
      colors: [0xFF1C1A22, 0xFF221B2A],
      angleTenths: 1350,
    ),
    motion: _m3eMotionSoft,
    sound: SoundPackId.softTap,
    name: 'Lavender Dusk',
    nonColourOperatorCue: OperatorCue.shape,
  ),
  // 2 — whisked green tea on rice paper; a deep forest `=`.
  ThemeSpec(
    seed: 2,
    family: ThemeFamily.m3Expressive,
    engineVersion: 1,
    variant: ThemeVariant.hero,
    heroId: 2,
    brightness: ThemeBrightness.light,
    palette: Palette(
      background: 0xFFF5F8EE,
      surface: 0xFFE9EEE0,
      displayText: 0xFF181D14,
      previewText: 0xFF434C3B,
      error: 0xFFBA1A1A,
      caret: 0xFF3F6A2E,
      focusRing: 0xFF3F6A2E,
      accent: 0xFF3F6A2E,
      digit: KeyColors(face: 0xFFFFFFFF, label: 0xFF181D14, edge: 0xFFE4E4E4),
      operator: KeyColors(
        face: 0xFF3F6A2E,
        label: 0xFFFFFFFF,
        edge: 0xFF2F5221,
      ),
      equals: KeyColors(face: 0xFF1E3D14, label: 0xFFFFFFFF, edge: 0xFF0E2706),
      function: KeyColors(
        face: 0xFFD9E7CB,
        label: 0xFF131F0B,
        edge: 0xFFC0CCB5,
      ),
      shadow: 0x29000000,
      highlight: 0x66FFFFFF,
      seedColor: 0xFF3F6A2E,
    ),
    keyShape: KeyShapeSpec(
      kind: KeyShapeKind.m3eMorph,
      cornerPermille: 500,
      m3eShape: M3eShape.circle,
      morphTo: KeyShapeKind.roundedRect,
      morphCornerPermille: 300,
    ),
    keyStyle: _m3eStyle,
    type: _robotoFlex,
    background: BackgroundSpec(
      kind: BackgroundKind.solid,
      colors: [0xFFF5F8EE],
    ),
    motion: _m3eMotionSoft,
    sound: SoundPackId.softTap,
    name: 'Matcha Morning',
  ),
  // 3 — warm coral operators and a lagoon-teal `=` on shell white.
  ThemeSpec(
    seed: 3,
    family: ThemeFamily.m3Expressive,
    engineVersion: 1,
    variant: ThemeVariant.hero,
    heroId: 3,
    brightness: ThemeBrightness.light,
    palette: Palette(
      background: 0xFFFFF8F6,
      surface: 0xFFFAEBE6,
      displayText: 0xFF231917,
      previewText: 0xFF54433F,
      error: 0xFFBA1A1A,
      caret: 0xFF9A3B22,
      focusRing: 0xFF9A3B22,
      accent: 0xFF9A3B22,
      digit: KeyColors(face: 0xFFFFFFFF, label: 0xFF231917, edge: 0xFFE4E4E4),
      operator: KeyColors(
        face: 0xFFA8401F,
        label: 0xFFFFFFFF,
        edge: 0xFF853116,
      ),
      equals: KeyColors(face: 0xFF00695E, label: 0xFFFFFFFF, edge: 0xFF005047),
      function: KeyColors(
        face: 0xFFFFDAD1,
        label: 0xFF3A0B01,
        edge: 0xFFE0C2BA,
      ),
      shadow: 0x29000000,
      highlight: 0x66FFFFFF,
      seedColor: 0xFFA8401F,
    ),
    keyShape: KeyShapeSpec(
      kind: KeyShapeKind.m3eMorph,
      cornerPermille: 500,
      m3eShape: M3eShape.cookie6Sided,
      morphTo: KeyShapeKind.roundedRect,
      morphCornerPermille: 300,
      operatorKind: KeyShapeKind.m3eMorph,
      operatorM3eShape: M3eShape.sunny,
    ),
    keyStyle: _m3eStyle,
    type: _robotoFlex,
    background: BackgroundSpec(
      kind: BackgroundKind.solid,
      colors: [0xFFFFF8F6],
    ),
    motion: _m3eMotionBouncy,
    sound: SoundPackId.softTap,
    name: 'Coral Reef',
    nonColourOperatorCue: OperatorCue.shape,
  ),
  // 4 — deep-sea navy, periwinkle operators and a gold `=`.
  ThemeSpec(
    seed: 4,
    family: ThemeFamily.m3Expressive,
    engineVersion: 1,
    variant: ThemeVariant.hero,
    heroId: 4,
    brightness: ThemeBrightness.dark,
    palette: Palette(
      background: 0xFF0E1320,
      surface: 0xFF161C2B,
      displayText: 0xFFE9EEFF,
      previewText: 0xFFB7C1DA,
      error: 0xFFFFB4AB,
      caret: 0xFFADC6FF,
      focusRing: 0xFFADC6FF,
      accent: 0xFFADC6FF,
      digit: KeyColors(face: 0xFF1D2537, label: 0xFFE9EEFF, edge: 0xFF32394A),
      operator: KeyColors(
        face: 0xFFADC6FF,
        label: 0xFF0A2A66,
        edge: 0xFFD3E1FF,
      ),
      equals: KeyColors(face: 0xFFFFD479, label: 0xFF3A2800, edge: 0xFFFFF3DC),
      function: KeyColors(
        face: 0xFF2D3950,
        label: 0xFFFFFFFF,
        edge: 0xFF444E63,
      ),
      shadow: 0x52000000,
      highlight: 0x14FFFFFF,
      seedColor: 0xFFADC6FF,
    ),
    keyShape: KeyShapeSpec(
      kind: KeyShapeKind.m3eMorph,
      cornerPermille: 500,
      m3eShape: M3eShape.square,
      morphTo: KeyShapeKind.roundedRect,
      morphCornerPermille: 300,
    ),
    keyStyle: _m3eStyle,
    type: _robotoFlex,
    background: BackgroundSpec(
      kind: BackgroundKind.linearGradient,
      colors: [0xFF0E1320, 0xFF121A2C],
    ),
    motion: _m3eMotionBouncy,
    sound: SoundPackId.softTap,
    name: 'Midnight Sapphire',
  ),
  // 5 — CRED-dark charcoal, mango operators, mint `=`.
  ThemeSpec(
    seed: 5,
    family: ThemeFamily.neoPop,
    engineVersion: 1,
    variant: ThemeVariant.hero,
    heroId: 5,
    brightness: ThemeBrightness.dark,
    palette: Palette(
      background: 0xFF0D0D0D,
      surface: 0xFF171717,
      displayText: 0xFFFFFFFF,
      previewText: 0xFFBDBDBD,
      error: 0xFFFF6B6B,
      caret: 0xFFFFB800,
      focusRing: 0xFFFFB800,
      accent: 0xFFFFB800,
      digit: KeyColors(face: 0xFF262626, label: 0xFFFFFFFF, edge: 0xFF020202),
      operator: KeyColors(
        face: 0xFFFFB800,
        label: 0xFF0D0D0D,
        edge: 0xFFB88400,
      ),
      equals: KeyColors(face: 0xFF00E0B0, label: 0xFF0D0D0D, edge: 0xFF00A07D),
      function: KeyColors(
        face: 0xFF3B3B3B,
        label: 0xFFFFFFFF,
        edge: 0xFF101010,
      ),
      shadow: 0xB3000000,
      highlight: 0x14FFFFFF,
      seedColor: 0xFFFFB800,
    ),
    keyShape: KeyShapeSpec(kind: KeyShapeKind.roundedRect, cornerPermille: 0),
    keyStyle: _neoPopStyle4,
    type: _spaceGrotesk,
    background: BackgroundSpec(
      kind: BackgroundKind.solid,
      colors: [0xFF0D0D0D],
    ),
    motion: _neoPopMotion4,
    sound: SoundPackId.pop,
    name: 'Electric Mango',
  ),
  // 6 — hot pink and acid lime on aubergine black, dotted ground.
  ThemeSpec(
    seed: 6,
    family: ThemeFamily.neoPop,
    engineVersion: 1,
    variant: ThemeVariant.hero,
    heroId: 6,
    brightness: ThemeBrightness.dark,
    palette: Palette(
      background: 0xFF121014,
      surface: 0xFF1B181F,
      displayText: 0xFFFFFFFF,
      previewText: 0xFFC4BCCB,
      error: 0xFFFF8A80,
      caret: 0xFFFF4D94,
      focusRing: 0xFFFF4D94,
      accent: 0xFFFF4D94,
      digit: KeyColors(face: 0xFF2A2530, label: 0xFFFFFFFF, edge: 0xFF040206),
      operator: KeyColors(
        face: 0xFFFF4D94,
        label: 0xFF000000,
        edge: 0xFFB31E60,
      ),
      equals: KeyColors(face: 0xFFC6FF3D, label: 0xFF000000, edge: 0xFF93C017),
      function: KeyColors(
        face: 0xFF403848,
        label: 0xFFFFFFFF,
        edge: 0xFF140E19,
      ),
      shadow: 0xB3000000,
      highlight: 0x14FFFFFF,
      seedColor: 0xFFFF4D94,
    ),
    keyShape: KeyShapeSpec(kind: KeyShapeKind.roundedRect, cornerPermille: 40),
    keyStyle: _neoPopStyle5,
    type: _spaceGrotesk,
    background: BackgroundSpec(
      kind: BackgroundKind.pattern,
      colors: [0xFF121014],
      pattern: BackgroundPattern.dots,
      patternColor: 0xFFEDE6F2,
      patternScaleCdp: 1600,
      patternOpacityPermille: 60,
    ),
    motion: _neoPopMotion5,
    sound: SoundPackId.pop,
    name: 'Voltage Pink',
  ),
  // 7 — arcade cyan and ember orange on blue-black, on a grid.
  ThemeSpec(
    seed: 7,
    family: ThemeFamily.neoPop,
    engineVersion: 1,
    variant: ThemeVariant.hero,
    heroId: 7,
    brightness: ThemeBrightness.dark,
    palette: Palette(
      background: 0xFF0A1215,
      surface: 0xFF121C20,
      displayText: 0xFFF2FCFF,
      previewText: 0xFFB3C6CC,
      error: 0xFFFF8A65,
      caret: 0xFF00D1FF,
      focusRing: 0xFF00D1FF,
      accent: 0xFF00D1FF,
      digit: KeyColors(face: 0xFF1D292E, label: 0xFFF2FCFF, edge: 0xFF000305),
      operator: KeyColors(
        face: 0xFF00D1FF,
        label: 0xFF001820,
        edge: 0xFF0094B5,
      ),
      equals: KeyColors(face: 0xFFFF7A3D, label: 0xFF1A0600, edge: 0xFFB54B14),
      function: KeyColors(
        face: 0xFF324349,
        label: 0xFFFFFFFF,
        edge: 0xFF09161A,
      ),
      shadow: 0xB3000000,
      highlight: 0x14FFFFFF,
      seedColor: 0xFF00D1FF,
    ),
    keyShape: KeyShapeSpec(kind: KeyShapeKind.roundedRect, cornerPermille: 80),
    keyStyle: _neoPopStyle3,
    type: _spaceGrotesk,
    background: BackgroundSpec(
      kind: BackgroundKind.pattern,
      colors: [0xFF0A1215],
      pattern: BackgroundPattern.grid,
      patternColor: 0xFFD8F6FF,
      patternScaleCdp: 2400,
      patternOpacityPermille: 50,
    ),
    motion: _neoPopMotion3,
    sound: SoundPackId.pop,
    name: 'Cyan Arcade',
  ),
  // 20–22: Liquid Glass (liquid_glass_heroes.dart).
  ...liquidGlassHeroes,
  // 40–42: Neumorphism (neumorphism_heroes.dart).
  ...neumorphismHeroes,
  // 50–52: Retro hardware (retro_heroes.dart).
  ...retroHeroes,
  // 60–62: Neo-brutalism (neo_brutalism_heroes.dart).
  ...neoBrutalismHeroes,
  // 70–72: Claymorphism (claymorphism_heroes.dart).
  ...claymorphismHeroes,
  // 100–102: Y2K / Frutiger Aero (y2k_aero_heroes.dart).
  ...y2kAeroHeroes,
  // 110–112: Paper & ink (paper_ink_heroes.dart).
  ...paperInkHeroes,
  // 130–132: Cyberpunk (cyberpunk_heroes.dart).
  ...cyberpunkHeroes,
  // 140–142: Vaporwave (vaporwave_heroes.dart).
  ...vaporwaveHeroes,
  // 150–152: Bauhaus (bauhaus_heroes.dart).
  ...bauhausHeroes,
];

/// The hero with [id], or null.
ThemeSpec? heroById(int id) {
  for (final h in heroThemes) {
    if (h.heroId == id) return h;
  }
  return null;
}

/// Heroes of [family] in id order.
List<ThemeSpec> heroesFor(ThemeFamily family) => [
  for (final h in heroThemes)
    if (h.family == family) h,
];

/// [hero] repaired for the Accessible lock (labels and display text
/// ≥ 7:1). Returns [hero] unchanged when [accessible] is false.
ThemeSpec heroForAccessible(ThemeSpec hero, {bool accessible = true}) {
  if (!accessible) return hero;
  final locked = hero.copyWith(accessible: true);
  return repairTheme(locked) ??
      (throw StateError('hero ${hero.heroId} cannot reach 7:1'));
}

/// The deterministic last-resort theme for ([seed], [family]) when every
/// generator attempt fails: one of the family's heroes (or any hero).
ThemeSpec heroFallback(
  int seed,
  ThemeFamily family, {
  bool accessible = false,
}) {
  var pool = heroesFor(family);
  if (pool.isEmpty) pool = heroThemes;
  final hero = pool[(seed & 0xFFFFFFFF) % pool.length];
  return heroForAccessible(hero, accessible: accessible);
}
