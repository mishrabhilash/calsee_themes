/// Hand-crafted Retro hardware heroes (docs/m4-design.md §B: ≥ 3 per
/// family), spread into `heroThemes` (heroes.dart).
///
/// Literal ARGB palettes made with the generator's recipe (retro.dart): a
/// plastic body, muted keycaps with one coloured accent, and a 7-segment
/// panel whose lit segments reach 7:1 and whose ghost segments stay near
/// 1.15:1 against it. Ids 50–52 are reserved for this family; never reuse
/// or renumber one.
library;

import 'package:calsee_themes/engine/families.dart' show FontIds;
import 'package:calsee_themes/engine/theme_spec.dart';

const KeyStyleSpec _keycaps3 = KeyStyleSpec(
  kind: KeyStyleKind.extruded,
  extrudeDepthCdp: 300,
  edgeShadePermille: 110,
  shadowOffsetCdp: 100,
  shadowBlurCdp: 200,
  stateLayerPermille: 0,
);

const KeyStyleSpec _keycaps2 = KeyStyleSpec(
  kind: KeyStyleKind.extruded,
  extrudeDepthCdp: 200,
  edgeShadePermille: 110,
  shadowOffsetCdp: 100,
  shadowBlurCdp: 200,
  stateLayerPermille: 0,
);

/// Motion brief §2.3 "Retro hardware": hardPress in, a hand-tuned release
/// near 1200/0.7, segment entry, rigid haptic plus a release tick.
const MotionSpec _travelDesk = MotionSpec(
  verb: PressVerb.travel,
  scheme: MotionScheme.standard,
  pressIn: SpringTokens.hardPress,
  release: SpringToken(1200, 700),
  depthCdp: 300,
  entry: EntryStyle.segments,
  impact: ImpactStyle.rigid,
  releaseHaptic: true,
  releaseImpactPermille: 350,
);

const MotionSpec _travelPocket = MotionSpec(
  verb: PressVerb.travel,
  scheme: MotionScheme.standard,
  pressIn: SpringTokens.hardPress,
  release: SpringToken(1320, 700),
  depthCdp: 200,
  entry: EntryStyle.segments,
  impact: ImpactStyle.rigid,
  releaseHaptic: true,
  releaseImpactPermille: 300,
);

const MotionSpec _travelVfd = MotionSpec(
  verb: PressVerb.travel,
  scheme: MotionScheme.standard,
  pressIn: SpringTokens.hardPress,
  release: SpringToken(1080, 720),
  depthCdp: 300,
  entry: EntryStyle.segments,
  impact: ImpactStyle.rigid,
  releaseHaptic: true,
  releaseImpactPermille: 350,
);

