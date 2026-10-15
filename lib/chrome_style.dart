/// Per-family Material chrome: the settings, history, dialogs and sheets
/// around the calculator take their family's type, shapes, edges and
/// surfaces, not just its colours.
///
/// Derived from the theme's family alone (plus the colours it already
/// resolved), never from new generator draws, so a theme's seed still
/// produces exactly the same keypad: [familyChrome] can change in any
/// release without an engine bump.
///
/// The Accessible lock and the plain theme get no chrome style
/// ([chromeStyleFor] returns null): their chrome stays stock Material 3.
library;

import 'dart:math' as math;

import 'package:calsee_themes/calc_theme_data.dart';
import 'package:calsee_themes/engine/theme_spec.dart';
import 'package:calsee_themes/render/fonts.dart';
import 'package:material_ui/material_ui.dart';

/// How container and control corners are cut.
enum ChromeCorner {
  /// Rounded corners (a stadium at [ChromeStyle.stadium]).
  round,

  /// Chamfered corners (Cyberpunk's cut panels).
  bevel,
}

/// The colour of a family's edges (borders, rules, hard shadows).
enum ChromeEdge {
  /// No border.
  none,

  /// A quiet hairline (`ColorScheme.outlineVariant`).
  outline,

  /// The theme's ink: the keys' outline colour, else the text colour.
  ink,

  /// The theme's focus-ring colour (its neon or chrome accent).
  accent,
}

/// One family's chrome recipe. Fonts come from the theme: headings, titles
/// and labels use its key font; body text uses [bodyFont] (null = the key
/// font too).
@immutable
final class ChromeStyle {
  /// Creates a recipe; the defaults are stock Material 3.
  const new({
    this.bodyFont,
    this.handFont,
    this.bodyWeight = 400,
    this.headingWeight = 500,
    this.headingWidth,
    this.headingCaps = false,
    this.headingTracking = 0,
    this.containerRadius = 28,
    this.controlRadius = stadium,
    this.corner = ChromeCorner.round,
    this.edge = ChromeEdge.none,
    this.edgeWidth = 0,
    this.offsetShadow = 0,
    this.elevation,
    this.flatSurfaces = false,
    this.accentSelection = false,
    this.underlineFields = false,
  });

  /// A radius that makes a stadium (fully round ends).
  static const double stadium = double.infinity;

  /// Body text (list subtitles, paragraphs); null = the theme's key font.
  final BundledFont? bodyFont;

  /// Screen and dialog titles (display and headline text) in this font at
  /// its one weight (Paper & ink's handwriting); null = the heading font.
  /// Never list, value or number text.
  final BundledFont? handFont;

  /// CSS weight of body text.
  final double bodyWeight;

  /// CSS weight of display, headline and title text (labels are 100
  /// lighter, never under 500).
  final double headingWeight;

  /// `wdth` of heading text, for fonts that have the axis.
  final double? headingWidth;

  /// Section headers in capitals (with [headingTracking]).
  final bool headingCaps;

  /// Letter spacing of capitalised section headers, in logical pixels.
  final double headingTracking;

  /// Corner radius (or chamfer) of dialogs, sheets, cards and panels.
  final double containerRadius;

  /// Corner radius (or chamfer) of chips, buttons and fields.
  final double controlRadius;

  /// Rounded or chamfered corners.
  final ChromeCorner corner;

  /// Edge colour of containers and controls.
  final ChromeEdge edge;

  /// Edge width in logical pixels (0 with [ChromeEdge.none]).
  final double edgeWidth;

  /// A hard, unblurred shadow this far down and to the end in the edge
  /// colour (Neo-brutalism, NeoPOP); 0 = none.
  final double offsetShadow;

  /// Elevation of dialogs, sheets and cards; null = Material's.
  final double? elevation;

  /// Dialogs, sheets and cards on the calculator background (edged, with
  /// no elevation or tint), not on Material's tonal containers.
  final bool flatSurfaces;

  /// Selected chips, switches and filled buttons take the `=` key's fill
  /// and label (already checked for contrast) instead of tonal colours.
  final bool accentSelection;

  /// Text fields drawn as a rule underneath (Paper & ink's ledger line).
  final bool underlineFields;
}

