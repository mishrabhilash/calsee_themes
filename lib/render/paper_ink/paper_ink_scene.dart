/// Paper & ink background scene (`BackgroundKind.paperSheet`): a sheet of
/// stationery that never moves.
///
/// `BackgroundSpec` fields (paper_ink.dart): `colors` = `[paper, rule
/// ink]`; `pattern` = the layout (none = plain, stripes = ruled, grid =
/// graph, dots = dot grid); `patternScaleCdp` = the pitch;
/// `patternOpacityPermille` = the line alpha (a grid's minor lines; its
/// majors are 1.6 × that, ≤ 45 %); `angleTenths` = the grain strength
/// (‰).
///
/// Layers: the paper, the shared grain tile (paint alpha = grain), then
/// the line tile recoloured with the rule ink — drawn only outside the
/// display's `textSafeArea`, so nothing but paper and grain sits behind
/// the display. The lines fade out toward it — over [paperSideFade] dp
/// beside it and [paperBelowFade] dp below it (the shared painter's
/// pattern fade), elliptically round its lower corners — so a desktop
/// sheet never ends in a hard cut beside the display column. Up to three
/// plain rects plus up to five small faded ones (each its own saveLayer,
/// masked `dstIn` by a gradient); tiles are built once per (layout,
/// pitch) and kept for the app's life (paper_grain.dart), so a Paper →
/// Paper morph that lerps the colours rebuilds nothing. Malformed specs
/// (one colour, a pattern the family never makes) get the plain fallback
/// gradient.
library;

import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:calsee_themes/engine/paper_ink.dart'
    show paperGrainOf, paperMajorCapPermille;
import 'package:calsee_themes/engine/theme_spec.dart';
import 'package:calsee_themes/render/background_painter.dart';
import 'package:calsee_themes/render/paper_ink/paper_grain.dart';
import 'package:flutter/widgets.dart';

final Paint _paper = Paint();
final Paint _grain = Paint();
final Paint _lines = Paint();
final Paint _layer = Paint();
final Paint _mask = Paint()..blendMode = BlendMode.dstIn;

/// How far the lines fade out beside the text-safe area, dp.
const double paperSideFade = 32;

/// How far the lines fade out below the text-safe area, dp.
const double paperBelowFade = BackgroundPainter.safeFade;

const List<Color> _out = [Color(0xFFFFFFFF), Color(0x00FFFFFF)];
const List<Color> _in = [Color(0x00FFFFFF), Color(0xFFFFFFFF)];

/// The alpha the line tile is drawn with for [spec] (before
/// `patternFade`): the line alpha for ruled and dot sheets; for a grid
/// 1.6 × the minor alpha (≤ 45 %), its minor lines being 0.625 of that.
double paperLineAlpha(BackgroundSpec spec) {
  final o = spec.patternOpacityPermille.clamp(0, 1000) / 1000;
  return switch (spec.pattern) {
    BackgroundPattern.grid => math.min(paperMajorCapPermille / 1000, 1.6 * o),
    _ => o,
  };
}

/// Paints the Paper & ink scene for [scene] over the whole canvas.
void paintPaperInkScene(Canvas canvas, Size size, BackgroundScene scene) {
  if (size.isEmpty || !size.isFinite) return;
  final spec = scene.spec;
  final layout = spec.pattern;
  final known =
      layout == BackgroundPattern.none ||
      layout == BackgroundPattern.stripes ||
      layout == BackgroundPattern.grid ||
      layout == BackgroundPattern.dots;
  if (spec.colors.length < 2 || !known) {
    scene.paintFallback(canvas, size);
    return;
  }
  final full = Offset.zero & size;
  canvas.drawRect(full, _paper..color = Color(spec.colors[0] | 0xFF000000));

  final g = paperGrainOf(spec) / 1000;
  if (g > 0) {
    _grain
      ..shader = PaperTextures.grain
      ..color = Color.fromRGBO(0, 0, 0, g);
    canvas.drawRect(full, _grain);
  }

  if (layout == BackgroundPattern.none) return;
  final alpha = paperLineAlpha(spec) * scene.patternFade;
  if (alpha <= 0) return;
  _lines
    ..shader = PaperTextures.lines(layout, spec.patternScaleCdp)
    ..colorFilter = ColorFilter.mode(
      Color(spec.colors[1] | 0xFF000000),
      BlendMode.srcIn,
    )
    ..color = Color.fromRGBO(0, 0, 0, alpha.clamp(0.0, 1.0));
  final safe = scene.textSafeArea?.intersect(full);
  if (safe == null || safe.isEmpty || safe.width <= 0 || safe.height <= 0) {
    canvas.drawRect(full, _lines);
    return;
  }
  final (l, r, b) = (safe.left, safe.right, safe.bottom);
  const side = paperSideFade;
  const below = paperBelowFade;
  // Clear of the fades: below them, then beside them.
  for (final rect in [
    Rect.fromLTRB(0, b + below, size.width, size.height),
    Rect.fromLTRB(0, 0, l - side, b + below),
    Rect.fromLTRB(r + side, 0, size.width, b + below),
  ]) {
    final clipped = rect.intersect(full);
    if (clipped.width > 0 && clipped.height > 0) {
      canvas.drawRect(clipped, _lines);
    }
  }
  // The fades: left and right of the area, below it, and its two lower
  // corners (an elliptical ramp that meets both neighbours).
  void fade(Rect band, Shader Function() mask) {
    final rect = band.intersect(full);
    if (rect.width <= 0 || rect.height <= 0) return;
    canvas
      ..saveLayer(rect, _layer)
      ..drawRect(rect, _lines)
      ..drawRect(rect, _mask..shader = mask())
      ..restore();
  }

  Shader corner(Offset c) => ui.Gradient.radial(
    Offset.zero,
    1,
    _in,
    null,
    TileMode.clamp,
    Float64List.fromList([
      side, 0, 0, 0, //
      0, below, 0, 0, //
      0, 0, 1, 0, //
      c.dx, c.dy, 0, 1,
    ]),
  );

  fade(
    Rect.fromLTRB(l - side, 0, l, b),
    () => ui.Gradient.linear(Offset(l - side, 0), Offset(l, 0), _out),
  );
  fade(
    Rect.fromLTRB(r, 0, r + side, b),
    () => ui.Gradient.linear(Offset(r, 0), Offset(r + side, 0), _in),
  );
  fade(
    Rect.fromLTRB(l, b, r, b + below),
    () => ui.Gradient.linear(Offset(0, b), Offset(0, b + below), _in),
  );
  fade(Rect.fromLTRB(l - side, b, l, b + below), () => corner(Offset(l, b)));
  fade(Rect.fromLTRB(r, b, r + side, b + below), () => corner(Offset(r, b)));
}
