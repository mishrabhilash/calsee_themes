/// Hand-picked Paper & ink heroes (≥ 3 per family), spread into
/// `heroThemes` (heroes.dart).
///
/// Literal ARGB palettes made with the generator's recipe (paper_ink.dart):
/// one ink for outlines, labels, display text and the operator hatch, slips
/// a shade off the sheet, an operator wash of the stamp ink, a `=` rubber
/// stamp with a knocked-out label, and a ruled or graph sheet with grain.
/// Ids 110–112 are reserved for this family; never reuse or renumber one.
library;

import 'package:calsee_themes/engine/families.dart' show FontIds;
import 'package:calsee_themes/engine/theme_spec.dart';

/// Motion brief §2.3 "Paper & ink": effectsFast in, the 1 dp drop releasing
/// on `release` (1400/0.9 × {0.9, 1, 1.1}), the ink drying on effectsSlow,
/// a bleed entry from 104 %, soft · 0.6.
const MotionSpec _ink1400 = MotionSpec(
  verb: PressVerb.ink,
  scheme: MotionScheme.standard,
  pressIn: SpringTokens.effectsFast,
  release: SpringTokens.standardFast,
  releaseAlt: SpringTokens.effectsSlow,
  depthCdp: 100,
  entry: EntryStyle.bleed,
  entryScalePermille: 1040,
  fx: PressFx.inkWash,
  impact: ImpactStyle.soft,
  impactPermille: 600,
);

const MotionSpec _ink1260 = MotionSpec(
  verb: PressVerb.ink,
  scheme: MotionScheme.standard,
  pressIn: SpringTokens.effectsFast,
  release: SpringToken(1260, 900),
  releaseAlt: SpringTokens.effectsSlow,
  depthCdp: 100,
  entry: EntryStyle.bleed,
  entryScalePermille: 1040,
  fx: PressFx.inkWash,
  impact: ImpactStyle.soft,
  impactPermille: 600,
);

const MotionSpec _ink1540 = MotionSpec(
  verb: PressVerb.ink,
  scheme: MotionScheme.standard,
  pressIn: SpringTokens.effectsFast,
  release: SpringToken(1540, 900),
  releaseAlt: SpringTokens.effectsSlow,
  depthCdp: 100,
  entry: EntryStyle.bleed,
  entryScalePermille: 1040,
  fx: PressFx.inkWash,
  impact: ImpactStyle.soft,
  impactPermille: 600,
);

