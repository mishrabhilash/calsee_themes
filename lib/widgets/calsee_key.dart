import 'dart:async';
import 'dart:math' as math;

import 'package:calsee_themes/calc_theme.dart';
import 'package:calsee_themes/key_press_motion.dart';
import 'package:calsee_themes/live_key.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Builds a key's content in its label colour. [shortSide] is the key's
/// shorter side, for sizing.
typedef CalseeKeyBuilder =
    Widget Function(BuildContext context, KeyStyle style, double shortSide);

/// A button drawn by the current theme's key renderer, with its spring
/// press motion: Claymorphism squishes, NeoPOP extrudes, Liquid Glass
/// inflates, and so on.
///
/// [role] picks which of the theme's key faces it wears: [KeyRole.digit]
/// for ordinary keys, [KeyRole.equals] for the one primary action (the
/// theme's accent), [KeyRole.operator] and [KeyRole.function] for secondary
/// ones. Size it like any widget; it fills its box.
///
/// With [onLongPress], a hold fills the face and fires after
/// [KeyPressMotion.holdDuration].
class CalseeKey extends StatefulWidget {
  /// A key whose content comes from [builder].
  const CalseeKey({
    required this.role,
    required this.builder,
    required this.semanticLabel,
    this.onPressed,
    this.onLongPress,
    this.haptics = true,
    this.artSeed = 0,
    super.key,
  });

  /// A key showing [text] in the theme's key font.
  factory CalseeKey.text(
    String text, {
    required KeyRole role,
    VoidCallback? onPressed,
    VoidCallback? onLongPress,
    String? semanticLabel,
    double sizeFactor = 0.4,
    bool haptics = true,
    Key? key,
  }) => CalseeKey(
    role: role,
    semanticLabel: semanticLabel ?? text,
    onPressed: onPressed,
    onLongPress: onLongPress,
    haptics: haptics,
    artSeed: text.hashCode & 0x7FFFFFFF,
    key: key,
    builder: (context, style, shortSide) =>
        CalseeKeyLabel(text, style: style, size: shortSide * sizeFactor),
  );

  /// A key showing [icon], with an optional [label] under it.
  factory CalseeKey.icon(
    IconData icon, {
    required KeyRole role,
    required String semanticLabel,
    String? label,
    VoidCallback? onPressed,
    VoidCallback? onLongPress,
    double sizeFactor = 0.42,
    bool haptics = true,
    Key? key,
  }) => CalseeKey(
    role: role,
    semanticLabel: semanticLabel,
    onPressed: onPressed,
    onLongPress: onLongPress,
    haptics: haptics,
    artSeed: semanticLabel.hashCode & 0x7FFFFFFF,
    key: key,
    builder: (context, style, shortSide) {
      final glyph = Icon(
        icon,
        color: style.label,
        size: shortSide * sizeFactor,
      );
      if (label == null) return glyph;
      // Some faces (Material 3 Expressive shapes) leave less than the
      // short side for content: shrink to fit, as text labels do.
      return FittedBox(
        fit: BoxFit.scaleDown,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            glyph,
            SizedBox(height: shortSide * 0.06),
            CalseeKeyLabel(label, style: style, size: shortSide * 0.14),
          ],
        ),
      );
    },
  );

  /// Which of the theme's key faces this key wears.
  final KeyRole role;

  /// The key's content.
  final CalseeKeyBuilder builder;

  /// What screen readers announce.
  final String semanticLabel;

  /// Called on tap; the key is disabled (dimmed) without it and
  /// [onLongPress].
  final VoidCallback? onPressed;

  /// Called after a hold.
  final VoidCallback? onLongPress;

  /// Whether presses give haptic feedback.
  final bool haptics;

  /// Varies hand-drawn artwork (Paper & Ink, Bauhaus) between keys of the
  /// same size.
  final int artSeed;

  @override
  State<CalseeKey> createState() => _CalseeKeyState();
}

class _CalseeKeyState extends State<CalseeKey> with TickerProviderStateMixin {
  late final KeyPressMotion _motion = KeyPressMotion(vsync: this);
  Timer? _holdTimer;
  bool _longPressed = false;

  bool get _enabled => widget.onPressed != null || widget.onLongPress != null;

  CalcThemeData get _theme => CalcTheme.of(context);

  bool get _reduceMotion => MediaQuery.disableAnimationsOf(context);

  double get _lead => KeyPressMotion.frameLead(
    View.maybeOf(context)?.display.refreshRate ?? 60,
  );

  void _down(PointerDownEvent event) {
    if (!_enabled) return;
    _longPressed = false;
    if (widget.haptics) unawaited(HapticFeedback.lightImpact());
    _motion.down(
      spring: _theme.pressIn,
      lead: _lead,
      reduceMotion: _reduceMotion,
    );
    if (widget.onLongPress != null) {
      _motion.startHold();
      _holdTimer = Timer(KeyPressMotion.holdDuration, _fireLongPress);
    }
  }

  void _fireLongPress() {
    _longPressed = true;
    _motion.completeHold();
    if (widget.haptics) unawaited(HapticFeedback.heavyImpact());
    widget.onLongPress?.call();
  }

