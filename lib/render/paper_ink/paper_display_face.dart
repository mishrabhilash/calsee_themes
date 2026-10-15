/// Paper & ink's display ([DisplayFace]): the display is a paper panel in
/// the sheet's ink — a ruled **ledger** on ruled sheets, a torn **index
/// card** otherwise — with the serif display face drawing every glyph.
///
/// Panel layers (static: the panel repaints only when the face changes):
/// 1. a soft contact shadow — ink at 16 % on light sheets, black at 45 %
///    on dark ones, blurred 2.5, 1 dp down — that alone lifts the card off
///    pale sheets (a card has no inked border); on the lite tier an
///    unblurred 1 dp bottom/right edge in ink at 12 % instead;
/// 2. the panel (palette `surface`): a 2 dp-cornered ledger, or a card
///    with 5 dp top corners and a torn bottom edge;
/// 3. the paper grain at half the sheet's strength;
/// 4. feint rules in the sheet's rule ink at 56/255, at the sheet's own
///    pitch on the ledger — only in the upper 40 % of the panel (display
///    text is bottom-aligned; no baselines hook, so the result and typing
///    lines never sit on a rule), none under the Accessible lock;
/// 5. the red-pen margin rule (palette `error`): a double rule on the
///    ledger, a single one on the card, always ≤ 12 dp from the left edge
///    (display text starts ≥ 16 dp in), so no text ever sits on it.
///
/// The display text is checked against the panel with its grain and
/// feint-rule composites (`paperInkDisplayBackdrops`). Mid-morph the
/// transition re-solves the text against the panel colour only, so an
/// in-between panel fades its grain and rules out
/// ([PaperDisplayFace.ruleFade]).
library;

import 'dart:math' as math;

import 'package:calsee_themes/display_face.dart';
import 'package:calsee_themes/engine/paper_ink.dart'
    show paperDisplayRuleAlpha;
import 'package:calsee_themes/render/fonts.dart';
import 'package:calsee_themes/render/paper_ink/paper_grain.dart';
import 'package:calsee_themes/render/paper_ink/paper_key_art.dart'
    show paperUnit;
import 'package:flutter/painting.dart';

/// Every accent (margin) rule lies at most this far from the panel's left
/// edge (display text starts ≥ 16 dp in).
const double paperMarginRuleMaxX = 12;

/// Feint rules stay in this top fraction of the panel.
const double paperFeintRuleZone = 0.4;

/// The Paper & ink display panel.
final class PaperDisplayFace extends DisplayFace {
  const new({
    required this.panel,
    required this.ink,
    required this.rule,
    required this.margin,
    this.ledger = false,
    this.rules = true,
    this.grain = 0,
    this.dark = false,
    this.accessible = false,
    this.weight = 400,
    this.lite = false,
    this.ruleFade = 1,
    this.rulePitch,
  });

  /// The panel colour (palette `surface`, opaque).
  final Color panel;

  /// The ink (display text colour family): the contact shadow on light
  /// sheets and the lite tier's edge.
  final Color ink;

  /// Feint-rule ink (the sheet's rule colour).
  final Color rule;

  /// The margin rule's red pen (palette `error`).
  final Color margin;

  /// Ruled ledger (ruled sheets) rather than a torn index card.
  final bool ledger;

  /// Whether feint rules are drawn (off under the Accessible lock).
  final bool rules;

  /// Paper grain opacity on the panel (0–1).
  final double grain;

  /// The ledger's feint-rule pitch, dp: the sheet's own ruling (null:
  /// a seventh of the panel, 20–34 dp).
  final double? rulePitch;

  /// Dark sheet (a black contact shadow).
  final bool dark;

  /// Accessible lock: heavier small text.
  final bool accessible;

  /// Display weight (CSS) for results; typing is 100 lighter, messages
  /// 100 heavier, Bold Text adds three steps.
  final int weight;

  /// Lite effects tier: no blurred contact shadow.
  final bool lite;

  /// The feint rules' opacity factor (0–1): 1 for a theme's own panel.
  /// An in-between panel of a Paper → Paper morph fades its rules **and
  /// its grain** out over the first quarter and back in over the last
  /// (neither in between; neither at all between a light and a dark
  /// sheet), since the lerped display text is repaired against the panel
  /// colour alone.
  final double ruleFade;

