/// Hand-crafted Bauhaus heroes (≥ 3 per family), spread into `heroThemes`
/// (heroes.dart).
///
/// Literal ARGB palettes made with the generator's recipe (bauhaus.dart,
/// `assembleBauhausPalette` on hand-picked draws): flat primaries with
/// cream or ink labels, neutral digit blocks, an opaque display sheet with
/// a thick rule and a quarter-disc in the `=` primary, and the scene's six
/// colours. Ids 150–152 are reserved for this family; never reuse or
/// renumber one.
library;

import 'package:calsee_themes/engine/families.dart' show FontIds;
import 'package:calsee_themes/engine/theme_spec.dart';

const KeyStyleSpec _flat = KeyStyleSpec(
  kind: KeyStyleKind.flat,
  stateLayerPermille: 0,
);

/// The family's motion (bauhaus.dart): hardPress in, the release seeded
/// × {0.9, 1, 1.1} of effectsDefault (1600 / 1.0), scale 0.96, a pop entry
/// 0.90 → 1 on effectsDefault, rigid impact.
const MotionSpec _invert1600 = MotionSpec(
  verb: PressVerb.invert,
  scheme: MotionScheme.standard,
  pressIn: SpringTokens.hardPress,
  release: SpringTokens.effectsDefault,
  scalePermille: 960,
  entry: EntryStyle.pop,
  entryScalePermille: 900,
  entrySpring: SpringTokens.effectsDefault,
  impact: ImpactStyle.rigid,
);

const MotionSpec _invert1760 = MotionSpec(
  verb: PressVerb.invert,
  scheme: MotionScheme.standard,
  pressIn: SpringTokens.hardPress,
  release: SpringToken(1760, 1000),
  scalePermille: 960,
  entry: EntryStyle.pop,
  entryScalePermille: 900,
  entrySpring: SpringTokens.effectsDefault,
  impact: ImpactStyle.rigid,
);

const MotionSpec _invert1440 = MotionSpec(
  verb: PressVerb.invert,
  scheme: MotionScheme.standard,
  pressIn: SpringTokens.hardPress,
  release: SpringToken(1440, 1000),
  scalePermille: 960,
  entry: EntryStyle.pop,
  entryScalePermille: 900,
  entrySpring: SpringTokens.effectsDefault,
  impact: ImpactStyle.rigid,
);

