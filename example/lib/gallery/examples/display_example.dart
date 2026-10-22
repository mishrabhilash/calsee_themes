// CalseeDisplayPanel and CalseeReadout: amounts, scores and timers.
//
// The panel is the family's display (Retro's LCD, Clay's inset well, Y2K's
// glass); families without one draw nothing. CalseeReadout is one line in
// the theme's display font that shrinks to fit. Below the panel,
// CalseeTextColors switches to colours solved against the panel.
import 'package:calsee_themes/calsee_themes.dart';
import 'package:flutter/widgets.dart';

class DisplayExample extends StatefulWidget {
  const DisplayExample({super.key});

  @override
  State<DisplayExample> createState() => _DisplayExampleState();
}

class _DisplayExampleState extends State<DisplayExample> {
  int _score = 0;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(16),
    child: Column(
      children: [
        CalseeDisplayPanel(
          child: SizedBox(
            width: double.infinity,
            child: Builder(
              // A context inside the panel gets the panel's text colours.
              builder: (context) => Column(
                children: [
                  Text(
                    'SCORE',
                    style: TextStyle(
                      color: CalseeTextColors.of(context).secondary,
                      fontSize: 13,
                      letterSpacing: 2,
                    ),
                  ),
                  CalseeReadout('$_score', size: 72),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 60,
          child: Row(
            children: [
              Expanded(
                child: CalseeKey.text(
                  '−',
                  role: KeyRole.operator,
                  onPressed: () => setState(() => _score--),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: CalseeKey.text(
                  'Reset',
                  role: KeyRole.clear,
                  sizeFactor: 0.3,
                  onPressed: () => setState(() => _score = 0),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: CalseeKey.text(
                  '+',
                  role: KeyRole.operator,
                  onPressed: () => setState(() => _score++),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
