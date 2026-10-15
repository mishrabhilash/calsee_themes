/// Hand-picked Vaporwave heroes (ids 140–142), spread into `heroThemes`
/// (heroes.dart).
///
/// Literal ARGB palettes copied from generated seeds 3, 197 and 162 (so
/// they follow the generator's recipe in vaporwave.dart exactly):
/// pastel Win95 buttons at face-grey lightness, a warm neon a step darker
/// and a cool neon a step lighter, one ink for every key line and the
/// window frame, an opaque client panel, and a ten-colour sunset scene.
/// Ids 140–142 are reserved for this family; never reuse or renumber one.
library;

import 'package:calsee_themes/engine/families.dart' show FontIds;
import 'package:calsee_themes/engine/theme_spec.dart';
import 'package:calsee_themes/engine/vaporwave.dart';

/// Motion brief row "Vaporwave": effectsFast in (the bevel inverts in
/// frame 1 on `tint`), the label travels (+d, +d) and returns on the
/// release spring, display glyphs rise 6 dp on standard.normal, light · 0.6.
const MotionSpec _sink439 = MotionSpec(
  verb: PressVerb.sink,
  scheme: MotionScheme.expressive,
  pressIn: SpringTokens.effectsFast,
  release: SpringToken(439, 800),
  depthCdp: 100,
  entry: EntryStyle.rise,
  entryOffsetCdp: 600,
  entrySpring: SpringTokens.standardNormal,
  impact: ImpactStyle.light,
  impactPermille: 600,
);

const MotionSpec _sink395 = MotionSpec(
  verb: PressVerb.sink,
  scheme: MotionScheme.expressive,
  pressIn: SpringTokens.effectsFast,
  release: SpringToken(395, 850),
  depthCdp: 200,
  entry: EntryStyle.rise,
  entryOffsetCdp: 600,
  entrySpring: SpringTokens.standardNormal,
  impact: ImpactStyle.light,
  impactPermille: 600,
);

const MotionSpec _sink482 = MotionSpec(
  verb: PressVerb.sink,
  scheme: MotionScheme.expressive,
  pressIn: SpringTokens.effectsFast,
  release: SpringToken(482, 750),
  depthCdp: 100,
  entry: EntryStyle.rise,
  entryOffsetCdp: 600,
  entrySpring: SpringTokens.standardNormal,
  impact: ImpactStyle.light,
  impactPermille: 600,
);

/// Bevel 3 dp, shade 0.30, highlight 0.85, label travel 1 dp.
const KeyStyleSpec _bevel3 = KeyStyleSpec(
  kind: KeyStyleKind.extruded,
  outlineWidthCdp: vaporwaveOutlineWidthCdp,
  extrudeDepthCdp: 300,
  edgeShadePermille: 300,
  shadowOffsetCdp: 100,
  stateLayerPermille: vaporwaveStateLayerPermille,
  highlightPermille: 850,
);

/// Bevel 2 dp, shade 0.28, highlight 0.90, label travel 2 dp.
const KeyStyleSpec _bevel2 = KeyStyleSpec(
  kind: KeyStyleKind.extruded,
  outlineWidthCdp: vaporwaveOutlineWidthCdp,
  extrudeDepthCdp: 200,
  edgeShadePermille: 280,
  shadowOffsetCdp: 200,
  stateLayerPermille: vaporwaveStateLayerPermille,
  highlightPermille: 900,
);

/// Bevel 3 dp, shade 0.34, highlight 0.80, label travel 1 dp.
const KeyStyleSpec _bevel3Deep = KeyStyleSpec(
  kind: KeyStyleKind.extruded,
  outlineWidthCdp: vaporwaveOutlineWidthCdp,
  extrudeDepthCdp: 300,
  edgeShadePermille: 340,
  shadowOffsetCdp: 100,
  stateLayerPermille: vaporwaveStateLayerPermille,
  highlightPermille: 800,
);

