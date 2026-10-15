/// Vaporwave's display ([DisplayFace]): a floating Windows-95 window. A
/// 1 dp ink frame, a raised two-tone bevel, a body in the "3D face" colour
/// the buttons share, a titleless gradient title bar with a mini striped
/// sun and minimise / maximise / close caption buttons (no ×: they do
/// nothing), and a sunken client panel (`Palette.surface`, opaque) that
/// holds every display glyph.
///
/// Anybody draws the digits and letters. The operators `+ − × ÷`
/// ([vaporwaveDisplayOperators]) are drawn by the face in Roboto Flex, as
/// on the keys: Anybody's are a third of its digit height and read as
/// broken text. Each is painted into the box the font laid out for it, so
/// layout, fitting, caret positions and semantics stay exactly the font's.
///
/// The window chrome is painted in the `panelMargin` band, outside the
/// client rect it is given (nothing between `Display`'s padding and the
/// panel painter clips). The margin leaves the scene showing around the
/// window, and a band below it where the sunset scene puts its horizon
/// and the striped bottom of the sun (`vaporwave_scene.dart` reads
/// `vaporwaveWindowBottomGap`, `vaporwaveMarginTop` and
/// `vaporwaveWindowTopInset`).
library;

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:calsee_themes/display_face.dart';
import 'package:calsee_themes/engine/oklab.dart';
import 'package:calsee_themes/render/fonts.dart';
import 'package:calsee_themes/render/vaporwave/vaporwave_bevel.dart';
import 'package:calsee_themes/render/vaporwave/vaporwave_key_face.dart';
import 'package:flutter/painting.dart';

/// Window frame thickness outside the client bevel: ink 1 + raised bevel
/// 2 + body 3 dp.
const double vaporwaveWindowFrame = 6;

/// The sunken client bevel, dp.
const double vaporwaveClientBevel = 2;

/// Title bar height and the gap below it, dp.
const double vaporwaveTitleBarHeight = 18;
const double vaporwaveTitleGap = 3;

/// The display's margin around the client panel: the window chrome plus a
/// little scene on the sides and top, and a taller band below for the
/// horizon and the sun.
const double vaporwaveMarginSide = 14;
const double vaporwaveMarginTop = 34;
const double vaporwaveMarginBottom = 40;
const EdgeInsets vaporwavePanelMargin = EdgeInsets.fromLTRB(
  vaporwaveMarginSide,
  vaporwaveMarginTop,
  vaporwaveMarginSide,
  vaporwaveMarginBottom,
);

/// How far the window's outer edge extends past the client rect on the
/// left, right and bottom.
const double vaporwaveWindowInset = vaporwaveWindowFrame + vaporwaveClientBevel;

/// How far it extends above the client rect (frame, title bar, gap,
/// client bevel).
const double vaporwaveWindowTopInset =
    vaporwaveWindowFrame +
    vaporwaveTitleBarHeight +
    vaporwaveTitleGap +
    vaporwaveClientBevel;

/// The scene between the window's bottom edge and the display's bottom
/// edge, dp.
const double vaporwaveWindowBottomGap =
    vaporwaveMarginBottom - vaporwaveWindowInset;

/// The display characters the window draws itself (in Roboto Flex): `+`,
/// `−` (U+2212, the formatter's minus), `×` and `÷`.
const Set<int> vaporwaveDisplayOperators = {0x2B, 0x2212, 0xD7, 0xF7};

/// The operators' ink centre in Roboto Flex, em above the baseline
/// (measured from the bundled RobotoFlex.ttf: 0.326–0.331 for all four at
/// every weight).
const double vaporwaveOperatorInkCentreEm = 0.329;

/// Where the operators are centred: the middle of Anybody's digits, em
/// above the baseline (its `8` spans −0.008–0.681 em).
const double vaporwaveOperatorCentreEm = 0.34;

/// How far an operator's ink may spill out of its (narrow, Anybody-sized)
/// box on each side, em: into a neighbouring space (Anybody's is 0.36 em
/// wide at 130 % width) or past the end of the text, or toward a digit
/// (less than Anybody's digit side bearings, 0.03–0.06 em). A wider glyph
/// is scaled down to fit.
const double vaporwaveOperatorSpillBySpaceEm = 0.25;
const double vaporwaveOperatorSpillByGlyphEm = 0.03;

