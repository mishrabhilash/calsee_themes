/// The mesh-gradient background (`BackgroundKind.meshGradient`; Liquid
/// Glass's "vivid animated background", spec §5.3 #2): the base colour
/// plus a soft radial blob per further colour, laid out by the spec's
/// angle and drifting on its period (motion brief §4.13, ≥ 40 s).
///
/// Cheap: each blob is one cached unit radial shader (colour →
/// transparent) drawn as a rect moved and scaled with the canvas, so a
/// drift frame is one rect fill plus one rect per blob and allocates no
/// shader. Blobs blend in encoded sRGB, so every painted colour lies in
/// the colour hull the guardrails sample (`meshHullSamples`).
library;

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:calsee_themes/engine/theme_spec.dart';
import 'package:flutter/painting.dart';

/// One blob: centre and radius in logical pixels.
typedef MeshBlob = ({Offset center, double radius});

/// Blob anchors in the unit square (before the spec's rotation) and
/// radii as a fraction of the longest side.
const List<(double, double, double)> meshAnchors = [
  (0.10, 0.16, 0.62),
  (0.94, 0.48, 0.56),
  (0.26, 0.96, 0.66),
  (0.78, 0.04, 0.50),
];

/// The blob geometry of [spec] on [size] at drift time [seconds].
List<MeshBlob> meshBlobs(BackgroundSpec spec, Size size, double seconds) {
  final count = math.max(0, spec.colors.length - 1);
  final period = spec.driftPeriodMs / 1000;
  final phi = period > 0 ? 2 * math.pi * seconds / period : 0.0;
  final angle = spec.angleTenths / 10 * math.pi / 180;
  final cosA = math.cos(angle);
  final sinA = math.sin(angle);
  final longest = math.max(size.width, size.height);
  return [
    for (var i = 0; i < count; i++)
      () {
        final (ax, ay, r) = meshAnchors[i % meshAnchors.length];
        final x = ax - 0.5;
        final y = ay - 0.5;
        final dx = 0.09 * math.sin(phi + i * 2.09);
        final dy = 0.07 * math.sin(2 * phi + i * 1.3);
        final rx = 0.5 + x * cosA - y * sinA + dx;
        final ry = 0.5 + x * sinA + y * cosA + dy;
        return (
          center: Offset(rx * size.width, ry * size.height),
          radius: r * longest,
        );
      }(),
  ];
}

/// The unit radial shader of one blob colour (colour → transparent).
ui.Shader meshBlobShader(Color color) => ui.Gradient.radial(
  Offset.zero,
  1,
  [color, color.withValues(alpha: color.a * 0.72), color.withValues(alpha: 0)],
  const [0, 0.38, 1],
);

/// Paints [spec]'s mesh on [canvas] at drift time [seconds]; [shaderFor]
/// returns the (cached) unit shader of a blob colour.
void paintMesh(
  Canvas canvas,
  Size size,
  BackgroundSpec spec,
  double seconds, {
  required ui.Shader Function(int argb) shaderFor,
}) {
  final rect = Offset.zero & size;
  final colors = spec.colors;
  canvas.drawRect(
    rect,
    Paint()..color = Color(colors.isEmpty ? 0xFF000000 : colors.first),
  );
  if (colors.length < 2) return;
  final blobs = meshBlobs(spec, size, seconds);
  final paint = Paint();
  canvas
    ..save()
    ..clipRect(rect);
  for (var i = 0; i < blobs.length; i++) {
    final blob = blobs[i];
    paint.shader = shaderFor(colors[i + 1] | 0xFF000000);
    canvas
      ..save()
      ..translate(blob.center.dx, blob.center.dy)
      ..scale(blob.radius)
      ..drawRect(const Rect.fromLTRB(-1, -1, 1, 1), paint)
      ..restore();
  }
  canvas.restore();
}
