/// Paper & ink's textures: the paper grain tile (flecks, fibres, chalk
/// dust) shared by the sheet, every key slip and the display card, and the
/// sheet's line tiles (ruled, graph, dot grid).
///
/// Each tile is built once with `toImageSync` and kept for the life of the
/// app (it is constant for the family: colour-independent, so it lerps
/// with the theme without rebuilds), outside the shared
/// `BackgroundCache` LRU, where a Glass ↔ Paper swipe would evict and
/// rebuild it mid-transition.
///
/// The grain is hash-seeded (never `Random`), and every primitive is drawn
/// with [BlendMode.src], so a texel holds only its last primitive: no
/// black texel is darker than 20 % and no white texel lighter than 14 %
/// (scaled by the sheet's grain strength at paint time) — the ceilings the
/// guardrail samples assume (`paperInkSceneSamples`).
library;

import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:calsee_themes/engine/paper_ink.dart'
    show paperFibreMaxPermille, paperFleckMaxPermille, paperInkGridMajorEvery;
import 'package:calsee_themes/engine/theme_spec.dart'
    show BackgroundPattern;
import 'package:calsee_themes/render/paper_ink/paper_key_art.dart'
    show paperUnit;
import 'package:flutter/painting.dart';

/// The shared textures.
abstract final class PaperTextures {
  /// Grain tile edge, dp.
  static const double grainTile = 160;

  /// Tiles are rasterised at this scale (sharp on 3× screens).
  static const double tileScale = 3;

  static ui.ImageShader? _grain;
  static final Map<(BackgroundPattern, int), ui.ImageShader> _lines = {};

  /// Tiles built so far (tests).
  static int builds = 0;

  /// The grain tile as a repeating shader (white and black primitives on
  /// transparent; modulate with the paint's alpha).
  static ui.ImageShader get grain => _grain ??= _buildGrain();

  /// The line tile of a ruled ([BackgroundPattern.stripes]), graph
  /// ([BackgroundPattern.grid]) or dot-grid ([BackgroundPattern.dots])
  /// sheet with pitch [pitchCdp] (dp × 100): white lines on transparent,
  /// recoloured with a `srcIn` colour filter at paint time. Grid minor
  /// lines are 0.625 of the major lines' alpha.
  static ui.ImageShader lines(BackgroundPattern layout, int pitchCdp) =>
      _lines[(layout, pitchCdp)] ??= _buildLines(layout, pitchCdp);

