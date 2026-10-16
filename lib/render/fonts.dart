// Bundled font families for themes (M3, docs/m3-theme-engine-design.md).
//
// Maps the theme engine's font ids (plain strings, so lib/themes/engine
// stays pure Dart) to the families declared in pubspec.yaml `fonts:`, and
// builds the `fontFeatures` / `fontVariations` a TextStyle needs.
//
// Both bundled fonts are variable fonts with a single file each. Flutter
// does not reliably map `fontWeight` onto the `wght` axis of a variable
// font, so every style built here sets the axis explicitly
// (Space Grotesk's default instance is Light 300, not Regular).
import 'dart:ui' show FontFeature, FontVariation, FontWeight;

import 'package:flutter/painting.dart' show TextStyle;
import 'package:meta/meta.dart';

/// One variation axis of a bundled variable font: `[min, max]`, `default`.
@immutable
final class FontAxisRange {
  /// Creates an axis range.
  const new(this.tag, this.min, this.defaultValue, this.max);

  /// OpenType axis tag, e.g. `wght`.
  final String tag;

  /// Smallest supported value.
  final double min;

  /// Value of the font's default instance.
  final double defaultValue;

  /// Largest supported value.
  final double max;

  /// [value] clamped into `[min, max]`.
  double clamp(double value) => value.clamp(min, max);

  /// A [FontVariation] for [value], clamped into range.
  FontVariation variation(double value) => FontVariation(tag, clamp(value));
}

/// Fonts a theme may use. [id] is the stable string stored in a ThemeSpec's
/// TypeSpec; [family] is the pubspec family name (null = platform default).
enum BundledFont {
  /// Platform default UI font (M2 behaviour; the plain theme).
  platform('platform', null, tabularByDefault: false),

  /// Roboto Flex: Material 3 Expressive display and keys, and the
  /// settings/history UI face. Figures are tabular by default (the font
  /// has `pnum`, not `tnum`).
  robotoFlex(
    'roboto_flex',
    'RobotoFlex',
    tabularByDefault: true,
    weight: FontAxisRange('wght', 100, 400, 1000),
    width: FontAxisRange('wdth', 25, 100, 151),
    grade: FontAxisRange('GRAD', -200, 0, 150),
    opticalSize: FontAxisRange('opsz', 8, 14, 144),
  ),

  /// Space Grotesk: NeoPOP's chunky grotesque (weight 300–700, has `tnum`
  /// and slashed `zero`).
  spaceGrotesk(
    'space_grotesk',
    'SpaceGrotesk',
    tabularByDefault: false,
    hasSlashedZero: true,
    weight: FontAxisRange('wght', 300, 300, 700),
  ),

  /// Nunito: Claymorphism's rounded heavy sans (weight 200–1000; digits
  /// equal width by default; default instance ExtraLight, so the axis is
  /// always set).
  nunito(
    'nunito',
    'Nunito',
    tabularByDefault: true,
    weight: FontAxisRange('wght', 200, 200, 1000),
  ),

  /// Open Sans: the Y2K / Frutiger Aero humanist sans, a sibling of the
  /// Vista / 7 system face (weight 300–800, width pinned at 100; `tnum`,
  /// slashed `zero`).
  openSans(
    'open_sans',
    'OpenSans',
    tabularByDefault: true,
    hasSlashedZero: true,
    weight: FontAxisRange('wght', 300, 400, 800),
  ),

  /// Newsreader: Paper & ink's editorial serif (weight 200–800, optical
  /// size 6–72 follows the font size; tabular figures by default).
  newsreader(
    'newsreader',
    'Newsreader',
    tabularByDefault: true,
    weight: FontAxisRange('wght', 200, 400, 800),
    opticalSize: FontAxisRange('opsz', 6, 18, 72),
  ),