/// The chrome recipe of every enabled family. Families missing here
/// (plain, the disabled placeholders) get stock Material 3.
const Map<ThemeFamily, ChromeStyle> familyChrome = {
  ThemeFamily.m3Expressive: ChromeStyle(headingWeight: 600, headingWidth: 110),
  ThemeFamily.liquidGlass: ChromeStyle(
    containerRadius: 32,
    edge: ChromeEdge.outline,
    edgeWidth: 1,
    elevation: 2,
  ),
  ThemeFamily.neoPop: ChromeStyle(
    bodyFont: BundledFont.spaceGrotesk,
    headingWeight: 700,
    headingCaps: true,
    headingTracking: 1.2,
    containerRadius: 0,
    controlRadius: 0,
    edge: ChromeEdge.ink,
    edgeWidth: 1.5,
    offsetShadow: 3,
    flatSurfaces: true,
    accentSelection: true,
  ),
  ThemeFamily.neumorphism: ChromeStyle(
    headingWeight: 600,
    containerRadius: 24,
    controlRadius: 16,
    elevation: 8,
  ),
  ThemeFamily.retro: ChromeStyle(
    bodyFont: BundledFont.robotoFlex,
    headingWeight: 700,
    headingCaps: true,
    headingTracking: 1.5,
    containerRadius: 6,
    controlRadius: 4,
    edge: ChromeEdge.ink,
    edgeWidth: 2,
    flatSurfaces: true,
    accentSelection: true,
  ),
  ThemeFamily.neoBrutalism: ChromeStyle(
    bodyWeight: 500,
    headingWeight: 800,
    containerRadius: 8,
    controlRadius: 6,
    edge: ChromeEdge.ink,
    edgeWidth: 2.5,
    offsetShadow: 4,
    flatSurfaces: true,
    accentSelection: true,
  ),
  ThemeFamily.claymorphism: ChromeStyle(
    bodyFont: BundledFont.nunito,
    bodyWeight: 500,
    headingWeight: 800,
    containerRadius: 36,
    elevation: 10,
  ),
  ThemeFamily.y2kChrome: ChromeStyle(
    bodyFont: BundledFont.openSans,
    headingWeight: 600,
    containerRadius: 14,
    edge: ChromeEdge.outline,
    edgeWidth: 1,
  ),
  ThemeFamily.paperInk: ChromeStyle(
    bodyFont: BundledFont.newsreader,
    handFont: BundledFont.patrickHand,
    headingWeight: 600,
    containerRadius: 2,
    controlRadius: 3,
    edge: ChromeEdge.ink,
    edgeWidth: 1.25,
    flatSurfaces: true,
    accentSelection: true,
    underlineFields: true,
  ),
  ThemeFamily.cyberpunk: ChromeStyle(
    bodyFont: BundledFont.robotoFlex,
    headingWeight: 700,
    headingCaps: true,
    headingTracking: 2,
    containerRadius: 14,
    controlRadius: 7,
    corner: ChromeCorner.bevel,
    edge: ChromeEdge.accent,
    edgeWidth: 1.5,
    flatSurfaces: true,
    accentSelection: true,
  ),
  ThemeFamily.vaporwave: ChromeStyle(
    bodyFont: BundledFont.robotoFlex,
    headingWeight: 800,
    headingWidth: 125,
    headingCaps: true,
    headingTracking: 1,
    containerRadius: 4,
    controlRadius: 4,
    edge: ChromeEdge.accent,
    edgeWidth: 1.5,
    offsetShadow: 3,
    flatSurfaces: true,
    accentSelection: true,
  ),
  ThemeFamily.bauhaus: ChromeStyle(
    bodyFont: BundledFont.jost,
    headingWeight: 600,
    headingCaps: true,
    headingTracking: 2.5,
    containerRadius: 0,
    edge: ChromeEdge.ink,
    edgeWidth: 2,
    flatSurfaces: true,
    accentSelection: true,
  ),
};

/// The chrome recipe of [spec]: its family's, or null (stock Material 3)
/// for the plain theme and under the Accessible lock.
ChromeStyle? chromeStyleFor(ThemeSpec spec) =>
    spec.accessible ? null : familyChrome[spec.family];

