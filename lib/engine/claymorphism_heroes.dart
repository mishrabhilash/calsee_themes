/// Hand-crafted Claymorphism heroes (≥ 3 per family), spread into
/// `heroThemes` (heroes.dart).
///
/// Literal ARGB palettes made with the generator's recipe
/// (claymorphism.dart): opaque multi-pastel faces on the lightness ladder,
/// drop shadows from `clayDropShadow`, a white highlight, the pillow card
/// (0.06 L above the body), the focus ring solved over the scene and the
/// keys' own shadows (`clayFocusShadowSamples`), a nine-colour `claySoft`
/// scene. Ids 70–72 are reserved for this family; never reuse
/// or renumber one.
library;

import 'package:calsee_themes/engine/families.dart' show FontIds;
import 'package:calsee_themes/engine/theme_spec.dart';

/// Motion brief §2.3 "Claymorphism": squash on 1755/0.85, release
/// 322/0.65 (a visible tall-and-thin rebound), pop entry from 0.86,
/// soft · 0.8.
const MotionSpec _squash = MotionSpec(
  verb: PressVerb.squash,
  scheme: MotionScheme.expressive,
  pressIn: SpringTokens.glassPressIn,
  release: SpringToken(322, 650),
  depthCdp: 500,
  scalePermille: 920,
  stateLayerSnap: true,
  entry: EntryStyle.pop,
  entryScalePermille: 860,
  impact: ImpactStyle.soft,
);

const MotionSpec _squashFirm = MotionSpec(
  verb: PressVerb.squash,
  scheme: MotionScheme.expressive,
  pressIn: SpringTokens.glassPressIn,
  release: SpringToken(354, 700),
  depthCdp: 400,
  scalePermille: 920,
  stateLayerSnap: true,
  entry: EntryStyle.pop,
  entryScalePermille: 860,
  impact: ImpactStyle.soft,
);

const MotionSpec _squashDeep = MotionSpec(
  verb: PressVerb.squash,
  scheme: MotionScheme.expressive,
  pressIn: SpringTokens.glassPressIn,
  release: SpringToken(322, 650),
  depthCdp: 600,
  scalePermille: 920,
  stateLayerSnap: true,
  entry: EntryStyle.pop,
  entryScalePermille: 860,
  impact: ImpactStyle.soft,
);

