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

import 'package:calsee_themes/engine/theme_spec.dart';
import 'package:calsee_themes/render/fonts.dart';
import 'package:flutter/widgets.dart';

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
  const ChromeStyle({
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
