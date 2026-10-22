// CalseeSurface: cards and tiles that aren't buttons.
//
// A surface wears a key face at rest, with no press motion. Its builder
// gets the face's KeyStyle, and calseeFaceInset keeps content clear of the
// face's rounded corners.
import 'package:calsee_themes/calsee_themes.dart';
import 'package:flutter/widgets.dart';

class SurfaceExample extends StatelessWidget {
  const SurfaceExample({super.key});

  static const _players = [
    ('Asha', 'Times tables', '42 stars'),
    ('Leo', 'Addition', '37 stars'),
    ('Mia', 'Subtraction', '29 stars'),
  ];

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(16),
    child: Column(
      children: [
        for (final (name, topic, stars) in _players)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: SizedBox(
              height: 72,
              child: CalseeSurface(
                role: KeyRole.digit,
                builder: (context, style, shortSide) => Padding(
                  padding: calseeFaceInset(context, shortSide),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              name,
                              style: TextStyle(
                                color: style.label,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              topic,
                              style: TextStyle(
                                color: style.label.withValues(alpha: 0.75),
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      CalseeKeyLabel(stars, style: style, size: 20),
                    ],
                  ),
                ),
              ),
            ),
          ),
        // Another role for a highlighted card.
        SizedBox(
          height: 72,
          child: CalseeSurface(
            role: KeyRole.equals,
            builder: (context, style, shortSide) => Center(
              child: CalseeKeyLabel(
                'Total 108 stars',
                style: style,
                size: shortSide * 0.3,
              ),
            ),
          ),
        ),
      ],
    ),
  );
}