  /// Oxanium: Cyberpunk's squared techno face (weight 200–800, digits
  /// equal width by default, slashed `zero`).
  oxanium(
    'oxanium',
    'Oxanium',
    tabularByDefault: true,
    hasSlashedZero: true,
    weight: FontAxisRange('wght', 200, 200, 800),
  ),

  /// Anybody: Vaporwave's extended 90s grotesque (weight 100–900, width
  /// 50–150; `tnum`, slashed `zero`).
  anybody(
    'anybody',
    'Anybody',
    tabularByDefault: false,
    hasSlashedZero: true,
    weight: FontAxisRange('wght', 100, 100, 900),
    width: FontAxisRange('wdth', 50, 100, 150),
  ),

  /// Jost: Bauhaus's Futura-model geometric sans (weight 100–900, `tnum`).
  jost(
    'jost',
    'Jost',
    tabularByDefault: false,
    weight: FontAxisRange('wght', 100, 400, 900),
  ),

  /// Patrick Hand: Paper & ink's handwritten chrome headings (settings and
  /// dialog titles, section headers). A static Regular with proportional
  /// figures, so it is never used for numbers or by the theme generator.
  patrickHand('patrick_hand', 'PatrickHand', tabularByDefault: false);

  new(
    this.id,
    this.family, {
    required this.tabularByDefault,
    this.hasSlashedZero = false,
    this.weight,
    this.width,
    this.grade,
    this.opticalSize,
  });

  /// Looks up a font by its stable [id]; unknown ids fall back to
  /// [platform] so an older app never fails on a newer theme.
  static BundledFont fromId(String? id) {
    for (final font in values) {
      if (font.id == id) return font;
    }
    return platform;
  }

  /// Looks up a font by its pubspec [family] name (null → [platform]).
  static BundledFont fromFamily(String? family) {
    for (final font in values) {
      if (font.family == family) return font;
    }
    return platform;
  }

  /// Stable id used in ThemeSpec JSON.
  final String id;

  /// Family name declared in pubspec.yaml, or null for the platform font.
  final String? family;

  /// Whether digits are already fixed-width without the `tnum` feature.
  final bool tabularByDefault;

  /// Whether the font supports the `zero` (slashed zero) feature.
  final bool hasSlashedZero;

  /// `wght` axis, if variable in weight.
  final FontAxisRange? weight;

  /// `wdth` axis, if any.
  final FontAxisRange? width;

  /// `GRAD` axis (weight change without reflow), if any.
  final FontAxisRange? grade;

  /// `opsz` axis, if any.
  final FontAxisRange? opticalSize;

  /// Whether this is a bundled asset font (not the platform font).
  bool get isBundled => family != null;

  /// OpenType features for this font. Tabular figures are on by default
  /// (calculator display, keys, history and settings values all align).
  List<FontFeature> features({bool tabular = true, bool slashedZero = false}) {
    final zero = slashedZero && hasSlashedZero;
    if (tabular && zero) return _tabularZero;
    if (tabular) return tabularFigures;
    if (zero) return _zeroOnly;
    return const [];
  }

  /// Variation-axis settings, clamped to this font's ranges; axes the font
  /// does not have are omitted. [weight] defaults to Regular 400 (clamped,
  /// so Space Grotesk never renders at its Light default by accident).
  /// [opticalSize] defaults to [fontSize] when given (auto optical sizing).
  List<FontVariation> variations({
    double weight = 400,
    double? width,
    double? grade,
    double? opticalSize,
    double? fontSize,
  }) {
    final out = <FontVariation>[];
    final w = this.weight;
    if (w != null) out.add(w.variation(weight));
    final wd = this.width;
    if (wd != null && width != null) out.add(wd.variation(width));
    final g = this.grade;
    if (g != null && grade != null) out.add(g.variation(grade));
    final o = this.opticalSize;
    final opsz = opticalSize ?? fontSize;
    if (o != null && opsz != null) out.add(o.variation(opsz));
    return out;
  }

