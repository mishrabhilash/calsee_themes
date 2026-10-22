// CalseeKey.icon: keys with an icon, and an optional label under it.
//
// Icons are drawn in the key's label colour, so they stay readable on
// every face. These use Material Icons (`uses-material-design: true` in
// the app's pubspec); any IconData works.
import 'package:calsee_themes/calsee_themes.dart';
import 'package:flutter/widgets.dart';

const _send = IconData(0xe571, fontFamily: 'MaterialIcons');
const _scan = IconData(0xe4f7, fontFamily: 'MaterialIcons');
const _history = IconData(0xe314, fontFamily: 'MaterialIcons');
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
                  _send,
                  role: KeyRole.equals,
                  semanticLabel: 'Send money',
                  label: 'Send',
                  onPressed: () => _say('Send'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: CalseeKey.icon(
                  _scan,
                  role: KeyRole.function,
                  semanticLabel: 'Scan a QR code',
                  label: 'Scan',
                  onPressed: () => _say('Scan'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: CalseeKey.icon(
                  _history,
                  role: KeyRole.operator,
                  semanticLabel: 'History',
                  label: 'History',
                  onPressed: () => _say('History'),
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
