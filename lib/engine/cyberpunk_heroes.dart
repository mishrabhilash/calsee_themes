/// Hand-crafted Cyberpunk heroes (≥ 3 per family), spread into
/// `heroThemes` (heroes.dart).
///
/// Literal ARGB palettes made with the generator's recipe (cyberpunk.dart):
/// dark plates with neon edge lines, neon slabs at their chroma cusp with
/// dark labels, hot rims (black boundaries on the light Hazard body), a
/// recessed black HUD panel with faint lighter scanlines, and a static
/// cyber-grid scene.
/// All three play `mech_tactile` (the family's only pack).
/// Ids 130–132 are reserved for this family; never reuse or renumber one.
library;

import 'package:calsee_themes/engine/families.dart' show FontIds;
import 'package:calsee_themes/engine/theme_spec.dart';

/// The family's motion (Terminal row of the motion brief): `hardPress` in,
/// a 2 dp plunge, release 4000/1.0, glyph entry 115 % → 100 %, afterglow,
/// rigid · 0.6.
const MotionSpec _plunge = MotionSpec(
  verb: PressVerb.plunge,
  scheme: MotionScheme.standard,
  pressIn: SpringTokens.hardPress,
  release: SpringToken(4000, 1000),
  depthCdp: 200,
  entry: EntryStyle.glyph,
  entryScalePermille: 1150,
  fx: PressFx.afterglow,
  impact: ImpactStyle.rigid,
  impactPermille: 600,
);