/// [base] (the theme's colour scheme on stock Material 3) restyled by
/// [style]: text in the theme's fonts, and dialogs, sheets, cards, menus,
/// chips, buttons, switches, fields, dividers and the app bar in its
/// shapes, edges and surfaces. Also registers the resolved [ChromeTheme].
ThemeData applyChrome(ThemeData base, CalcThemeData calc, ChromeStyle style) {
  final scheme = base.colorScheme;
  final keyFont = BundledFont.fromFamily(calc.keyFontFamily);
  final heading = keyFont.isBundled ? keyFont : BundledFont.robotoFlex;
  // Sizes are merged in by Theme.of (the localised geometry), so component
  // themes leave their text styles to the defaults, which read this.
  final text = _chromeText(base.textTheme, heading, style);

  final ink = calc.digitKey.outline ?? scheme.onSurface;
  final edgeColor = switch (style.edge) {
    ChromeEdge.none || ChromeEdge.ink => ink,
    ChromeEdge.outline => scheme.outlineVariant,
    ChromeEdge.accent => calc.focusRing,
  };
  final edged = style.edge != ChromeEdge.none && style.edgeWidth > 0;
  final edgeSide = edged
      ? BorderSide(color: edgeColor, width: style.edgeWidth)
      : BorderSide.none;
  final chrome = ChromeTheme(
    style: style,
    edgeSide: edgeSide,
    edgeColor: edgeColor,
  );

  final flat = style.flatSurfaces;
  final surface = flat ? calc.background : null;
  final tint = flat ? Colors.transparent : null;
  final elevation = flat ? 0.0 : style.elevation;
  final accent = style.accentSelection;
  final equals = calc.equalsKey;
  bool selected(Set<WidgetState> s) => s.contains(WidgetState.selected);
  bool disabled(Set<WidgetState> s) => s.contains(WidgetState.disabled);

  final fieldRadius = BorderRadius.circular(
    style.controlRadius == ChromeStyle.stadium ? 28 : style.controlRadius,
  );
  final fieldBorder = style.underlineFields
      ? const UnderlineInputBorder()
      : OutlineInputBorder(borderRadius: fieldRadius);

  return base.copyWith(
    textTheme: text,
    extensions: [chrome],
    appBarTheme: AppBarThemeData(
      // Screen titles in the hand font: an explicit style needs its size
      // (M3 titleLarge, 22), since component styles are not merged with
      // the localised geometry.
      titleTextStyle: style.handFont == null
          ? null
          : text.headlineSmall?.copyWith(
              fontSize: 22,
              height: 28 / 22,
              color: scheme.onSurface,
            ),
      backgroundColor: calc.background,
      surfaceTintColor: tint,
      scrolledUnderElevation: flat ? 0 : null,
      shape: edged ? Border(bottom: edgeSide) : null,
    ),
    dialogTheme: DialogThemeData(
      shape: chrome.container(),
      backgroundColor: surface,
      surfaceTintColor: tint,
      elevation: elevation,
    ),
    bottomSheetTheme: BottomSheetThemeData(
      shape: chrome.container(bottom: false, shadow: false),
      backgroundColor: surface,
      modalBackgroundColor: surface,
      surfaceTintColor: tint,
      elevation: elevation,
      modalElevation: elevation,
    ),
    cardTheme: CardThemeData(
      shape: chrome.container(),
      color: surface,
      surfaceTintColor: tint,
      elevation: elevation,
    ),
    popupMenuTheme: PopupMenuThemeData(
      shape: chrome.container(),
      color: surface,
      surfaceTintColor: tint,
      elevation: elevation,
    ),
    chipTheme: ChipThemeData(
      shape: chrome.control(),
      side: edged ? edgeSide : null,
      backgroundColor: surface,
      selectedColor: accent ? equals.fill : null,
      checkmarkColor: accent ? equals.label : null,
      labelStyle: accent
          ? text.labelLarge?.copyWith(
              color: WidgetStateColor.resolveWith(
                (s) => selected(s) ? equals.label : scheme.onSurface,
              ),
            )
          : null,
    ),
    switchTheme: SwitchThemeData(
      trackOutlineColor: edged
          ? WidgetStateProperty.resolveWith(
              (s) => disabled(s) ? null : edgeColor,
            )
          : null,
      trackOutlineWidth: edged
          ? WidgetStatePropertyAll(style.edgeWidth.clamp(1, 2))
          : null,
      trackColor: accent
          ? WidgetStateProperty.resolveWith(
              (s) => disabled(s)
                  ? null
                  : selected(s)
                  ? equals.fill
                  : calc.background,
            )
          : null,
      thumbColor: accent
          ? WidgetStateProperty.resolveWith(
              (s) => disabled(s)
                  ? null
                  : selected(s)
                  ? equals.label
                  : edged
                  ? edgeColor
                  : scheme.outline,
            )
          : null,
    ),
    textButtonTheme: TextButtonThemeData(
      style: ButtonStyle(
        shape: WidgetStatePropertyAll(
          chrome.control(edged: false, shadow: false),
        ),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: ButtonStyle(
        shape: WidgetStatePropertyAll(chrome.control()),
        backgroundColor: accent
            ? WidgetStateProperty.resolveWith(
                (s) => disabled(s) ? null : equals.fill,
              )
            : null,
        foregroundColor: accent
            ? WidgetStateProperty.resolveWith(
                (s) => disabled(s) ? null : equals.label,
              )
            : null,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: ButtonStyle(
        shape: WidgetStatePropertyAll(chrome.control(shadow: false)),
        side: edged ? WidgetStatePropertyAll(edgeSide) : null,
      ),
    ),
    inputDecorationTheme: InputDecorationThemeData(
      border: fieldBorder,
      enabledBorder: edged ? fieldBorder.copyWith(borderSide: edgeSide) : null,
    ),
    dividerTheme: DividerThemeData(
      color: edged ? edgeColor.withValues(alpha: 0.35) : null,
    ),
  );
}

/// [base] in the chrome's fonts: display, headline, title and label styles
/// in [heading] (labels a step lighter), body styles in the style's body
/// font. Every style sets the `wght` axis (variable fonts ignore
/// `fontWeight`) and keeps the Devanagari fallback.
TextTheme _chromeText(TextTheme base, BundledFont heading, ChromeStyle s) {
  final body = s.bodyFont ?? heading;
  final labelWeight = math.max(500, s.headingWeight - 100).toDouble();
  TextStyle? restyle(
    TextStyle? style,
    BundledFont font,
    double weight, {
    double? width,
  }) => style?.copyWith(
    fontFamily: font.family,
    fontFamilyFallback: scriptFallbackFonts,
    fontWeight: nearestFontWeight(weight),
    fontFeatures: font.features(),
    fontVariations: font.variations(weight: weight, width: width),
  );
  final hand = s.handFont;
  TextStyle? head(TextStyle? style) =>
      restyle(style, heading, s.headingWeight, width: s.headingWidth);
  // Display and headline text (dialog and screen titles): the hand font
  // when there is one. Title styles also show numbers and section headers,
  // and a hand at 14 px reads thin, so they stay in the heading font.
  TextStyle? title(TextStyle? style) =>
      hand == null ? head(style) : restyle(style, hand, 400);
  TextStyle? label(TextStyle? style) =>
      restyle(style, heading, labelWeight, width: s.headingWidth);
  TextStyle? text(TextStyle? style) => restyle(style, body, s.bodyWeight);
  return base.copyWith(
    displayLarge: title(base.displayLarge),
    displayMedium: title(base.displayMedium),
    displaySmall: title(base.displaySmall),
    headlineLarge: title(base.headlineLarge),
    headlineMedium: title(base.headlineMedium),
    headlineSmall: title(base.headlineSmall),
    titleLarge: head(base.titleLarge),
    titleMedium: head(base.titleMedium),
    titleSmall: head(base.titleSmall),
    labelLarge: label(base.labelLarge),
    labelMedium: label(base.labelMedium),
    labelSmall: label(base.labelSmall),
    bodyLarge: text(base.bodyLarge),
    bodyMedium: text(base.bodyMedium),
    bodySmall: text(base.bodySmall),
  );
}

/// A [ChromeStyle] resolved against one theme's colours and fonts, for the
/// few widgets that draw their own containers or headers (the history
/// panel, section headers). Read it with [ChromeTheme.of].
@immutable
final class ChromeTheme extends ThemeExtension<ChromeTheme> {
  /// Creates a resolved chrome.
  const new({
    required this.style,
    required this.edgeSide,
    required this.edgeColor,
  });

  /// The recipe.
  final ChromeStyle style;

  /// Border of containers and controls ([BorderSide.none] without edges).
  final BorderSide edgeSide;

  /// The edge colour (also the hard shadow's).
  final Color edgeColor;

  /// The chrome of [context]'s theme, or null for stock Material 3.
  static ChromeTheme? of(BuildContext context) =>
      Theme.of(context).extension<ChromeTheme>();

  /// A container shape (dialog, sheet, card, panel) with [style]'s corners,
  /// only on the [top] and/or [bottom] corners when either is false, with
  /// the edge and, when [shadow], the hard offset shadow.
  OutlinedBorder container({
    bool top = true,
    bool bottom = true,
    bool shadow = true,
  }) => _shape(style.containerRadius, top: top, bottom: bottom, shadow: shadow);

  /// A control shape (chip, button, field) with the edge and shadow.
  OutlinedBorder control({bool edged = true, bool shadow = true}) =>
      _shape(style.controlRadius, edged: edged, shadow: shadow);

  /// [text] as a section header shows it (capitals in some families).
  String headerText(String text) =>
      style.headingCaps ? text.toUpperCase() : text;

  /// [base] as a section header's style (tracked when capitalised).
  TextStyle? headerStyle(TextStyle? base) => style.headingCaps
      ? base?.copyWith(letterSpacing: style.headingTracking)
      : base;

  OutlinedBorder _shape(
    double radius, {
    bool top = true,
    bool bottom = true,
    bool edged = true,
    bool shadow = true,
  }) {
    final side = edged ? edgeSide : BorderSide.none;
    final OutlinedBorder base;
    if (radius == ChromeStyle.stadium && top && bottom) {
      base = StadiumBorder(side: side);
    } else {
      final r = Radius.circular(radius == ChromeStyle.stadium ? 28 : radius);
      final corners = BorderRadius.vertical(
        top: top ? r : Radius.zero,
        bottom: bottom ? r : Radius.zero,
      );
      base = switch (style.corner) {
        ChromeCorner.round => RoundedRectangleBorder(
          borderRadius: corners,
          side: side,
        ),
        ChromeCorner.bevel => BeveledRectangleBorder(
          borderRadius: corners,
          side: side,
        ),
      };
    }
    if (!shadow || style.offsetShadow <= 0) return base;
    return OffsetShadowBorder(
      inner: base,
      offset: style.offsetShadow,
      color: edgeColor,
    );
  }

  @override
  ChromeTheme copyWith({
    ChromeStyle? style,
    BorderSide? edgeSide,
    Color? edgeColor,
  }) => ChromeTheme(
    style: style ?? this.style,
    edgeSide: edgeSide ?? this.edgeSide,
    edgeColor: edgeColor ?? this.edgeColor,
  );

  @override
  ChromeTheme lerp(ChromeTheme? other, double t) {
    if (other == null) return this;
    return ChromeTheme(
      style: t < 0.5 ? style : other.style,
      edgeSide: BorderSide.lerp(edgeSide, other.edgeSide, t),
      edgeColor: Color.lerp(edgeColor, other.edgeColor, t)!,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ChromeTheme &&
      other.style == style &&
      other.edgeSide == edgeSide &&
      other.edgeColor == edgeColor;

  @override
  int get hashCode => Object.hash(style, edgeSide, edgeColor);
}

/// [inner] with a hard, unblurred shadow [offset] down and to the right in
/// [color] (Neo-brutalism's and NeoPOP's stacked slabs). The shadow is
/// painted only outside [inner], so it never covers the content; it falls
/// outside the widget's bounds, so the surface must not clip.
@immutable
final class OffsetShadowBorder extends OutlinedBorder {
  /// Wraps [inner].
  const new({required this.inner, required this.offset, required this.color});

  /// The visible shape and edge.
  final OutlinedBorder inner;

  /// Shadow offset in logical pixels (both axes).
  final double offset;

  /// Shadow colour.
  final Color color;

  @override
  BorderSide get side => inner.side;

  @override
  EdgeInsetsGeometry get dimensions => inner.dimensions;

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) =>
      inner.getInnerPath(rect, textDirection: textDirection);

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) =>
      inner.getOuterPath(rect, textDirection: textDirection);

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    final outer = inner.getOuterPath(rect, textDirection: textDirection);
    canvas.drawPath(
      Path.combine(
        PathOperation.difference,
        outer.shift(Offset(offset, offset)),
        outer,
      ),
      Paint()..color = color,
    );
    inner.paint(canvas, rect, textDirection: textDirection);
  }

  @override
  OffsetShadowBorder copyWith({BorderSide? side}) => OffsetShadowBorder(
    inner: inner.copyWith(side: side),
    offset: offset,
    color: color,
  );

  @override
  ShapeBorder scale(double t) => switch (inner.scale(t)) {
    final OutlinedBorder scaled => OffsetShadowBorder(
      inner: scaled,
      offset: offset * t,
      color: color,
    ),
    final other => other,
  };

  @override
  ShapeBorder? lerpFrom(ShapeBorder? a, double t) {
    if (a is OffsetShadowBorder) {
      final shape = ShapeBorder.lerp(a.inner, inner, t);
      if (shape is OutlinedBorder) {
        return OffsetShadowBorder(
          inner: shape,
          offset: a.offset + (offset - a.offset) * t,
          color: Color.lerp(a.color, color, t)!,
        );
      }
    }
    return super.lerpFrom(a, t);
  }

  @override
  ShapeBorder? lerpTo(ShapeBorder? b, double t) {
    if (b is OffsetShadowBorder) return b.lerpFrom(this, t);
    return super.lerpTo(b, t);
  }

  @override
  bool operator ==(Object other) =>
      other is OffsetShadowBorder &&
      other.inner == inner &&
      other.offset == offset &&
      other.color == color;

  @override
  int get hashCode => Object.hash(inner, offset, color);
}