  /// Feint-rule alpha (of 255).
  static const int ruleAlpha = paperDisplayRuleAlpha;

  @override
  Color get panelColor => panel;

  /// One margin for both panels, so a ledger ↔ card swipe never reflows
  /// the display.
  @override
  EdgeInsets get panelMargin => const EdgeInsets.fromLTRB(12, 6, 12, 14);

  @override
  bool drawsChar(int codeUnit) => false;

  /// An editorial serif cut: the display asks for w300 (typing), w400
  /// (results) or w500 (messages), plus three steps under Bold Text; each
  /// maps onto [weight] shifted by the same amount, floored at 350 (400
  /// below 24 dp and under the Accessible lock) and capped at the font's
  /// 800. Optical size follows the font size (the display cut at 56 dp).
  @override
  TextStyle textStyle(TextStyle base) {
    final font = BundledFont.fromFamily(base.fontFamily);
    if (!font.isBundled) return base;
    final asked = (base.fontWeight ?? FontWeight.w400).value;
    final size = base.fontSize ?? 14;
    final floor = accessible || size < 24 ? 400 : 350;
    final w = (weight + asked - 400).clamp(floor, 800).toDouble();
    return base.copyWith(
      fontWeight: nearestFontWeight(w),
      fontVariations: font.variations(weight: w, fontSize: base.fontSize),
      fontFeatures: font.features(),
    );
  }

  /// The feint rules' y positions in [rect] (none under the Accessible
  /// lock): every pitch from the top, within the upper 40 %.
  List<double> feintRulesIn(Rect rect) {
    if (!rules || ruleFade <= 0 || rect.height < 24) return const [];
    final pitch = ledger && rulePitch != null && rulePitch! >= 8
        ? rulePitch!
        : (rect.height / 7).clamp(20.0, 34.0);
    final limit = rect.top + rect.height * paperFeintRuleZone;
    final first = rect.top + math.max(14.0, 0.12 * rect.height);
    final ys = <double>[];
    if (ledger) {
      for (var y = first; y <= limit; y += pitch) {
        ys.add(y.roundToDouble() + 0.5);
      }
    } else if (first <= limit) {
      // The card's one header rule.
      ys.add(first.roundToDouble() + 0.5);
    }
    return ys;
  }

  /// The margin rules' x positions in [rect].
  List<double> marginRulesIn(Rect rect) =>
      ledger ? [rect.left + 8, rect.left + 11] : [rect.left + 10];

  // Shared by every panel (painting is single-threaded and every use sets
  // what it reads): an in-between panel is a new face every morph frame.
  static final Paint _shadow = Paint();
  static final Paint _fill = Paint();
  static final Paint _grain = Paint();
  static final Paint _line = Paint();
  static const MaskFilter _blur = MaskFilter.blur(BlurStyle.normal, 2.5);

  @override
  void paintPanel(Canvas canvas, Rect rect) {
    if (rect.isEmpty || rect.width < 4 || rect.height < 4) return;
    final shape = ledger ? null : _tornCard(rect);
    final ledgerShape = RRect.fromRectAndRadius(rect, const Radius.circular(2));
    void drawShape(Paint paint) => shape == null
        ? canvas.drawRRect(ledgerShape, paint)
        : canvas.drawPath(shape, paint);

    // 1. Contact shadow (0.5 dp larger all round, 1 dp down), or the lite
    // tier's crisp bottom/right edge.
    canvas.save();
    if (lite) {
      _shadow
        ..maskFilter = null
        ..color = ink.withValues(alpha: 0.12);
      canvas.translate(1, 1);
    } else {
      _shadow
        ..maskFilter = _blur
        ..color = dark ? const Color(0x73000000) : ink.withValues(alpha: 0.16);
      final c = rect.center;
      canvas
        ..translate(c.dx, c.dy + 1)
        ..scale((rect.width + 1) / rect.width, (rect.height + 1) / rect.height)
        ..translate(-c.dx, -c.dy);
    }
    drawShape(_shadow);
    canvas.restore();

    // 2. The panel; 3. its grain.
    drawShape(_fill..color = panel);
    if (grain > 0) {
      drawShape(
        _grain
          ..shader = PaperTextures.grain
          ..color = Color.fromRGBO(0, 0, 0, grain.clamp(0.0, 1.0)),
      );
    }

    // 4. Feint rules (upper part only).
    final ys = feintRulesIn(rect);
    if (ys.isNotEmpty) {
      _line.color = rule.withValues(alpha: ruleAlpha / 255 * ruleFade);
      for (final y in ys) {
        canvas.drawRect(
          Rect.fromLTRB(rect.left + 2, y - 0.5, rect.right - 2, y + 0.5),
          _line,
        );
      }
    }

    // 5. The red margin rule(s), stopping short of the torn edge.
    final bottom = ledger ? rect.bottom - 1 : rect.bottom - 6;
    _line.color = margin.withValues(alpha: ledger ? 0.8 : 0.7);
    final width = ledger ? 1.0 : 1.25;
    for (final x in marginRulesIn(rect)) {
      if (x + width / 2 > rect.right) continue;
      canvas.drawRect(
        Rect.fromLTRB(x - width / 2, rect.top + 1, x + width / 2, bottom),
        _line,
      );
    }
  }

