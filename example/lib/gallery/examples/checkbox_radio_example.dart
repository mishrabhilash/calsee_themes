// CalseeCheckbox and CalseeRadio: ticks and one-of-many choices.
//
// A ticked box or chosen radio wears the theme's accent face, an empty one
// the plain face; the tick and the dot are drawn in the face's own label
// colour, so they stay readable in every family. Tap the box or its label.
import 'package:calsee_themes/calsee_themes.dart';
import 'package:flutter/widgets.dart';

class CheckboxRadioExample extends StatefulWidget {
  const CheckboxRadioExample({super.key});

  @override
  State<CheckboxRadioExample> createState() => _CheckboxRadioExampleState();
}

enum _Level { easy, medium, hard }

class _CheckboxRadioExampleState extends State<CheckboxRadioExample> {
  _Level _level = _Level.easy;
  bool _bonusRound = true;
  bool _readAloud = false;

  static const Map<_Level, String> _labels = {
    _Level.easy: 'Easy',
    _Level.medium: 'Medium',
    _Level.hard: 'Hard',
  };

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Difficulty',
          style: TextStyle(
            color: CalseeTextColors.of(context).secondary,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 10),
        for (final level in _Level.values)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: CalseeRadio<_Level>(
              value: level,
              groupValue: _level,
              label: _labels[level],
              onChanged: (value) => setState(() => _level = value),
            ),
          ),
        const SizedBox(height: 10),
        CalseeCheckbox(
          value: _bonusRound,
          label: 'Bonus round',
          // Disabled unless Hard is chosen: no onChanged.
          onChanged: _level == _Level.hard
              ? (value) => setState(() => _bonusRound = value)
              : null,
        ),
        const SizedBox(height: 10),
        CalseeCheckbox(
          value: _readAloud,
          label: 'Read questions aloud',
          onChanged: (value) => setState(() => _readAloud = value),
        ),
      ],
    ),
  );
}
