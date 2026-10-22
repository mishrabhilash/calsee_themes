/// Retro's display ([DisplayFace]): a 7-segment LCD or VFD panel
/// (docs/m4-design.md §B; motion brief §2.3 "Retro hardware", §4.4).
///
/// - Digits, the decimal point / comma, minus and `E` are drawn with the
///   in-house [SegmentGlyphPainter], each over a faint ghost "8" (every
///   unlit segment in [LcdDisplayFace.ghost], ≤ 1.3:1 against the panel).
/// - Every other glyph (`×`, `÷`, brackets, function names, the letters of
///   error messages) uses the theme's bundled display font — Roboto Flex
///   condensed on its `wdth` axis, a mono-ish match for the segments.
/// - The panel: a rounded window in a darker bezel with a soft inner
///   shadow along its top edge; a VFD's lit segments also glow.
/// - Timing: segments on 30 ms / off 50 ms (linear), and a full clear
///   switches them off right to left, 15 ms per character.
library;

import 'dart:ui' as ui;

import 'package:calsee_themes/display_face.dart';
import 'package:calsee_themes/render/fonts.dart';
import 'package:calsee_themes/render/retro/seven_segment.dart';
import 'package:flutter/painting.dart';

/// The Retro LCD / VFD display face.
final class LcdDisplayFace extends DisplayFace {
  const LcdDisplayFace({
    required this.panel,
    required this.bezel,
    this.ghost,
    this.vfd = false,
    this.widthPermille = 800,
    this.segments = const SegmentGlyphPainter(),
  });

  /// The panel (palette `surface`).
  final Color panel;

  /// The frame around the panel.
  final Color bezel;

  /// Unlit segments; null draws none.
  final Color? ghost;

  /// Vacuum-fluorescent look: lit segments glow.
  final bool vfd;

  /// `wdth` axis of the fallback font × 10 (750 = 75 %).
  final int widthPermille;

  /// Segment geometry.
  final SegmentGlyphPainter segments;

  /// Segments on (motion brief §2.4 `segmentOn`).
  static const Duration segmentOn = Duration(milliseconds: 30);

  /// Segments off (motion brief §2.4 `segmentOff`).
  static const Duration segmentOff = Duration(milliseconds: 50);

  /// Long-press clear: per-character delay, right to left (§4.4).
  static const Duration clearStep = Duration(milliseconds: 15);

  @override
  Duration get glyphOn => segmentOn;

  @override
  Duration get glyphOff => segmentOff;

  @override
  Duration get clearStagger => clearStep;

  @override
  Color get panelColor => panel;

  @override
  EdgeInsets get panelMargin => const EdgeInsets.fromLTRB(12, 6, 12, 12);

  @override
  bool drawsChar(int codeUnit) => SevenSegment.draws(codeUnit);

  @override
  TextStyle textStyle(TextStyle base) {
    final font = BundledFont.fromFamily(base.fontFamily);
    if (!font.isBundled) return base;
    final weight = (base.fontWeight ?? FontWeight.w400).value.toDouble();
    return base.copyWith(
      fontVariations: font.variations(
        weight: weight,
        width: widthPermille / 10,
        fontSize: base.fontSize,
      ),
      fontFeatures: font.features(),
    );
  }

  @override
  void paintPanel(Canvas canvas, Rect rect) {
    if (rect.isEmpty) return;
    final radius = Radius.circular((rect.shortestSide * 0.08).clamp(4.0, 12.0));
    final window = RRect.fromRectAndRadius(rect, radius);
    canvas
      ..drawRRect(window.inflate(3), Paint()..color = bezel)
      ..drawRRect(window, Paint()..color = panel);
    // Inner shadow: the window sits below the bezel, lit from above.
    final depth = (rect.shortestSide * 0.03).clamp(2.0, 5.0);
    canvas
      ..save()
      ..clipRRect(window)
      ..drawRRect(
        window.shift(Offset(0, depth * 0.8)).inflate(depth * 1.5),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = depth * 3
          ..color = Color(vfd ? 0x8C000000 : 0x40000000)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, depth),
      )
      ..restore();
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
  }) {
    final stop = (end ?? text.length).clamp(0, text.length);
    if (start >= stop || fontSize <= 0) return;
    final baseline =
        origin.dy +
        painter.computeDistanceToActualBaseline(TextBaseline.alphabetic);
    final ghostColor = ghost;
    // Batch glyphs of equal opacity into one lit and one ghost path.
    var batchOpacity = -1.0;
    final lit = Path();
    final unlit = Path();
    void flush() {
      if (batchOpacity <= 0) {
        lit.reset();
        unlit.reset();
        return;
      }
      if (ghostColor != null && ghostColor.a > 0) {
        canvas.drawPath(
          unlit,
          Paint()
            ..color = ghostColor.withValues(alpha: ghostColor.a * batchOpacity),
        );
      }
      final c = color.withValues(alpha: color.a * batchOpacity);
      if (vfd) {
        canvas.drawPath(
          lit,
          Paint()
            ..color = c.withValues(alpha: c.a * 0.55)
            ..maskFilter = ui.MaskFilter.blur(
              BlurStyle.normal,
              segments.thicknessFor(fontSize * 0.7) * 0.9,
            ),
        );
      }
      canvas.drawPath(lit, Paint()..color = c);
      lit.reset();
      unlit.reset();
    }

    double caretX(int i) =>
        origin.dx +
        painter.getOffsetForCaret(TextPosition(offset: i), Rect.zero).dx;

    var x0 = caretX(start);
    for (var i = start; i < stop; i++) {
      final unit = text.codeUnitAt(i);
      final x1 = caretX(i + 1);
      final mask = SevenSegment.maskOfUnit(unit);
      final point = SevenSegment.isPoint(unit);
      if (mask != 0 || point) {
        final o = (opacity?.call(i) ?? 1).clamp(0.0, 1.0);
        if (o != batchOpacity) {
          flush();
          batchOpacity = o;
        }
        if (point) {
          segments.addPoint(
            lit,
            left: x0,
            right: x1,
            baseline: baseline,
            fontSize: fontSize,
            comma: unit == 0x2C,
          );
        } else {
          final r = segments.glyphRect(
            left: x0,
            right: x1,
            baseline: baseline,
            fontSize: fontSize,
          );
          segments
            ..addMask(lit, mask, r)
            ..addMask(unlit, SevenSegment.all & ~mask, r);
        }
      }
      x0 = x1;
    }
    flush();
  }

  @override
  DisplayFace lerpTo(DisplayFace other, double t) {
    if (other is! LcdDisplayFace) return t < 0.5 ? this : other;
    if (other == this) return this;
    final c = t.clamp(0.0, 1.0);
    final g = ghost == null && other.ghost == null
        ? null
        : Color.lerp(
            ghost ?? other.ghost!.withValues(alpha: 0),
            other.ghost ?? ghost!.withValues(alpha: 0),
            c,
          );
    return LcdDisplayFace(
      panel: Color.lerp(panel, other.panel, c)!,
      bezel: Color.lerp(bezel, other.bezel, c)!,
      ghost: g,
      vfd: c < 0.5 ? vfd : other.vfd,
      widthPermille: c < 0.5 ? widthPermille : other.widthPermille,
      segments: segments,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is LcdDisplayFace &&
      other.panel == panel &&
      other.bezel == bezel &&
      other.ghost == ghost &&
      other.vfd == vfd &&
      other.widthPermille == widthPermille &&
      other.segments == segments;

  @override
  int get hashCode => Object.hash(
    LcdDisplayFace,
    panel,
    bezel,
    ghost,
    vfd,
    widthPermille,
    segments,
  );
}