  static (Rect, Path)? _torn;

  /// The card: 5 dp top corners and a torn bottom edge (a fine ±1.4 dp
  /// tear on a slow 1.2 dp swell), seeded by the width; cached for the
  /// last rect.
  static Path _tornCard(Rect rect) {
    final hit = _torn;
    if (hit != null && hit.$1 == rect) return hit.$2;
    final seed = 0x7EA2 ^ rect.width.round();
    final path = Path();
    const r = 5.0;
    path
      ..moveTo(rect.left, rect.top + r)
      ..quadraticBezierTo(rect.left, rect.top, rect.left + r, rect.top)
      ..lineTo(rect.right - r, rect.top)
      ..quadraticBezierTo(rect.right, rect.top, rect.right, rect.top + r);
    final phase = paperUnit(seed, 0) * 2 * math.pi;
    final wave = 36 + 24 * paperUnit(seed, 1);
    double yAt(double x, int i) =>
        rect.bottom -
        2.7 +
        1.4 * (paperUnit(seed, 10 + i) * 2 - 1) +
        1.2 * math.sin((x - rect.left) / wave * 2 * math.pi + phase);
    var x = rect.right;
    var i = 0;
    path.lineTo(rect.right, yAt(x, i));
    while (x > rect.left) {
      i++;
      x = math.max(rect.left, x - (3 + 2 * paperUnit(seed, 500 + i)));
      path.lineTo(x, yAt(x, i));
    }
    path.close();
    _torn = (rect, path);
    return path;
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
    if (other is! PaperDisplayFace) return t < 0.5 ? this : other;
    if (other == this) return this;
    final c = t.clamp(0.0, 1.0);
    final near = c < 0.5 ? this : other;
    // Grain and rules fade out by a quarter of the way and back in from
    // three quarters (never between a light and a dark sheet): the text is
    // re-solved against the bare panel colour.
    final flip = dark != other.dark;
    final envelope = (1 - 4 * math.min(c, 1 - c)).clamp(0.0, 1.0);
    return PaperDisplayFace(
      panel: Color.lerp(panel, other.panel, c)!,
      ink: Color.lerp(ink, other.ink, c)!,
      rule: Color.lerp(rule, other.rule, c)!,
      margin: Color.lerp(margin, other.margin, c)!,
      ledger: near.ledger,
      rules: near.rules,
      grain: flip ? 0 : (grain + (other.grain - grain) * c) * envelope,
      dark: near.dark,
      accessible: near.accessible,
      weight: near.weight,
      lite: near.lite,
      ruleFade: flip ? 0 : math.min(ruleFade, other.ruleFade) * envelope,
      rulePitch: near.rulePitch,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is PaperDisplayFace &&
      other.panel == panel &&
      other.ink == ink &&
      other.rule == rule &&
      other.margin == margin &&
      other.ledger == ledger &&
      other.rules == rules &&
      other.grain == grain &&
      other.dark == dark &&
      other.accessible == accessible &&
      other.weight == weight &&
      other.lite == lite &&
      other.ruleFade == ruleFade &&
      other.rulePitch == rulePitch;

  @override
  int get hashCode => Object.hash(
    PaperDisplayFace,
    panel,
    ink,
    rule,
    margin,
    ledger,
    rules,
    grain,
    dark,
    accessible,
    weight,
    lite,
    ruleFade,
    rulePitch,
  );
}
