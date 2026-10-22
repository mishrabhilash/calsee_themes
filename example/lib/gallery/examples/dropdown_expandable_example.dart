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
  String? _account;

  @override
  Widget build(BuildContext context) {
    final colors = CalseeTextColors.of(context);
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Pay from', style: TextStyle(color: colors.secondary)),
          const SizedBox(height: 8),
          CalseeDropdown<String>(
            items: const [
              ('savings', 'Savings ••4821'),
              ('salary', 'Salary ••1290'),
              ('joint', 'Joint ••7754'),
            ],
            value: _account,
            hint: 'Choose an account',
            semanticLabel: 'Pay from',
            onChanged: (value) => setState(() => _account = value),
          ),
          const SizedBox(height: 20),
          CalseeExpandable(
            title: 'Fees and limits',
            child: Text(
              'No fee for UPI payments. Up to ₹1,00,000 a day, '
              '20 payments a day.',
              style: TextStyle(color: colors.primary, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}
