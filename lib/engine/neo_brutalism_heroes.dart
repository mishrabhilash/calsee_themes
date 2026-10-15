/// Hand-crafted Neo-brutalism heroes (≥ 3 per family), spread into
/// `heroThemes` (heroes.dart).
///
/// Literal ARGB palettes made with the generator's recipe
/// (neo_brutalism.dart): ink outlines and an opaque hard shadow, saturated
/// flat fills with ink labels, and an outlined display card. Ids 60–62 are
/// reserved for this family; never reuse or renumber one.
library;

import 'package:calsee_themes/engine/families.dart' show FontIds;
import 'package:calsee_themes/engine/theme_spec.dart';

const KeyStyleSpec _outlined3x4 = KeyStyleSpec(
  kind: KeyStyleKind.outlined,
  outlineWidthCdp: 300,
  shadowOffsetCdp: 400,
  stateLayerPermille: 0,
);

const KeyStyleSpec _outlined35x5 = KeyStyleSpec(
  kind: KeyStyleKind.outlined,
  outlineWidthCdp: 350,
  shadowOffsetCdp: 500,
  stateLayerPermille: 0,
);

const KeyStyleSpec _outlined25x3 = KeyStyleSpec(
  kind: KeyStyleKind.outlined,
  outlineWidthCdp: 250,
  shadowOffsetCdp: 300,
  stateLayerPermille: 0,
);

/// Motion brief §2.3 "Neo-brutalism": hardPress in, a blunt release near
/// 2500/1.0, stamp entry 1.12 → 1 on hardPress, rigid · 1.0.
const MotionSpec _stamp4 = MotionSpec(
  verb: PressVerb.stamp,
  scheme: MotionScheme.standard,
  pressIn: SpringTokens.hardPress,
  release: SpringToken(2500, 1000),
  depthCdp: 400,
  entry: EntryStyle.stamp,
  entryScalePermille: 1120,
  entrySpring: SpringTokens.hardPress,
  impact: ImpactStyle.rigid,
  impactPermille: 1000,
);

const MotionSpec _stamp5 = MotionSpec(
  verb: PressVerb.stamp,
  scheme: MotionScheme.standard,
  pressIn: SpringTokens.hardPress,
  release: SpringToken(2250, 1000),
  depthCdp: 500,
  entry: EntryStyle.stamp,
  entryScalePermille: 1120,
  entrySpring: SpringTokens.hardPress,
  impact: ImpactStyle.rigid,
  impactPermille: 1000,
);

const MotionSpec _stamp3 = MotionSpec(
  verb: PressVerb.stamp,
  scheme: MotionScheme.standard,
  pressIn: SpringTokens.hardPress,
  release: SpringToken(2750, 1000),
  depthCdp: 300,
  entry: EntryStyle.stamp,
  entryScalePermille: 1120,
  entrySpring: SpringTokens.hardPress,
  impact: ImpactStyle.rigid,
  impactPermille: 1000,
);

