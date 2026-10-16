/// Bauhaus background scene (`BackgroundKind.bauhausComposition`): a flat
/// poster ground, the grid variant's ink field behind the keypad, a small
/// masthead of primitives in the toolbar and, where the screen has margins
/// beside the calculator column (tablets, desktop), a poster composition
/// in them.
///
/// `BackgroundSpec.colors` (always 6 for generated themes):
///
/// | index | meaning |
/// |---|---|
/// | 0 | ground (= `palette.background`) |
/// | 1 | keypad field (= ground when the variant has none) |
/// | 2 | disc colour (blue) |
/// | 3 | square colour (red) |
/// | 4 | triangle colour (yellow; cream on ochre) |
/// | 5 | rule ink (bars, quarter-disc): ink on light grounds, cream on dark |
///
/// `angleTenths` ∈ {0, 900, 1800, 2700} is the orientation
/// `o = ((angle + 450) ~/ 900) % 4` (so lerped angles snap): bit 0 mirrors
/// left ↔ right, bit 1 flips vertically.
///
/// **Text calm.** The text-safe area `S` (toolbar + display column) is the
/// ground everywhere except the masthead, which sits in the toolbar's free
/// middle: a band from 60 dp to `width − 104` dp across the column, 8 dp
/// below its top and 8 dp above the display. The history button's slot
/// ends 52 dp in and the lock badge's and settings button's begin 96 dp
/// from the right, so the band keeps 8 dp from every icon; no text or
/// theme chip is ever there. Side-panel layouts have no history button
/// (history is the panel), so there the band starts 12 dp in, on the line
/// the display sheet's rule starts on. The toolbar's mode button sits at
/// the start of that middle (after the history button, or first beside a
/// side panel): the band starts 8 dp after the scene's toolbar exclusion
/// (`BackgroundScene.toolbarExclusion`, m7-design §6), and the masthead is
/// dropped when that leaves under [BauhausSceneGeometry.minMastheadWidth]
/// (the app then shows the button's icon form where that keeps it). The
/// keypad region `K` is the field colour only. So every key, label, focus
/// ring, toolbar control and the display only ever sit on `colors[0]` /
/// `colors[1]` — exactly the guardrails' background samples
/// (`bauhausSceneSamples`).
///
/// **Margins** (tablets, desktop): two poster columns beside the
/// calculator, locked to its grid — the keypad field's top edge is the
/// structural line: margin A's bar continues it from the column, crossing
/// the diameter of a half-disc centred on the column edge; margin B's
/// vertical bar drops from near the top onto it, through a square. A
/// triangle and a quarter-disc anchor the far ends; on narrow margins
/// (< 90 dp) the triangle and square grow 1.4× so they still read.
///
/// Static (driftPeriodMs 0): nothing animates, Reduce Motion is moot.
/// Geometry is cached per (size, text-safe area, exclusion, orientation)
/// in a small static LRU (rectangles plus two triangle paths); colours are
/// applied per paint, so a same-family transition reuses it. The cache
/// holds only paths and rectangles (no GPU resources), so it is
/// deliberately not tied to `BackgroundCache.clear()`; it is bounded by
/// [BauhausSceneGeometry.capacity]. At most 14 draws, one `save`/`clipRect`
/// per margin, no `saveLayer`, shader or picture.
library;

import 'dart:collection';
import 'dart:math' as math;

import 'package:calsee_themes/render/background_painter.dart';
import 'package:flutter/widgets.dart';

/// Paints the Bauhaus scene for [scene] over the whole canvas.
void paintBauhausScene(Canvas canvas, Size size, BackgroundScene scene) {
  if (size.isEmpty || !size.isFinite) return;
  final colors = scene.spec.colors;
  if (colors.length < 6) {
    scene.paintFallback(canvas, size);
    return;
  }
  final g = BauhausSceneGeometry.of(
    size,
    scene.textSafeArea,
    bauhausOrientation(scene.spec.angleTenths),
    exclusion: scene.toolbarExclusion,
  );
  final paint = _paint;
  Color c(int i) => Color(colors[i] | 0xFF000000);
  canvas.drawRect(Offset.zero & size, paint..color = c(0));
  final field = g.field;
  if (field != null && colors[1] != colors[0]) {
    canvas.drawRect(field, paint..color = c(1));
  }
  final masthead = g.masthead;
  if (masthead != null) {
    canvas
      ..drawRect(masthead.bar, paint..color = c(5))
      ..drawRect(masthead.square, paint..color = c(3))
      ..drawPath(masthead.triangle, paint..color = c(4))
      ..drawOval(masthead.disc, paint..color = c(2));
  }
  final a = g.marginA;
  if (a != null) {
    canvas
      ..save()
      ..clipRect(a.clip)
      ..drawOval(a.halfDisc, paint..color = c(2))
      ..drawPath(a.triangle, paint..color = c(4))
      ..drawRect(a.bar, paint..color = c(5))
      ..restore();
  }
  final b = g.marginB;
  if (b != null) {
    canvas
      ..save()
      ..clipRect(b.clip)
      ..drawOval(b.quarterDisc, paint..color = c(5))
      ..drawRect(b.square, paint..color = c(3))
      ..drawRect(b.bar, paint..color = c(5))
      ..restore();
  }
}

