import 'dart:collection';
import 'dart:math' as math;

import 'package:calsee_themes/key_role.dart';
import 'package:flutter/widgets.dart';
import 'package:material_ui/material_ui.dart' show Icons;

/// Colours and label weight for one group of keys.
@immutable
final class KeyStyle {
  const new({
    required this.fill,
    required this.label,
    this.labelWeight = FontWeight.w400,
    this.outline,
  });

  /// Interpolates fill, label, weight and outline.
  factory lerp(KeyStyle a, KeyStyle b, double t) => KeyStyle(
    fill: Color.lerp(a.fill, b.fill, t)!,
    label: Color.lerp(a.label, b.label, t)!,
    labelWeight: FontWeight.lerp(a.labelWeight, b.labelWeight, t)!,
    outline: a.outline == null && b.outline == null
        ? null
        : Color.lerp(
            a.outline ?? b.outline!.withValues(alpha: 0),
            b.outline ?? a.outline!.withValues(alpha: 0),
            t,
          ),
  );

  /// Key background.
  final Color fill;

  /// Label colour (≥ 4.5:1 against [fill]).
  final Color label;

  /// Label weight. Operators and `=` use a heavier weight than digits so
  /// they differ by more than colour (spec §5.4).
  final FontWeight labelWeight;

  /// Optional key outline (high-contrast themes: ≥ 3:1 against the
  /// background, so the key's extent is visible); null for none.
  final Color? outline;

  /// The label weight under the platform's Bold Text setting: three steps
  /// heavier (w400 → w700, w600 → w900), so roles keep their weight order
  /// instead of all becoming bold.
  FontWeight labelWeightFor({required bool boldText}) => boldText
      ? FontWeight(math.min(labelWeight.value + 300, FontWeight.w900.value))
      : labelWeight;

  @override
  bool operator ==(Object other) =>
      other is KeyStyle &&
      other.fill == fill &&
      other.label == label &&
      other.labelWeight == labelWeight &&
      other.outline == outline;

  @override
  int get hashCode => Object.hash(fill, label, labelWeight, outline);

  @override
  String toString() => 'KeyStyle($fill, $label, $labelWeight, $outline)';
}

/// A key's animation channels, as a [KeyFaceRenderer] reads them (the
/// calculator's `KeyPressMotion` implements it).
abstract interface class KeyFaceMotion {
  /// Press depth: 0 at rest, 1 fully pressed (springs may overshoot).
  Animation<double> get press;

  /// Pressed state layer, 0–1.
  Animation<double> get tint;

  /// Hover state layer, 0–1.
  Animation<double> get hover;

  /// Long-press fill progress, 0–1 (0 until the fill should show).
  double get holdFill;

  /// Every channel, for a painter's `repaint`.
  Listenable get listenable;
}

/// Extra channels a [KeyFaceMotion] may also provide (the calculator's
/// `KeyPressMotion` does). Renderers must still work without them (test
/// fakes, previews): check with `motion is KeyFaceMotionDetail`.
abstract interface class KeyFaceMotionDetail implements KeyFaceMotion {
  /// The press depth of the key's *scale* (its press transform): the same
  /// as [press] on the way in; on release it follows the theme's
  /// `release` spring while [press] follows `releaseAlt`. Liquid Glass's
  /// jelly reads both: X on this channel, Y on [press].
  Animation<double> get scale;

  /// Where the current (or last) touch went down, as a fraction of the
  /// key's box (0–1 on both axes; may fall slightly outside for the hit
  /// slop); null for presses without a touch point (physical keys,
  /// screen readers).
  Offset? get touchFraction;
}

/// What a [KeyFaceRenderer] draws one key with.
@immutable
final class KeyFaceSpec {
  const new({
    required this.role,
    required this.style,
    required this.cornerFraction,
    required this.pressedOverlayOpacity,
    required this.hoverOverlayOpacity,
    this.reduceMotion = false,
    this.artSeed = 0,
  });

  /// The key's role.
  final KeyRole role;

  /// Fill, label and outline colours.
  final KeyStyle style;

  /// Corner radius as a fraction of the shorter side.
  final double cornerFraction;

  /// Opacity of the label-coloured layer when fully pressed.
  final double pressedOverlayOpacity;

  /// Opacity of the label-coloured layer when hovered.
  final double hoverOverlayOpacity;

  /// Discrete changes instead of movement (the long-press fill fades in
  /// place instead of growing).
  final bool reduceMotion;

  /// A stable number per key (0 when unknown, e.g. in tests): renderers
  /// that draw hand-made artwork (Paper & ink's sketched outlines) vary it
  /// per key so same-sized keys do not share one drawing.
  final int artSeed;

  @override
  bool operator ==(Object other) =>
      other is KeyFaceSpec &&
      other.role == role &&
      other.style == style &&
      other.cornerFraction == cornerFraction &&
      other.pressedOverlayOpacity == pressedOverlayOpacity &&
      other.hoverOverlayOpacity == hoverOverlayOpacity &&
      other.reduceMotion == reduceMotion &&
      other.artSeed == artSeed;