/// The Cyberpunk heroes, ids 130–132.
const List<ThemeSpec> cyberpunkHeroes = [
  // 130 "Cipher Rain" — acid-yellow slabs and a cyan `=` on blue-black
  // glass, cyan-edged digits, acid function labels, a cyan street glow at
  // the bottom.
  ThemeSpec(
    seed: 130,
    family: ThemeFamily.cyberpunk,
    engineVersion: 3,
    variant: ThemeVariant.hero,
    heroId: 130,
    brightness: ThemeBrightness.dark,
    palette: Palette(
      background: 0xFF060C19,
      surface: 0xFF04060D,
      displayText: 0xFFE5F8F8,
      previewText: 0xFF43D5D9,
      error: 0xFFFF9797,
      caret: 0xFFD8D04C,
      focusRing: 0xFF2CECF2,
      accent: 0xFF2CECF2,
      digit: KeyColors(face: 0xFF171E2B, label: 0xFFE3F8F9, edge: 0xFF2CECF2),
      operator: KeyColors(
        face: 0xFFF6EB32,
        label: 0xFF060D1A,
        edge: 0xFFFEFAA9,
      ),
      equals: KeyColors(face: 0xFF10EDF3, label: 0xFF060D1A, edge: 0xFFB7FDFF),
      function: KeyColors(
        face: 0xFF1E2737,
        label: 0xFFE8DE27,
        edge: 0xFFE8DE27,
      ),
      shadow: 0x24066264,
      highlight: 0x00000000,
      seedColor: 0xFFF6EB32,
    ),
    keyShape: KeyShapeSpec(kind: KeyShapeKind.cut, cornerPermille: 180),
    keyStyle: KeyStyleSpec(
      kind: KeyStyleKind.flat,
      outlineWidthCdp: 125,
      shadowBlurCdp: 400,
      stateLayerPermille: 0,
    ),
    type: TypeSpec(
      displayFont: FontIds.oxanium,
      keyFont: FontIds.oxanium,
      displayWeight: 500,
      keyWeight: 550,
      operatorWeight: 800,
      slashedZero: true,
    ),
    background: BackgroundSpec(
      kind: BackgroundKind.cyberGrid,
      colors: [0xFF060C19, 0xFF002224, 0x1014BBC0, 0x34B2A912, 0x1E066264],
    ),
    motion: _plunge,
    sound: SoundPackId.mechTactile,
    name: 'Cipher Rain',
    nonColourOperatorCue: OperatorCue.outline,
  ),
  // 131 "Hazard Glitch" — the light variant: an acid-yellow body (no grid:
  // traces and scanlines only), black plates with yellow digits and cyan
  // edges, cyan slabs, a hot-magenta `=`, and a black HUD screen with
  // yellow digits, a cyan frame set inside a black rim and yellow
  // brackets.
  ThemeSpec(
    seed: 131,
    family: ThemeFamily.cyberpunk,
    engineVersion: 3,
    variant: ThemeVariant.hero,
    heroId: 131,
    brightness: ThemeBrightness.light,
    palette: Palette(
      background: 0xFFF9E818,
      surface: 0xFF070F0F,
      displayText: 0xFFF9E818,
      previewText: 0xFF5BDAE0,
      error: 0xFFFF898B,
      caret: 0xFFF076D9,
      focusRing: 0xFF111006,
      accent: 0xFF111006,
      digit: KeyColors(face: 0xFF0C1617, label: 0xFFF9E818, edge: 0xFF1BE5EE),
      operator: KeyColors(
        face: 0xFF00EDF3,
        label: 0xFF0C0C03,
        edge: 0xFF111006,
      ),
      equals: KeyColors(face: 0xFFFD39E0, label: 0xFF0C0C03, edge: 0xFF111006),
      function: KeyColors(
        face: 0xFF131F21,
        label: 0xFF2CECF2,
        edge: 0xFF2CECF2,
      ),
      shadow: 0x25006266,
      highlight: 0x00000000,
      seedColor: 0xFF00EDF3,
    ),
    keyShape: KeyShapeSpec(kind: KeyShapeKind.cut, cornerPermille: 200),
    keyStyle: KeyStyleSpec(
      kind: KeyStyleKind.flat,
      outlineWidthCdp: 150,
      shadowBlurCdp: 300,
      stateLayerPermille: 0,
    ),
    type: TypeSpec(
      displayFont: FontIds.oxanium,
      keyFont: FontIds.oxanium,
      displayWeight: 500,
      keyWeight: 550,
      operatorWeight: 800,
    ),
    background: BackgroundSpec(
      kind: BackgroundKind.cyberGrid,
      colors: [0xFFF9E818, 0xFFF8DC00, 0x001D1B0A, 0x22222007, 0x0F423A1E],
      angleTenths: 3500,
    ),
    motion: _plunge,
    sound: SoundPackId.mechTactile,
    name: 'Hazard Glitch',
    nonColourOperatorCue: OperatorCue.outline,
  ),
  // 132 "Toxic Uplink" — toxic-green slabs and digit edges on teal-black,
  // a magenta `=` and hot-pink function labels, a green floor glow.
  ThemeSpec(
    seed: 132,
    family: ThemeFamily.cyberpunk,
    engineVersion: 3,
    variant: ThemeVariant.hero,
    heroId: 132,
    brightness: ThemeBrightness.dark,
    palette: Palette(
      background: 0xFF000E12,
      surface: 0xFF00070A,
      displayText: 0xFFECF7EB,
      previewText: 0xFF8BD28D,
      error: 0xFFFF9393,
      caret: 0xFF67EB72,
      focusRing: 0xFF5EF56D,
      accent: 0xFF5EF56D,
      digit: KeyColors(face: 0xFF0D2126, label: 0xFFEBF8EB, edge: 0xFF5EF56D),
      operator: KeyColors(
        face: 0xFF49F860,
        label: 0xFF001015,
        edge: 0xFFCBFFCC,
      ),
      equals: KeyColors(face: 0xFFF826DB, label: 0xFF001015, edge: 0xFFF18BDB),
      function: KeyColors(
        face: 0xFF112B30,
        label: 0xFFF86DDF,
        edge: 0xFFF86DDF,
      ),
      shadow: 0x24376139,
      highlight: 0x00000000,
      seedColor: 0xFF49F860,
    ),
    keyShape: KeyShapeSpec(kind: KeyShapeKind.cut, cornerPermille: 160),
    keyStyle: KeyStyleSpec(
      kind: KeyStyleKind.flat,
      outlineWidthCdp: 125,
      shadowBlurCdp: 450,
      stateLayerPermille: 0,
    ),
    type: TypeSpec(
      displayFont: FontIds.oxanium,
      keyFont: FontIds.oxanium,
      displayWeight: 550,
      keyWeight: 600,
      operatorWeight: 800,
      slashedZero: true,
    ),
    background: BackgroundSpec(
      kind: BackgroundKind.cyberGrid,
      colors: [0xFF000E12, 0xFF042207, 0x0E72B875, 0x305BBE62, 0x1E376139],
      angleTenths: 150,
    ),
    motion: _plunge,
    sound: SoundPackId.mechTactile,
    name: 'Toxic Uplink',
    nonColourOperatorCue: OperatorCue.outline,
  ),
];
