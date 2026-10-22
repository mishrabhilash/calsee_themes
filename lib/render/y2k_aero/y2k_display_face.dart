/// Y2K / Frutiger Aero's display ([DisplayFace]): a glossy panel in the
/// palette `surface` — AERO a pale sky-tinted glass card with a soft rim
/// and an inner white edge (light) or a smoked-aqua glass slab with a
/// darker rim (dark), CHROME an ice or lilac LCD (light) or a black LCD
/// (dark) recessed in a light–dark–light chrome bezel — with a white gloss
/// lens over its top 30 % (at most 96 dp) and a catch-light along the top
/// edge that fades out down the sides. The font draws every glyph (Open
/// Sans on the `wght` axis; CHROME with a slashed zero).
///
/// Display text is validated on the panel, on the panel under its gloss
/// and (CHROME) under the gloss and the glare (`y2kPanelSamples`,
/// `y2kAeroDisplayBackdrops`). Inside the panel only the surface and
/// lighter overlays (gloss, bottom glow, glare, catch-light) are drawn,
/// except at the edge (rim, bezel: within 5 dp), where no text goes at
/// standard text sizes. The panel is static.
///
/// A same-family theme change lerps the surface through mid-tones, where
/// neither text polarity is certain: the light artwork
/// ([Y2kDisplayFace.artwork]) fades out on the way, so a mid-tone panel is
/// flat and [Y2kDisplayFace.panelColor] — what the shared lerp solves each
/// frame's display text against — is exactly the worst colour behind the
/// text on every frame.
library;

import 'dart:math' as math;

import 'package:calsee_themes/display_face.dart';
import 'package:calsee_themes/engine/oklab.dart';
import 'package:calsee_themes/engine/y2k_aero.dart';
import 'package:calsee_themes/render/fonts.dart';
import 'package:flutter/painting.dart';

/// The panel's margin inside the display area: the scene's side margins
/// and a horizon strip under the panel (the scene puts its horizon there).
/// Kept to 13 dp vertically: the display's own layout overflows on a
/// 320 × 568 phone at 200 % text with more (m3_a11y-perf_test).
const EdgeInsets y2kPanelMargin = EdgeInsets.fromLTRB(12, 4, 12, 9);

/// The Y2K / Frutiger Aero display panel.
final class Y2kDisplayFace extends DisplayFace {
  const Y2kDisplayFace({
    required this.surface,
    required this.rim,
    this.bezelTints = const [
      Color(0xFFF4F4F6),
      Color(0xFFEAF0F4),
      Color(0xFFF0F4F2),
    ],
    this.liteBezel = const Color(0xFFC4C6C9),
    this.chrome = false,
    this.lite = false,
    this.weight = 300,
  });

  /// The opaque panel colour (palette `surface`).
  final Color surface;

  /// AERO: the 1.25 dp rim (a darker tone of the surface; unused on
  /// CHROME).
  final Color rim;

  /// CHROME: the three light bezel stops (the foil's colours, lightened).
  final List<Color> bezelTints;

  /// CHROME, lite tier: the flat bezel.
  final Color liteBezel;

  /// CHROME (bezel, LCD glare, slashed zero) vs AERO (glass card).
  final bool chrome;

  /// The lite effects tier: flat panel, flat gloss band, no gradients.
  final bool lite;

  /// Display weight (CSS) for the result line; the expression line is
  /// 100 lighter, Bold Text adds its steps on top.
  final int weight;

  /// Width of the CHROME bezel ring, dp.
  static const double bezel = 5;

  /// Whether the panel is dark (light display text), as the guardrails
  /// decide it (`y2kPanelGlossAlpha`).
  bool get dark => y2kPanelGlossAlpha(_argb) == y2kDarkPanelGloss;

  /// How much of the light artwork (gloss lens, CHROME glare, light-panel
  /// top tone and bottom glow) shows: 1 on a panel in a validated band (L
  /// ≥ 0.85 or ≤ 0.24), fading to 0 at L 0.80 and 0.30, 0 between. Inside
  /// both fade bands the text polarity is forced (white cannot reach 3:1
  /// on L ≥ 0.80, nor black on L ≤ 0.30), and between them the panel is
  /// flat.
  double get artwork {
    final l = argbToOklab(_argb).$1;
    if (l >= 0.85 || l <= 0.24) return 1;
    if (l > 0.80) return (l - 0.80) / 0.05;
    if (l < 0.30) return (0.30 - l) / 0.06;
    return 0;
  }

  int get _glossByte => (y2kPanelGlossAlpha(_argb) * artwork).round();

  int get _glareByte => (y2kPanelGlareAlpha(_argb) * artwork).round();

  /// The gloss lens's peak alpha (the guardrails check text on the panel
  /// under it: `y2kPanelSamples`), × [artwork].
  double get glossAlpha => _glossByte / 255;

  /// The CHROME glare streak's peak alpha, × [artwork].
  double get glareAlpha => _glareByte / 255;