  /// A complete [TextStyle] for this font. [weight] is a CSS-style weight
  /// (Roboto Flex accepts 100–1000); `fontWeight` is set to the nearest
  /// [FontWeight] so platform fallback glyphs match.
  TextStyle style({
    double? fontSize,
    double weight = 400,
    double? width,
    double? grade,
    double? opticalSize,
    bool tabular = true,
    bool slashedZero = false,
    double? height,
    double? letterSpacing,
  }) => TextStyle(
    fontFamily: family,
    fontFamilyFallback: scriptFallbackFonts,
    fontSize: fontSize,
    fontWeight: nearestFontWeight(weight),
    fontFeatures: features(tabular: tabular, slashedZero: slashedZero),
    fontVariations: isBundled
        ? variations(
            weight: weight,
            width: width,
            grade: grade,
            opticalSize: opticalSize,
            fontSize: fontSize,
          )
        : null,
    height: height,
    letterSpacing: letterSpacing,
  );
}

/// `tnum` only.
const List<FontFeature> tabularFigures = [FontFeature.tabularFigures()];
const List<FontFeature> _tabularZero = [
  FontFeature.tabularFigures(),
  FontFeature.slashedZero(),
];
const List<FontFeature> _zeroOnly = [FontFeature.slashedZero()];

/// The [FontWeight] closest to a CSS weight (clamped to 100–900).
FontWeight nearestFontWeight(double weight) {
  final index = ((weight.clamp(100, 900) - 100) / 100).round();
  return FontWeight.values[index];
}

/// Noto Sans Devanagari (variable `wght` 100–900, Devanagari-only subset;
/// assets/fonts/README.md): the bundled fallback that renders Hindi amount
/// words at the same size and weight as the Latin text around them, instead
/// of the platform's lighter Devanagari face. Not a theme font: it is only
/// ever a [scriptFallbackFonts] entry.
const String devanagariFontFamily = 'NotoSansDevanagari';

/// CalseeSymbols (m7-design D14; assets/fonts/README.md): the glyphs the
/// theme fonts lack, from Noto Sans, Noto Sans Mono and Noto Sans Thai,
/// variable in `wght` 100–900. It has every super- and subscript
/// (U+2070–209F, ¹ ² ³), ʸ ˣ, √ ∛ ∞ π µ μ and the Currency Symbols block
/// (₹ ₨ ₩ ₽ ₺ ₫ ₦ ₱ ₪ …) plus ฿, and nothing else: no digits, letters or
/// spaces. Not a theme font: it is a [scriptFallbackFonts] entry, and key
/// labels draw their super- and subscript runs in it ([symbolRunStyle]).
const String symbolsFontFamily = 'CalseeSymbols';

/// CalseeSymbols' `wght` axis (its only axis).
const FontAxisRange symbolsFontWeight = FontAxisRange('wght', 100, 400, 900);

/// `fontFamilyFallback` for every display, amount, history, settings and
/// key-label style: what the theme fonts lack (Devanagari, the scientific
/// symbols) resolves to bundled faces before the platform's. Weight
/// follows the style's `wght` variation / `fontWeight`.
const List<String> scriptFallbackFonts = [
  devanagariFontFamily,
  symbolsFontFamily,
];

/// Whether [rune] is a super- or subscript that labels draw in
/// CalseeSymbols as a run ([symbolRuns]): ² ³ ¹ (U+00B2, B3, B9), ʸ
/// (U+02B8), ˣ (U+02E3) and U+2070–209F. Fallback is chosen glyph by
/// glyph, so `sin⁻¹` would otherwise mix a fallback ⁻ with the family's
/// own ¹, and `x²` would not match a fallback `xʸ` beside it.
bool isSymbolRunRune(int rune) =>
    rune == 0x00B2 ||
    rune == 0x00B3 ||
    rune == 0x00B9 ||
    rune == 0x02B8 ||
    rune == 0x02E3 ||
    (rune >= 0x2070 && rune <= 0x209F);

