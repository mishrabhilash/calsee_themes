/// Hand-crafted Neumorphism (Soft UI) heroes (docs/m4-design.md §C: ≥ 3
/// per family), spread into `heroThemes` (heroes.dart).
///
/// Literal ARGB palettes made with the same recipe as the generator
/// (research theme-engine.md §7.2): surface-coloured keys, a light and a
/// dark shadow derived in OKLCH from the surface, a rim solved to ≥ 3:1
/// against it, labels ≥ 4.5:1 and an accent that reads on the surface
/// (the pressed label). Ids 40–42 are reserved for this family; never
/// reuse or renumber one.
library;

import 'package:calsee_themes/engine/families.dart' show FontIds;
import 'package:calsee_themes/engine/theme_spec.dart';

const KeyStyleSpec _softStyle125 = KeyStyleSpec(
  kind: KeyStyleKind.soft,
  outlineWidthCdp: 125,
  shadowOffsetCdp: 300,
  shadowBlurCdp: 600,
  stateLayerPermille: 60,
);

const KeyStyleSpec _softStyle150 = KeyStyleSpec(
  kind: KeyStyleKind.soft,
  outlineWidthCdp: 150,
  shadowOffsetCdp: 300,
  shadowBlurCdp: 600,
  stateLayerPermille: 60,
);

/// Motion brief §2.3 row 4: outer pair off in frame 1, inner pair and
/// scale 0.98 on `effectsFast`, release on `effectsDefault` (never
/// bounces), rise 4 dp entry, soft · 0.5 haptic.
const MotionSpec _softMotion = MotionSpec(
  verb: PressVerb.sink,
  scheme: MotionScheme.standard,
  pressIn: SpringTokens.effectsFast,
  release: SpringTokens.effectsDefault,
  depthCdp: 600,
  scalePermille: 980,
  entry: EntryStyle.rise,
  entryOffsetCdp: 400,
  entrySpring: SpringTokens.effectsDefault,
  impact: ImpactStyle.soft,
  impactPermille: 500,
);

/// A slightly softer release for the dark hero.
const MotionSpec _softMotionSlow = MotionSpec(
  verb: PressVerb.sink,
  scheme: MotionScheme.standard,
  pressIn: SpringTokens.effectsFast,
  release: SpringToken(1440, 1000),
  depthCdp: 600,
  scalePermille: 980,
  entry: EntryStyle.rise,
  entryOffsetCdp: 400,
  entrySpring: SpringTokens.effectsDefault,
  impact: ImpactStyle.soft,
  impactPermille: 500,
);

const TypeSpec _softType = TypeSpec(
  displayFont: FontIds.robotoFlex,
  keyFont: FontIds.robotoFlex,
  displayWeight: 350,
  keyWeight: 450,
  operatorWeight: 700,
);

