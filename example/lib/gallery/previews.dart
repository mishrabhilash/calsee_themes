import 'package:calsee_themes/calsee_themes.dart';
import 'package:flutter/widgets.dart';

// Small live previews for the gallery's home page: each element drawn in
// the current theme, sized for a card. They don't take input; the card
// opens the element's page.

const _send = IconData(0xe571, fontFamily: 'MaterialIcons');
const _scan = IconData(0xe4f7, fontFamily: 'MaterialIcons');
const _history = IconData(0xe314, fontFamily: 'MaterialIcons');

Widget _row(List<Widget> children, {double height = 52}) => SizedBox(
  height: height,
  child: Row(
    children: [
      for (final child in children)
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: child,
          ),
        ),
    ],
  ),
);

Widget _panel(Widget child) => CalseeDisplayPanel(
  child: SizedBox(
    width: double.infinity,
    child: Center(child: child),
  ),
);

void _noop() {}

Widget backdropPreview(BuildContext context) => Builder(
  builder: (context) {
    final colors = CalseeTextColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Good evening, Alex',
          style: TextStyle(
            color: colors.primary,
            fontSize: 22,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Readable on every backdrop.',
          style: TextStyle(color: colors.secondary, fontSize: 14),
        ),
      ],
    );
  },
);

Widget keysPreview(BuildContext context) => Column(
  mainAxisAlignment: MainAxisAlignment.center,
  children: [
    _row([
      CalseeKey.text('7', role: KeyRole.digit, onPressed: _noop),
      CalseeKey.text('8', role: KeyRole.digit, onPressed: _noop),
      CalseeKey.text('fn', role: KeyRole.function, onPressed: _noop),
      CalseeKey.text('+', role: KeyRole.operator, onPressed: _noop),
    ]),
    const SizedBox(height: 8),
    _row([
      CalseeKey.text('4', role: KeyRole.digit, onPressed: _noop),
      CalseeKey.text('5', role: KeyRole.digit, onPressed: _noop),
      CalseeKey.text('AC', role: KeyRole.clear, onPressed: _noop),
      CalseeKey.text('=', role: KeyRole.equals, onPressed: _noop),
    ]),
  ],
);

Widget iconKeysPreview(BuildContext context) => Center(
  child: _row(height: 84, [
    CalseeKey.icon(
      _send,
      role: KeyRole.equals,
      semanticLabel: 'Send',
      label: 'Send',
      onPressed: _noop,
    ),
    CalseeKey.icon(
      _scan,
      role: KeyRole.function,
      semanticLabel: 'Scan',
      label: 'Scan',
      onPressed: _noop,
    ),
    CalseeKey.icon(
      _history,
      role: KeyRole.operator,
      semanticLabel: 'History',
      label: 'History',
      onPressed: _noop,
    ),
  ]),
);

Widget customKeysPreview(BuildContext context) => Center(
  child: _row(height: 84, [
    for (final (percent, amount) in const [(10, 125), (15, 187), (20, 250)])
      CalseeKey(
        role: percent == 15 ? KeyRole.equals : KeyRole.digit,
        semanticLabel: '$percent percent',
        onPressed: _noop,
        builder: (context, style, shortSide) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CalseeKeyLabel('$percent%', style: style, size: shortSide * 0.3),
            Text(
              '₹$amount',
              style: TextStyle(color: style.label, fontSize: shortSide * 0.16),
            ),
          ],
        ),
      ),
  ]),
);

Widget displayPreview(BuildContext context) =>
    Center(child: _panel(const CalseeReadout('₹1,250', size: 48)));

Widget surfacesPreview(BuildContext context) => Column(
  mainAxisAlignment: MainAxisAlignment.center,
  children: [
    for (final (name, amount) in const [
      ('Alex Morgan', '₹1,250'),
      ('Priya Shah', '₹640'),
    ])
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: SizedBox(
          height: 52,
          child: CalseeSurface(
            role: KeyRole.digit,
            builder: (context, style, shortSide) => Padding(
              padding: calseeFaceInset(context, shortSide),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      name,
                      style: TextStyle(
                        color: style.label,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  CalseeKeyLabel(amount, style: style, size: 17),
                ],
              ),
            ),
          ),
        ),
      ),
  ],
);

Widget swipePreview(BuildContext context) => Center(
  child: _panel(
    Builder(
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CalseeReadout(CalseeScope.of(context).spec.name, size: 26),
          Text(
            '← swipe →',
            style: TextStyle(
              color: CalseeTextColors.of(context).secondary,
              fontSize: 13,
            ),
          ),
        ],
      ),
    ),
  ),
);

Widget themeDataPreview(BuildContext context) {
  final theme = CalcTheme.of(context);
  return Center(
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final color in [
          theme.background,
          theme.digitKey.fill,
          theme.operatorKey.fill,
          theme.functionKey.fill,
          theme.equalsKey.fill,
        ])
          Container(
            width: 40,
            height: 40,
            margin: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(color: theme.displayText, width: 1.5),
            ),
          ),
      ],
    ),
  );
}

Widget sharePreview(BuildContext context) {
  final entry = CalseeScope.of(context).entry;
  final code = entry.heroId != null
      ? encodeShareCode(shareFamilyHero, entry.engineVersion, entry.heroId!)
      : encodeShareCode(entry.family!.id, entry.engineVersion, entry.seed!);
  return Center(child: _panel(CalseeReadout(code, size: 30)));
}