/// The Vaporwave heroes, ids 140–142.
const List<ThemeSpec> vaporwaveHeroes = [
  // 140 — dusk: an indigo → violet sky over a red-orange → magenta
  // striped sun, a neon-magenta grid, lavender buttons with peach
  // function keys, hot-pink operators and a cyan `=`; the title bar runs
  // pink → cyan.
  ThemeSpec(
    seed: 140,
    family: ThemeFamily.vaporwave,
    engineVersion: 3,
    variant: ThemeVariant.hero,
    heroId: 140,
    brightness: ThemeBrightness.dark,
    palette: Palette(
      background: 0xFF18033A,
      surface: 0xFF150E28,
      displayText: 0xFFFFECF2,
      previewText: 0xFF56D2DE,
      error: 0xFFFE8B83,
      caret: 0xFFF3A2C1,
      focusRing: 0xFFFFF6F9,
      accent: 0xFF99F5FE,
      digit: KeyColors(face: 0xFFC3BBDE, label: 0xFF1D153C, edge: 0xFF050112),
      operator: KeyColors(
        face: 0xFFF95EA5,
        label: 0xFF1D153C,
        edge: 0xFF050112,
      ),
      equals: KeyColors(face: 0xFF99F5FE, label: 0xFF1D153C, edge: 0xFF050112),
      function: KeyColors(
        face: 0xFFF3B998,
        label: 0xFF1D153C,
        edge: 0xFF050112,
      ),
      shadow: 0xFF050112,
      highlight: 0xFFF95EA5,
      seedColor: 0xFFF95EA5,
    ),
    keyShape: KeyShapeSpec(kind: KeyShapeKind.roundedRect, cornerPermille: 0),
    keyStyle: _bevel3,
    type: TypeSpec(
      displayFont: FontIds.anybody,
      keyFont: FontIds.anybody,
      displayWeight: 500,
      operatorWeight: 750,
      widthPermille: 1300,
    ),
    background: BackgroundSpec(
      kind: BackgroundKind.vaporSunset,
      colors: [
        0xFF18033A,
        0xFF4D1567,
        0xFF811470,
        0xFFFB3E26,
        0xFFEE2D7F,
        0xFFC118AB,
        0xFF31074D,
        0xFF0B0421,
        0xFFD523BE,
        0xFFEB238E,
      ],
      angleTenths: 380,
      driftPeriodMs: vaporwaveDriftPeriodMs,
    ),
    motion: _sink439,
    sound: SoundPackId.softTap,
    name: 'Dusk Plaza',
    nonColourOperatorCue: OperatorCue.weight,
  ),
  // 141 — pastel: a pink-lilac sky with a butter → hot-pink sun over a
  // lilac floor with a pale pink neon grid, lavender buttons with peach
  // function keys, cyan operators and a hot-pink `=`, a near-white client
  // under a classic navy → teal title bar.
  ThemeSpec(
    seed: 141,
    family: ThemeFamily.vaporwave,
    engineVersion: 3,
    variant: ThemeVariant.hero,
    heroId: 141,
    brightness: ThemeBrightness.light,
    palette: Palette(
      background: 0xFFE2BCE0,
      surface: 0xFFF9F5FF,
      displayText: 0xFF1D183E,
      previewText: 0xFF5B4481,
      error: 0xFFB71824,
      caret: 0xFF2A6F74,
      focusRing: 0xFF1D1743,
      accent: 0xFF008190,
      digit: KeyColors(face: 0xFFC4B6D9, label: 0xFF191535, edge: 0xFF1F1D38),
      operator: KeyColors(
        face: 0xFF81F6FF,
        label: 0xFF191535,
        edge: 0xFF1F1D38,
      ),
      equals: KeyColors(face: 0xFFF8649D, label: 0xFF191535, edge: 0xFF1F1D38),
      function: KeyColors(
        face: 0xFFECB08E,
        label: 0xFF191535,
        edge: 0xFF1F1D38,
      ),
      shadow: 0xFF1F1D38,
      highlight: 0xFF042872,
      seedColor: 0xFF81F6FF,
    ),
    keyShape: KeyShapeSpec(kind: KeyShapeKind.roundedRect, cornerPermille: 10),
    keyStyle: _bevel2,
    type: TypeSpec(
      displayFont: FontIds.anybody,
      keyFont: FontIds.anybody,
      displayWeight: 450,
      keyWeight: 450,
      operatorWeight: 700,
      widthPermille: 1250,
      slashedZero: true,
    ),
    background: BackgroundSpec(
      kind: BackgroundKind.vaporSunset,
      colors: [
        0xFFE2BCE0,
        0xFFF9CEDD,
        0xFFFFDECD,
        0xFFFFDB87,
        0xFFFBA468,
        0xFFF2669D,
        0xFFA085C4,
        0xFF8969AF,
        0xFFFBD8F5,
        0xFFE6498A,
      ],
      angleTenths: 420,
      driftPeriodMs: vaporwaveDriftPeriodMs,
    ),
    motion: _sink395,
    sound: SoundPackId.softTap,
    name: 'Pastel Atrium',
    nonColourOperatorCue: OperatorCue.weight,
  ),
  // 142 — midnight: a navy sky with a magenta haze, a cooler hot-pink →
  // violet sun, an electric-violet grid on a near-black floor, periwinkle
  // buttons with peach function keys, magenta operators and an aqua `=`;
  // the title bar runs magenta → aqua.
  ThemeSpec(
    seed: 142,
    family: ThemeFamily.vaporwave,
    engineVersion: 3,
    variant: ThemeVariant.hero,
    heroId: 142,
    brightness: ThemeBrightness.dark,
    palette: Palette(
      background: 0xFF040C21,
      surface: 0xFF0B162E,
      displayText: 0xFFFDECF9,
      previewText: 0xFF62D5BE,
      error: 0xFFFE8B83,
      caret: 0xFFF39AE6,
      focusRing: 0xFFFFF5FD,
      accent: 0xFF91FCE5,
      digit: KeyColors(face: 0xFFB8C6EB, label: 0xFF151332, edge: 0xFF020719),
      operator: KeyColors(
        face: 0xFFE064D2,
        label: 0xFF151332,
        edge: 0xFF020719,
      ),
      equals: KeyColors(face: 0xFF91FCE5, label: 0xFF151332, edge: 0xFF020719),
      function: KeyColors(
        face: 0xFFEAB99C,
        label: 0xFF151332,
        edge: 0xFF020719,
      ),
      shadow: 0xFF020719,
      highlight: 0xFFE064D2,
      seedColor: 0xFFE064D2,
    ),
    keyShape: KeyShapeSpec(kind: KeyShapeKind.roundedRect, cornerPermille: 0),
    keyStyle: _bevel3Deep,
    type: TypeSpec(
      displayFont: FontIds.anybody,
      keyFont: FontIds.anybody,
      displayWeight: 500,
      operatorWeight: 800,
      widthPermille: 1400,
    ),
    background: BackgroundSpec(
      kind: BackgroundKind.vaporSunset,
      colors: [
        0xFF040C21,
        0xFF241252,
        0xFF690369,
        0xFFFD2888,
        0xFFD13BBD,
        0xFF9D3DE5,
        0xFF12163D,
        0xFF010208,
        0xFFA050F6,
        0xFFD73BC8,
      ],
      angleTenths: 380,
      driftPeriodMs: vaporwaveDriftPeriodMs,
    ),
    motion: _sink482,
    sound: SoundPackId.softTap,
    name: 'Moonlit Dolphin',
    nonColourOperatorCue: OperatorCue.weight,
  ),
];
