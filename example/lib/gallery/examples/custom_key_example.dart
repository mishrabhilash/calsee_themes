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
  int _tip = 15;

  static const _bill = 1250;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(16),
    child: Column(
      children: [
        Text(
          'Tip $_tip%: ₹${(_bill * (100 + _tip) / 100).round()} in total',
          style: const TextStyle(fontSize: 16),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 100,
          child: Row(
            children: [
              for (final percent in const [10, 15, 20])
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                    child: CalseeKey(
                      // The chosen tip wears the accent face.
                      role: percent == _tip ? KeyRole.equals : KeyRole.digit,
                      semanticLabel: '$percent percent tip',
                      onPressed: () => setState(() => _tip = percent),
                      builder: (context, style, shortSide) => Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CalseeKeyLabel(
                            '$percent%',
                            style: style,
                            size: shortSide * 0.32,
                          ),
                          SizedBox(height: shortSide * 0.06),
                          Text(
                            '₹${_bill * percent ~/ 100}',
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
