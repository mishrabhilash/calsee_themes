// CalseeKey.text: buttons drawn by the theme, one face per KeyRole.
//
// Each family has its own spring press: Claymorphism squishes, NeoPOP
// extrudes, Liquid Glass inflates. Use KeyRole.equals for the one primary
// action, KeyRole.operator and KeyRole.function for secondary ones, and
// KeyRole.digit for everything else.
import 'package:calsee_themes/calsee_themes.dart';
import 'package:flutter/widgets.dart';

class KeysExample extends StatefulWidget {
  const KeysExample({super.key});

  @override
  State<KeysExample> createState() => _KeysExampleState();
}

class _KeysExampleState extends State<KeysExample> {
  String _pressed = 'Press a key';
  int _holds = 0;

  static const Map<KeyRole, String> _keys = {
    KeyRole.digit: '7',
    KeyRole.decimal: '.',
    KeyRole.operator: '+',
    KeyRole.equals: '=',
    KeyRole.function: 'fn',
    KeyRole.constant: 'π',
    KeyRole.paren: '( )',
    KeyRole.clear: 'AC',
    KeyRole.sign: '±',
    KeyRole.percent: '%',
    KeyRole.memory: 'M+',
    KeyRole.mode: 'DEG',
  };

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(16),
    child: Column(
      children: [
        Text(_pressed, style: const TextStyle(fontSize: 16)),
        const SizedBox(height: 12),
        // Keys fill their box: size them with SizedBox, Expanded or a grid.
        GridView.count(
          crossAxisCount: 4,
          shrinkWrap: true,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            for (final MapEntry(key: role, value: label) in _keys.entries)
              CalseeKey.text(
                label,
                role: role,
                onPressed: () => setState(() => _pressed = role.name),
              ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 60,
          child: Row(
            children: [
              Expanded(
                // A hold fills the face, then fires onLongPress.
                child: CalseeKey.text(
                  'Hold me ($_holds)',
                  role: KeyRole.equals,
                  sizeFactor: 0.3,
                  onLongPress: () => setState(() => _holds++),
                ),
              ),
              const SizedBox(width: 10),
              // No onPressed or onLongPress: the key is disabled (dimmed).
              Expanded(
                child: CalseeKey.text(
                  'Disabled',
                  role: KeyRole.digit,
                  sizeFactor: 0.3,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