  static ui.ImageShader _tile(
    void Function(Canvas canvas) draw,
    double width,
    double height,
  ) {
    builds++;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)..scale(tileScale);
    draw(canvas);
    final pw = (width * tileScale).round().clamp(1, 2048);
    final ph = (height * tileScale).round().clamp(1, 2048);
    final image = recorder.endRecording().toImageSync(pw, ph);
    final matrix = Float64List.fromList([
      width / pw, 0, 0, 0, //
      0, height / ph, 0, 0, //
      0, 0, 1, 0, //
      0, 0, 0, 1, //
    ]);
    return ui.ImageShader(
      image,
      TileMode.repeated,
      TileMode.repeated,
      matrix,
      filterQuality: FilterQuality.low,
    );
  }

  static ui.ImageShader _buildGrain() =>
      _tile(_paintGrain, grainTile, grainTile);

  static void _paintGrain(Canvas canvas) {
    const seed = 0x5EED0B11;
    const t = grainTile;
    final paint = Paint()
      ..blendMode = BlendMode.src
      ..isAntiAlias = true;
    const black = paperFleckMaxPermille / 1000;
    const white = paperFibreMaxPermille / 1000;

    // Draws [draw] at its place and again across every tile edge it
    // reaches, so the tile repeats seamlessly.
    void wrapped(Offset c, double reach, void Function(Offset at) draw) {
      for (final dx in [-t, 0.0, t]) {
        for (final dy in [-t, 0.0, t]) {
          final at = c + Offset(dx, dy);
          if (at.dx + reach < 0 ||
              at.dx - reach > t ||
              at.dy + reach < 0 ||
              at.dy - reach > t) {
            continue;
          }
          draw(at);
        }
      }
    }

    var i = 0;
    double u() => paperUnit(seed, i++);

    // Flecks: dark specks of wood pulp.
    for (var n = 0; n < 700; n++) {
      final c = Offset(u() * t, u() * t);
      final r = 0.25 + 0.55 * u();
      paint
        ..style = PaintingStyle.fill
        ..color = Color.fromRGBO(0, 0, 0, black * (0.35 + 0.65 * u()));
      wrapped(c, r, (at) => canvas.drawCircle(at, r, paint));
    }
    // Chalk dust / light pulp: pale specks (they read on dark sheets).
    for (var n = 0; n < 320; n++) {
      final c = Offset(u() * t, u() * t);
      final r = 0.2 + 0.45 * u();
      paint
        ..style = PaintingStyle.fill
        ..color = Color.fromRGBO(255, 255, 255, white * (0.3 + 0.7 * u()));
      wrapped(c, r, (at) => canvas.drawCircle(at, r, paint));
    }
    // Fibres: short curved hairs, mostly light.
    for (var n = 0; n < 220; n++) {
      final c = Offset(u() * t, u() * t);
      final length = 2.5 + 6.5 * u();
      final angle = u() * math.pi;
      final bend = (u() - 0.5) * length * 0.5;
      final width = 0.35 + 0.35 * u();
      final light = u() < 0.6;
      final alpha = light
          ? white * (0.5 + 0.5 * u())
          : black * (0.25 + 0.35 * u());
      final d = Offset(math.cos(angle), math.sin(angle)) * (length / 2);
      final nrm = Offset(-d.dy, d.dx) / (length / 2) * bend;
      paint
        ..style = PaintingStyle.stroke
        ..strokeWidth = width
        ..strokeCap = StrokeCap.round
        ..color = light
            ? Color.fromRGBO(255, 255, 255, alpha)
            : Color.fromRGBO(0, 0, 0, alpha);
      wrapped(c, length / 2 + bend.abs() + width, (at) {
        final a = at - d;
        final b = at + d;
        final control = at + nrm;
        canvas.drawPath(
          Path()
            ..moveTo(a.dx, a.dy)
            ..quadraticBezierTo(control.dx, control.dy, b.dx, b.dy),
          paint,
        );
      });
    }
  }

  static ui.ImageShader _buildLines(BackgroundPattern layout, int pitchCdp) {
    final p = pitchCdp > 0 ? pitchCdp / 100 : 30.0;
    final paint = Paint()
      ..blendMode = BlendMode.src
      ..isAntiAlias = false;
    switch (layout) {
      case BackgroundPattern.grid:
        final size = p * paperInkGridMajorEvery;
        return _tile(
          (canvas) {
            // Minor lines (0.75 dp), then the major line (1 dp) on top.
            paint.color = const Color.fromRGBO(255, 255, 255, 0.625);
            for (var k = 1; k < paperInkGridMajorEvery; k++) {
              canvas
                ..drawRect(Rect.fromLTWH(0, k * p, size, 2 / 3), paint)
                ..drawRect(Rect.fromLTWH(k * p, 0, 2 / 3, size), paint);
            }
            paint.color = const Color(0xFFFFFFFF);
            canvas
              ..drawRect(Rect.fromLTWH(0, 0, size, 1), paint)
              ..drawRect(Rect.fromLTWH(0, 0, 1, size), paint);
          },
          size,
          size,
        );
      case BackgroundPattern.dots:
        return _tile(
          (canvas) {
            paint
              ..isAntiAlias = true
              ..color = const Color(0xFFFFFFFF);
            canvas.drawCircle(Offset(p / 2, p / 2), 0.9, paint);
          },
          p,
          p,
        );
      case _:
        // Ruled: one 1 dp line per pitch.
        return _tile(
          (canvas) {
            paint.color = const Color(0xFFFFFFFF);
            canvas.drawRect(Rect.fromLTWH(0, p - 1, p, 1), paint);
          },
          p,
          p,
        );
    }
  }
}
