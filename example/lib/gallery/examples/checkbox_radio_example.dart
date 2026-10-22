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

enum _Method { upi, card, netBanking }

class _CheckboxRadioExampleState extends State<CheckboxRadioExample> {
  _Method _method = _Method.upi;
  bool _saveCard = true;
  bool _receipt = false;

  static const Map<_Method, String> _labels = {
    _Method.upi: 'UPI',
    _Method.card: 'Card',
    _Method.netBanking: 'Net banking',
  };

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Pay with',
          style: TextStyle(
            color: CalseeTextColors.of(context).secondary,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 10),
        for (final method in _Method.values)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: CalseeRadio<_Method>(
              value: method,
              groupValue: _method,
              label: _labels[method],
              onChanged: (value) => setState(() => _method = value),
            ),
          ),
        const SizedBox(height: 10),
        CalseeCheckbox(
          value: _saveCard,
          label: 'Save this card',
          // Disabled unless the card is chosen: no onChanged.
          onChanged: _method == _Method.card
              ? (value) => setState(() => _saveCard = value)
              : null,
        ),
        const SizedBox(height: 10),
        CalseeCheckbox(
          value: _receipt,
          label: 'Email me a receipt',
          onChanged: (value) => setState(() => _receipt = value),
        ),
      ],
    ),
  );
}
