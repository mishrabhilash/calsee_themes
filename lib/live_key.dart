/// Key pieces that follow the per-frame theme of a transition by
/// repainting only (design doc "60 fps budget: keys repaint without
/// relayout"): the face painter, the label tint, the press scale and the
/// focus ring read `CalcTheme.liveOf` at paint time, so a theme morph
/// never rebuilds a key or re-runs its label-sizing layout.
library;

import 'package:calsee_themes/calc_theme_data.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Paints a key with the renderer and colours of the *current* frame of
/// [theme]: it delegates to `theme.value.keyFace.painter(...)`, rebuilt
/// only when the face or its spec changes.
class LiveKeyFacePainter extends CustomPainter {
  new({
    required this.motion,
    required this.theme,
    required this.role,
    this.reduceMotion = false,
    this.artSeed = 0,
  }) : super(repaint: Listenable.merge([motion.listenable, theme]));

  /// The key's animation channels.
  final KeyFaceMotion motion;

  /// The per-frame theme.
  final ValueListenable<CalcThemeData> theme;

  /// The key's role.
  final KeyRole role;

  /// Discrete pressed artwork.
  final bool reduceMotion;

  /// The key's stable art seed ([KeyFaceSpec.artSeed]).
  final int artSeed;

  CustomPainter? _delegate;
  KeyFaceRenderer? _face;
  KeyFaceSpec? _spec;

  /// The renderer's painter for this frame.
  CustomPainter get delegate {
    final data = theme.value;
    final face = data.keyFace;
    final spec = data.keyFaceSpec(
      role,
      reduceMotion: reduceMotion,
      artSeed: artSeed,
    );
    final current = _delegate;
    if (current != null && face == _face && spec == _spec) return current;
    _face = face;
    _spec = spec;
    return _delegate = face.painter(motion, spec);
  }

  @override
  void paint(Canvas canvas, Size size) => delegate.paint(canvas, size);

  @override
  bool? hitTest(Offset position) => delegate.hitTest(position);

  @override
  bool shouldRepaint(LiveKeyFacePainter oldDelegate) =>
      !identical(oldDelegate.motion, motion) ||
      oldDelegate.theme != theme ||
      oldDelegate.role != role ||
      oldDelegate.reduceMotion != reduceMotion ||
      oldDelegate.artSeed != artSeed;
}

/// The focus ring in the per-frame colour, corner fraction and width of
/// [theme].
class LiveKeyFocusRingPainter extends KeyFocusRingPainter {
  new(this.theme)
    : super(color: const Color(0x00000000), cornerFraction: 0, repaint: theme);

  /// The per-frame theme.
  final ValueListenable<CalcThemeData> theme;

  @override
  Color get color => theme.value.focusRing;

  @override
  double get cornerFraction => theme.value.keyCornerFraction;

  @override
  double get width => theme.value.focusRingWidth;

  @override
  bool shouldRepaint(KeyFocusRingPainter oldDelegate) =>
      oldDelegate is! LiveKeyFocusRingPainter || oldDelegate.theme != theme;
}

/// The label colour of keys with [role] in the per-frame [theme].
@immutable
final class LiveLabelColor implements ValueListenable<Color> {
  const new(this.theme, this.role);

  /// The per-frame theme.
  final ValueListenable<CalcThemeData> theme;

  /// The key role.
  final KeyRole role;

  @override
  Color get value => theme.value.keyStyle(role).label;

  @override
  void addListener(VoidCallback listener) => theme.addListener(listener);

  @override
  void removeListener(VoidCallback listener) => theme.removeListener(listener);

  @override
  bool operator ==(Object other) =>
      other is LiveLabelColor && other.theme == theme && other.role == role;

  @override
  int get hashCode => Object.hash(theme, role);
}

/// Recolours [child] (a label drawn in [baked]) to [color]'s current value
/// by repainting: no layer while they agree (always, once a transition
/// settles and the key rebuilds), a `srcIn` colour filter while a theme
/// transition runs.
class LiveLabelTint extends SingleChildRenderObjectWidget {
  const new({required this.color, required this.baked, super.child, super.key});

  /// The colour to show.
  final ValueListenable<Color> color;

  /// The colour [child] is drawn in.
  final Color baked;

  @override
  RenderLiveLabelTint createRenderObject(BuildContext context) =>
      RenderLiveLabelTint(color: color, baked: baked);

  @override
  void updateRenderObject(
    BuildContext context,
    RenderLiveLabelTint renderObject,
  ) {
    renderObject
      ..color = color
      ..baked = baked;
  }
}

/// Render object of [LiveLabelTint].
class RenderLiveLabelTint extends RenderProxyBox {
  new({required this._color, required this._baked});

  ValueListenable<Color> _color;
  Color _baked;

