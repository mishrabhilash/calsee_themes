// CalseeKey with a builder: any content on a themed key.
//
// The builder gets the face's KeyStyle (label colour and weight) and the
// key's shorter side, so content can match the theme and scale with the
// key. CalseeKeyLabel draws text in the theme's key font.
import 'package:calsee_themes/calsee_themes.dart';
import 'package:flutter/widgets.dart';

class CustomKeyExample extends StatefulWidget {
  const CustomKeyExample({super.key});

  @override
  State<CustomKeyExample> createState() => _CustomKeyExampleState();
}

class _CustomKeyExampleState extends State<CustomKeyExample> {
  int _choice = 56;

  static const _choices = [('A', 54), ('B', 56), ('C', 63)];

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(16),
    child: Column(
      children: [
        Text(
          '7 × 8 = $_choice: ${_choice == 7 * 8 ? 'correct!' : 'try again'}',
          style: const TextStyle(fontSize: 16),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 100,
          child: Row(
            children: [
              for (final (letter, answer) in _choices)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                    child: CalseeKey(
                      // The chosen answer wears the accent face.
                      role: answer == _choice ? KeyRole.equals : KeyRole.digit,
                      semanticLabel: 'Answer $answer',
                      onPressed: () => setState(() => _choice = answer),
                      builder: (context, style, shortSide) => Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CalseeKeyLabel(
                            '$answer',
                            style: style,
                            size: shortSide * 0.32,
                          ),
                          SizedBox(height: shortSide * 0.06),
                          Text(
                            letter,
                            style: TextStyle(
                              color: style.label,
                              fontSize: shortSide * 0.16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    ),
  );
}
