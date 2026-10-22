import 'package:calsee_themes/calc_theme.dart';
import 'package:calsee_themes/render/fonts.dart';
import 'package:calsee_themes/widgets/calsee_scope.dart';
import 'package:flutter/widgets.dart';

/// The theme's background, with the family's ambient artwork (Liquid
/// Glass blobs, Cyberpunk scanlines, Vaporwave sunsets), behind [child].
/// Text inside defaults to the theme's chrome colour.
class CalseeBackdrop extends StatelessWidget {
  /// A backdrop filling its box.
  const CalseeBackdrop({required this.child, super.key});

  /// What sits on the backdrop.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = CalcTheme.of(context);
    return ColoredBox(
      color: theme.background,
      child: CustomPaint(
        painter: LiveBackdropPainter(
          theme: CalcTheme.liveOf(context),
          reduceMotion: MediaQuery.disableAnimationsOf(context),
        ),
        child: DefaultTextStyle.merge(
          style: TextStyle(color: theme.chromeEmphasis),
          child: child,
        ),
      ),
    );
  }
}

/// Text colours for where a widget sits: on a [CalseeDisplayPanel] or
/// straight on the [CalseeBackdrop]. Families with a display panel (Retro's
/// LCD, Clay's well) solve their display colours against the panel only.
@immutable
final class CalseeTextColors {
  /// Colours for text at [context].
  factory CalseeTextColors.of(BuildContext context) {
    final theme = CalcTheme.of(context);
    return _OnDisplayPanel.at(context)
        ? CalseeTextColors._(theme.displayText, theme.secondaryText)
        : CalseeTextColors._(theme.chromeEmphasis, theme.chromeForeground);
  }

  const CalseeTextColors._(this.primary, this.secondary);

  /// Readouts and headings.
  final Color primary;

  /// Captions, hints and placeholders.
  final Color secondary;
}

class _OnDisplayPanel extends InheritedWidget {
  const _OnDisplayPanel({required super.child});

  static bool at(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_OnDisplayPanel>() != null;

  @override
  bool updateShouldNotify(_OnDisplayPanel oldWidget) => false;
}

/// The theme's display panel (Retro's LCD, Clay's inset well, Y2K's glass)
/// behind [child]; just [child] for families without one. Use it behind an
/// amount, a score or a timer.
class CalseeDisplayPanel extends StatelessWidget {
  /// A panel around [child].
  const CalseeDisplayPanel({required this.child, super.key});

  /// Space between the panel's painted rect and [child].
  static const EdgeInsets contentPadding = EdgeInsets.all(12);

  /// The panel's content.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = CalcTheme.of(context);
    final face = theme.displayFace;
    if (face == null) return child;
    // Faces paint into panelMargin (shadows, chrome), so it is reserved
    // outside the painted rect and everything stays inside this box.
    return Padding(
      padding: face.panelMargin,
      child: CustomPaint(
        painter: DisplayPanelPainter(face),
        child: Padding(
          padding: contentPadding,
          child: _OnDisplayPanel(
            child: DefaultTextStyle.merge(
              style: TextStyle(color: theme.displayText),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

/// The theme's display text style at [size]: its display font and weight,
/// tabular figures and the family's display treatment (Retro's LCD glow).
/// [color] defaults to [CalseeTextColors.primary] for where [context] sits.
TextStyle calseeDisplayStyle(
  BuildContext context,
  double size, {
  Color? color,
  FontWeight weight = FontWeight.w400,
}) {
  final theme = CalcTheme.of(context);
  final family =
      theme.displayFontFamily ?? DefaultTextStyle.of(context).style.fontFamily;
  final font = BundledFont.fromFamily(theme.displayFontFamily);
  final themed = theme.displayFace == null ? theme.displayWeight : null;
  final css = themed != null && font.isBundled
      ? (themed + weight.value - 400).clamp(100, 1000).toDouble()
      : null;
  final style = TextStyle(
    color: color ?? CalseeTextColors.of(context).primary,
    fontSize: size,
    fontWeight: css == null ? weight : nearestFontWeight(css),
    fontVariations: css == null
        ? null
        : font.variations(weight: css, fontSize: size),
    fontFamily: family,
    fontFamilyFallback: scriptFallbackFonts,
    fontFeatures: const [FontFeature.tabularFigures()],
    height: 1.1,
  );
  return theme.displayFace?.textStyle(style) ?? style;
}

/// One line of display text (an amount, a score) that shrinks to fit.
class CalseeReadout extends StatelessWidget {
  /// [text] at [size] in [calseeDisplayStyle].
  const CalseeReadout(
    this.text, {
    required this.size,
    this.color,
    this.weight = FontWeight.w400,
    super.key,
  });

  /// The text.
  final String text;

  /// Font size before shrinking to fit.
  final double size;

  /// Overrides [CalseeTextColors.primary].
  final Color? color;

  /// Weight relative to the theme's display weight.
  final FontWeight weight;

  @override
  Widget build(BuildContext context) => FittedBox(
    fit: BoxFit.scaleDown,
    child: Text(
      text,
      maxLines: 1,
      style: calseeDisplayStyle(context, size, color: color, weight: weight),
    ),
  );
}

/// Swiping across [child] changes the theme: left for the next one, right
/// for the exact previous one. Taps and vertical scrolls pass through.
class CalseeSwipeArea extends StatelessWidget {
  /// A swipe area over [child], driving the nearest [CalseeScope].
  const CalseeSwipeArea({
    required this.child,
    this.minDistance = 48,
    this.minVelocity = 300,
    super.key,
  });

  /// The area.
  final Widget child;

  /// Horizontal travel (logical pixels) that counts as a swipe.
  final double minDistance;

  /// Fling speed (logical pixels per second) that counts as a swipe.
  final double minVelocity;

  @override
  Widget build(BuildContext context) {
    var travel = 0.0;
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragStart: (_) => travel = 0,
      onHorizontalDragUpdate: (d) => travel += d.delta.dx,
      onHorizontalDragEnd: (d) {
        final v = d.primaryVelocity ?? 0;
        if (travel.abs() < minDistance && v.abs() < minVelocity) return;
        final controller = CalseeScope.of(context);
        if ((travel.abs() >= minDistance ? travel : v) < 0) {
          controller.next();
        } else {
          controller.previous();
        }
      },
      child: child,
    );
  }
}
