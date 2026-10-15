/// Bauhaus renderer factories (registered in `theme_resolver.dart`).
///
/// The faces read only the spec: Bauhaus draws flat opaque rounded
/// rectangles (and one cached triangle path), so the lite effects tier and
/// Reduce Transparency draw exactly the same — the `rendering` parameter is
/// accepted for the rendered registries and ignored.
library;

import 'dart:ui' show Color;

import 'package:calsee_themes/display_face.dart';
import 'package:calsee_themes/engine/theme_spec.dart';
import 'package:calsee_themes/key_face.dart';
import 'package:calsee_themes/render/bauhaus/bauhaus_display_face.dart';
import 'package:calsee_themes/render/bauhaus/bauhaus_key_face.dart';
import 'package:calsee_themes/render/glass/glass_rendering.dart';

/// The key renderer for a [ThemeFamily.bauhaus] spec.
///
/// `KeyShapeSpec.kind` is the digit silhouette (`circle` = disc, anything
/// else = block), `operatorKind` the operator one (null or anything but a
/// block or disc = the opposite of the digits) and `operatorM3eShape` the
/// `=` figure (disc, fan or triangle; anything else = the big disc next to
/// block digits, the triangle next to disc digits). Never throws on
/// another family's spec. [rendering] is ignored (nothing to
/// simplify on the lite tier).
KeyFaceRenderer bauhausKeyFaceFor(
  ThemeSpec spec, {
  GlassRendering rendering = GlassRendering.standard,
}) {
  final shape = spec.keyShape;
  final corner = shape.cornerFraction.clamp(0.0, 0.5);
  final block = BauhausFigure.block(corner);
  final discDigits = shape.kind == KeyShapeKind.circle;
  final digit = discDigits ? BauhausFigure.digitDisc : block;
  final operator = switch (shape.operatorKind) {
    KeyShapeKind.circle => BauhausFigure.operatorDisc,
    KeyShapeKind.roundedRect => block,
    _ => discDigits ? block : BauhausFigure.operatorDisc,
  };
  final equals = switch (shape.operatorM3eShape) {
    M3eShape.circle when !discDigits => BauhausFigure.equalsDisc,
    M3eShape.fan => BauhausFigure.fan,
    M3eShape.triangle => BauhausFigure.equalsTriangle,
    _ => discDigits ? BauhausFigure.equalsTriangle : BauhausFigure.equalsDisc,
  };
  return BauhausKeyFace(
    digitFigure: digit,
    operatorFigure: operator,
    equalsFigure: equals,
    functionFigure: block,
    accent: Color(spec.palette.function.edge),
    slashedZero: spec.type.slashedZero,
  );
}

/// The display sheet for a [ThemeFamily.bauhaus] spec: the opaque
/// `surface`, the `shadow` rule and the `highlight` corner disc, the
/// display weight on Jost's `wght` axis. [rendering] is ignored.
DisplayFace? bauhausDisplayFaceFor(
  ThemeSpec spec, {
  GlassRendering rendering = GlassRendering.standard,
}) => BauhausDisplayFace(
  panel: Color(spec.palette.surface | 0xFF000000),
  bar: Color(spec.palette.shadow | 0xFF000000),
  disc: Color(spec.palette.highlight | 0xFF000000),
  weight: spec.type.displayWeight,
  cornerFraction: spec.keyShape.cornerFraction.clamp(0.0, 0.5),
);
