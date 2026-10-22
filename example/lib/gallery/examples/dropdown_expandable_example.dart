// CalseeDropdown and CalseeExpandable: menus and sections that open.
//
// The dropdown's list opens in the app's Overlay (WidgetsApp has one) and
// closes on a choice or a tap outside; the chosen item wears the accent
// face. The expandable's header is a key; its body slides open below.
import 'package:calsee_themes/calsee_themes.dart';
import 'package:flutter/widgets.dart';

class DropdownExpandableExample extends StatefulWidget {
  const DropdownExpandableExample({super.key});

  @override
  State<DropdownExpandableExample> createState() =>
      _DropdownExpandableExampleState();
}

class _DropdownExpandableExampleState extends State<DropdownExpandableExample> {
  String? _table;

  @override
  Widget build(BuildContext context) {
    final colors = CalseeTextColors.of(context);
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Practise', style: TextStyle(color: colors.secondary)),
          const SizedBox(height: 8),
          CalseeDropdown<String>(
            items: const [
              ('twos', '2 times table'),
              ('fives', '5 times table'),
              ('sevens', '7 times table'),
            ],
            value: _table,
            hint: 'Choose a times table',
            semanticLabel: 'Times table',
            onChanged: (value) => setState(() => _table = value),
          ),
          const SizedBox(height: 20),
          CalseeExpandable(
            title: 'How to play',
            child: Text(
              'Type the answer on the number pad and press OK. A right '
              'answer earns a star; Skip moves on to the next sum.',
              style: TextStyle(color: colors.primary, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}