  @override
  int get hashCode => Object.hash(
    role,
    style,
    cornerFraction,
    pressedOverlayOpacity,
    hoverOverlayOpacity,
    reduceMotion,
    artSeed,
  );
}

/// Draws key faces for a theme: the seam M3's ThemeSpec renderers plug
/// into (`CalcThemeData.keyFace`), so the keypad widget never names a
/// concrete painter.
@immutable
abstract class KeyFaceRenderer {
  const new();

  /// The painter behind the label: fill, state layers, long-press fill. It
  /// should repaint from [motion]'s `listenable` without rebuilds.
  CustomPainter painter(KeyFaceMotion motion, KeyFaceSpec spec);

  /// The label widget for [text] in [style] (already sized, coloured and
  /// weighted, Bold Text included). Not scaled by the text scaler: the
  /// key size bounds it.
  Widget label(String text, TextStyle style) => KeyLabel(text, style: style);

  /// Places [label] on the face for the press (NeoPOP moves it with the
  /// face). Must follow [motion] by repainting, never by rebuilding. The
  /// default leaves it centred.
  Widget labelLayer(KeyFaceMotion motion, KeyFaceSpec spec, Widget label) =>
      label;

  /// The renderer that decides the key's *widgets* (label, label layer):
  /// itself, or for an in-between face of a theme morph the end it is
  /// closer to. Compared by `CalcThemeData.sameLayout`.
  // A getter, not a fluent API: in-between faces override it.
  // ignore: avoid_returning_this
  KeyFaceRenderer get layoutFace => this;

  /// Builds whatever the painter would otherwise build lazily (key-shape
  /// morphs) for keys of [cellSizes], ahead of a theme commit: called on
  /// keypad layout and when a theme enters the prefetch queue. The default
  /// does nothing.
  void prepare(Iterable<Size> cellSizes) {}
}

/// The key-face sizes the keypad lays out now, published by each key on
/// layout. Theme prefetch prepares renderers for them (key-shape morphs),
/// so no commit or transition frame builds one (design doc "60 fps
/// budget: no Morph construction in commit frames").
final class KeyCellSizes extends ChangeNotifier {
  new();

  /// The app-wide registry.
  static final KeyCellSizes instance = KeyCellSizes();

  /// Sizes kept (most recent last).
  static const int capacity = 12;

  final LinkedHashSet<Size> _sizes = LinkedHashSet();

  /// The sizes, oldest first.
  List<Size> get sizes => List.unmodifiable(_sizes);

  /// Records [size]; true (and listeners notified) when it is new.
  bool report(Size size) {
    if (size.isEmpty || !size.isFinite) return false;
    if (_sizes.remove(size)) {
      _sizes.add(size);
      return false;
    }
    _sizes.add(size);
    while (_sizes.length > capacity) {
      _sizes.remove(_sizes.first);
    }
    notifyListeners();
    return true;
  }

  /// Forgets every size (tests).
  void clear() => _sizes.clear();
}

/// A key face that can morph toward another face of the same renderer
/// during a theme transition (motion brief §6.4: one tree, `FlatMorph`
/// shapes). Renderers that implement it get their shapes interpolated at
/// the transition's shape progress; others switch at the midpoint.
abstract interface class LerpableKeyFace implements KeyFaceRenderer {
  /// This face [t] of the way to [other] (t may exceed 1 slightly: the
  /// shape rubber-band to 1.06). [other]'s `layoutFace` has this face's
  /// renderer type.
  KeyFaceRenderer lerpTo(KeyFaceRenderer other, double t);

  /// Builds what [lerpTo] faces toward [other] will paint (shape morphs)
  /// for keys of [cellSizes], ahead of the transition.
  void prepareLerp(KeyFaceRenderer other, Iterable<Size> cellSizes);
}

/// A one-line key label drawn exactly in [style].
///
/// A plain [Text] would force `FontWeight.bold` on every label under the
/// platform's Bold Text setting, erasing the weight difference between
/// digits and operators; the caller already made [style] heavier, so Bold
/// Text is switched off for this label only.
class KeyLabel extends StatelessWidget {
  const new(this.text, {required this.style, super.key});

  /// The label.
  final String text;

  /// Its full style.
  final TextStyle style;

  /// The backspace label text (`CalcKeys.backspace.label`).
  static const String backspaceText = '⌫';

  /// What [backspaceText] is drawn as. U+232B is in neither bundled font,
  /// so as text it fell back to a different system font on every platform
  /// (or to a missing-glyph box); the bundled Material icon looks the same
  /// everywhere.
  static const IconData backspaceIcon = Icons.backspace_outlined;