/// The Neo-brutalism heroes, ids 60–62.
const List<ThemeSpec> neoBrutalismHeroes = [
  // 60 — a gig poster on cream paper: hot-pink operators, a lemon `=`,
  // sky function keys, a dotted print.
  ThemeSpec(
    seed: 60,
    family: ThemeFamily.neoBrutalism,
    engineVersion: 2,
    variant: ThemeVariant.hero,
    heroId: 60,
    brightness: ThemeBrightness.light,
    palette: Palette(
      background: 0xFFFFF4DE,
      surface: 0xFFFFFFFF,
      displayText: 0xFF121212,
      previewText: 0xFF4A4A4A,
      error: 0xFFB0122A,
      caret: 0xFFC2186B,
      focusRing: 0xFF121212,
      accent: 0xFF121212,
      digit: KeyColors(face: 0xFFFFFFFF, label: 0xFF121212, edge: 0xFF121212),
      operator: KeyColors(
        face: 0xFFFF7EB6,
        label: 0xFF121212,
        edge: 0xFF121212,
      ),
      equals: KeyColors(face: 0xFFFFE04A, label: 0xFF121212, edge: 0xFF121212),
      function: KeyColors(
        face: 0xFF9EDCFF,
        label: 0xFF121212,
        edge: 0xFF121212,
      ),
      shadow: 0xFF121212,
      highlight: 0x00000000,
      seedColor: 0xFFFF7EB6,
    ),
    keyShape: KeyShapeSpec(kind: KeyShapeKind.roundedRect, cornerPermille: 100),
    keyStyle: _outlined3x4,
    type: TypeSpec(
      displayFont: FontIds.robotoFlex,
      keyFont: FontIds.robotoFlex,
      displayWeight: 850,
      keyWeight: 650,
      operatorWeight: 900,
      widthPermille: 1150,
    ),
    background: BackgroundSpec(
      kind: BackgroundKind.pattern,
      colors: [0xFFFFF4DE],
      pattern: BackgroundPattern.dots,
      patternColor: 0xFF121212,
      patternScaleCdp: 2000,
      patternOpacityPermille: 70,
    ),
    motion: _stamp4,
    sound: SoundPackId.mechLinear,
    name: 'Bubblegum Poster',
    nonColourOperatorCue: OperatorCue.weight,
  ),
  // 61 — a mango-yellow poster body on grid paper: coral operators, an
  // ink `=` with a mango label, mint function keys, a white card.
  ThemeSpec(
    seed: 61,
    family: ThemeFamily.neoBrutalism,
    engineVersion: 2,
    variant: ThemeVariant.hero,
    heroId: 61,
    brightness: ThemeBrightness.light,
    palette: Palette(
      background: 0xFFFFCB45,
      surface: 0xFFFFFFFF,
      displayText: 0xFF141414,
      previewText: 0xFF3D3A33,
      error: 0xFF8E0F1F,
      caret: 0xFF7A2E00,
      focusRing: 0xFF141414,
      accent: 0xFF141414,
      digit: KeyColors(face: 0xFFFFFFFF, label: 0xFF141414, edge: 0xFF141414),
      operator: KeyColors(
        face: 0xFFFF8A65,
        label: 0xFF141414,
        edge: 0xFF141414,
      ),
      equals: KeyColors(face: 0xFF141414, label: 0xFFFFCB45, edge: 0xFF141414),
      function: KeyColors(
        face: 0xFF8EF0C4,
        label: 0xFF141414,
        edge: 0xFF141414,
      ),
      shadow: 0xFF141414,
      highlight: 0x00000000,
      seedColor: 0xFFFF8A65,
    ),
    keyShape: KeyShapeSpec(kind: KeyShapeKind.roundedRect, cornerPermille: 40),
    keyStyle: _outlined35x5,
    type: TypeSpec(
      displayFont: FontIds.robotoFlex,
      keyFont: FontIds.spaceGrotesk,
      displayWeight: 900,
      operatorWeight: 700,
      widthPermille: 1250,
    ),
    background: BackgroundSpec(
      kind: BackgroundKind.pattern,
      colors: [0xFFFFCB45],
      pattern: BackgroundPattern.grid,
      patternColor: 0xFF141414,
      patternScaleCdp: 2400,
      patternOpacityPermille: 80,
    ),
    motion: _stamp5,
    sound: SoundPackId.mechLinear,
    name: 'Mango Sticker',
    nonColourOperatorCue: OperatorCue.weight,
  ),
  // 62 — the night edition: a black body drawn in cream ink, charcoal
  // digits, acid-lime operators, an orange `=`, lavender function keys.
  ThemeSpec(
    seed: 62,
    family: ThemeFamily.neoBrutalism,
    engineVersion: 2,
    variant: ThemeVariant.hero,
    heroId: 62,
    brightness: ThemeBrightness.dark,
    palette: Palette(
      background: 0xFF161616,
      surface: 0xFF262626,
      displayText: 0xFFFFF4DC,
      previewText: 0xFFC9C2B4,
      error: 0xFFFF8F80,
      caret: 0xFFC6FF3D,
      focusRing: 0xFFFFF4DC,
      accent: 0xFFFFF4DC,
      digit: KeyColors(face: 0xFF333333, label: 0xFFFFF4DC, edge: 0xFFFFF4DC),
      operator: KeyColors(
        face: 0xFFC6FF3D,
        label: 0xFF141414,
        edge: 0xFFFFF4DC,
      ),
      equals: KeyColors(face: 0xFFFF9248, label: 0xFF141414, edge: 0xFFFFF4DC),
      function: KeyColors(
        face: 0xFFC3B1FF,
        label: 0xFF141414,
        edge: 0xFFFFF4DC,
      ),
      shadow: 0xFFFFF4DC,
      highlight: 0x00000000,
      seedColor: 0xFFC6FF3D,
    ),
    keyShape: KeyShapeSpec(kind: KeyShapeKind.roundedRect, cornerPermille: 160),
    keyStyle: _outlined25x3,
    type: TypeSpec(
      displayFont: FontIds.robotoFlex,
      keyFont: FontIds.robotoFlex,
      displayWeight: 800,
      keyWeight: 600,
      operatorWeight: 850,
      widthPermille: 1100,
    ),
    background: BackgroundSpec(
      kind: BackgroundKind.solid,
      colors: [0xFF161616],
    ),
    motion: _stamp3,
    sound: SoundPackId.mechLinear,
    name: 'Midnight Rivet',
    nonColourOperatorCue: OperatorCue.weight,
  ),
];
