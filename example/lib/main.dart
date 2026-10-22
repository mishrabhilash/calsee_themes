// A kids' maths game in endless themes: the sum, the number pad and the
// OK button are drawn by calsee_themes; the game logic is ordinary app
// code that knows nothing about themes. Swipe the sum for a new theme.
import 'package:calsee_themes/calsee_themes.dart';
import 'package:calsee_themes/key_face.dart' show KeyLabel;
import 'package:flutter/widgets.dart';

void main() => runApp(const MathsGameApp());

class MathsGameApp extends StatelessWidget {
  const MathsGameApp({super.key, this.seed});

  /// Where the theme feed starts (random when null).
  final int? seed;

  @override
  Widget build(BuildContext context) => WidgetsApp(
    title: 'calsee_themes demo',
    color: const Color(0xFF000000),
    debugShowCheckedModeBanner: false,
    builder: (context, _) => CalseeScope(
      seed: seed,
      // In an app: load savedState at launch and store it in onChanged,
      // so the player keeps their theme.
      child: const MathsGameScreen(),
    ),
  );
}

class MathsGameScreen extends StatefulWidget {
  const MathsGameScreen({super.key});

  @override
  State<MathsGameScreen> createState() => _MathsGameScreenState();
}

class _MathsGameScreenState extends State<MathsGameScreen> {
  static const _sums = [
    (7, '+', 5),
    (9, '−', 4),
    (3, '×', 6),
    (8, '+', 7),
    (12, '−', 5),
    (4, '×', 4),
  ];

  int _round = 0;
  int _stars = 0;
  String _answer = '';
  String? _status;

  (int, String, int) get _sum => _sums[_round % _sums.length];

  int get _result => switch (_sum) {
    (final a, '+', final b) => a + b,
    (final a, '−', final b) => a - b,
    (final a, _, final b) => a * b,
  };

  // Answers have at most 3 digits.
  void _key(String key) => setState(() {
    _status = null;
    if (key == '<') {
      if (_answer.isNotEmpty) {
        _answer = _answer.substring(0, _answer.length - 1);
      }
      return;
    }
    if (key == 'Skip') {
      _round++;
      _answer = '';
      return;
    }
    if (_answer.length < 3) _answer += key;
  });

  void _check() => setState(() {
    if (int.parse(_answer) == _result) {
      _stars++;
      _round++;
      _status = 'Correct! Here is the next one.';
    } else {
      _status = 'Not quite. Try again!';
    }
    _answer = '';
  });

  @override
  Widget build(BuildContext context) {
    final colors = CalseeTextColors.of(context);
    final theme = CalseeScope.of(context);
    return CalseeBackdrop(
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Text(
                'Maths Quest',
                style: TextStyle(
                  color: colors.primary,
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Round ${_round + 1} · $_stars stars · ${theme.spec.name}',
                style: TextStyle(color: colors.secondary, fontSize: 14),
              ),
              Expanded(
                child: CalseeSwipeArea(
                  child: Center(child: _SumDisplay(_sum, _answer, _status)),
                ),
              ),
              SizedBox(
                height: 64,
                width: double.infinity,
                child: CalseeKey.text(
                  'OK',
                  role: KeyRole.equals,
                  sizeFactor: 0.36,
                  onPressed: _answer.isEmpty ? null : _check,
                ),
              ),
              const SizedBox(height: 16),
              _NumberPad(onKey: _key),
            ],
          ),
        ),
      ),
    );
  }
}

class _SumDisplay extends StatelessWidget {
  const _SumDisplay(this.sum, this.answer, this.status);

  final (int, String, int) sum;
  final String answer;
  final String? status;

  @override
  Widget build(BuildContext context) => CalseeDisplayPanel(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Builder(
        builder: (context) {
          final colors = CalseeTextColors.of(context);
          final (a, op, b) = sum;
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CalseeReadout('$a $op $b', size: 56),
              CalseeReadout(
                '= ${answer.isEmpty ? '?' : answer}',
                size: 56,
                color: answer.isEmpty ? colors.secondary : null,
              ),
              const SizedBox(height: 8),
              Text(
                status ?? 'Swipe here for a new theme',
                style: TextStyle(color: colors.secondary, fontSize: 13),
              ),
            ],
          );
        },
      ),
    ),
  );
}

class _NumberPad extends StatelessWidget {
  const _NumberPad({required this.onKey});

  final ValueChanged<String> onKey;

  static const _rows = [
    ['1', '2', '3'],
    ['4', '5', '6'],
    ['7', '8', '9'],
    ['Skip', '0', '<'],
  ];

  @override
  Widget build(BuildContext context) => Column(
    children: [
      for (final row in _rows)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            children: [
              for (final key in row)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                    child: SizedBox(height: 60, child: _key(key)),
                  ),
                ),
            ],
          ),
        ),
    ],
  );

  Widget _key(String key) => switch (key) {
    '<' => CalseeKey.icon(
      KeyLabel.backspaceIcon,
      role: KeyRole.backspace,
      semanticLabel: 'Delete',
      onPressed: () => onKey(key),
    ),
    'Skip' => CalseeKey.text(
      'Skip',
      role: KeyRole.function,
      onPressed: () => onKey(key),
    ),
    _ => CalseeKey.text(key, role: KeyRole.digit, onPressed: () => onKey(key)),
  };
}