  @override
  Widget build(BuildContext context) {
    if (text == backspaceText) {
      // Same colour (the live tint recolours it like text) and no text
      // scaling, sized to sit with the other labels.
      return Icon(
        backspaceIcon,
        size: (style.fontSize ?? 24) * 0.8,
        color: style.color,
      );
    }
    // The ambient text style, read without a dependency and re-provided
    // here: the only thing that animates in it is its colour (Material's
    // AnimatedDefaultTextStyle after a chrome theme change), which labels
    // always override, and a per-tick rebuild of every label would re-run
    // each key's label layout (design doc: keys repaint without relayout).
    final ambient =
        context.getInheritedWidgetOfExactType<DefaultTextStyle>() ??
        const DefaultTextStyle.fallback();
    final label = DefaultTextStyle(
      style: ambient.style,
      textAlign: ambient.textAlign,
      softWrap: ambient.softWrap,
      overflow: ambient.overflow,
      maxLines: ambient.maxLines,
      textWidthBasis: ambient.textWidthBasis,
      textHeightBehavior: ambient.textHeightBehavior,
      child: Text(
        text,
        textScaler: TextScaler.noScaling,
        maxLines: 1,
        softWrap: false,
        style: style,
      ),
    );
    if (!MediaQuery.boldTextOf(context)) return label;
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(boldText: false),
      child: label,
    );
  }
}

/// The plain theme's key faces: [PlainKeyPainter].
final class PlainKeyFace extends KeyFaceRenderer {
  const new();

  @override
  CustomPainter painter(KeyFaceMotion motion, KeyFaceSpec spec) =>
      PlainKeyPainter(motion: motion, spec: spec);

  @override
  bool operator ==(Object other) => other is PlainKeyFace;

  @override
  int get hashCode => (PlainKeyFace).hashCode;
}

/// Paints the plain-theme key face: a rounded-rect fill (and optional
/// outline) with the hover and pressed state layers, plus the long-press
/// radial fill (motion brief §2.2.4, §4.1, §4.4).
///
/// The press scale is applied outside the painter (a transform around the
/// face and label), so this only paints colour. It repaints on every
/// [KeyFaceMotion] channel without rebuilding any widget.
class PlainKeyPainter extends CustomPainter {
  new({required this.motion, required this.spec})
    : super(repaint: motion.listenable);

  /// The key's animation channels.
  final KeyFaceMotion motion;

  /// Colours and shape.
  final KeyFaceSpec spec;

  /// The key's outline for [size].
  RRect shapeFor(Size size) => RRect.fromRectAndRadius(
    Offset.zero & size,
    Radius.circular(size.shortestSide * spec.cornerFraction.clamp(0.0, 0.5)),
  );

  /// State-layer opacity: pressed replaces hover (M3 state layers).
  double get overlayOpacity => math.max(
    spec.hoverOverlayOpacity * motion.hover.value,
    spec.pressedOverlayOpacity * motion.tint.value,
  );

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final style = spec.style;
    final shape = shapeFor(size);
    final overlay = overlayOpacity.clamp(0.0, 1.0);
    final fill = overlay == 0
        ? style.fill
        : Color.alphaBlend(style.label.withValues(alpha: overlay), style.fill);
    canvas.drawRRect(shape, Paint()..color = fill);
    final outline = style.outline;
    if (outline != null) {
      canvas.drawRRect(
        shape.deflate(1),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = outline,
      );
    }

    final fraction = motion.holdFill;
    final tint = motion.tint.value.clamp(0.0, 1.0);
    if (fraction <= 0 || tint <= 0) return;
    final center = size.center(Offset.zero);
    final reach = math.sqrt(
      size.width * size.width / 4 + size.height * size.height / 4,
    );
    final reduceMotion = spec.reduceMotion;
    final alpha =
        spec.pressedOverlayOpacity * tint * (reduceMotion ? fraction : 1);
    canvas
      ..save()
      ..clipRRect(shape)
      ..drawCircle(
        center,
        reduceMotion ? reach : reach * fraction,
        Paint()..color = style.label.withValues(alpha: alpha.clamp(0.0, 1.0)),
      )
      ..restore();
  }

  @override
  bool shouldRepaint(PlainKeyPainter oldDelegate) =>
      !identical(oldDelegate.motion, motion) || oldDelegate.spec != spec;
}

/// Paints the keyboard focus ring just outside the key face (motion brief
/// §4.1: it appears instantly, no animation).
class KeyFocusRingPainter extends CustomPainter {
  const new({
    required this.color,
    required this.cornerFraction,
    this.width = 2,
    this.offset = 2,
    super.repaint,
  });

  /// Ring colour (≥ 3:1 against the background).
  final Color color;

  /// The key's corner fraction (the ring follows the key's corners).
  final double cornerFraction;

  /// Stroke width.
  final double width;

  /// Gap between the key edge and the ring.
  final double offset;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final grow = offset + width / 2;
    final radius = size.shortestSide * cornerFraction.clamp(0.0, 0.5) + grow;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        (Offset.zero & size).inflate(grow),
        Radius.circular(radius),
      ),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = width
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(KeyFocusRingPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.cornerFraction != cornerFraction ||
      oldDelegate.width != width ||
      oldDelegate.offset != offset;
}
