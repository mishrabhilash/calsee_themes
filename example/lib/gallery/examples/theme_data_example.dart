// CalcTheme.of: draw your own themed widgets.
//
// For anything the drop-in widgets don't cover, read the theme's colours,
// fonts and key styles directly. Widgets that read CalcTheme.of rebuild
// when the theme changes, and morph with it. calseeDisplayStyle gives the
// display font, tabular figures and the family's text treatment.
import 'dart:math' as math;

import 'package:calsee_themes/calsee_themes.dart';
import 'package:flutter/widgets.dart';

class ThemeDataExample extends StatefulWidget {
  const ThemeDataExample({super.key});

  @override
  State<ThemeDataExample> createState() => _ThemeDataExampleState();
}

class _ThemeDataExampleState extends State<ThemeDataExample> {
  double _progress = 0.6;

  void _add(double step) =>
      setState(() => _progress = (_progress + step).clamp(0, 1));

  @override
  Widget build(BuildContext context) {
    final theme = CalcTheme.of(context);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          SizedBox.square(
            dimension: 180,
            child: CustomPaint(
              painter: _RingPainter(
                progress: _progress,
                track: theme.digitKey.fill,
                fill: theme.equalsKey.fill,
              ),
              child: Center(
                child: Text(
                  '${(_progress * 100).round()}%',
                  style: calseeDisplayStyle(context, 40),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Swatches straight from the theme.
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (final color in [
                theme.background,
                theme.digitKey.fill,
                theme.operatorKey.fill,
                theme.functionKey.fill,
                theme.equalsKey.fill,
              ])
                Container(
                  width: 32,
                  height: 32,
                  margin: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(color: theme.displayText, width: 1.5),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 56,
            child: Row(
              children: [
                Expanded(
                  child: CalseeKey.text(
                    '−10%',
                    role: KeyRole.operator,
                    sizeFactor: 0.32,
                    onPressed: () => _add(-0.1),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: CalseeKey.text(
                    '+10%',
                    role: KeyRole.operator,
                    sizeFactor: 0.32,
                    onPressed: () => _add(0.1),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.progress,
    required this.track,
    required this.fill,
  });

  final double progress;
  final Color track;
  final Color fill;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final stroke = size.shortestSide * 0.1;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    final arc = rect.deflate(stroke / 2);
    canvas
      ..drawArc(arc, 0, math.pi * 2, false, paint..color = track)
      ..drawArc(
        arc,
        -math.pi / 2,
        math.pi * 2 * progress,
        false,
        paint..color = fill,
      );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress || old.track != track || old.fill != fill;
}
