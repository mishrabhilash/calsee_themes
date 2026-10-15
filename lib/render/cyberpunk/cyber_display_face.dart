/// Cyberpunk's display ([DisplayFace]): a recessed black HUD screen — the
/// palette `surface` as an opaque chamfered plate (top-left and
/// bottom-right cut, like the keys) with faint static lighter scanlines
/// (`palette.shadow`, snapped to device pixels; none under the Accessible
/// lock), a soft neon glow (dark themes, full effects tier), a 1 dp neon
/// frame (behind a 2 dp rim of the panel's own black on Hazard, as on the
/// Hazard plates), a tick ruler hanging from the top frame line,
/// HUD corner brackets and a segmented status rule on the bottom frame
/// line. None of it carries data, and all of it stays in the 2–6 dp band
/// along the frame, clear of display text. The font (Oxanium) draws every
/// glyph at the theme's display weight on the `wght` axis, so layout,
/// fitting and semantics are exactly the font's.
///
/// The panel is static (no repaint listenable), matching "static
/// scanlines"; its paths are cached per plate rect.
library;

import 'dart:collection';
import 'dart:math' as math;

import 'package:calsee_themes/display_face.dart';
import 'package:calsee_themes/render/cyberpunk/cyber_geometry.dart';
import 'package:calsee_themes/render/fonts.dart';
import 'package:flutter/painting.dart';

/// The Cyberpunk HUD display panel.
final class CyberHudDisplayFace extends DisplayFace {
  const new({
    required this.panel,
    required this.scanInk,
    required this.edge,
    required this.bracket,
    this.chamfer = 0.18,
    this.glow = 0.6,
    this.weight = 500,
    this.slashedZero = false,
    this.hazard = false,
  });

  /// The screen colour (palette `surface`, opaque; a black on every
  /// variant).
  final Color panel;

  /// Scanline ink (palette `shadow`, translucent lighter rows; alpha 0 =
  /// none).
  final Color scanInk;

  /// Frame, glow, tick-ruler colour: the digit edge neon (cyan on Hazard).
  final Color edge;

  /// Corner bracket and status-rule colour: the operator neon (dark), the
  /// yellow digit label (Hazard).
  final Color bracket;

  /// Key chamfer fraction; the panel's chamfer follows it (8–16 dp).
  final double chamfer;

  /// Outer frame glow opacity (0 on Hazard and on the lite tier).
  final double glow;

  /// Display weight (CSS) for results; typing is 100 lighter, messages
  /// 100 heavier, Bold Text adds its steps on top.
  final int weight;

  /// Draw `0` with a slash.
  final bool slashedZero;

  /// The Hazard variant: the frame sits [hazardFrameInset] in, behind a
  /// black rim (the panel itself), like the Hazard plates' neon line.
  final bool hazard;

  /// The frame line's centre inset on dark themes, dp.
  static const double frameInset = 0.5;

  /// The frame line's centre inset on Hazard, dp: a 2 dp black rim, then
  /// the 1 dp line, both on whole device pixels at 1×, 2× and 3×.
  static const double hazardFrameInset = 2.5;

  /// The worst-case backdrop of display text: of the bare panel and the
  /// panel under its scanline ink, the one nearer the luminance where
  /// black and white text tie (the lighter of two dark backdrops, the
  /// darker of two light ones), so text that reaches its floor on it
  /// reaches it on both — also mid-way through a theme transition, where
  /// this is the only backdrop the text is solved against.
  @override
  Color get panelColor {
    final scanned = Color.alphaBlend(scanInk, panel);
    double tie(Color c) => (c.computeLuminance() - 0.1791287847477920).abs();
    return tie(scanned) <= tie(panel) ? scanned : panel;
  }

  @override
  EdgeInsets get panelMargin => const EdgeInsets.fromLTRB(12, 6, 12, 12);

  @override
  bool drawsChar(int codeUnit) => false;

  /// The display passes w300 (typing) / w400 (results) / w500 (messages),
  /// plus three steps under Bold Text; each maps onto [weight] shifted by
  /// the same amount, always on the `wght` axis (Oxanium's default
  /// instance is ExtraLight 200).
  @override
  TextStyle textStyle(TextStyle base) {
    final font = BundledFont.fromFamily(base.fontFamily);
    if (!font.isBundled) return base;
    final asked = (base.fontWeight ?? FontWeight.w400).value;
    final raw = (weight + asked - 400).toDouble();
    final w = font.weight?.clamp(raw) ?? raw.clamp(100, 900);
    return base.copyWith(
      fontWeight: nearestFontWeight(w),
      fontVariations: font.variations(weight: w, fontSize: base.fontSize),
      fontFeatures: font.features(slashedZero: slashedZero),
    );
  }