/// [text] cut into its runs of [isSymbolRunRune] characters and the text
/// between them, in order: `sin` then `⁻¹` (symbols) for `sin⁻¹`. Empty
/// for an empty [text].
List<({String text, bool symbols})> symbolRuns(String text) {
  final runs = <({String text, bool symbols})>[];
  final run = StringBuffer();
  bool? current;
  for (final rune in text.runes) {
    final symbols = isSymbolRunRune(rune);
    if (current != null && symbols != current) {
      runs.add((text: run.toString(), symbols: current));
      run.clear();
    }
    current = symbols;
    run.writeCharCode(rune);
  }
  if (current != null) runs.add((text: run.toString(), symbols: current));
  return runs;
}

/// The style of a symbol run inside a span styled [style]: CalseeSymbols at
/// [style]'s weight (its `wght` variation, else its `fontWeight`); size,
/// colour and the rest are inherited from the span.
TextStyle symbolRunStyle(TextStyle style) {
  final weight =
      style.fontVariations
          ?.where((v) => v.axis == symbolsFontWeight.tag)
          .firstOrNull
          ?.value ??
      (style.fontWeight ?? FontWeight.w400).value.toDouble();
  return TextStyle(
    fontFamily: symbolsFontFamily,
    fontWeight: nearestFontWeight(weight),
    fontVariations: [symbolsFontWeight.variation(weight)],
  );
}

/// [style] with [scriptFallbackFonts] (kept when it already names some).
TextStyle withScriptFallback(TextStyle style) =>
    style.fontFamilyFallback == null
    ? style.copyWith(fontFamilyFallback: scriptFallbackFonts)
    : style;

/// Asset paths of the bundled fonts, keyed by pubspec family name.
/// Mirrors pubspec.yaml `fonts:`; test/helpers/load_fonts.dart uses it.
const Map<String, String> bundledFontAssets = {
  'RobotoFlex': 'assets/fonts/roboto_flex/RobotoFlex.ttf',
  'SpaceGrotesk': 'assets/fonts/space_grotesk/SpaceGrotesk.ttf',
  'Nunito': 'assets/fonts/nunito/Nunito.ttf',
  'OpenSans': 'assets/fonts/open_sans/OpenSans.ttf',
  'Newsreader': 'assets/fonts/newsreader/Newsreader.ttf',
  'Oxanium': 'assets/fonts/oxanium/Oxanium.ttf',
  'Anybody': 'assets/fonts/anybody/Anybody.ttf',
  'Jost': 'assets/fonts/jost/Jost.ttf',
  'PatrickHand': 'assets/fonts/patrick_hand/PatrickHand.ttf',
  devanagariFontFamily:
      'assets/fonts/NotoSansDevanagari/NotoSansDevanagari.ttf',
  symbolsFontFamily: 'assets/fonts/calsee_symbols/CalseeSymbols.ttf',
};

/// Licence files of the bundled fonts, keyed by pubspec family name.
const Map<String, String> bundledFontLicenses = {
  'RobotoFlex': 'assets/fonts/roboto_flex/OFL.txt',
  'SpaceGrotesk': 'assets/fonts/space_grotesk/OFL.txt',
  'Nunito': 'assets/fonts/nunito/OFL.txt',
  'OpenSans': 'assets/fonts/open_sans/OFL.txt',
  'Newsreader': 'assets/fonts/newsreader/OFL.txt',
  'Oxanium': 'assets/fonts/oxanium/OFL.txt',
  'Anybody': 'assets/fonts/anybody/OFL.txt',
  'Jost': 'assets/fonts/jost/OFL.txt',
  'PatrickHand': 'assets/fonts/patrick_hand/OFL.txt',
  devanagariFontFamily: 'assets/fonts/NotoSansDevanagari/OFL.txt',
  symbolsFontFamily: 'assets/fonts/calsee_symbols/OFL.txt',
};
