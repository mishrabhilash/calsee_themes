// CalseeKey.icon: keys with an icon, and an optional label under it.
//
// Icons are drawn in the key's label colour, so they stay readable on
// every face. These use Material Icons (`uses-material-design: true` in
// the app's pubspec); any IconData works.
import 'package:calsee_themes/calsee_themes.dart';
import 'package:flutter/widgets.dart';

const _play = IconData(0xe4cb, fontFamily: 'MaterialIcons');
const _hint = IconData(0xe37b, fontFamily: 'MaterialIcons');
const _scores = IconData(0xe36f, fontFamily: 'MaterialIcons');
const _backspace = IconData(
  0xeeb5,
  fontFamily: 'MaterialIcons',
  matchTextDirection: true,
);

class IconKeysExample extends StatefulWidget {
  const IconKeysExample({super.key});

  @override
  State<IconKeysExample> createState() => _IconKeysExampleState();
}

class _IconKeysExampleState extends State<IconKeysExample> {
  String _last = 'Tap an icon key';

  void _say(String what) => setState(() => _last = what);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(16),
    child: Column(
      children: [
        Text(_last, style: const TextStyle(fontSize: 16)),
        const SizedBox(height: 12),
        SizedBox(
          height: 96,
          child: Row(
            children: [
              Expanded(
                child: CalseeKey.icon(
                  _play,
                  role: KeyRole.equals,
                  semanticLabel: 'Play',
                  label: 'Play',
                  onPressed: () => _say('Play'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: CalseeKey.icon(
                  _hint,
                  role: KeyRole.function,
                  semanticLabel: 'Show a hint',
                  label: 'Hint',
                  onPressed: () => _say('Hint'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: CalseeKey.icon(
                  _scores,
                  role: KeyRole.operator,
                  semanticLabel: 'High scores',
                  label: 'Scores',
                  onPressed: () => _say('Scores'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 60,
          width: 120,
          // Icon-only keys need a semanticLabel for screen readers.
          child: CalseeKey.icon(
            _backspace,
            role: KeyRole.backspace,
            semanticLabel: 'Delete',
            onPressed: () => _say('Delete'),
          ),
        ),
      ],
    ),
  );
}
