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
  int _seconds = 20;
  double _questions = 10;

  @override
  Widget build(BuildContext context) {
    final minutes = (_questions * _seconds / 60).ceil();
    final colors = CalseeTextColors.of(context);
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CalseeDisplayPanel(
            child: Center(child: CalseeReadout('Up to $minutes min', size: 40)),
          ),
          const SizedBox(height: 20),
          Text(
            'Seconds per question',
            style: TextStyle(color: colors.secondary),
          ),
          const SizedBox(height: 8),
          CalseeSegmented<int>(
            options: const [(10, '10'), (20, '20'), (30, '30'), (60, '60')],
            selected: _seconds,
            onChanged: (value) => setState(() => _seconds = value),
          ),
          const SizedBox(height: 20),
          Text(
            '${_questions.round()} questions',
            style: TextStyle(color: colors.secondary),
          ),
          const SizedBox(height: 8),
          CalseeSlider(
            value: _questions,
            min: 5,
            max: 25,
            divisions: 4,
            semanticLabel: 'Questions',
            semanticFormatter: (value) => '${value.round()} questions',
            onChanged: (value) => setState(() => _questions = value),
          ),
        ],
      ),
    );
  }
}