/// The Paper & ink heroes, ids 110–112.
const List<ThemeSpec> paperInkHeroes = [
  // 110 — cream writing paper ruled in feint blue, a blue-black
  // fineliner, a vermilion hanko stamp, peach-washed operators and a
  // ledger display with a red margin.
  ThemeSpec(
    seed: 110,
    family: ThemeFamily.paperInk,
    engineVersion: 3,
    variant: ThemeVariant.hero,
    heroId: 110,
    brightness: ThemeBrightness.light,
    palette: Palette(
      background: 0xFFFDF2DF,
      surface: 0xFFFDFBF7,
      displayText: 0xFF0D1525,
      previewText: 0xFF434D60,
      error: 0xFFB02B27,
      caret: 0xFF992C1F,
      focusRing: 0xFF0D1525,
      accent: 0xFFB92F20,
      digit: KeyColors(face: 0xFFFFF9EF, label: 0xFF0D1525, edge: 0xFF0D1525),
      operator: KeyColors(
        face: 0xFFFCD9D1,
        label: 0xFF0D1525,
        edge: 0xFF0D1525,
      ),
      equals: KeyColors(face: 0xFFB92F20, label: 0xFFFFF9EF, edge: 0xFF0D1525),
      function: KeyColors(
        face: 0xFFE5EDF4,
        label: 0xFF0D1525,
        edge: 0xFF0D1525,
      ),
      shadow: 0xFF0D1525,
      highlight: 0x3A0D1525,
      seedColor: 0xFFB92F20,
    ),
    keyShape: KeyShapeSpec(kind: KeyShapeKind.roundedRect, cornerPermille: 40),
    keyStyle: KeyStyleSpec(
      kind: KeyStyleKind.outlined,
      outlineWidthCdp: 175,
      edgeShadePermille: 700,
      stateLayerPermille: 0,
    ),
    type: TypeSpec(
      displayFont: FontIds.newsreader,
      keyFont: FontIds.newsreader,
      keyWeight: 450,
      operatorWeight: 700,
    ),
    background: BackgroundSpec(
      kind: BackgroundKind.paperSheet,
      colors: [0xFFFDF2DF, 0xFF7898B1],
      angleTenths: 450,
      pattern: BackgroundPattern.stripes,
      patternScaleCdp: 4400,
      patternOpacityPermille: 260,
    ),
    motion: _ink1400,
    sound: SoundPackId.typewriter,
    name: 'Vermilion Ledger',
    nonColourOperatorCue: OperatorCue.pattern,
  ),
  // 111 — blue-white engineering paper with a pale blue grid, carbon ink,
  // an ultramarine stamp, periwinkle-washed operators and an index card.
  ThemeSpec(
    seed: 111,
    family: ThemeFamily.paperInk,
    engineVersion: 3,
    variant: ThemeVariant.hero,
    heroId: 111,
    brightness: ThemeBrightness.light,
    palette: Palette(
      background: 0xFFE6F4FD,
      surface: 0xFFF1F8FC,
      displayText: 0xFF171A1C,
      previewText: 0xFF4A4E50,
      error: 0xFFB02B27,
      caret: 0xFF1D4DBA,
      focusRing: 0xFF171A1C,
      accent: 0xFF2057D4,
      digit: KeyColors(face: 0xFFF2FAFF, label: 0xFF171A1C, edge: 0xFF171A1C),
      operator: KeyColors(
        face: 0xFFD6E3FC,
        label: 0xFF171A1C,
        edge: 0xFF171A1C,
      ),
      equals: KeyColors(face: 0xFF2057D4, label: 0xFFF2FAFF, edge: 0xFF171A1C),
      function: KeyColors(
        face: 0xFFE1EEF4,
        label: 0xFF171A1C,
        edge: 0xFF171A1C,
      ),
      shadow: 0xFF171A1C,
      highlight: 0x3A171A1C,
      seedColor: 0xFF2057D4,
    ),
    keyShape: KeyShapeSpec(kind: KeyShapeKind.roundedRect, cornerPermille: 20),
    keyStyle: KeyStyleSpec(
      kind: KeyStyleKind.outlined,
      outlineWidthCdp: 150,
      edgeShadePermille: 700,
      stateLayerPermille: 0,
    ),
    type: TypeSpec(
      displayFont: FontIds.newsreader,
      keyFont: FontIds.newsreader,
      displayWeight: 350,
      keyWeight: 450,
      operatorWeight: 700,
    ),
    background: BackgroundSpec(
      kind: BackgroundKind.paperSheet,
      colors: [0xFFE6F4FD, 0xFF5496B2],
      angleTenths: 272,
      pattern: BackgroundPattern.grid,
      patternScaleCdp: 3000,
      patternOpacityPermille: 187,
    ),
    motion: _ink1540,
    sound: SoundPackId.typewriter,
    name: 'Ultramarine Folio',
    nonColourOperatorCue: OperatorCue.pattern,
  ),
  // 112 — indigo-black ink paper ruled in dusk blue, a cream gel pen, a
  // coral gel stamp, plum-washed operators and a ledger display.
  ThemeSpec(
    seed: 112,
    family: ThemeFamily.paperInk,
    engineVersion: 3,
    variant: ThemeVariant.hero,
    heroId: 112,
    brightness: ThemeBrightness.dark,
    palette: Palette(
      background: 0xFF0E1628,
      surface: 0xFF171F30,
      displayText: 0xFFE3DED4,
      previewText: 0xFFBBB7AD,
      error: 0xFFF49287,
      caret: 0xFFF3A896,
      focusRing: 0xFFE3DED4,
      accent: 0xFFF48970,
      digit: KeyColors(face: 0xFF1D2433, label: 0xFFE3DED4, edge: 0xFFE3DED4),
      operator: KeyColors(
        face: 0xFF42232F,
        label: 0xFFE3DED4,
        edge: 0xFFE3DED4,
      ),
      equals: KeyColors(face: 0xFFF48970, label: 0xFF0E1628, edge: 0xFFE3DED4),
      function: KeyColors(
        face: 0xFF2B3038,
        label: 0xFFE3DED4,
        edge: 0xFFE3DED4,
      ),
      shadow: 0xFFE3DED4,
      highlight: 0x3AE3DED4,
      seedColor: 0xFFF48970,
    ),
    keyShape: KeyShapeSpec(kind: KeyShapeKind.roundedRect, cornerPermille: 50),
    keyStyle: KeyStyleSpec(
      kind: KeyStyleKind.outlined,
      outlineWidthCdp: 150,
      edgeShadePermille: 700,
      stateLayerPermille: 0,
    ),
    type: TypeSpec(
      displayFont: FontIds.newsreader,
      keyFont: FontIds.newsreader,
      keyWeight: 450,
      operatorWeight: 750,
    ),
    background: BackgroundSpec(
      kind: BackgroundKind.paperSheet,
      colors: [0xFF0E1628, 0xFF73819F],
      angleTenths: 363,
      pattern: BackgroundPattern.stripes,
      patternScaleCdp: 4400,
      patternOpacityPermille: 212,
    ),
    motion: _ink1260,
    sound: SoundPackId.typewriter,
    name: 'Indigo Quill',
    nonColourOperatorCue: OperatorCue.pattern,
  ),
];
