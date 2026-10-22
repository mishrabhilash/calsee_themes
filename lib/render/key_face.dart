/// Shared pieces of the ThemeSpec key renderers (M3 Expressive, NeoPOP and
/// every later family): the [ThemedKeyFace] base with bundled-font labels,
/// press/state-layer helpers, the long-press fill and [PressTranslate]
/// (a label that follows the press by repainting, never rebuilding).
///
/// The seam itself ([KeyFaceRenderer], [KeyFaceSpec], [KeyFaceMotion]) is
/// M2's `lib/themes/key_face.dart`; `CalcKeyButton` only talks to it.
library;

import 'dart:math' as math;

import 'package:calsee_themes/key_face.dart';
import 'package:calsee_themes/render/fonts.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

export 'package:calsee_themes/key_face.dart';

/// Base for ThemeSpec-driven key renderers: labels use the theme's bundled
/// variable font with its weight on the `wght` axis (Flutter does not map
/// `fontWeight` onto variable axes reliably), tabular figures, and an
/// optional slashed zero.
@immutable
abstract class ThemedKeyFace extends KeyFaceRenderer {
  const ThemedKeyFace({this.slashedZero = false});

  /// Draw `0` with a slash (fonts that support `zero`).
  final bool slashedZero;

  @override
  Widget label(String text, TextStyle style) =>
      KeyLabel(text, style: bundledLabelStyle(style, slashedZero: slashedZero));
}

/// [style] with the variable-font axes and features of its bundled family
/// (unchanged for the platform font).
TextStyle bundledLabelStyle(TextStyle style, {bool slashedZero = false}) {
  final font = BundledFont.fromFamily(style.fontFamily);
  if (!font.isBundled) return style;
  final weight = (style.fontWeight ?? FontWeight.w400).value.toDouble();
  return style.copyWith(
    fontVariations: font.variations(weight: weight, fontSize: style.fontSize),
    fontFeatures: font.features(slashedZero: slashedZero),
  );
}

/// The press depth a painter should draw: [p] itself (springs may
/// overshoot outside [0, 1]), or under Reduce Motion the discrete pressed
/// artwork (motion brief §2.2.5) — 1 for any press, 0 at rest.
double effectivePress(double p, {required bool reduceMotion}) {
  if (!reduceMotion) return p;
  return p > 0.01 ? 1 : 0;
}

/// State-layer opacity: the pressed layer replaces hover (M3 state
/// layers). The pressed tint is snapped on in frame 1 by `KeyPressMotion`,
/// which is the M3E frame-1 cue.
double stateLayerOpacity(KeyFaceMotion motion, KeyFaceSpec spec) => math
    .max(
      spec.hoverOverlayOpacity * motion.hover.value,
      spec.pressedOverlayOpacity * motion.tint.value,
    )
    .clamp(0.0, 1.0);

/// The state-layer colour of a key with [fill] and [label]: black when the
/// label is lighter than the face, white when it is darker. The layer
/// moves the face *away* from its label, so the pressed, hover and
/// long-press states can only raise label contrast — a label-coloured
/// layer (the M3 default) would pull a label resting at 4.5:1 down to
/// ≈ 3.7:1 while the key is held (spec §5.4; Accessible lock 7:1).
Color stateLayerColor(Color fill, Color label) =>
    label.computeLuminance() > fill.computeLuminance()
    ? const Color(0xFF000000)
    : const Color(0xFFFFFFFF);

/// [fill] with its contrast-safe state layer ([stateLayerColor]) at
/// [opacity] composited on.
Color withStateLayer(Color fill, Color label, double opacity) => opacity <= 0
    ? fill
    : Color.alphaBlend(
        stateLayerColor(fill, label).withValues(alpha: opacity.clamp(0.0, 1.0)),
        fill,
      );