  /// The plate inside [rect] (a 2 dp border for the glow).
  Rect plateRect(Rect rect) => rect.deflate(2);

  /// The plate's chamfer leg for [plate], dp.
  double chamferFor(Rect plate) => math.min(
    (chamfer * 80).clamp(8.0, 16.0),
    math.max(0, plate.shortestSide * 0.3).toDouble(),
  );

  /// The panel geometry for [plate] with chamfer leg [cut] (cached).
  CyberPanelGeometry geometryFor(
    Rect plate,
    double cut, {
    double scanOffset = 0,
    double dpr = 1,
  }) => CyberPanelGeometry.cached(
    plate,
    cut,
    inset: hazard ? hazardFrameInset : frameInset,
    scanOffset: scanOffset,
    dpr: dpr,
  );

  @override
  void paintPanel(Canvas canvas, Rect rect) {
    if (rect.isEmpty || !rect.isFinite) return;
    final plate = plateRect(rect);
    if (plate.width <= 0 || plate.height <= 0) return;
    final cp = chamferFor(plate);
    // Scanlines snap to device pixels: the plate's top in device pixels
    // (through the canvas transform) fixes the phase of the 3 dp rows.
    final dpr = cyberDevicePixelRatio();
    final m = canvas.getTransform();
    final sy = m[5] == 0 ? 1.0 : m[5];
    final top = (m[13] + sy * plate.top) * dpr;
    final geo = geometryFor(
      plate,
      cp,
      scanOffset: top - top.floorToDouble(),
      dpr: dpr * sy.abs(),
    );
    canvas.drawPath(geo.shape, Paint()..color = panel);
    if (scanInk.a > 0) {
      canvas.drawPath(geo.scan, Paint()..color = scanInk);
    }
    // The neon frame's glow: a blurred stroke spilling a few dp onto the
    // body only (clipped outside the plate, so the backdrop under display
    // text stays the panel; the panel paints only on theme changes).
    final g = glow.clamp(0.0, 1.0);
    if (g > 0) {
      canvas
        ..save()
        ..clipPath(geo.outside)
        ..drawPath(
          geo.shape,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3)
            ..color = edge.withValues(alpha: edge.a * g),
        )
        ..restore();
    }
    canvas
      ..drawPath(
        geo.frame,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = edge,
      )
      ..drawPath(
        geo.ruler,
        Paint()..color = edge.withValues(alpha: edge.a * 0.55),
      )
      ..drawPath(
        geo.brackets,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..strokeJoin = StrokeJoin.miter
          ..color = bracket,
      )
      ..drawPath(geo.rule, Paint()..color = bracket);
  }

  @override
  void paintGlyphs(
    Canvas canvas,
    TextPainter painter,
    String text, {
    required Offset origin,
    required Color color,
    required double fontSize,
    int start = 0,
    int? end,
    double Function(int index)? opacity,
  }) {}

  @override
  DisplayFace lerpTo(DisplayFace other, double t) {
    if (other is! CyberHudDisplayFace) return t < 0.5 ? this : other;
    if (other == this) return this;
    final c = t.clamp(0.0, 1.0);
    final near = c < 0.5 ? this : other;
    return CyberHudDisplayFace(
      panel: Color.lerp(panel, other.panel, c)!,
      scanInk: Color.lerp(scanInk, other.scanInk, c)!,
      edge: Color.lerp(edge, other.edge, c)!,
      bracket: Color.lerp(bracket, other.bracket, c)!,
      chamfer: chamfer + (other.chamfer - chamfer) * c,
      glow: (glow + (other.glow - glow) * c).clamp(0.0, 1.0),
      weight: near.weight,
      slashedZero: near.slashedZero,
      hazard: near.hazard,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is CyberHudDisplayFace &&
      other.panel == panel &&
      other.scanInk == scanInk &&
      other.edge == edge &&
      other.bracket == bracket &&
      other.chamfer == chamfer &&
      other.glow == glow &&
      other.weight == weight &&
      other.slashedZero == slashedZero &&
      other.hazard == hazard;

  @override
  int get hashCode => Object.hash(
    CyberHudDisplayFace,
    panel,
    scanInk,
    edge,
    bracket,
    chamfer,
    glow,
    weight,
    slashedZero,
    hazard,
  );
}

/// The HUD panel's paths for one plate rect, chamfer, frame inset and
/// device-pixel phase, kept in a small static LRU (`CyberPanelGeometry.cached`).
final class CyberPanelGeometry {
  /// Builds the panel geometry of [plate].
  ///
  /// [scanOffset] is the fractional device-pixel position of the plate's
  /// top and [dpr] the device pixels per canvas unit: scanline rows land on
  /// whole device pixels (no beat at 2.625× or 2.75×).
  new build(
    Rect plate,
    double cut, {
    required double inset,
    double scanOffset = 0,
    double dpr = 1,
  }) {
    addCutOctagon(shape, plate, cut);
    outside
      ..fillType = PathFillType.evenOdd
      ..addRect(plate.inflate(14));
    addCutOctagon(outside, plate, cut);
    addInsetCutOctagon(frame, plate, cut, inset);
    // Scanlines: 1 dp rows every 3 dp, each snapped to device pixels and
    // clipped to the octagon analytically (rows crossing a chamfer are
    // shortened to it).
    final px = dpr > 0 && dpr.isFinite ? dpr : 1.0;
    final row = math.max(1, px.round()) / px;
    final k = math.max(0, math.min(cut, plate.shortestSide / 2)).toDouble();
    for (var y = 1.0; y < plate.height; y += 3) {
      final snapped = ((y * px + scanOffset).roundToDouble() - scanOffset) / px;
      final y0 = plate.top + snapped;
      final y1 = math.min(y0 + row, plate.bottom);
      if (y1 <= y0) continue;
      // The chamfers: top-left over the first k dp, bottom-right over the
      // last k dp (use the row's narrower end).
      final fromTop = y1 - plate.top;
      final fromBottom = plate.bottom - y0;
      final left = plate.left + math.max(0, k - fromTop + (y1 - y0));
      final right = plate.right - math.max(0, k - fromBottom + (y1 - y0));
      if (right > left) scan.addRect(Rect.fromLTRB(left, y0, right, y1));
    }
    final i = inset + 2.5;
    // HUD brackets at the square corners (top-right, bottom-left).
    final a = math.min(10, plate.shortestSide / 4).toDouble();
    if (a >= 3) {
      brackets
        ..moveTo(plate.right - i - a, plate.top + i)
        ..lineTo(plate.right - i, plate.top + i)
        ..lineTo(plate.right - i, plate.top + i + a)
        ..moveTo(plate.left + i, plate.bottom - i - a)
        ..lineTo(plate.left + i, plate.bottom - i)
        ..lineTo(plate.left + i + a, plate.bottom - i);
    }
    // Tick ruler: nine 1 × 3 dp ticks at an 8 dp pitch hanging from the
    // top frame line, after the chamfer, clear of the top-right bracket.
    final x0 = plate.left + cut + 12;
    if (x0 + 8 * 8 + 1 <= plate.right - i - a - 6 && plate.height >= 40) {
      final y = plate.top + inset;
      for (var n = 0; n < 9; n++) {
        ruler.addRect(Rect.fromLTWH(x0 + 8 * n, y, 1, 3));
      }
    }
    // Status rule: 2.5 dp thickenings centred on the bottom frame line
    // (no digits, no letters; clear of any text at every display height).
    const segments = [10.0, 3.0, 10.0, 3.0, 22.0, 3.0, 6.0];
    if (plate.width >= 18 + 57 + cut + 8) {
      final y = plate.bottom - inset;
      var x = plate.left + 18;
      for (var n = 0; n < segments.length; n++) {
        if (n.isEven) {
          rule.addRect(Rect.fromLTWH(x, y - 1.25, segments[n], 2.5));
        }
        x += segments[n];
      }
    }
  }

  /// The cached geometry (built on a miss).
  factory cached(
    Rect plate,
    double cut, {
    required double inset,
    double scanOffset = 0,
    double dpr = 1,
  }) {
    final key = (plate, cut, inset, (scanOffset * 64).round(), dpr);
    final hit = _cache.remove(key);
    if (hit != null) return _cache[key] = hit;
    builds++;
    final g = _cache[key] = CyberPanelGeometry.build(
      plate,
      cut,
      inset: inset,
      scanOffset: scanOffset,
      dpr: dpr,
    );
    while (_cache.length > capacity) {
      _cache.remove(_cache.keys.first);
    }
    return g;
  }

  /// The plate (fill).
  final Path shape = Path();

  /// Everything outside the plate (the glow's clip).
  final Path outside = Path();

  /// The frame line's centre path (stroke at 1 dp).
  final Path frame = Path();

  /// The scanline rows (fill).
  final Path scan = Path();

  /// The corner brackets (stroke at 1.5 dp).
  final Path brackets = Path();

  /// The tick ruler (fill).
  final Path ruler = Path();

  /// The status rule segments (fill).
  final Path rule = Path();

  /// Geometries built (tests).
  static int builds = 0;

  /// Geometries kept.
  static const int capacity = 4;

  static final LinkedHashMap<
    (Rect, double, double, int, double),
    CyberPanelGeometry
  >
  _cache = LinkedHashMap();
}
