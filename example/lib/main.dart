// A payment keypad in endless themes: the amount, the keys and the Pay
// button are drawn by calsee_themes; the payment logic is ordinary app
// code that knows nothing about themes. Swipe the amount for a new theme.
import 'package:calsee_themes/calsee_themes.dart';
import 'package:calsee_themes/key_face.dart' show KeyLabel;
import 'package:flutter/widgets.dart';

void main() => runApp(const PayDemoApp());

class PayDemoApp extends StatelessWidget {
  const PayDemoApp({super.key, this.seed});

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
      // so the user keeps their theme.
      child: const PayScreen(),
    ),
  );
}

class PayScreen extends StatefulWidget {
  const PayScreen({super.key});

  @override
  State<PayScreen> createState() => _PayScreenState();
}

class _PayScreenState extends State<PayScreen> {
  String _amount = '';
  String? _status;

  // Up to 7 rupee digits and 2 paise digits.
  void _key(String key) => setState(() {
    _status = null;
    if (key == '<') {
      if (_amount.isNotEmpty) {
        _amount = _amount.substring(0, _amount.length - 1);
      }
      return;
    }
    final dot = _amount.indexOf('.');
    if (key == '.') {
      if (dot < 0) _amount = _amount.isEmpty ? '0.' : '$_amount.';
      return;
    }
    if (dot >= 0 ? _amount.length - dot > 2 : _amount.length >= 7) return;
    if (_amount == '0') _amount = '';
    _amount += key;
  });

  void _pay() => setState(() => _status = 'Paid ₹$_amount to Alex');

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
                'to Alex Morgan',
                style: TextStyle(
                  color: colors.primary,
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'alex@bank · ${theme.spec.name}',
                style: TextStyle(color: colors.secondary, fontSize: 14),
              ),
              Expanded(
                child: CalseeSwipeArea(
                  child: Center(child: _AmountDisplay(_amount, _status)),
                ),
              ),
              SizedBox(
                height: 64,
                width: double.infinity,
                child: CalseeKey.text(
                  'Pay',
                  role: KeyRole.equals,
                  sizeFactor: 0.36,
                  onPressed: _amount.isEmpty ? null : _pay,
                ),
              ),
              const SizedBox(height: 16),
              _Keypad(onKey: _key),
            ],
          ),
        ),
      ),
    );
  }
}

class _AmountDisplay extends StatelessWidget {
  const _AmountDisplay(this.amount, this.status);

  final String amount;
  final String? status;

  @override
  Widget build(BuildContext context) => CalseeDisplayPanel(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Builder(
        builder: (context) {
          final colors = CalseeTextColors.of(context);
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CalseeReadout(
                '₹${amount.isEmpty ? '0' : amount}',
                size: 64,
                color: amount.isEmpty ? colors.secondary : null,
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

class _Keypad extends StatelessWidget {
  const _Keypad({required this.onKey});

  final ValueChanged<String> onKey;

  static const _rows = [
    ['1', '2', '3'],
    ['4', '5', '6'],
    ['7', '8', '9'],
    ['.', '0', '<'],
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
    '.' => CalseeKey.text(
      '.',
      role: KeyRole.decimal,
      onPressed: () => onKey(key),
    ),
    _ => CalseeKey.text(key, role: KeyRole.digit, onPressed: () => onKey(key)),
  };
}
