// CalseeScope and CalseeThemeController: the endless theme feed.
//
// The scope themes everything below it. The controller moves through the
// feed (next, exact previous), limits it to some families and can keep
// only themes that pass stricter contrast checks.
import 'package:calsee_themes/calsee_themes.dart';
import 'package:flutter/widgets.dart';

class FeedExample extends StatefulWidget {
  const FeedExample({super.key});

  @override
  State<FeedExample> createState() => _FeedExampleState();
}

class _FeedExampleState extends State<FeedExample> {
  // Own the controller to drive the feed from your own UI. Without one,
  // CalseeScope makes its own (pass `families`, `seed` or `savedState`).
  final _themes = CalseeThemeController(seed: 2024);

  static const List<(ThemeFamily, String)> _choices = [
    (ThemeFamily.claymorphism, 'Clay'),
    (ThemeFamily.liquidGlass, 'Glass'),
    (ThemeFamily.retro, 'Retro'),
    (ThemeFamily.cyberpunk, 'Cyber'),
  ];

  @override
  void dispose() {
    _themes.dispose();
    super.dispose();
  }

  void _toggle(ThemeFamily family) {
    final families = {..._themes.families};
    if (!families.remove(family)) families.add(family);
    _themes.families = families;
  }

  @override
  Widget build(BuildContext context) => CalseeScope(
    controller: _themes,
    // Save the feed here (e.g. jsonEncode(state) into shared preferences)
    // and pass it back as `savedState` at launch.
    onChanged: (state) {},
    child: CalseeBackdrop(
      child: ListenableBuilder(
        listenable: _themes,
        builder: (context, _) => Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              CalseeDisplayPanel(
                child: CalseeReadout(_themes.spec.name, size: 32),
              ),
              const SizedBox(height: 16),
              _row([
                CalseeKey.text(
                  'Back',
                  role: KeyRole.function,
                  onPressed: _themes.canGoBack ? _themes.previous : null,
                ),
                CalseeKey.text(
                  'Next',
                  role: KeyRole.equals,
                  onPressed: _themes.next,
                ),
              ]),
              const SizedBox(height: 10),
              _row([
                for (final (family, label) in _choices)
                  CalseeKey.text(
                    label,
                    sizeFactor: 0.3,
                    // A selected family wears the operator face.
                    role: _themes.families.contains(family)
                        ? KeyRole.operator
                        : KeyRole.digit,
                    onPressed: () => _toggle(family),
                  ),
              ]),
              const SizedBox(height: 10),
              _row([
                CalseeKey.text(
                  _themes.accessible ? 'Accessible: on' : 'Accessible: off',
                  sizeFactor: 0.26,
                  role: KeyRole.function,
                  onPressed: () => _themes.accessible = !_themes.accessible,
                ),
              ]),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _row(List<Widget> keys) => SizedBox(
    height: 56,
    child: Row(
      children: [
        for (final key in keys)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: key,
            ),
          ),
      ],
    ),
  );
}
