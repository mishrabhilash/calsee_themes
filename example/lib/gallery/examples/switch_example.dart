// CalseeSwitch: on and off.
//
// The track wears the accent face when on and the plain face when off; the
// thumb is the track's label colour and slides across (instantly under
// Reduce Motion).
import 'package:calsee_themes/calsee_themes.dart';
import 'package:flutter/widgets.dart';

class SwitchExample extends StatefulWidget {
  const SwitchExample({super.key});

  @override
  State<SwitchExample> createState() => _SwitchExampleState();
}

class _SwitchExampleState extends State<SwitchExample> {
  final _settings = {
    'Sound effects': true,
    'Hints': true,
    'Timer': false,
  };

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final MapEntry(key: name, value: on) in _settings.entries)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: CalseeSwitch(
              value: on,
              label: name,
              onChanged: (value) => setState(() => _settings[name] = value),
            ),
          ),
        // No onChanged: disabled.
        const CalseeSwitch(
          value: false,
          label: 'Two players',
          onChanged: null,
        ),
      ],
    ),
  );
}