/// Neumorphism heroes, in id order.
const List<ThemeSpec> neumorphismHeroes = [
  // 40 — warm paper white: terracotta accent labels and `=`.
  ThemeSpec(
    seed: 40,
    family: ThemeFamily.neumorphism,
    engineVersion: 2,
    variant: ThemeVariant.hero,
    heroId: 40,
    brightness: ThemeBrightness.light,
    palette: Palette(
      background: 0xFFEEE9E1,
      surface: 0xFFEAE5DD,
      displayText: 0xFF191510,
      previewText: 0xFF4E463C,
      error: 0xFFA12F2F,
      caret: 0xFF9E4421,
      focusRing: 0xFF9E4421,
      accent: 0xFF9E4421,
      digit: KeyColors(face: 0xFFEEE9E1, label: 0xFF1F1A13, edge: 0xFF8E8578),
      operator: KeyColors(
        face: 0xFFEEE9E1,
        label: 0xFF9E4421,
        edge: 0xFF8E8578,
      ),
      equals: KeyColors(face: 0xFFB6522D, label: 0xFFFFF6F3, edge: 0xFF8E8578),
      function: KeyColors(
        face: 0xFFEEE9E1,
        label: 0xFF543429,
        edge: 0xFF8E8578,
      ),
      shadow: 0xFFC5BAAD,
      highlight: 0xFFFFFDFB,
      seedColor: 0xFFB6522D,
    ),
    keyShape: KeyShapeSpec(kind: KeyShapeKind.roundedRect),
    keyStyle: _softStyle125,
    type: _softType,
    background: BackgroundSpec(
      kind: BackgroundKind.solid,
      colors: [0xFFEEE9E1],
    ),
    motion: _softMotion,
    sound: SoundPackId.tick,
    name: 'Porcelain Morning',
    nonColourOperatorCue: OperatorCue.weight,
  ),
  // 41 — cool slate dark: ice-blue `=`, deep-sea operator faces.
  ThemeSpec(
    seed: 41,
    family: ThemeFamily.neumorphism,
    engineVersion: 2,
    variant: ThemeVariant.hero,
    heroId: 41,
    brightness: ThemeBrightness.dark,
    palette: Palette(
      background: 0xFF1D2229,
      surface: 0xFF161B22,
      displayText: 0xFFEDF2FA,
      previewText: 0xFFB5BFCB,
      error: 0xFFFB817A,
      caret: 0xFF89CEF6,
      focusRing: 0xFF89CEF6,
      accent: 0xFF89CEF6,
      digit: KeyColors(face: 0xFF1D2229, label: 0xFFE8EFF9, edge: 0xFF626C79),
      operator: KeyColors(
        face: 0xFF0F455F,
        label: 0xFFECF7FE,
        edge: 0xFF626C79,
      ),
      equals: KeyColors(face: 0xFF7AC8F5, label: 0xFF0B1317, edge: 0xFF626C79),
      function: KeyColors(
        face: 0xFF1D2229,
        label: 0xFFB2D7EE,
        edge: 0xFF626C79,
      ),
      shadow: 0xFF050B16,
      highlight: 0xFF2A2D31,
      seedColor: 0xFF7AC8F5,
    ),
    keyShape: KeyShapeSpec(kind: KeyShapeKind.circle, cornerPermille: 500),
    keyStyle: _softStyle150,
    type: _softType,
    background: BackgroundSpec(
      kind: BackgroundKind.solid,
      colors: [0xFF1D2229],
    ),
    motion: _softMotionSlow,
    sound: SoundPackId.tick,
    name: 'Slate Nocturne',
    nonColourOperatorCue: OperatorCue.weight,
  ),
  // 42 — mint: sea-glass operator faces and a deep teal `=`.
  ThemeSpec(
    seed: 42,
    family: ThemeFamily.neumorphism,
    engineVersion: 2,
    variant: ThemeVariant.hero,
    heroId: 42,
    brightness: ThemeBrightness.light,
    palette: Palette(
      background: 0xFFD7EAE2,
      surface: 0xFFD3E6DE,
      displayText: 0xFF111815,
      previewText: 0xFF3E4B46,
      error: 0xFFA12F2F,
      caret: 0xFF026E5B,
      focusRing: 0xFF026E5B,
      accent: 0xFF026E5B,
      digit: KeyColors(face: 0xFFD7EAE2, label: 0xFF141D19, edge: 0xFF70897F),
      operator: KeyColors(
        face: 0xFF8DCDBB,
        label: 0xFF0F1816,
        edge: 0xFF70897F,
      ),
      equals: KeyColors(face: 0xFF007B66, label: 0xFFEFFCF8, edge: 0xFF70897F),
      function: KeyColors(
        face: 0xFFD7EAE2,
        label: 0xFF1C463C,
        edge: 0xFF70897F,
      ),
      shadow: 0xFFA5BEB3,
      highlight: 0xFFF2FBF7,
      seedColor: 0xFF007B66,
    ),
    keyShape: KeyShapeSpec(kind: KeyShapeKind.roundedRect, cornerPermille: 360),
    keyStyle: _softStyle125,
    type: _softType,
    background: BackgroundSpec(
      kind: BackgroundKind.solid,
      colors: [0xFFD7EAE2],
    ),
    motion: _softMotion,
    sound: SoundPackId.tick,
    name: 'Mint Pillow',
    nonColourOperatorCue: OperatorCue.weight,
  ),
];