final Paint _paint = Paint()..isAntiAlias = true;

/// The scene orientation of [angleTenths]: 0–3, snapping lerped angles.
int bauhausOrientation(int angleTenths) => ((angleTenths + 450) % 3600) ~/ 900;

/// The toolbar masthead: a rule and a square, triangle and disc.
final class BauhausMasthead {
  const new({
    required this.bounds,
    required this.bar,
    required this.square,
    required this.triangle,
    required this.disc,
  });

  /// The band the masthead keeps inside.
  final Rect bounds;

  /// The 6 dp rule.
  final Rect bar;

  /// The red square.
  final Rect square;

  /// The triangle (points down when flipped).
  final Path triangle;

  /// The blue disc's box.
  final Rect disc;
}

/// The left-hand poster margin's figures (before mirroring).
final class BauhausMarginA {
  const new({
    required this.clip,
    required this.halfDisc,
    required this.triangle,
    required this.bar,
  });

  /// The margin; every figure is clipped to it.
  final Rect clip;

  /// A disc centred on the column edge (clipped into a half-disc).
  final Rect halfDisc;

  /// An isosceles triangle.
  final Path triangle;

  /// A full-width bar.
  final Rect bar;
}

/// The right-hand poster margin's figures (before mirroring).
final class BauhausMarginB {
  const new({
    required this.clip,
    required this.quarterDisc,
    required this.square,
    required this.bar,
  });

  /// The margin; every figure is clipped to it.
  final Rect clip;

  /// A disc centred on the outer bottom corner (a quarter-disc).
  final Rect quarterDisc;

  /// A square.
  final Rect square;

  /// A vertical bar.
  final Rect bar;
}

/// Where everything in the scene goes for one size, text-safe area,
/// toolbar exclusion and orientation (cached).
final class BauhausSceneGeometry {
  new _({this.field, this.masthead, this.marginA, this.marginB});

  /// The geometry for a canvas of [size], the text-safe area [safe] and
  /// orientation [o] (see [bauhausOrientation]), with the masthead clear
  /// of the toolbar chrome [exclusion] (see [mastheadBand]), from the
  /// cache.
  factory of(Size size, Rect? safe, int o, {Rect? exclusion}) {
    final key = (size, safe, exclusion, o);
    final hit = _cache.remove(key);
    if (hit != null) return _cache[key] = hit;
    final made = _cache[key] = BauhausSceneGeometry._build(
      size,
      safe,
      o,
      exclusion,
    );
    while (_cache.length > capacity) {
      _cache.remove(_cache.keys.first);
    }
    return made;
  }

  factory _build(Size size, Rect? safe, int o, Rect? exclusion) {
    final canvas = Offset.zero & size;
    if (safe == null || !safe.isFinite) return BauhausSceneGeometry._();
    final s = safe.intersect(canvas);
    if (s.width <= 0 || s.height <= 0) return BauhausSceneGeometry._();
    final w = size.width;
    final h = size.height;
    final mirror = o & 1 == 1;
    final flip = o & 2 == 2;
    // Portrait / side panel: the keypad is below the column; landscape:
    // to its right (ScreenLayout).
    final portrait = s.height < 0.75 * h;
    final keypad = portrait
        ? Rect.fromLTRB(s.left, s.bottom, s.right, h)
        : Rect.fromLTRB(s.right, s.top, w, h);
    final field = keypad.width > 0 && keypad.height > 0 ? keypad : null;
    // Side-panel layouts (ScreenLayout): the column is centred in the
    // width left of the 320 dp history panel, so the right margin is the
    // left one plus 320; elsewhere both margins match (insets aside).
    final sidePanel = portrait && (w - s.right) - s.left > sidePanelAsymmetry;
    return BauhausSceneGeometry._(
      field: field,
      masthead: _masthead(
        s,
        sidePanel: sidePanel,
        exclusion: exclusion,
        mirror: mirror,
        flip: flip,
      ),
      marginA: portrait ? _marginA(s, size, mirror: mirror, flip: flip) : null,
      marginB: portrait ? _marginB(s, size, mirror: mirror, flip: flip) : null,
    );
  }

  static final LinkedHashMap<(Size, Rect?, Rect?, int), BauhausSceneGeometry>
  _cache = LinkedHashMap();