  void _up() {
    _holdTimer?.cancel();
    _motion.stopHold();
    if (!mounted) return;
    _motion.up(
      spring: _theme.release,
      shapeSpring: _theme.releaseAlt,
      reduceMotion: _reduceMotion,
    );
  }

  void _tap() {
    if (_longPressed) return;
    widget.onPressed?.call();
  }

  @override
  void dispose() {
    _holdTimer?.cancel();
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = _theme;
    final live = CalcTheme.liveOf(context);
    final spec = theme.keyFaceSpec(
      widget.role,
      reduceMotion: _reduceMotion,
      artSeed: widget.artSeed,
    );
    final face = LayoutBuilder(
      builder: (context, constraints) {
        final shortest = constraints.biggest.shortestSide;
        final shortSide = shortest.isFinite ? shortest : 64.0;
        // The scope prepares upcoming themes for the sizes keys use.
        KeyCellSizes.instance.report(constraints.biggest);
        return RepaintBoundary(
          child: PressScale(
            press: _motion.scale,
            theme: live,
            child: CustomPaint(
              painter: LiveKeyFacePainter(
                motion: _motion,
                theme: live,
                role: widget.role,
                reduceMotion: _reduceMotion,
                artSeed: widget.artSeed,
              ),
              child: theme.keyFace.labelLayer(
                _motion,
                spec,
                Center(child: widget.builder(context, spec.style, shortSide)),
              ),
            ),
          ),
        );
      },
    );
    return Semantics(
      button: true,
      enabled: _enabled,
      label: widget.semanticLabel,
      onTap: widget.onPressed,
      onLongPress: widget.onLongPress,
      excludeSemantics: true,
      child: Listener(
        onPointerDown: _down,
        onPointerUp: (_) => _up(),
        onPointerCancel: (_) => _up(),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onPressed == null ? null : _tap,
          child: Opacity(opacity: _enabled ? 1 : 0.45, child: face),
        ),
      ),
    );
  }
}

/// A key face at rest that isn't a button (a tile, a card, a badge),
/// drawn by the current theme's key renderer.
class CalseeSurface extends StatelessWidget {
  /// A surface wearing the key face of [role].
  const CalseeSurface({
    required this.role,
    required this.builder,
    this.artSeed = 0,
    super.key,
  });

  /// Which of the theme's key faces this surface wears.
  final KeyRole role;

  /// The surface's content.
  final CalseeKeyBuilder builder;

  /// Varies hand-drawn artwork between surfaces of the same size.
  final int artSeed;

  @override
  Widget build(BuildContext context) {
    final theme = CalcTheme.of(context);
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final spec = theme.keyFaceSpec(
      role,
      reduceMotion: reduceMotion,
      artSeed: artSeed,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final shortest = constraints.biggest.shortestSide;
        KeyCellSizes.instance.report(constraints.biggest);
        return CustomPaint(
          painter: LiveKeyFacePainter(
            motion: const _RestMotion(),
            theme: CalcTheme.liveOf(context),
            role: role,
            reduceMotion: reduceMotion,
            artSeed: artSeed,
          ),
          child: builder(
            context,
            spec.style,
            shortest.isFinite ? shortest : 64,
          ),
        );
      },
    );
  }
}

/// Padding that keeps content inside the rounded corners of a key or
/// surface whose shorter side is [shortSide].
EdgeInsets calseeFaceInset(
  BuildContext context,
  double shortSide, {
  double min = 12,
}) {
  final radius = shortSide * CalcTheme.of(context).keyCornerFraction;
  return EdgeInsets.all(math.max(min, radius * 0.32));
}

/// Key-face motion that never moves: a face at rest.
final class _RestMotion implements KeyFaceMotion {
  const _RestMotion();

  @override
  Animation<double> get press => kAlwaysDismissedAnimation;

  @override
  Animation<double> get tint => kAlwaysDismissedAnimation;

  @override
  Animation<double> get hover => kAlwaysDismissedAnimation;

  @override
  double get holdFill => 0;

  @override
  Listenable get listenable => kAlwaysDismissedAnimation;
}

/// [text] in the theme's key font, in [style]'s label colour and weight,
/// through the renderer's own label treatment.
class CalseeKeyLabel extends StatelessWidget {
  /// A label of [size] logical pixels.
  const CalseeKeyLabel(
    this.text, {
    required this.style,
    required this.size,
    super.key,
  });

  /// The label.
  final String text;

  /// The key's style (from a [CalseeKeyBuilder]).
  final KeyStyle style;

  /// Font size.
  final double size;

  @override
  Widget build(BuildContext context) {
    final theme = CalcTheme.of(context);
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: theme.keyFace.label(
        text,
        TextStyle(
          color: style.label,
          fontSize: size,
          fontWeight: style.labelWeightFor(
            boldText: MediaQuery.boldTextOf(context),
          ),
          fontFamily: theme.keyFontFamily,
          fontFeatures: const [FontFeature.tabularFigures()],
          height: 1,
        ),
      ),
    );
  }
}