/// The Bauhaus heroes, ids 150–152.
const List<ThemeSpec> bauhausHeroes = [
  // 150 — a school primer on parchment: cream number blocks, ultramarine
  // operator discs, a big red `=` disc, ink function blocks with yellow
  // corners, a white sheet with a black rule.
  ThemeSpec(
    seed: 150,
    family: ThemeFamily.bauhaus,
    engineVersion: 3,
    variant: ThemeVariant.hero,
    heroId: 150,
    brightness: ThemeBrightness.light,
    palette: Palette(
      background: 0xFFE5DDCE,
      surface: 0xFFFEFDFA,
      displayText: 0xFF131311,
      previewText: 0xFF4E4D4B,
      error: 0xFFB7191C,
      caret: 0xFFC21A13,
      focusRing: 0xFF131311,
      accent: 0xFFC72219,
      digit: KeyColors(face: 0xFFFBFAF7, label: 0xFF131311, edge: 0xFFFBFAF7),
      operator: KeyColors(
        face: 0xFF264BA4,
        label: 0xFFF8F3E8,
        edge: 0xFF264BA4,
      ),
      equals: KeyColors(face: 0xFFC72219, label: 0xFFF8F3E8, edge: 0xFFC72219),
      function: KeyColors(
        face: 0xFF161513,
        label: 0xFFF8F3E8,
        edge: 0xFFFBCB21,
      ),
      shadow: 0xFF131311,
      highlight: 0xFFC72219,
      seedColor: 0xFF264BA4,
    ),
    keyShape: KeyShapeSpec(
      kind: KeyShapeKind.roundedRect,
      cornerPermille: 0,
      operatorKind: KeyShapeKind.circle,
      operatorM3eShape: M3eShape.circle,
    ),
    keyStyle: _flat,
    type: TypeSpec(
      displayFont: FontIds.jost,
      keyFont: FontIds.jost,
      displayWeight: 500,
      operatorWeight: 650,
    ),
    background: BackgroundSpec(
      kind: BackgroundKind.bauhausComposition,
      colors: [
        0xFFE5DDCE,
        0xFFE5DDCE,
        0xFF264BA4,
        0xFFC72219,
        0xFFFBCB21,
        0xFF131311,
      ],
    ),
    motion: _invert1600,
    sound: SoundPackId.wood,
    name: 'Weimar Primer',
    nonColourOperatorCue: OperatorCue.shape,
  ),
  // 151 — cream number blocks set into a black grid, ultramarine discs, a
  // red quarter-disc `=` rising from its corner, yellow function blocks
  // with red corners (the `=` primary).
  ThemeSpec(
    seed: 151,
    family: ThemeFamily.bauhaus,
    engineVersion: 3,
    variant: ThemeVariant.hero,
    heroId: 151,
    brightness: ThemeBrightness.light,
    palette: Palette(
      background: 0xFFE5DFD1,
      surface: 0xFFFDFCFA,
      displayText: 0xFF121110,
      previewText: 0xFF4E4D4B,
      error: 0xFFB7191C,
      caret: 0xFFC11C04,
      focusRing: 0xFF4D77CC,
      accent: 0xFFC71B02,
      digit: KeyColors(face: 0xFFF8F5EE, label: 0xFF121110, edge: 0xFFF8F5EE),
      operator: KeyColors(
        face: 0xFF254EA8,
        label: 0xFFF7F2E7,
        edge: 0xFF254EA8,
      ),
      equals: KeyColors(face: 0xFFC71B02, label: 0xFFF7F2E7, edge: 0xFFC71B02),
      function: KeyColors(
        face: 0xFFFBCE1E,
        label: 0xFF121110,
        edge: 0xFFC71B02,
      ),
      shadow: 0xFF0F0E0D,
      highlight: 0xFFC71B02,
      seedColor: 0xFF254EA8,
    ),
    keyShape: KeyShapeSpec(
      kind: KeyShapeKind.roundedRect,
      cornerPermille: 20,
      operatorKind: KeyShapeKind.circle,
      operatorM3eShape: M3eShape.fan,
    ),
    keyStyle: _flat,
    type: TypeSpec(
      displayFont: FontIds.jost,
      keyFont: FontIds.jost,
      displayWeight: 550,
      operatorWeight: 700,
    ),
    background: BackgroundSpec(
      kind: BackgroundKind.bauhausComposition,
      colors: [
        0xFFE5DFD1,
        0xFF0F0E0D,
        0xFF254EA8,
        0xFFC71B02,
        0xFFFBCE1E,
        0xFF0F0E0D,
      ],
      angleTenths: 900,
    ),
    motion: _invert1760,
    sound: SoundPackId.wood,
    name: 'Dessau Grid',
    nonColourOperatorCue: OperatorCue.shape,
  ),
  // 152 — the workshop after hours: graphite number blocks on warm black,
  // red operator discs, a yellow quarter-disc `=` rising from its corner,
  // cream function blocks with red corners, a graphite sheet with a cream
  // rule and a yellow corner disc.
  ThemeSpec(
    seed: 152,
    family: ThemeFamily.bauhaus,
    engineVersion: 3,
    variant: ThemeVariant.hero,
    heroId: 152,
    brightness: ThemeBrightness.dark,
    palette: Palette(
      background: 0xFF0F0E0C,
      surface: 0xFF292725,
      displayText: 0xFFF8F1E5,
      previewText: 0xFFBBB7B0,
      error: 0xFFFB8276,
      caret: 0xFFFCCA21,
      focusRing: 0xFFFCCA21,
      accent: 0xFFFCCA21,
      digit: KeyColors(face: 0xFF2A2926, label: 0xFFF8F1E5, edge: 0xFF2A2926),
      operator: KeyColors(
        face: 0xFFC92420,
        label: 0xFFF8F1E5,
        edge: 0xFFC92420,
      ),
      equals: KeyColors(face: 0xFFFCCA21, label: 0xFF121110, edge: 0xFFFCCA21),
      function: KeyColors(
        face: 0xFFF0E8DC,
        label: 0xFF121110,
        edge: 0xFFC92420,
      ),
      shadow: 0xFFF8F1E5,
      highlight: 0xFFFCCA21,
      seedColor: 0xFFC92420,
    ),
    keyShape: KeyShapeSpec(
      kind: KeyShapeKind.roundedRect,
      cornerPermille: 30,
      operatorKind: KeyShapeKind.circle,
      operatorM3eShape: M3eShape.fan,
    ),
    keyStyle: _flat,
    type: TypeSpec(
      displayFont: FontIds.jost,
      keyFont: FontIds.jost,
      displayWeight: 500,
      keyWeight: 450,
      operatorWeight: 600,
    ),
    background: BackgroundSpec(
      kind: BackgroundKind.bauhausComposition,
      colors: [
        0xFF0F0E0C,
        0xFF0F0E0C,
        0xFF3768DC,
        0xFFC92420,
        0xFFFCCA21,
        0xFFF8F1E5,
      ],
      angleTenths: 2700,
    ),
    motion: _invert1440,
    sound: SoundPackId.wood,
    name: 'Night Workshop',
    nonColourOperatorCue: OperatorCue.shape,
  ),
];
