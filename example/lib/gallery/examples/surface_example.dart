// CalseeSurface: cards and tiles that aren't buttons.
//
// A surface wears a key face at rest, with no press motion. Its builder
// gets the face's KeyStyle, and calseeFaceInset keeps content clear of the
// face's rounded corners.
import 'package:calsee_themes/calsee_themes.dart';
import 'package:flutter/widgets.dart';

class SurfaceExample extends StatelessWidget {
  const SurfaceExample({super.key});

  static const _payments = [
    ('Alex Morgan', 'Dinner', '₹1,250'),
    ('Priya Shah', 'Movie tickets', '₹640'),
    ('Sam Lee', 'Groceries', '₹2,310'),
  ];

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(16),
    child: Column(
      children: [
        for (final (name, note, amount) in _payments)
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
                              note,
                              style: TextStyle(
                                color: style.label.withValues(alpha: 0.75),
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      CalseeKeyLabel(amount, style: style, size: 20),
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
                'Total ₹4,200',
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