  /// The contrast backdrop for per-frame repair: the worst case — behind
  /// light text the panel under its gloss (CHROME: and the glare), behind
  /// dark text the bare panel (everything else inside a light panel is
  /// lighter). Composited as the guardrails do (`y2kPanelSamples`), so on
  /// a validated panel it is exactly their lightest sample.
  @override
  Color get panelColor {
    if (!dark) return surface;
    final gloss = compositeOver(withAlpha(0xFFFFFFFF, _glossByte), _argb);
    return Color(
      chrome ? compositeOver(withAlpha(0xFFFFFFFF, _glareByte), gloss) : gloss,
    );
  }

  @override
  EdgeInsets get panelMargin => y2kPanelMargin;

  @override
  bool drawsChar(int codeUnit) => false;

  /// The display passes w300 (typing) / w400 (results) / w500 (messages),
  /// plus three steps under Bold Text; each maps onto [weight] shifted by
  /// the same amount, within Open Sans's 300–800 axis.
  @override
  TextStyle textStyle(TextStyle base) {
    final font = BundledFont.fromFamily(base.fontFamily);
    if (!font.isBundled) return base;
    final asked = (base.fontWeight ?? FontWeight.w400).value;
    final w = (weight + asked - 400).clamp(300, 800).toDouble();
    return base.copyWith(
      fontWeight: nearestFontWeight(w),
      fontVariations: font.variations(weight: w, fontSize: base.fontSize),
      fontFeatures: font.features(slashedZero: chrome),
    );
  }

  /// The gloss lens inside the screen rectangle [s]: inset 3 dp, over the
  /// top 30 % (at most 96 dp), so it ends above the expression line.
  Rect glossRect(Rect s) => Rect.fromLTRB(
    s.left + 3,
    s.top + 2,
    s.right - 3,
    s.top + 2 + math.min(0.30 * s.height, 96),
  );

  /// The panel's corner radius in [rect].
  double radiusFor(Rect rect) => chrome
      ? math.min(rect.shortestSide * 0.12, 14)
      : math.min(rect.shortestSide * 0.16, 20);

