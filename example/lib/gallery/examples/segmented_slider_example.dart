// CalseeSegmented and CalseeSlider: pick one of a few, or a value in a
// range.
//
// Each segment is a key with the family's press; the chosen one wears the
// accent face. The slider's track is the plain face, filled in the accent
// colour up to its thumb. Drag it, tap along it, or let divisions snap it.
import 'package:calsee_themes/calsee_themes.dart';
import 'package:flutter/widgets.dart';

class SegmentedSliderExample extends StatefulWidget {
  const SegmentedSliderExample({super.key});

  @override
  State<SegmentedSliderExample> createState() => _SegmentedSliderExampleState();
}

class _SegmentedSliderExampleState extends State<SegmentedSliderExample> {
  static const _bill = 2400;
  int _people = 3;
  double _tip = 10;

  @override
  Widget build(BuildContext context) {
    final each = (_bill * (1 + _tip / 100) / _people).round();
    final colors = CalseeTextColors.of(context);
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CalseeDisplayPanel(
            child: Center(child: CalseeReadout('₹$each each', size: 40)),
          ),
          const SizedBox(height: 20),
          Text('Split between', style: TextStyle(color: colors.secondary)),
          const SizedBox(height: 8),
          CalseeSegmented<int>(
            options: const [(2, '2'), (3, '3'), (4, '4'), (5, '5')],
            selected: _people,
            onChanged: (value) => setState(() => _people = value),
          ),
          const SizedBox(height: 20),
          Text(
            'Tip ${_tip.round()}%',
            style: TextStyle(color: colors.secondary),
          ),
          const SizedBox(height: 8),
          CalseeSlider(
            value: _tip,
            max: 25,
            divisions: 5,
            semanticLabel: 'Tip',
            semanticFormatter: (value) => '${value.round()} percent',
            onChanged: (value) => setState(() => _tip = value),
          ),
        ],
      ),
    );
  }
}
