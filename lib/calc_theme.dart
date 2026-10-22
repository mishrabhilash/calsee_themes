import 'package:calsee_themes/calc_theme_data.dart';
import 'package:calsee_themes/plain_theme.dart';
import 'package:calsee_themes/render/ambient_drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

export 'package:calsee_themes/calc_theme_data.dart';

/// What a [CalcTheme] dependent rebuilds for.
enum CalcThemeAspect {
  /// Fields that change layout or widget structure (fonts, label weights,
  /// brightness, springs, renderer): [CalcTheme.layoutOf].
  layout,

  /// The per-frame listenable itself: [CalcTheme.liveOf].
  live,
}

/// Provides [CalcThemeData] to the calculator widgets.
///
/// During a theme transition the data changes every frame. Widgets that
/// only need its structure read [layoutOf] (they rebuild only when fonts,
/// weights, brightness, springs or the renderer change) and paint colours
/// from [liveOf], a listenable that repaints without rebuilding or
/// relayout (design doc "60 fps budget: keys repaint without relayout";
/// "theme widgets rebuild only theme-dependent layers"). [of] still
/// rebuilds on every change.
class CalcTheme extends InheritedModel<CalcThemeAspect> {
  const CalcTheme({
    required this.data,
    required super.child,
    this.live,
    this.settled = true,
    super.key,
  });

  final CalcThemeData data;

  /// Whether [data] is a resting theme (no transition running). When it
  /// changes while settled — a transition ended — every dependent
  /// rebuilds once, so widgets built from [layoutOf] bake the new colours
  /// and the live tints switch off.
  final bool settled;

  /// The per-frame theme (its value is [data] whenever this widget is
  /// built). Null: dependents of [layoutOf] rebuild on every change.
  final ValueListenable<CalcThemeData>? live;

  /// The nearest [CalcThemeData]; without a [CalcTheme] ancestor, the
  /// [PlainTheme] for the platform brightness (handy in widget tests).
  static CalcThemeData of(BuildContext context) =>
      maybeOf(context) ??
      PlainTheme.of(MediaQuery.maybePlatformBrightnessOf(context));

  /// The nearest [CalcThemeData], or null.
  static CalcThemeData? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<CalcTheme>()?.data;

  /// The nearest [CalcThemeData], rebuilding [context] only when its
  /// structure changes ([CalcThemeData.sameLayout]). Colours read from it
  /// may be stale during a transition: paint them from [liveOf].
  static CalcThemeData layoutOf(BuildContext context) =>
      InheritedModel.inheritFrom<CalcTheme>(
        context,
        aspect: CalcThemeAspect.layout,
      )?.data ??
      PlainTheme.of(MediaQuery.maybePlatformBrightnessOf(context));

  /// The per-frame theme as a listenable for painters (`repaint:`).
  /// Registers no dependency on the data itself.
  static ValueListenable<CalcThemeData> liveOf(BuildContext context) {
    final theme = InheritedModel.inheritFrom<CalcTheme>(
      context,
      aspect: CalcThemeAspect.live,
    );
    if (theme == null) {
      return FixedCalcTheme(
        PlainTheme.of(MediaQuery.maybePlatformBrightnessOf(context)),
      );
    }
    return theme.live ?? FixedCalcTheme(theme.data);
  }

  @override
  bool updateShouldNotify(CalcTheme oldWidget) =>
      data != oldWidget.data || live != oldWidget.live;

  @override
  bool updateShouldNotifyDependent(
    CalcTheme oldWidget,
    Set<CalcThemeAspect> dependencies,
  ) {
    if (live != oldWidget.live) return true;
    // Without a live listenable, painters hold a fixed snapshot: every
    // change must rebuild them.
    if (live == null && data != oldWidget.data) return true;
    if (settled && data != oldWidget.data) return true;
    return dependencies.contains(CalcThemeAspect.layout) &&
        !data.sameLayout(oldWidget.data);
  }
}

