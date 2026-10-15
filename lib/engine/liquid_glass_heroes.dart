/// Hand-crafted Liquid Glass heroes (design doc: ≥ 3 per family), spread
/// into `heroThemes` (heroes.dart).
///
/// Literal ARGB palettes made with the generator's recipe
/// (liquid_glass.dart): a vivid mesh, translucent glass tints whose labels
/// were solved on the tint composited over every hull sample of the mesh,
/// and a dense display backing. Ids 20–22 are reserved for this family
/// (its family id is 2); never reuse or renumber one.
library;

import 'package:calsee_themes/engine/families.dart' show FontIds;
import 'package:calsee_themes/engine/theme_spec.dart';

/// Motion brief §2.3 "Liquid Glass": the glass press spring (never
/// varied), a hand-tuned jelly release (X / Y axes), rise entry, glow.
const MotionSpec _jelly = MotionSpec(
  verb: PressVerb.inflate,
  scheme: MotionScheme.standard,
  pressIn: SpringTokens.glassPressIn,
  release: SpringToken(439, 650),
  releaseAlt: SpringToken(439, 800),
  scalePermille: 1080,
  entry: EntryStyle.rise,
  entryOffsetCdp: 600,
  entrySpring: SpringTokens.effectsDefault,
  fx: PressFx.glow,
  impact: ImpactStyle.soft,
  impactPermille: 700,
);

const MotionSpec _jellySoft = MotionSpec(
  verb: PressVerb.inflate,
  scheme: MotionScheme.standard,
  pressIn: SpringTokens.glassPressIn,
  release: SpringToken(400, 680),
  releaseAlt: SpringToken(439, 800),
  scalePermille: 1080,
  entry: EntryStyle.rise,
  entryOffsetCdp: 600,
  entrySpring: SpringTokens.effectsDefault,
  fx: PressFx.glow,
  impact: ImpactStyle.soft,
  impactPermille: 650,
);