  /// Geometries kept.
  static const int capacity = 6;

  /// Clears the cache (tests).
  @visibleForTesting
  static void clearCache() => _cache.clear();

  /// Height of the toolbar band at the top of the text-safe area.
  static const double toolbarHeight = 48;

  /// Smallest margin (dp) that gets a poster composition.
  static const double minMargin = 32;

  /// Narrowest toolbar band (dp) that gets a masthead.
  static const double minMastheadWidth = 120;

  /// Where the masthead band starts beside the history button, and where
  /// it ends before the lock badge and settings button, dp from the
  /// column's edges (the icons' 52 / 96 dp slots plus 8 dp).
  static const double mastheadStart = 60;
  static const double mastheadEnd = 104;

  /// Where the band starts when there is no history button (side-panel
  /// layouts): the display sheet's rule line.
  static const double mastheadStartNoHistory = 12;

  /// Room between the toolbar exclusion (the mode button) and the band.
  static const double exclusionGap = 8;

  /// How much wider the right margin is than the left one in a side-panel
  /// layout (the 320 dp panel), at least: insets alone never reach it.
  static const double sidePanelAsymmetry = 160;

  /// Narrow margins (dp) get a larger triangle and square.
  static const double narrowMargin = 90;

  /// The triangle's and square's scale on narrow margins.
  static const double narrowMarginScale = 1.4;

  /// Clearance between the calculator column and a margin, dp (focus rings
  /// reach at most 5 dp outside a key).
  static const double columnGuard = 8;

  /// The keypad region (the field colour only), or null without a
  /// text-safe area.
  final Rect? field;

  /// The toolbar masthead, or null when the band is too narrow.
  final BauhausMasthead? masthead;

  /// The two poster margins, or null when the screen has none.
  final BauhausMarginA? marginA;
  final BauhausMarginB? marginB;

  /// The band the masthead may use in the toolbar row of the text-safe
  /// area [s]: from [mastheadStart] (beside a side panel,
  /// [mastheadStartNoHistory]) to [mastheadEnd] from the right, 8 dp
  /// below the top and above the display, starting [exclusionGap] after
  /// [exclusion] when that reaches into it (the mode button, which sits at
  /// the start of the toolbar's free middle). Its width may be under
  /// [minMastheadWidth], or negative: then there is no masthead. The app
  /// asks this too, to choose the mode button's form.
  static Rect mastheadBand(Rect s, {required bool sidePanel, Rect? exclusion}) {
    var left = s.left + (sidePanel ? mastheadStartNoHistory : mastheadStart);
    final right = s.right - mastheadEnd;
    if (exclusion != null &&
        exclusion.top < s.top + toolbarHeight &&
        exclusion.bottom > s.top &&
        exclusion.left < right &&
        exclusion.right + exclusionGap > left) {
      left = exclusion.right + exclusionGap;
    }
    return Rect.fromLTRB(left, s.top + 8, right, s.top + 40);
  }

  /// The masthead in the toolbar band's free middle: three primitives
  /// clustered at one end, a rule running from them to the other.
  static BauhausMasthead? _masthead(
    Rect s, {
    required bool sidePanel,
    required Rect? exclusion,
    required bool mirror,
    required bool flip,
  }) {
    if (s.height < toolbarHeight) return null;
    final band = mastheadBand(s, sidePanel: sidePanel, exclusion: exclusion);
    if (band.width < minMastheadWidth) return null;
    const unit = 24.0;
    const gap = 6.0;
    const rule = 6.0;
    final cy = band.center.dy;
    // Left to right before mirroring: square, triangle, disc, rule.
    double x(double fromStart, double width) =>
        mirror ? band.right - fromStart - width : band.left + fromStart;
    final square = Rect.fromLTWH(x(0, unit), cy - unit / 2, unit, unit);
    const tw = unit + 4;
    final th = tw * math.sqrt(3) / 2;
    final tx = x(unit + gap, tw);
    final triangle = Path();
    if (flip) {
      triangle
        ..moveTo(tx, cy - th / 2)
        ..lineTo(tx + tw, cy - th / 2)
        ..lineTo(tx + tw / 2, cy + th / 2);
    } else {
      triangle
        ..moveTo(tx + tw / 2, cy - th / 2)
        ..lineTo(tx + tw, cy + th / 2)
        ..lineTo(tx, cy + th / 2);
    }
    triangle.close();
    const discD = unit + 2;
    final disc = Rect.fromLTWH(
      x(unit + gap + tw + gap, discD),
      cy - discD / 2,
      discD,
      discD,
    );
    const used = unit + gap + tw + gap + discD + gap + 4;
    final barLength = band.width - used;
    final bar = barLength >= 12
        ? Rect.fromLTWH(x(used, barLength), cy - rule / 2, barLength, rule)
        : Rect.zero;
    return BauhausMasthead(
      bounds: band,
      bar: bar,
      square: square,
      triangle: triangle,
      disc: disc,
    );
  }