/// Roboto Flex's operator ink spans this share of its advance (measured:
/// 0.84–0.87 for all four at every weight).
const double vaporwaveOperatorInkShare = 0.87;

/// How much heavier the operators are than the text around them (`wght`).
const double vaporwaveOperatorWeightBonus = 100;

/// Operator glyphs are laid out once at this size and scaled (dp).
const double vaporwaveOperatorGlyphSize = 48;

/// Operator glyphs kept laid out (four operators × the typing, result and
/// Bold Text weights × display and secondary colours, with room for the
/// colours of a theme change).
const int vaporwaveOperatorGlyphCacheSize = 48;

/// The Vaporwave display window.
final class VaporwaveDisplayFace extends DisplayFace {
  const new({
    required this.panel,
    required this.chrome,
    required this.ink,
    required this.titleStart,
    required this.titleEnd,
    required this.sunTop,
    required this.sunBottom,
    this.shadeDepth = 0.30,
    this.highlightMix = 0.85,
    this.weight = 450,
    this.widthPermille = 1250,
    this.slashedZero = false,
    this.gradients = true,
  });

  /// The client panel (palette `surface`): every display glyph sits on it.
  final Color panel;

  /// The window body and caption buttons (the digit key face).
  final Color chrome;

  /// The frame line.
  final Color ink;

  /// Title bar gradient start (palette `highlight`) and end (`accent`).
  final Color titleStart;
  final Color titleEnd;

  /// The mini sun's top and bottom halves.
  final Color sunTop;
  final Color sunBottom;

  /// Bevel shade depth and highlight mix (as the keys).
  final double shadeDepth;
  final double highlightMix;

  /// Display weight (CSS) for the result line; typing is 100 lighter,
  /// Bold Text adds its steps on top.
  final int weight;

  /// `wdth` axis × 10 (1000 = 100 %).
  final int widthPermille;

  /// Draw `0` with a slash.
  final bool slashedZero;

  /// Whether the title bar may use a gradient shader (off on the lite
  /// effects tier: a solid Windows-95 bar in [titleStart] instead).
  final bool gradients;

  @override
  Color get panelColor => panel;

  @override
  EdgeInsets get panelMargin => vaporwavePanelMargin;

  /// The operators ([vaporwaveDisplayOperators]); Anybody draws the rest.
  @override
  bool drawsChar(int codeUnit) => vaporwaveDisplayOperators.contains(codeUnit);

  /// The display passes w300 (typing) / w400 (results) / w500 (messages),
  /// plus three steps under Bold Text; each maps onto [weight] shifted by
  /// the same amount, always on the `wght` axis (Anybody's default
  /// instance is Thin).
  @override
  TextStyle textStyle(TextStyle base) {
    final font = BundledFont.fromFamily(base.fontFamily);
    if (!font.isBundled) return base;
    final asked = (base.fontWeight ?? FontWeight.w400).value;
    final w = (weight + asked - 400).clamp(100, 900).toDouble();
    return base.copyWith(
      fontWeight: nearestFontWeight(w),
      fontFamilyFallback: vaporwaveFontFallback,
      fontVariations: font.variations(
        weight: w,
        width: widthPermille / 10,
        fontSize: base.fontSize,
      ),
      fontFeatures: font.features(slashedZero: slashedZero),
    );
  }

  /// The window's outer rectangle around the client [rect].
  static Rect windowRect(Rect rect) => Rect.fromLTRB(
    rect.left - vaporwaveWindowInset,
    rect.top - vaporwaveWindowTopInset,
    rect.right + vaporwaveWindowInset,
    rect.bottom + vaporwaveWindowInset,
  );

  /// The title bar inside the window [w].
  static Rect titleBarRect(Rect w) => Rect.fromLTRB(
    w.left + vaporwaveWindowFrame,
    w.top + vaporwaveWindowFrame,
    w.right - vaporwaveWindowFrame,
    w.top + vaporwaveWindowFrame + vaporwaveTitleBarHeight,
  );

  /// A 1 dp two-tone band: [br] fills [rect], [tl] covers all but its
  /// bottom and right edges (Win95 joins).
  static void _band(Canvas canvas, Rect rect, Color tl, Color br, Paint p) {
    if (rect.width <= 1 || rect.height <= 1) return;
    canvas
      ..drawRect(rect, p..color = br)
      ..drawRect(
        Rect.fromLTRB(rect.left, rect.top, rect.right - 1, rect.bottom - 1),
        p..color = tl,
      );
  }