/// The Claymorphism heroes, ids 70–72.
const List<ThemeSpec> claymorphismHeroes = [
  // 70 — lavender clay with coral-pink candy operators, a mint function
  // row and a deep grape gummy `=`; a coral sphere behind the settings
  // button, a mint one under the bottom-left keys; a pillow card.
  ThemeSpec(
    seed: 70,
    family: ThemeFamily.claymorphism,
    engineVersion: 3,
    variant: ThemeVariant.hero,
    heroId: 70,
    brightness: ThemeBrightness.light,
    palette: Palette(
      background: 0xFFD9D1E9,
      surface: 0xFFEBE6F5,
      displayText: 0xFF2A2139,
      previewText: 0xFF564E63,
      error: 0xFFB02A2D,
      caret: 0xFFB3314F,
      focusRing: 0xFF650E25,
      accent: 0xFFB3314F,
      digit: KeyColors(face: 0xFFF1EBDE, label: 0xFF2A2009, edge: 0x5C705F8B),
      operator: KeyColors(
        face: 0xFFF68293,
        label: 0xFF32191C,
        edge: 0x706D0025,
      ),
      equals: KeyColors(face: 0xFF7C37BE, label: 0xFFFEFAF1, edge: 0x7A450773),
      function: KeyColors(
        face: 0xFF86DCB7,
        label: 0xFF0C281D,
        edge: 0x66005F43,
      ),
      shadow: 0x40382B4D,
      highlight: 0xB4FFFFFF,
      seedColor: 0xFFF68293,
    ),
    keyShape: KeyShapeSpec(kind: KeyShapeKind.squircle, cornerPermille: 360),
    keyStyle: KeyStyleSpec(
      kind: KeyStyleKind.clay,
      shadowOffsetCdp: 500,
      shadowBlurCdp: 1200,
      edgeShadePermille: 90,
      stateLayerPermille: 60,
    ),
    type: TypeSpec(
      displayFont: FontIds.nunito,
      keyFont: FontIds.nunito,
      displayWeight: 700,
      keyWeight: 700,
      operatorWeight: 850,
    ),
    background: BackgroundSpec(
      kind: BackgroundKind.claySoft,
      colors: [
        0xFFD9D1E9,
        0xFFDFD9EB,
        0xFFF3B9BF,
        0xFFEEA3AB,
        0xFFD98993,
        0xFFA3DBC1,
        0xFF83CFAE,
        0xFF63B895,
        0xFFBFB4D8,
      ],
      angleTenths: 300,
    ),
    motion: _squash,
    sound: SoundPackId.pop,
    name: 'Lilac Gumdrop',
  ),
  // 71 — warm peach plasticine on a pale peach pillow card: cool
  // milk-white digits, rose function keys, tangerine operators (the candy
  // rule moved them out of mustard) and a deep raspberry `=`.
  ThemeSpec(
    seed: 71,
    family: ThemeFamily.claymorphism,
    engineVersion: 3,
    variant: ThemeVariant.hero,
    heroId: 71,
    brightness: ThemeBrightness.light,
    palette: Palette(
      background: 0xFFEAD2C3,
      surface: 0xFFF7E8DF,
      displayText: 0xFF372010,
      previewText: 0xFF624E40,
      error: 0xFFB02A2D,
      caret: 0xFF8D5D28,
      focusRing: 0xFF492800,
      accent: 0xFF8D5D28,
      digit: KeyColors(face: 0xFFE4ECF6, label: 0xFF142234, edge: 0x5C895E41),
      operator: KeyColors(
        face: 0xFFEC9630,
        label: 0xFF2F1D0B,
        edge: 0x70542F00,
      ),
      equals: KeyColors(face: 0xFFB21B4B, label: 0xFFFEFAF1, edge: 0x7A630024),
      function: KeyColors(
        face: 0xFFEAB9B8,
        label: 0xFF32191A,
        edge: 0x66723F3F,
      ),
      shadow: 0x404A2A12,
      highlight: 0xAAFFFFFF,
      seedColor: 0xFFEC9630,
    ),
    keyShape: KeyShapeSpec(kind: KeyShapeKind.squircle, cornerPermille: 400),
    keyStyle: KeyStyleSpec(
      kind: KeyStyleKind.clay,
      shadowOffsetCdp: 400,
      shadowBlurCdp: 1000,
      edgeShadePermille: 80,
      stateLayerPermille: 60,
    ),
    type: TypeSpec(
      displayFont: FontIds.nunito,
      keyFont: FontIds.nunito,
      displayWeight: 650,
      keyWeight: 700,
      operatorWeight: 850,
    ),
    background: BackgroundSpec(
      kind: BackgroundKind.claySoft,
      colors: [
        0xFFEAD2C3,
        0xFFEDDACE,
        0xFFEDC5A0,
        0xFFE6B27F,
        0xFFD19961,
        0xFFF4BAB5,
        0xFFEFA49D,
        0xFFDA8A84,
        0xFFD8B49C,
      ],
      angleTenths: 600,
    ),
    motion: _squashFirm,
    sound: SoundPackId.pop,
    name: 'Apricot Fondant',
  ),
  // 72 — night clay: a deep plum body on a plum pillow card, a glowing
  // berry sphere behind the toolbar and a cobalt one at the keypad corner;
  // lavender-white digits, mint function keys, coral candy operators (35°,
  // the berry-mint row on a plum body) and a deep emerald gummy `=`
  // (156°).
  ThemeSpec(
    seed: 72,
    family: ThemeFamily.claymorphism,
    engineVersion: 3,
    variant: ThemeVariant.hero,
    heroId: 72,
    brightness: ThemeBrightness.dark,
    palette: Palette(
      background: 0xFF2B102D,
      surface: 0xFF3B1F3D,
      displayText: 0xFFFBF2FB,
      previewText: 0xFFC8B7C9,
      error: 0xFFFE8A88,
      caret: 0xFFF3A895,
      focusRing: 0xFFFFC9BB,
      accent: 0xFFF3A895,
      digit: KeyColors(face: 0xFFF1E3FB, label: 0xFF281C30, edge: 0xB805000B),
      operator: KeyColors(
        face: 0xFFF98568,
        label: 0xFF301B16,
        edge: 0xCC060007,
      ),
      equals: KeyColors(face: 0xFF007E49, label: 0xFFFEFAF1, edge: 0xD6060007),
      function: KeyColors(
        face: 0xFF7CE2B8,
        label: 0xFF0C281D,
        edge: 0xC2060007,
      ),
      shadow: 0x80040004,
      highlight: 0xA0FFFFFF,
      seedColor: 0xFFF98568,
    ),
    keyShape: KeyShapeSpec(kind: KeyShapeKind.squircle, cornerPermille: 340),
    keyStyle: KeyStyleSpec(
      kind: KeyStyleKind.clay,
      shadowOffsetCdp: 600,
      shadowBlurCdp: 1400,
      edgeShadePermille: 110,
      stateLayerPermille: 60,
    ),
    type: TypeSpec(
      displayFont: FontIds.nunito,
      keyFont: FontIds.nunito,
      displayWeight: 700,
      keyWeight: 750,
      operatorWeight: 900,
    ),
    background: BackgroundSpec(
      kind: BackgroundKind.claySoft,
      colors: [
        0xFF2B102D,
        0xFF341936,
        0xFF97406B,
        0xFF852558,
        0xFF6A1644,
        0xFF3A5EA2,
        0xFF234993,
        0xFF153676,
        0xFF150317,
      ],
    ),
    motion: _squashDeep,
    sound: SoundPackId.pop,
    name: 'Plum Taffy',
  ),
];
