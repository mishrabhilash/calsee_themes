/// Liquid Glass's display backing (spec §5.3 #2: "glass is for the
/// controls; keep the display readable with a solid-enough backing").
///
/// The display text keeps the theme font (this face draws no glyphs); the
/// panel is the palette `surface` — dense glass — over the live
/// background, with the same frost underlay as the keys and a light-
/// catching rim that never crosses the text. Display text is solved by the
/// engine on the surface composited over every background hull sample
/// (`displayBackdrops`), so `panelColor` (what in-app per-frame repair
/// measures against) is the solid tint: the surface over the base colour.
/// Reduce Transparency paints exactly that opaque tint.
library;

import 'package:calsee_themes/display_face.dart';
import 'package:calsee_themes/render/glass/glass_rendering.dart';
import 'package:flutter/widgets.dart';

/// The glass display backing for one theme.
@immutable
final class GlassDisplayFace extends DisplayFace {
  const new({
    required this.panel,
    required this.solid,
    required this.frostColor,
    required this.rim,
    this.frost = 0.15,
    this.rendering = GlassRendering.standard,
  });

  /// The translucent panel glass (`Palette.surface`).
  final Color panel;

  /// The panel composited over the background's base colour (opaque).
  final Color solid;

  /// The frost underlay (the background's base colour) and its strength.
  final Color frostColor;
  final double frost;

  /// The rim's light catcher.
  final Color rim;

  final GlassRendering rendering;

  @override
  bool drawsChar(int codeUnit) => false;

  @override
  Color get panelColor => solid;

  @override
  EdgeInsets get panelMargin => const EdgeInsets.fromLTRB(10, 6, 10, 10);

  /// Corner radius for a panel of [rect].
  static double radiusFor(Rect rect) {
    final r = rect.shortestSide / 5;
    return r > 28 ? 28 : r;
  }

  @override
  void paintPanel(Canvas canvas, Rect rect) {
    final rrect = RRect.fromRectAndRadius(
      rect,
      Radius.circular(radiusFor(rect)),
    );
    if (rendering.mode == GlassMode.solid) {
      canvas.drawRRect(rrect, Paint()..color = solid.withValues(alpha: 1));
    } else {
      final f = rendering.mode == GlassMode.frosted && frost < 0.6
          ? 0.6
          : frost;
      if (f > 0) {
        canvas.drawRRect(
          rrect,
          Paint()..color = frostColor.withValues(alpha: f.clamp(0.0, 1.0)),
        );
      }
      canvas.drawRRect(rrect, Paint()..color = panel);
    }
    if (rim.a <= 0) return;
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    if (rendering.gradients) {
      stroke.shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          rim,
          rim.withValues(alpha: rim.a * 0.12),
          rim.withValues(alpha: rim.a * 0.5),
        ],
        stops: const [0, 0.55, 1],
      ).createShader(rect);
    } else {
      stroke.color = rim.withValues(alpha: rim.a * 0.6);
    }
    canvas.drawRRect(rrect.deflate(0.6), stroke);
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
    if (other is! GlassDisplayFace) return t < 0.5 ? this : other;
    final c = t.clamp(0.0, 1.0);
    if (c == 0) return this;
    if (c == 1) return other;
    return GlassDisplayFace(
      panel: Color.lerp(panel, other.panel, c)!,
      solid: Color.lerp(solid, other.solid, c)!,
      frostColor: Color.lerp(frostColor, other.frostColor, c)!,
      rim: Color.lerp(rim, other.rim, c)!,
      frost: frost + (other.frost - frost) * c,
      rendering: c < 0.5 ? rendering : other.rendering,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is GlassDisplayFace &&
      other.panel == panel &&
      other.solid == solid &&
      other.frostColor == frostColor &&
      other.rim == rim &&
      other.frost == frost &&
      other.rendering == rendering;

  @override
  int get hashCode => Object.hash(
    GlassDisplayFace,
    panel,
    solid,
    frostColor,
    rim,
    frost,
    rendering,
  );
}