  static final Paint _paint = Paint();
  static final Paint _shaderPaint = Paint();

  /// The last title-bar gradient (the panel repaints with every display
  /// repaint: caret blink, entry and reveal animations).
  static (Rect, Color, Color, ui.Gradient)? _titleGradient;

  static ui.Gradient _titleShader(Rect tb, Color start, Color end) {
    final memo = _titleGradient;
    if (memo != null && memo.$1 == tb && memo.$2 == start && memo.$3 == end) {
      return memo.$4;
    }
    final shader = ui.Gradient.linear(
      tb.centerLeft,
      tb.centerRight,
      [start, titleMidpoint(start, end), end],
      const [0, 0.5, 1],
    );
    _titleGradient = (tb, start, end, shader);
    return shader;
  }

  /// The title bar's middle stop: the OKLCH average of [a] and [b] along
  /// the hue arc that avoids yellow-green (60–150°), so a warm → cool bar
  /// runs through lilac or violet (pink → lavender → cyan, coral → violet
  /// → aqua) instead of the grey or khaki an sRGB blend of two
  /// near-complementary neons passes through.
  static Color titleMidpoint(Color a, Color b) {
    final x = argbToOklch(a.toARGB32() | 0xFF000000);
    final y = argbToOklch(b.toARGB32() | 0xFF000000);
    var d = (y.h - x.h) % 360; // 0–360, counter-clockwise from x to y
    if (d > 180) d -= 360; // the shorter arc
    bool crossesYellowGreen(double from, double delta) {
      for (var t = 0.0; t <= 1; t += 0.05) {
        final h = (from + delta * t) % 360;
        if (h >= 60 && h <= 150) return true;
      }
      return false;
    }

    if (crossesYellowGreen(x.h, d)) d = d > 0 ? d - 360 : d + 360;
    final h = (x.h + d / 2) % 360;
    return Color(oklchToArgb((x.l + y.l) / 2, (x.c + y.c) / 2, h) | 0xFF000000);
  }

  @override
  void paintPanel(Canvas canvas, Rect rect) {
    if (rect.isEmpty) return;
    final p = _paint;
    final w = windowRect(rect);
    canvas.drawRect(w, p..color = ink);
    final tones = vaporBevelTones(chrome, shadeDepth, highlightMix);
    if (rect.width < 48 || rect.height < 16) {
      canvas.drawRect(rect, p..color = panel);
      return;
    }
    // Raised frame, body.
    _band(canvas, w.deflate(1), tones.hiOuter, tones.shadeOuter, p);
    _band(canvas, w.deflate(2), tones.hiInner, tones.shadeInner, p);
    canvas.drawRect(w.deflate(3), p..color = chrome);

    // Title bar: a Win98 gradient through [titleMidpoint], or (lite tier)
    // a solid Win95 bar.
    final tb = titleBarRect(w);
    if (gradients) {
      canvas.drawRect(
        tb,
        _shaderPaint..shader = _titleShader(tb, titleStart, titleEnd),
      );
      _shaderPaint.shader = null;
    } else {
      canvas.drawRect(tb, p..color = titleStart);
    }

    // Caption buttons, right to left: close (plain: no ×, nothing here
    // closes), maximise (a box with a 2 dp top) and minimise (a bar).
    const bw = 15.0;
    const bh = 13.0;
    final top = tb.top + (tb.height - bh) / 2;
    if (tb.width >= 120) {
      var right = tb.right - 3;
      for (var i = 0; i < 3; i++) {
        final b = Rect.fromLTWH(right - bw, top, bw, bh);
        _captionButton(canvas, b, tones, p);
        // Glyphs on whole dp, so their 1 dp strokes stay crisp.
        if (i == 1) {
          final box = Rect.fromLTWH(
            (b.left + 3).roundToDouble(),
            (b.top + 3).roundToDouble(),
            8,
            7,
          );
          canvas
            ..drawRect(Rect.fromLTWH(box.left, box.top, 8, 2), p..color = ink)
            ..drawRect(Rect.fromLTWH(box.left, box.top, 1, 7), p)
            ..drawRect(Rect.fromLTWH(box.right - 1, box.top, 1, 7), p)
            ..drawRect(Rect.fromLTWH(box.left, box.bottom - 1, 8, 1), p);
        } else if (i == 2) {
          canvas.drawRect(
            Rect.fromLTWH(
              (b.left + 4).roundToDouble(),
              (b.bottom - 5).roundToDouble(),
              6,
              2,
            ),
            p..color = ink,
          );
        }
        right = b.left - (i == 0 ? 2 : 0);
      }
    } else if (tb.width >= 48) {
      _captionButton(
        canvas,
        Rect.fromLTWH(tb.right - 3 - bw, top, bw, bh),
        tones,
        p,
      );
    }

    // The mini striped sun on a chrome tile at the left of the bar.
    if (tb.width >= 48) {
      final tile = Rect.fromLTWH(tb.left + 3, top, bh + 1, bh);
      _captionButton(canvas, tile, tones, p);
      final c = tile.center;
      const rad = 4.5;
      final sun = Rect.fromCircle(center: c, radius: rad);
      canvas
        ..drawArc(sun, math.pi, math.pi, true, p..color = sunTop)
        ..drawArc(sun, 0, math.pi, true, p..color = sunBottom)
        ..drawRect(
          Rect.fromLTWH(sun.left, c.dy + 1, sun.width, 0.9),
          p..color = chrome,
        )
        ..drawRect(
          Rect.fromLTWH(sun.left, c.dy + 2.9, sun.width, 1.1),
          p..color = chrome,
        );
    }

    // Sunken client bevel and the client panel.
    _band(canvas, rect.inflate(2), tones.shadeInner, tones.hiOuter, p);
    _band(canvas, rect.inflate(1), tones.shadeOuter, tones.hiInner, p);
    canvas.drawRect(rect, p..color = panel);
  }