  /// The colour to show.
  ValueListenable<Color> get color => _color;
  set color(ValueListenable<Color> value) {
    if (value == _color) return;
    if (attached) _color.removeListener(_changed);
    _color = value;
    if (attached) _color.addListener(_changed);
    _changed();
  }

  /// The colour the child is drawn in.
  Color get baked => _baked;
  set baked(Color value) {
    if (value == _baked) return;
    _baked = value;
    _changed();
  }

  bool _tinted = false;

  void _changed() {
    final tinted = _color.value != _baked;
    if (tinted != _tinted) {
      _tinted = tinted;
      markNeedsCompositingBitsUpdate();
    }
    markNeedsPaint();
  }

  @override
  bool get alwaysNeedsCompositing => _tinted;

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _color.addListener(_changed);
    _tinted = _color.value != _baked;
  }

  @override
  void detach() {
    _color.removeListener(_changed);
    super.detach();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final child = this.child;
    if (child == null) return;
    final c = _color.value;
    if (c == _baked) {
      layer = null;
      context.paintChild(child, offset);
      return;
    }
    layer = context.pushColorFilter(
      offset,
      ColorFilter.mode(c, BlendMode.srcIn),
      (context, offset) => context.paintChild(child, offset),
      oldLayer: layer is ColorFilterLayer ? layer! as ColorFilterLayer : null,
    );
  }
}

/// Scales [child] about its centre by `1 + (scale − 1) × press`, where
/// scale is the per-frame theme's press scale, by repainting (a paint
/// transform: no rebuild, no relayout). Replaces a `ScaleTransition`,
/// whose per-tick rebuild inside the key's label-sizing `LayoutBuilder`
/// re-ran that layout every press frame.
class PressScale extends SingleChildRenderObjectWidget {
  const new({required this.press, required this.theme, super.child, super.key});

  /// Press depth (0 rest, 1 pressed; springs may overshoot).
  final Animation<double> press;

  /// The per-frame theme (its `pressScale`).
  final ValueListenable<CalcThemeData> theme;

  /// The scale now.
  double get currentScale => scaleFor(press.value, theme.value.pressScale);

  /// `1 + (pressScale − 1) × press`.
  static double scaleFor(double press, double pressScale) =>
      1 + (pressScale - 1) * press;

  @override
  RenderPressScale createRenderObject(BuildContext context) =>
      RenderPressScale(press: press, theme: theme);

  @override
  void updateRenderObject(BuildContext context, RenderPressScale renderObject) {
    renderObject
      ..press = press
      ..theme = theme;
  }
}

/// Render object of [PressScale].
class RenderPressScale extends RenderProxyBox {
  new({required this._press, required this._theme});

  Animation<double> _press;
  ValueListenable<CalcThemeData> _theme;

  /// Press depth.
  Animation<double> get press => _press;
  set press(Animation<double> value) {
    if (identical(value, _press)) return;
    if (attached) _press.removeListener(markNeedsPaint);
    _press = value;
    if (attached) _press.addListener(markNeedsPaint);
    markNeedsPaint();
  }

  /// The per-frame theme.
  ValueListenable<CalcThemeData> get theme => _theme;
  set theme(ValueListenable<CalcThemeData> value) {
    if (value == _theme) return;
    if (attached) _theme.removeListener(markNeedsPaint);
    _theme = value;
    if (attached) _theme.addListener(markNeedsPaint);
    markNeedsPaint();
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _press.addListener(markNeedsPaint);
    _theme.addListener(markNeedsPaint);
  }

  @override
  void detach() {
    _press.removeListener(markNeedsPaint);
    _theme.removeListener(markNeedsPaint);
    super.detach();
  }

  Matrix4 get _transform {
    final s = PressScale.scaleFor(_press.value, _theme.value.pressScale);
    final c = size.center(Offset.zero);
    return Matrix4.identity()
      ..translateByDouble(c.dx, c.dy, 0, 1)
      ..scaleByDouble(s, s, 1, 1)
      ..translateByDouble(-c.dx, -c.dy, 0, 1);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final child = this.child;
    if (child == null) return;
    layer = context.pushTransform(
      needsCompositing,
      offset,
      _transform,
      (context, offset) => context.paintChild(child, offset),
      oldLayer: layer is TransformLayer ? layer! as TransformLayer : null,
    );
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      result.addWithPaintTransform(
        transform: _transform,
        position: position,
        hitTest: (result, position) =>
            super.hitTestChildren(result, position: position),
      );

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) {
    transform.multiply(_transform);
  }
}

/// Test and tooling access to a key face's renderer painter.
extension LiveKeyFacePainterAccess on CustomPainter {
  /// The renderer's painter behind a [LiveKeyFacePainter] (this painter
  /// otherwise).
  CustomPainter get keyFaceDelegate => switch (this) {
    final LiveKeyFacePainter live => live.delegate,
    final other => other,
  };
}
