/// The display-style seam (docs/m4-design.md §B): how a theme draws the
/// calculator display's *glyphs* and the panel behind them.
///
/// Most themes draw the display with a font and have no [DisplayFace]
/// (`CalcThemeData.displayFace == null`). A face (Retro's 7-segment LCD)
/// draws some characters itself — digits, the decimal point, minus, `E` —
/// while every other glyph (`×`, `÷`, letters, brackets) stays in the
/// theme's font. Layout never changes: the text is laid out by a normal
/// [TextPainter] with the face-drawn characters transparent
/// ([DisplayFace.maskedSpan]), and the face paints its glyphs into those
/// characters' boxes ([DisplayFace.paintGlyphs]). Measuring, fitting,
/// caret positions and hit testing are therefore exactly the font's, and
/// screen readers keep reading the same text (painting adds no semantics).
library;

import 'package:flutter/widgets.dart';

/// Draws display glyphs and the display panel for a theme family.
@immutable
abstract class DisplayFace {
  const DisplayFace();

  /// Whether this face draws the UTF-16 code unit [codeUnit] itself.
  bool drawsChar(int codeUnit);

  /// The style the font-drawn glyphs use, from the display's [base] style
  /// (e.g. a condensed width axis). Measuring and painting both use it.
  TextStyle textStyle(TextStyle base) => base;

  /// The panel colour the display text sits on (its contrast backdrop).
  Color get panelColor;

  /// Space between the display's edges and the panel.
  EdgeInsets get panelMargin;

  /// Paints the panel filling [rect].
  void paintPanel(Canvas canvas, Rect rect);

  /// Paints the face-drawn characters `[start, end)` of [text], which
  /// [painter] has laid out (with [maskedSpan]) at [origin], in [color].
  /// [opacity] (per character index) fades glyphs in or out.
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
  });

  /// How long a newly lit glyph takes to appear (Retro: segments on 30 ms).
  Duration get glyphOn => Duration.zero;

  /// How long an unlit glyph takes to disappear (Retro: off 50 ms).
  Duration get glyphOff => Duration.zero;

  /// Delay between characters when the whole line clears, right to left
  /// (Retro long-press clear: 15 ms per digit); zero = no stagger.
  Duration get clearStagger => Duration.zero;

  /// This face [t] of the way to [other] (theme transitions between two
  /// themes of the same family); switches at the midpoint by default.
  DisplayFace lerpTo(DisplayFace other, double t) => t < 0.5 ? this : other;

  /// [text] in [style] with the face-drawn characters transparent: the
  /// same layout as `TextSpan(text: text, style: style)`.
  TextSpan maskedSpan(String text, TextStyle style) {
    var drawn = false;
    for (var i = 0; i < text.length; i++) {
      if (drawsChar(text.codeUnitAt(i))) {
        drawn = true;
        break;
      }
    }
    if (!drawn) return TextSpan(text: text, style: style);
    const hidden = TextStyle(color: Color(0x00000000));
    final children = <TextSpan>[];
    var runStart = 0;
    var runDrawn = drawsChar(text.codeUnitAt(0));
    for (var i = 1; i <= text.length; i++) {
      final d = i < text.length && drawsChar(text.codeUnitAt(i));
      if (i == text.length || d != runDrawn) {
        final run = text.substring(runStart, i);
        children.add(
          runDrawn ? TextSpan(text: run, style: hidden) : TextSpan(text: run),
        );
        runStart = i;
        runDrawn = d;
      }
    }
    return TextSpan(style: style, children: children);
  }
}

/// One line of display text drawn with a [DisplayFace]: a [Text]
/// replacement (no wrapping, no text scaling) for faces that paint glyphs.
class FaceText extends LeafRenderObjectWidget {
  const FaceText(
    this.text, {
    required this.style,
    required this.face,
    super.key,
  });

  /// The text.
  final String text;

  /// Its full style (colour included).
  final TextStyle style;

  /// The face drawing its glyphs.
  final DisplayFace face;

  @override
  RenderFaceText createRenderObject(BuildContext context) =>
      RenderFaceText(text: text, style: style, face: face);

  @override
  void updateRenderObject(BuildContext context, RenderFaceText renderObject) {
    renderObject
      ..text = text
      ..style = style
      ..face = face;
  }
}

/// Render object of [FaceText].
class RenderFaceText extends RenderBox {
  RenderFaceText({
    required String text,
    required TextStyle style,
    required DisplayFace face,
  }) : _text = text,
       _style = style,
       _face = face;

  final TextPainter _painter = TextPainter(
    textDirection: TextDirection.ltr,
    maxLines: 1,
  );
  bool _needsText = true;

  String _text;
  String get text => _text;
  set text(String value) {
    if (value == _text) return;
    _text = value;
    _needsText = true;
    markNeedsLayout();
  }

  TextStyle _style;
  TextStyle get style => _style;
  set style(TextStyle value) {
    if (value == _style) return;
    final layout =
        value.copyWith(color: const Color(0xFF000000)) !=
        _style.copyWith(color: const Color(0xFF000000));
    _style = value;
    _needsText = true;
    if (layout) {
      markNeedsLayout();
    } else {
      markNeedsPaint();
    }
  }

  DisplayFace _face;
  DisplayFace get face => _face;
  set face(DisplayFace value) {
    if (value == _face) return;
    _face = value;
    _needsText = true;
    markNeedsLayout();
  }

  void _layoutText() {
    if (_needsText) {
      _painter.text = _face.maskedSpan(_text, _style);
      _needsText = false;
    }
    _painter.layout();
  }

  @override
  double computeMinIntrinsicWidth(double height) {
    _layoutText();
    return _painter.width;
  }

  @override
  double computeMaxIntrinsicWidth(double height) {
    _layoutText();
    return _painter.width;
  }

  @override
  double computeMinIntrinsicHeight(double width) {
    _layoutText();
    return _painter.height;
  }

  @override
  double computeMaxIntrinsicHeight(double width) {
    _layoutText();
    return _painter.height;
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    _layoutText();
    return constraints.constrain(Size(_painter.width, _painter.height));
  }

  @override
  double? computeDistanceToActualBaseline(TextBaseline baseline) {
    _layoutText();
    return _painter.computeDistanceToActualBaseline(baseline);
  }

  @override
  void performLayout() {
    _layoutText();
    size = constraints.constrain(Size(_painter.width, _painter.height));
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (_needsText) _layoutText();
    final canvas = context.canvas;
    _painter.paint(canvas, offset);
    _face.paintGlyphs(
      canvas,
      _painter,
      _text,
      origin: offset,
      color: _style.color ?? const Color(0xFF000000),
      fontSize: _style.fontSize ?? 14,
    );
  }

  @override
  void dispose() {
    _painter.dispose();
    super.dispose();
  }
}

/// Paints a [DisplayFace]'s panel behind the display.
class DisplayPanelPainter extends CustomPainter {
  const DisplayPanelPainter(this.face);

  /// The face whose panel to paint.
  final DisplayFace face;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    face.paintPanel(canvas, Offset.zero & size);
  }

  @override
  bool shouldRepaint(DisplayPanelPainter oldDelegate) =>
      oldDelegate.face != face;
}