/// Paints the long-press progress (motion brief §4.4) clipped to [clip]
/// (in the canvas' current space).
///
/// Families with a pressed state layer get a radial fill in the
/// contrast-safe state-layer colour at exactly `pressedOverlayOpacity`
/// (never more, so the label keeps its floor). Families without a tint
/// (NeoPOP: "no tint") get a label-coloured bar sweeping along the bottom
/// edge instead. Under Reduce Motion both fade in place instead of
/// growing.
void paintHoldFill(
  Canvas canvas,
  Rect rect,
  KeyFaceMotion motion,
  KeyFaceSpec spec, {
  required Path clip,
}) {
  final fraction = motion.holdFill;
  final tint = motion.tint.value.clamp(0.0, 1.0);
  if (fraction <= 0 || tint <= 0) return;
  final rm = spec.reduceMotion;
  canvas
    ..save()
    ..clipPath(clip);
  if (spec.pressedOverlayOpacity > 0) {
    final reach = math.sqrt(
      rect.width * rect.width / 4 + rect.height * rect.height / 4,
    );
    final alpha = spec.pressedOverlayOpacity * tint * (rm ? fraction : 1);
    canvas.drawCircle(
      rect.center,
      rm ? reach : reach * fraction,
      Paint()
        ..color = stateLayerColor(
          spec.style.fill,
          spec.style.label,
        ).withValues(alpha: alpha.clamp(0.0, 1.0)),
    );
  } else {
    final h = rect.height * 0.06;
    final width = rm ? rect.width : rect.width * fraction;
    canvas.drawRect(
      Rect.fromLTWH(rect.left, rect.bottom - h, width, h),
      Paint()
        ..color = spec.style.label.withValues(
          alpha: (rm ? fraction : 1) * tint,
        ),
    );
  }
  canvas.restore();
}

/// Paints [child] offset by `rest + travel × p` where p is the clamped
/// press depth (see [effectivePress]); repaints on [press] without
/// rebuilding or relayout. NeoPOP moves the label with the face.
class PressTranslate extends SingleChildRenderObjectWidget {
  const PressTranslate({
    required this.press,
    required this.rest,
    required this.travel,
    this.reduceMotion = false,
    super.child,
    super.key,
  });

  /// Press depth.
  final Animation<double> press;

  /// Offset at rest.
  final Offset rest;

  /// Extra offset when fully pressed.
  final Offset travel;

  /// Discrete pressed position.
  final bool reduceMotion;

  @override
  RenderPressTranslate createRenderObject(BuildContext context) =>
      RenderPressTranslate(
        press: press,
        rest: rest,
        travel: travel,
        reduceMotion: reduceMotion,
      );

  @override
  void updateRenderObject(
    BuildContext context,
    RenderPressTranslate renderObject,
  ) {
    renderObject
      ..press = press
      ..rest = rest
      ..travel = travel
      ..reduceMotion = reduceMotion;
  }
}

/// Render object of [PressTranslate].
class RenderPressTranslate extends RenderProxyBox {
  RenderPressTranslate({
    required Animation<double> press,
    required Offset rest,
    required Offset travel,
    bool reduceMotion = false,
  }) : _press = press,
       _rest = rest,
       _travel = travel,
       _reduceMotion = reduceMotion;

  Animation<double> _press;
  Offset _rest;
  Offset _travel;
  bool _reduceMotion;

  /// Press depth.
  Animation<double> get press => _press;
  set press(Animation<double> value) {
    if (identical(value, _press)) return;
    if (attached) _press.removeListener(markNeedsPaint);
    _press = value;
    if (attached) _press.addListener(markNeedsPaint);
    markNeedsPaint();
  }

  /// Offset at rest.
  Offset get rest => _rest;
  set rest(Offset value) {
    if (value == _rest) return;
    _rest = value;
    markNeedsPaint();
  }

  /// Extra offset when fully pressed.
  Offset get travel => _travel;
  set travel(Offset value) {
    if (value == _travel) return;
    _travel = value;
    markNeedsPaint();
  }

  /// Discrete pressed position.
  bool get reduceMotion => _reduceMotion;
  set reduceMotion(bool value) {
    if (value == _reduceMotion) return;
    _reduceMotion = value;
    markNeedsPaint();
  }

  /// The child's paint offset now.
  Offset get currentOffset {
    final p = effectivePress(
      _press.value,
      reduceMotion: _reduceMotion,
    ).clamp(0.0, 1.0);
    return _rest + _travel * p;
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _press.addListener(markNeedsPaint);
  }

  @override
  void detach() {
    _press.removeListener(markNeedsPaint);
    super.detach();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final child = this.child;
    if (child != null) context.paintChild(child, offset + currentOffset);
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    final child = this.child;
    if (child == null) return false;
    return result.addWithPaintOffset(
      offset: currentOffset,
      position: position,
      hitTest: (result, transformed) =>
          child.hitTest(result, position: transformed),
    );
  }

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) {
    final o = currentOffset;
    transform.translateByDouble(o.dx, o.dy, 0, 1);
  }
}