  @override
  void paintPanel(Canvas canvas, Rect rect) {
    if (rect.isEmpty || rect.width < 8 || rect.height < 8) return;
    final r = radiusFor(rect);
    final outer = RRect.fromRectAndRadius(rect, Radius.circular(r));
    final screen = chrome
        ? RRect.fromRectAndRadius(
            rect.deflate(bezel),
            Radius.circular(math.max(0, r - bezel)),
          )
        : outer;
    final s = screen.outerRect;

    // 1. Bezel (CHROME) and body.
    if (chrome) {
      final ring = Paint();
      if (lite) {
        ring.color = liteBezel;
      } else {
        ring.shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            _tint(0),
            const Color(0xFFE3E5E8),
            const Color(0xFF6A6D72),
            _tint(2),
            const Color(0xFF9A9DA2),
          ],
          stops: const [0, 0.30, 0.52, 0.78, 1],
        ).createShader(rect);
      }
      canvas.drawDRRect(outer, screen, ring);
    }
    final art = artwork;
    final body = Paint()..color = surface;
    if (!lite && !dark && art > 0) {
      body.shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color.lerp(surface, Color(y2kTone(_argb, 12, 600)), art)!,
          surface,
          surface,
        ],
        stops: const [0, 0.6, 1],
      ).createShader(s);
    }
    canvas.drawRRect(screen, body);

    canvas
      ..save()
      ..clipRRect(screen);
    if (!lite && art > 0) {
      // 2. Light panels: a lighter glow rising from the bottom edge.
      if (!dark) {
        final glow = Color(y2kTone(_argb, 12, 1500));
        canvas.drawRect(
          s,
          Paint()
            ..shader =
                RadialGradient(
                  center: const Alignment(0, 1.2),
                  radius: 0.9,
                  colors: [
                    glow.withValues(alpha: 0.5 * art),
                    glow.withValues(alpha: 0),
                  ],
                ).createShader(
                  Rect.fromCenter(
                    center: Offset(s.center.dx, s.bottom + 0.1 * s.height),
                    width: 1.3 * s.width,
                    height: 1.1 * s.height,
                  ),
                ),
        );
      }
      // 3. The gloss lens over the top 30 %: strongest at the top, its
      // softly curved lower edge still visible (it ends above the text).
      final band = glossRect(s);
      final r2 = math.max<double>(0, r - 2);
      final lens = RRect.fromRectAndCorners(
        band,
        topLeft: Radius.circular(r2),
        topRight: Radius.circular(r2),
        bottomLeft: Radius.elliptical(band.width * 0.5, band.height * 0.35),
        bottomRight: Radius.elliptical(band.width * 0.5, band.height * 0.35),
      ).scaleRadii();
      canvas.drawRRect(
        lens,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFFFFFFFF).withValues(alpha: glossAlpha),
              const Color(0xFFFFFFFF).withValues(alpha: glossAlpha * 0.5),
              const Color(0xFFFFFFFF).withValues(alpha: glossAlpha * 0.22),
            ],
            stops: const [0, 0.55, 1],
          ).createShader(band),
      );
      // CHROME: a diagonal glare streak across the LCD.
      if (chrome) {
        final w = 0.18 * s.width;
        canvas
          ..save()
          ..translate(s.left + 0.72 * s.width, s.center.dy)
          ..rotate(35 * math.pi / 180)
          ..drawRect(
            Rect.fromLTRB(-w / 2, -s.height * 2, w / 2, s.height * 2),
            Paint()
              ..shader = LinearGradient(
                colors: [
                  const Color(0x00FFFFFF),
                  const Color(0xFFFFFFFF).withValues(alpha: glareAlpha),
                  const Color(0x00FFFFFF),
                ],
              ).createShader(Rect.fromLTRB(-w / 2, 0, w / 2, 1)),
          )
          ..restore();
      }
    } else if (lite && art > 0) {
      // Lite: a flat gloss band at half strength.
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          glossRect(s),
          Radius.circular(math.max<double>(0, r - 2)),
        ),
        Paint()
          ..color = const Color(0xFFFFFFFF).withValues(alpha: glossAlpha * 0.5),
      );
    }
    canvas.restore();

    // 4. Rim: CHROME a dark lip where the screen sinks into the bezel and
    // a white hairline on the screen; AERO a darker stroke (light glass: a
    // soft 1 dp rim, its inner white edge drawn with the catch-light).
    final stroke = Paint()..style = PaintingStyle.stroke;
    if (chrome) {
      if (!lite) {
        canvas.drawRRect(
          screen.inflate(0.5),
          stroke
            ..strokeWidth = 1
            ..color = const Color(0x40000000),
        );
      }
      canvas.drawRRect(
        screen.deflate(0.375),
        stroke
          ..strokeWidth = 0.75
          ..color = const Color(0x80FFFFFF),
      );
    } else if (dark || lite) {
      canvas.drawRRect(
        outer.deflate(0.625),
        stroke
          ..strokeWidth = 1.25
          ..color = rim,
      );
    } else {
      canvas.drawRRect(
        outer.deflate(0.5),
        stroke
          ..strokeWidth = 1
          ..color = rim.withValues(alpha: rim.a * 0.7),
      );
    }

    // 5. Catch-light along the top edge, fading out down the sides (light
    // AERO glass: the inner white edge, strongest at the top, all round).
    if (!lite) {
      final glass = !chrome && !dark;
      final top = dark ? 0.35 : 0.9;
      final rest = glass ? 0.45 : 0.0;
      const white = Color(0xFFFFFFFF);
      canvas.drawRRect(
        chrome ? screen.deflate(1) : outer.deflate(glass ? 1.5 : 1.75),
        stroke
          ..strokeWidth = 1
          ..color = white
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              white.withValues(alpha: top),
              white.withValues(alpha: top),
              white.withValues(alpha: rest),
              white.withValues(alpha: rest),
            ],
            stops: const [0, 0.10, 0.26, 1],
          ).createShader(s),
      );
    }
  }

  int get _argb => surface.toARGB32() | 0xFF000000;

  Color _tint(int i) => bezelTints.isEmpty
      ? const Color(0xFFF2F2F2)
      : bezelTints[math.min(i, bezelTints.length - 1)];

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
    if (other is! Y2kDisplayFace) return t < 0.5 ? this : other;
    if (other == this) return this;
    final c = t.clamp(0.0, 1.0);
    final near = c < 0.5 ? this : other;
    // The surface snaps to 8-bit channels, so the painted panel is
    // exactly [panelColor] (what each frame's text is solved against).
    return Y2kDisplayFace(
      surface: Color(Color.lerp(surface, other.surface, c)!.toARGB32()),
      rim: Color.lerp(rim, other.rim, c)!,
      bezelTints: [
        for (var i = 0; i < 3; i++) Color.lerp(_tint(i), other._tint(i), c)!,
      ],
      liteBezel: Color.lerp(liteBezel, other.liteBezel, c)!,
      chrome: near.chrome,
      lite: near.lite,
      weight: near.weight,
    );
  }

  @override
  bool operator ==(Object other) {
    if (other is! Y2kDisplayFace ||
        other.surface != surface ||
        other.rim != rim ||
        other.liteBezel != liteBezel ||
        other.chrome != chrome ||
        other.lite != lite ||
        other.weight != weight ||
        other.bezelTints.length != bezelTints.length) {
      return false;
    }
    for (var i = 0; i < bezelTints.length; i++) {
      if (other.bezelTints[i] != bezelTints[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(
    Y2kDisplayFace,
    surface,
    rim,
    Object.hashAll(bezelTints),
    liteBezel,
    chrome,
    lite,
    weight,
  );
}