  void _captionButton(Canvas canvas, Rect b, VaporBevelTones tones, Paint p) {
    _band(canvas, b, tones.hiOuter, ink, p);
    _band(canvas, b.deflate(1), chrome, tones.shadeInner, p);
    canvas.drawRect(b.deflate(2), p..color = chrome);
  }

  /// Paints the operators of `[start, end)` in Roboto Flex at the text's
  /// size, each centred in the box the font laid out for it and on the
  /// digits' mid-height, at the text's weight +
  /// [vaporwaveOperatorWeightBonus]; scaled down only where it would spill
  /// past its box into a digit ([vaporwaveOperatorSpillByGlyphEm]) rather
  /// than a space.
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
  }) {
    final stop = (end ?? text.length).clamp(0, text.length);
    if (start >= stop || fontSize <= 0 || color.a <= 0) return;
    double? baseline;
    double? wght;
    for (var i = start; i < stop; i++) {
      final unit = text.codeUnitAt(i);
      if (!vaporwaveDisplayOperators.contains(unit)) continue;
      final o = (opacity?.call(i) ?? 1).clamp(0.0, 1.0);
      if (o <= 0) continue;
      final boxes = painter.getBoxesForSelection(
        TextSelection(baseOffset: i, extentOffset: i + 1),
      );
      if (boxes.isEmpty) continue;
      final box = boxes.first;
      baseline ??=
          origin.dy +
          painter.computeDistanceToActualBaseline(TextBaseline.alphabetic);
      wght ??= (_weightOf(painter) + vaporwaveOperatorWeightBonus)
          .clamp(100, 900)
          .toDouble();
      // Laid out once at the reference size and scaled to fontSize, so the
      // display's shrink-to-fit animation reuses it.
      final glyph = _operatorGlyph(unit, wght, color);
      const ref = vaporwaveOperatorGlyphSize;
      final advance = glyph.width * fontSize / ref;
      if (advance <= 0) continue;
      // Room beside a space or the end of the text, little beside a glyph.
      double room(int j) =>
          (j < 0 || j >= text.length || _isSpace(text.codeUnitAt(j))
              ? vaporwaveOperatorSpillBySpaceEm
              : vaporwaveOperatorSpillByGlyphEm) *
          fontSize;
      final spill = math.min(room(i - 1), room(i + 1));
      final fit =
          (box.right - box.left + 2 * spill) /
          (vaporwaveOperatorInkShare * advance);
      final scale = (fit < 1 ? fit : 1.0) * fontSize / ref;
      // The ink centre in the glyph's own (reference-size) coordinates.
      final inkCentre =
          glyph.computeDistanceToActualBaseline(TextBaseline.alphabetic) -
          vaporwaveOperatorInkCentreEm * ref;
      canvas
        ..save()
        ..translate(
          origin.dx + (box.left + box.right) / 2 - glyph.width / 2 * scale,
          baseline - vaporwaveOperatorCentreEm * fontSize - inkCentre * scale,
        )
        ..scale(scale);
      if (o < 1) {
        canvas.saveLayer(
          Offset.zero & glyph.size,
          Paint()..color = Color.fromRGBO(0, 0, 0, o),
        );
      }
      glyph.paint(canvas, Offset.zero);
      if (o < 1) canvas.restore();
      canvas.restore();
    }
  }

  static bool _isSpace(int unit) =>
      unit == 0x20 || unit == 0xA0 || unit == 0x2009 || unit == 0x202F;

  /// The `wght` the font-drawn text around the operators uses (typing,
  /// result, Bold Text), from the laid-out style.
  double _weightOf(TextPainter painter) {
    final variations = painter.text?.style?.fontVariations;
    if (variations != null) {
      for (final v in variations) {
        if (v.axis == 'wght') return v.value;
      }
    }
    return weight.toDouble();
  }

  /// Operator glyphs laid out at [vaporwaveOperatorGlyphSize], by (code
  /// unit, weight, colour); the oldest is disposed past
  /// [vaporwaveOperatorGlyphCacheSize].
  static final Map<(int, double, int), TextPainter> _glyphs = {};

  static TextPainter _operatorGlyph(int unit, double wght, Color color) {
    const fontSize = vaporwaveOperatorGlyphSize;
    final key = (unit, wght, color.toARGB32());
    final hit = _glyphs.remove(key);
    if (hit != null) return _glyphs[key] = hit;
    const maths = BundledFont.robotoFlex;
    final glyph = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(unit),
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontFamily: maths.family,
          fontFamilyFallback: scriptFallbackFonts,
          fontWeight: nearestFontWeight(wght),
          fontVariations: maths.variations(
            weight: wght,
            width: 100,
            fontSize: fontSize,
          ),
          height: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    _glyphs[key] = glyph;
    while (_glyphs.length > vaporwaveOperatorGlyphCacheSize) {
      final oldest = _glyphs.keys.first;
      _glyphs.remove(oldest)!.dispose();
    }
    return glyph;
  }

  @override
  DisplayFace lerpTo(DisplayFace other, double t) {
    if (other is! VaporwaveDisplayFace) return t < 0.5 ? this : other;
    if (other == this) return this;
    final c = t.clamp(0.0, 1.0);
    Color color(Color a, Color b) => Color.lerp(a, b, c)!;
    double number(double a, double b) => a + (b - a) * c;
    final near = c < 0.5 ? this : other;
    return VaporwaveDisplayFace(
      panel: color(panel, other.panel),
      chrome: color(chrome, other.chrome),
      ink: color(ink, other.ink),
      titleStart: color(titleStart, other.titleStart),
      titleEnd: color(titleEnd, other.titleEnd),
      sunTop: color(sunTop, other.sunTop),
      sunBottom: color(sunBottom, other.sunBottom),
      shadeDepth: number(shadeDepth, other.shadeDepth).clamp(0, 1),
      highlightMix: number(highlightMix, other.highlightMix).clamp(0, 1),
      weight: near.weight,
      widthPermille: near.widthPermille,
      slashedZero: near.slashedZero,
      gradients: gradients && other.gradients,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is VaporwaveDisplayFace &&
      other.panel == panel &&
      other.chrome == chrome &&
      other.ink == ink &&
      other.titleStart == titleStart &&
      other.titleEnd == titleEnd &&
      other.sunTop == sunTop &&
      other.sunBottom == sunBottom &&
      other.shadeDepth == shadeDepth &&
      other.highlightMix == highlightMix &&
      other.weight == weight &&
      other.widthPermille == widthPermille &&
      other.slashedZero == slashedZero &&
      other.gradients == gradients;

  @override
  int get hashCode => Object.hash(
    VaporwaveDisplayFace,
    panel,
    chrome,
    ink,
    titleStart,
    titleEnd,
    sunTop,
    sunBottom,
    shadeDepth,
    highlightMix,
    weight,
    widthPermille,
    slashedZero,
    gradients,
  );
}
