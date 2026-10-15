import 'dart:ui' show Color;

/// WCAG 2.x contrast helpers (spec §5.4 guardrails).
abstract final class Contrast {
  /// Minimum ratio for normal-size text (key labels): WCAG AA 4.5:1.
  static const double minText = 4.5;

  /// Minimum ratio for large text (the display): WCAG AA 3:1.
  static const double minLargeText = 3;

  /// WCAG relative luminance of [color] (alpha ignored), 0 (black) to 1
  /// (white).
  static double luminance(Color color) => color.computeLuminance();

  /// WCAG contrast ratio between [foreground] and [background], 1 to 21.
  ///
  /// A translucent [foreground] is first composited over [background].
  static double ratio(Color foreground, Color background) {
    final fg = foreground.a < 1
        ? Color.alphaBlend(foreground, background)
        : foreground;
    final a = luminance(fg);
    final b = luminance(background);
    final lighter = a > b ? a : b;
    final darker = a > b ? b : a;
    return (lighter + 0.05) / (darker + 0.05);
  }

  /// Whether [foreground] on [background] reaches [minimum] (default
  /// [minText]).
  static bool meets(
    Color foreground,
    Color background, {
    double minimum = minText,
  }) => ratio(foreground, background) >= minimum;
}