/// The Retro heroes, ids 50–52.
const List<ThemeSpec> retroHeroes = [
  // 50 — an office desk calculator: oatmeal plastic, cream keys, graphite
  // operators, an orange `=`, a grey-green LCD.
  ThemeSpec(
    seed: 50,
    family: ThemeFamily.retro,
    engineVersion: 2,
    variant: ThemeVariant.hero,
    heroId: 50,
    brightness: ThemeBrightness.light,
    palette: Palette(
      background: 0xFFD8CCB2,
      surface: 0xFFB8BE9A,
      displayText: 0xFF22261A,
      previewText: 0xFF494D3B,
      error: 0xFF7A1F12,
      caret: 0xFF6B3A10,
      focusRing: 0xFF904100,
      accent: 0xFF904100,
      digit: KeyColors(face: 0xFFF1EADB, label: 0xFF1A150B, edge: 0xFFCCC6B9),
      operator: KeyColors(
        face: 0xFF4A4540,
        label: 0xFFFFF3E7,
        edge: 0xFF2D2925,
      ),
      equals: KeyColors(face: 0xFFD8732B, label: 0xFF160D07, edge: 0xFFAD5611),
      function: KeyColors(
        face: 0xFF6E665A,
        label: 0xFFFDF4E7,
        edge: 0xFF4E483E,
      ),
      shadow: 0x47000000,
      highlight: 0x8CFFFFFF,
      seedColor: 0xFFD8732B,
      lcdGhost: 0xFFACB28F,
    ),
    keyShape: KeyShapeSpec(kind: KeyShapeKind.keycap, cornerPermille: 160),
    keyStyle: _keycaps3,
    type: TypeSpec(
      displayFont: FontIds.robotoFlex,
      keyFont: FontIds.robotoFlex,
      displayWeight: 450,
      operatorWeight: 750,
      widthPermille: 800,
      lcd: true,
    ),
    background: BackgroundSpec(
      kind: BackgroundKind.linearGradient,
      colors: [0xFFD8CCB2, 0xFFCABEA4],
    ),
    motion: _travelDesk,
    sound: SoundPackId.mechClicky,
    name: 'Oatmeal Desk',
    nonColourOperatorCue: OperatorCue.weight,
  ),
  // 51 — a black pocket calculator: graphite keys, slate-blue operators,
  // a red `=`, a pale LCD.
  ThemeSpec(
    seed: 51,
    family: ThemeFamily.retro,
    engineVersion: 2,
    variant: ThemeVariant.hero,
    heroId: 51,
    brightness: ThemeBrightness.dark,
    palette: Palette(
      background: 0xFF1B1B1E,
      surface: 0xFFAEB4A0,
      displayText: 0xFF1A1E1E,
      previewText: 0xFF404645,
      error: 0xFF7A1A12,
      caret: 0xFF1F3550,
      focusRing: 0xFFFFA098,
      accent: 0xFFFFA098,
      digit: KeyColors(face: 0xFF36363B, label: 0xFFF4F4FF, edge: 0xFF1B1B1F),
      operator: KeyColors(
        face: 0xFF81A1CA,
        label: 0xFF091018,
        edge: 0xFF647FA3,
      ),
      equals: KeyColors(face: 0xFFE15A50, label: 0xFF170C0B, edge: 0xFFB43F37),
      function: KeyColors(
        face: 0xFF4E4F57,
        label: 0xFFF3F4FF,
        edge: 0xFF313239,
      ),
      shadow: 0x8C000000,
      highlight: 0x2EFFFFFF,
      seedColor: 0xFFE15A50,
      lcdGhost: 0xFFA4AA97,
    ),
    keyShape: KeyShapeSpec(kind: KeyShapeKind.keycap, cornerPermille: 220),
    keyStyle: _keycaps2,
    type: TypeSpec(
      displayFont: FontIds.robotoFlex,
      keyFont: FontIds.spaceGrotesk,
      operatorWeight: 700,
      widthPermille: 750,
      lcd: true,
    ),
    background: BackgroundSpec(
      kind: BackgroundKind.solid,
      colors: [0xFF1B1B1E],
    ),
    motion: _travelPocket,
    sound: SoundPackId.beep,
    name: 'Midnight Pocket',
    nonColourOperatorCue: OperatorCue.weight,
  ),
  // 52 — a vacuum-fluorescent desk model: charcoal body, cyan segments
  // glowing behind dark glass, a green `=`.
  ThemeSpec(
    seed: 52,
    family: ThemeFamily.retro,
    engineVersion: 2,
    variant: ThemeVariant.hero,
    heroId: 52,
    brightness: ThemeBrightness.dark,
    palette: Palette(
      background: 0xFF232427,
      surface: 0xFF031011,
      displayText: 0xFF3BF4F4,
      previewText: 0xFF63B5B4,
      error: 0xFFF9875E,
      caret: 0xFF4DDCDC,
      focusRing: 0xFF75D78D,
      accent: 0xFF75D78D,
      digit: KeyColors(face: 0xFF3A3B3F, label: 0xFFF2F5FF, edge: 0xFF1F2023),
      operator: KeyColors(
        face: 0xFF8E9096,
        label: 0xFF0C0F18,
        edge: 0xFF6E6F75,
      ),
      equals: KeyColors(face: 0xFF4CB86A, label: 0xFF09120B, edge: 0xFF339350),
      function: KeyColors(
        face: 0xFF55565C,
        label: 0xFFF3F4FF,
        edge: 0xFF38393E,
      ),
      shadow: 0x8C000000,
      highlight: 0x2EFFFFFF,
      seedColor: 0xFF4CB86A,
      lcdGhost: 0xFF072122,
    ),
    keyShape: KeyShapeSpec(kind: KeyShapeKind.keycap, cornerPermille: 120),
    keyStyle: _keycaps3,
    type: TypeSpec(
      displayFont: FontIds.robotoFlex,
      keyFont: FontIds.robotoFlex,
      operatorWeight: 750,
      widthPermille: 800,
      lcd: true,
    ),
    background: BackgroundSpec(
      kind: BackgroundKind.solid,
      colors: [0xFF232427],
    ),
    motion: _travelVfd,
    sound: SoundPackId.beep,
    name: 'Cyan Tube',
    nonColourOperatorCue: OperatorCue.weight,
  ),
];