  /// Margin width beside the column (0 when there is none).
  static double _margin(Rect s) => s.left - columnGuard;

  /// The margins' structural line: the keypad field's top edge (the
  /// text-safe area's bottom), kept within the middle half of the margin
  /// height.
  static double _structuralLine(Rect s, Size size) {
    final hgt = size.height - s.top;
    return s.bottom.clamp(s.top + 0.25 * hgt, s.top + 0.75 * hgt);
  }

  /// The half-disc / triangle / bar margin.
  static BauhausMarginA? _marginA(
    Rect s,
    Size size, {
    required bool mirror,
    required bool flip,
  }) {
    final m = _margin(s);
    if (m < minMargin) return null;
    final hgt = size.height - s.top;
    if (hgt <= 0) return null;
    // On the left by default: the column edge is its right side.
    final left = !mirror;
    final clip = left
        ? Rect.fromLTRB(0, s.top, m, size.height)
        : Rect.fromLTRB(
            s.right + columnGuard,
            s.top,
            s.right + columnGuard + m,
            size.height,
          );
    final inner = left ? clip.right : clip.left;
    final sign = left ? -1.0 : 1.0;
    double x(double p) => inner + sign * p * m;
    // The structural line: the keypad field's top edge.
    final line = _structuralLine(s, size);
    final r = math.min(0.90 * m, 0.20 * hgt);
    // A disc centred on the column edge and the line (a half-disc in the
    // margin), the bar continuing the field's top edge across its
    // diameter.
    final halfDisc = Rect.fromCircle(center: Offset(x(0), line), radius: r);
    final barH = (0.014 * hgt).clamp(8.0, 14.0);
    final bar = Rect.fromCenter(
      center: Offset(clip.center.dx, line),
      width: clip.width,
      height: barH,
    );
    // The triangle below the half-disc (above it when flipped), apex away
    // from the far edge.
    final k = m < narrowMargin ? narrowMarginScale : 1.0;
    final base = 0.60 * m * k;
    final height = 0.52 * m * k;
    final gap = r + 0.12 * hgt;
    // Kept whole inside the margin (pulled towards the half-disc when the
    // margin is short).
    final edge = 0.04 * hgt;
    final baseY = flip
        ? math.max(line - gap - height, s.top + edge)
        : math.min(line + gap + height, size.height - edge);
    final apexY = flip ? baseY + height : baseY - height;
    final cx = x(0.50);
    final triangle = Path()
      ..moveTo(cx, apexY)
      ..lineTo(cx + base / 2, baseY)
      ..lineTo(cx - base / 2, baseY)
      ..close();
    return BauhausMarginA(
      clip: clip,
      halfDisc: halfDisc,
      triangle: triangle,
      bar: bar,
    );
  }

  /// The quarter-disc / square / bar margin.
  static BauhausMarginB? _marginB(
    Rect s,
    Size size, {
    required bool mirror,
    required bool flip,
  }) {
    final m = _margin(s);
    if (m < minMargin) return null;
    final hgt = size.height - s.top;
    if (hgt <= 0) return null;
    // On the right by default: the column edge is its left side.
    final right = !mirror;
    final clip = right
        ? Rect.fromLTRB(
            s.right + columnGuard,
            s.top,
            s.right + columnGuard + m,
            size.height,
          )
        : Rect.fromLTRB(0, s.top, m, size.height);
    final inner = right ? clip.left : clip.right;
    final sign = right ? 1.0 : -1.0;
    double x(double p) => inner + sign * p * m;
    double y(double f) => s.top + (flip ? 1 - f : f) * hgt;
    final r = math.min(m, 0.28 * hgt);
    final quarterDisc = Rect.fromCircle(center: Offset(x(1), y(1)), radius: r);
    final k = m < narrowMargin ? narrowMarginScale : 1.0;
    final side = 0.50 * m * k;
    final square = Rect.fromCenter(
      center: Offset(x(0.40), y(0.20)),
      width: side,
      height: side,
    );
    // The vertical bar runs through the square, a quarter of its side
    // from the centre (an overlap, never a near miss), from near the far
    // edge onto the structural line.
    final barW = (0.06 * m).clamp(6.0, 12.0);
    final barX = x(0.40) + sign * side / 4;
    final bar = Rect.fromPoints(
      Offset(barX - barW / 2, y(0.08)),
      Offset(barX + barW / 2, _structuralLine(s, size)),
    );
    return BauhausMarginB(
      clip: clip,
      quarterDisc: quarterDisc,
      square: square,
      bar: bar,
    );
  }
}