/// A [ValueListenable] that never changes (a [CalcTheme] without a live
/// theme). Equal when the data is equal, so painters built from it
/// compare cheaply.
@immutable
final class FixedCalcTheme implements ValueListenable<CalcThemeData> {
  const FixedCalcTheme(this.value);

  @override
  final CalcThemeData value;

  @override
  void addListener(VoidCallback listener) {}

  @override
  void removeListener(VoidCallback listener) {}

  @override
  bool operator ==(Object other) =>
      other is FixedCalcTheme && other.value == value;

  @override
  int get hashCode => value.hashCode;
}

/// Interpolates two [CalcThemeData]s with [CalcThemeData.lerp].
class CalcThemeDataTween extends Tween<CalcThemeData> {
  CalcThemeDataTween({super.begin, super.end});

  @override
  CalcThemeData lerp(double t) => CalcThemeData.lerp(begin!, end!, t);
}

/// A [CalcTheme] that animates to a new [data] over [duration] (theme
/// transitions: a brightness change now, theme switches in M3), in step
/// with Material's own `AnimatedTheme`.
class AnimatedCalcTheme extends ImplicitlyAnimatedWidget {
  const AnimatedCalcTheme({
    required this.data,
    required this.child,
    super.duration = const Duration(
      milliseconds: 200,
    ), // Material's theme change
    super.curve,
    super.key,
  });

  /// The theme to show (animated to when it changes).
  final CalcThemeData data;

  /// The calculator.
  final Widget child;

  @override
  AnimatedWidgetBaseState<AnimatedCalcTheme> createState() =>
      _AnimatedCalcThemeState();
}

class _AnimatedCalcThemeState
    extends AnimatedWidgetBaseState<AnimatedCalcTheme> {
  CalcThemeDataTween? _data;

  @override
  void forEachTween(TweenVisitor<dynamic> visitor) {
    _data =
        visitor(
              _data,
              widget.data,
              (value) => CalcThemeDataTween(begin: value as CalcThemeData),
            )
            as CalcThemeDataTween?;
  }

  @override
  Widget build(BuildContext context) =>
      CalcTheme(data: _data!.evaluate(animation), child: widget.child);
}

/// A rebuild boundary for a theme-dependent layer (toolbar, display, chip):
/// widgets below it that read the full per-frame theme ([CalcTheme.of])
/// rebuild inside this layer's own build scope during a transition, so
/// the screen's layout above it is never re-run (design doc: "theme
/// widgets rebuild only theme-dependent layers").
class ThemeLayer extends StatelessWidget {
  const ThemeLayer({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) =>
      LayoutBuilder(builder: (context, constraints) => child);
}

/// Paints the calculator background — the per-frame [theme]'s background
/// colour and its backdrop (gradient / pattern) — by repainting only.
class LiveBackdropPainter extends CustomPainter {
  LiveBackdropPainter({
    required this.theme,
    this.textSafeArea,
    this.toolbarExclusion,
    this.reduceMotion = false,
  }) : super(repaint: Listenable.merge([theme, AmbientClock.instance]));

  /// The per-frame theme.
  final ValueListenable<CalcThemeData> theme;

  /// Display text area the backdrop keeps plain.
  final Rect? textSafeArea;

  /// Toolbar chrome the backdrop's scene art keeps clear of (the mode
  /// button).
  final Rect? toolbarExclusion;

  /// Freezes any backdrop drift.
  final bool reduceMotion;

  /// The backdrop's own painter this frame (null: a plain colour).
  CustomPainter? get backdropPainter => theme.value.backdrop?.painter(
    textSafeArea: textSafeArea,
    toolbarExclusion: toolbarExclusion,
    reduceMotion: reduceMotion,
  );

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = theme.value.background,
    );
    backdropPainter?.paint(canvas, size);
  }

  @override
  bool shouldRepaint(LiveBackdropPainter oldDelegate) =>
      oldDelegate.theme != theme ||
      oldDelegate.textSafeArea != textSafeArea ||
      oldDelegate.toolbarExclusion != toolbarExclusion ||
      oldDelegate.reduceMotion != reduceMotion;
}