/// The Liquid Glass heroes, ids 20–22.
const List<ThemeSpec> liquidGlassHeroes = [
  // 20 — midnight: smoky glass over a navy, electric blue, violet and
  // deep teal mesh; lavender operators, an aqua `=`.
  ThemeSpec(
    seed: 20,
    family: ThemeFamily.liquidGlass,
    engineVersion: 2,
    variant: ThemeVariant.hero,
    heroId: 20,
    brightness: ThemeBrightness.dark,
    palette: Palette(
      background: 0xFF000C22,
      surface: 0xA2111822,
      displayText: 0xFFF4F9FF,
      previewText: 0xFFB1BFD1,
      error: 0xFFFF7E77,
      caret: 0xFFC8C3FC,
      focusRing: 0xFFC8C3FC,
      accent: 0xFFC8C3FC,
      digit: KeyColors(face: 0x5C000103, label: 0xFFF4F9FF, edge: 0x89FAFCFF),
      operator: KeyColors(
        face: 0xCCA393FF,
        label: 0xFF111117,
        edge: 0x89FBFBFF,
      ),
      equals: KeyColors(face: 0xDC4ACDE3, label: 0xFF0B1315, edge: 0x89F6FDFF),
      function: KeyColors(
        face: 0x6B2B333C,
        label: 0xFFF4F9FF,
        edge: 0x89FAFCFF,
      ),
      shadow: 0x60000205,
      highlight: 0x33FFFFFF,
      seedColor: 0xFFA393FF,
    ),
    keyShape: KeyShapeSpec(kind: KeyShapeKind.circle, cornerPermille: 500),
    keyStyle: KeyStyleSpec(
      kind: KeyStyleKind.glass,
      outlineWidthCdp: 125,
      shadowOffsetCdp: 250,
      shadowBlurCdp: 800,
      opacityPermille: 360,
      stateLayerPermille: 80,
      frostPermille: 100,
      highlightPermille: 700,
      refractionPermille: 650,
    ),
    type: TypeSpec(
      displayFont: FontIds.robotoFlex,
      keyFont: FontIds.robotoFlex,
      displayWeight: 300,
      keyWeight: 450,
      operatorWeight: 700,
    ),
    background: BackgroundSpec(
      kind: BackgroundKind.meshGradient,
      colors: [0xFF000C22, 0xFF094689, 0xFF4D07B1, 0xFF084F5A],
      angleTenths: 748,
      driftPeriodMs: 45000,
    ),
    motion: _jelly,
    sound: SoundPackId.glass,
    name: 'Midnight Lens',
    nonColourOperatorCue: OperatorCue.weight,
  ),
  // 21 — ember lagoon: smoky glass over oxblood, ember red, burnt orange
  // and lagoon teal; aqua operators, an apricot `=`.
  ThemeSpec(
    seed: 21,
    family: ThemeFamily.liquidGlass,
    engineVersion: 2,
    variant: ThemeVariant.hero,
    heroId: 21,
    brightness: ThemeBrightness.dark,
    palette: Palette(
      background: 0xFF2C0604,
      surface: 0x8E241310,
      displayText: 0xFFFFF6F5,
      previewText: 0xFFD0B7B3,
      error: 0xFFFF7E77,
      caret: 0xFF63DEF5,
      focusRing: 0xFF63DEF5,
      accent: 0xFF63DEF5,
      digit: KeyColors(face: 0x47040000, label: 0xFFFDF7F6, edge: 0x80FFFBFA),
      operator: KeyColors(
        face: 0xC240BED4,
        label: 0xFF0E1213,
        edge: 0x80F6FDFF,
      ),
      equals: KeyColors(face: 0xEDFBB592, label: 0xFF14110F, edge: 0x80FFFBF9),
      function: KeyColors(
        face: 0x7A342725,
        label: 0xFFFDF7F6,
        edge: 0x80FFFBFA,
      ),
      shadow: 0x60050101,
      highlight: 0x3CFFFFFF,
      seedColor: 0xFF40BED4,
    ),
    keyShape: KeyShapeSpec(kind: KeyShapeKind.roundedRect, cornerPermille: 380),
    keyStyle: KeyStyleSpec(
      kind: KeyStyleKind.glass,
      outlineWidthCdp: 100,
      shadowOffsetCdp: 200,
      shadowBlurCdp: 800,
      opacityPermille: 278,
      stateLayerPermille: 80,
      frostPermille: 50,
      highlightPermille: 650,
      refractionPermille: 600,
    ),
    type: TypeSpec(
      displayFont: FontIds.robotoFlex,
      keyFont: FontIds.spaceGrotesk,
      displayWeight: 250,
      keyWeight: 450,
      operatorWeight: 650,
    ),
    background: BackgroundSpec(
      kind: BackgroundKind.meshGradient,
      colors: [0xFF2C0604, 0xFF841D13, 0xFF256874, 0xFF93491E],
      angleTenths: 3367,
      driftPeriodMs: 55000,
    ),
    motion: _jellySoft,
    sound: SoundPackId.glass,
    name: 'Ember Lagoon',
    nonColourOperatorCue: OperatorCue.weight,
  ),
  // 22 — morning prism: milky glass over peach, coral, mint and
  // periwinkle; jade operators, an indigo `=`.
  ThemeSpec(
    seed: 22,
    family: ThemeFamily.liquidGlass,
    engineVersion: 2,
    variant: ThemeVariant.hero,
    heroId: 22,
    brightness: ThemeBrightness.light,
    palette: Palette(
      background: 0xFFFFEDE7,
      surface: 0xA9FFFBFA,
      displayText: 0xFF120C0A,
      previewText: 0xFF5C4841,
      error: 0xFFAC3031,
      caret: 0xFF306448,
      focusRing: 0xFF306448,
      accent: 0xFF306448,
      digit: KeyColors(face: 0x8DFDFCFC, label: 0xFF17100D, edge: 0xEAFFFBF9),
      operator: KeyColors(
        face: 0xFA007849,
        label: 0xFFF2FBF5,
        edge: 0xEAF7FEF9,
      ),
      equals: KeyColors(face: 0xF23C30B6, label: 0xFFF7F8FF, edge: 0xEAFBFBFF),
      function: KeyColors(
        face: 0xA1F2D7CF,
        label: 0xFF17100D,
        edge: 0xEAFFFBF9,
      ),
      shadow: 0x2E472217,
      highlight: 0x28FFFFFF,
      seedColor: 0xFF007849,
    ),
    keyShape: KeyShapeSpec(kind: KeyShapeKind.circle, cornerPermille: 500),
    keyStyle: KeyStyleSpec(
      kind: KeyStyleKind.glass,
      outlineWidthCdp: 125,
      shadowOffsetCdp: 300,
      shadowBlurCdp: 800,
      opacityPermille: 552,
      stateLayerPermille: 80,
      frostPermille: 100,
      highlightPermille: 550,
      refractionPermille: 450,
    ),
    type: TypeSpec(
      displayFont: FontIds.robotoFlex,
      keyFont: FontIds.robotoFlex,
      displayWeight: 300,
      operatorWeight: 750,
    ),
    background: BackgroundSpec(
      kind: BackgroundKind.meshGradient,
      colors: [0xFFFFEDE7, 0xFFEDA893, 0xFF72E7A8, 0xFFAAB3E9],
      angleTenths: 2520,
      driftPeriodMs: 45000,
    ),
    motion: _jellySoft,
    sound: SoundPackId.glass,
    name: 'Morning Prism',
    nonColourOperatorCue: OperatorCue.weight,
  ),
];
