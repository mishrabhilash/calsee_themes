import 'package:calsee_themes/calsee_themes.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app(Widget child) => WidgetsApp(
  color: const Color(0xFF000000),
  builder: (context, _) => child,
);

void main() {
  testWidgets('CalseeKey calls onPressed and stays disabled without it', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      _app(
        CalseeScope(
          seed: 1,
          child: CalseeBackdrop(
            child: Column(
              children: [
                SizedBox(
                  height: 60,
                  width: 120,
                  child: CalseeKey.text(
                    '7',
                    role: KeyRole.digit,
                    onPressed: () => taps++,
                  ),
                ),
                SizedBox(
                  height: 60,
                  width: 120,
                  child: CalseeKey.text('Pay', role: KeyRole.equals),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.bySemanticsLabel('7'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(taps, 1);
    await tester.tap(find.bySemanticsLabel('Pay'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(taps, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('swiping changes the theme; back returns the exact one', (
    tester,
  ) async {
    final saved = <Object>[];
    final controller = CalseeThemeController(seed: 42);
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      _app(
        CalseeScope(
          controller: controller,
          onChanged: saved.add,
          child: const CalseeBackdrop(
            child: CalseeSwipeArea(
              child: Center(
                child: CalseeDisplayPanel(
                  child: CalseeReadout('₹1250', size: 48),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    final first = controller.spec;
    expect(controller.canGoBack, isFalse);

    await tester.drag(find.byType(CalseeSwipeArea), const Offset(-200, 0));
    await tester.pump(const Duration(seconds: 1));
    final second = controller.spec;
    expect(second, isNot(first));
    expect(saved, hasLength(1));

    await tester.drag(find.byType(CalseeSwipeArea), const Offset(200, 0));
    await tester.pump(const Duration(seconds: 1));
    expect(controller.spec, first);
    expect(saved, hasLength(2));
    expect(tester.takeException(), isNull);

    // The saved state resumes on the same theme, with the same history.
    final restored = CalseeThemeController(savedState: saved.last);
    addTearDown(restored.dispose);
    expect(restored.spec, first);
    restored.next();
    expect(restored.spec, second);
  });

  test('families limit new themes; the same seed gives the same themes', () {
    const families = [ThemeFamily.retro, ThemeFamily.claymorphism];
    final a = CalseeThemeController(seed: 9, families: families);
    final b = CalseeThemeController(seed: 9, families: families);
    addTearDown(a.dispose);
    addTearDown(b.dispose);
    for (var i = 0; i < 20; i++) {
      expect(families, contains(a.spec.family));
      expect(a.spec, b.spec);
      a.next();
      b.next();
    }
  });

  testWidgets('display text follows where it sits', (tester) async {
    late CalseeTextColors outside;
    late CalseeTextColors inside;
    await tester.pumpWidget(
      _app(
        CalseeScope(
          seed: 3,
          families: const [ThemeFamily.retro],
          child: Builder(
            builder: (context) {
              outside = CalseeTextColors.of(context);
              return CalseeDisplayPanel(
                child: Builder(
                  builder: (context) {
                    inside = CalseeTextColors.of(context);
                    return const SizedBox(width: 100, height: 40);
                  },
                ),
              );
            },
          ),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    // Retro's LCD solves its text against the panel, not the backdrop.
    expect(inside.primary, isNot(outside.primary));
  });

  testWidgets('icon keys with a label fit their key in every theme', (
    tester,
  ) async {
    const icon = IconData(0xe571, fontFamily: 'MaterialIcons');
    // Steps through the feed, so hero themes are covered too.
    final controller = CalseeThemeController(seed: 7);
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      _app(
        CalseeScope(
          controller: controller,
          child: CalseeBackdrop(
            child: Center(
              child: Wrap(
                children: [
                  for (final (width, height) in const [
                    (100.0, 84.0),
                    (94.7, 84.0),
                    (60.0, 60.0),
                    (120.0, 48.0),
                  ])
                    for (final role in const [
                      KeyRole.equals,
                      KeyRole.function,
                      KeyRole.operator,
                    ])
                      SizedBox(
                        width: width,
                        height: height,
                        child: CalseeKey.icon(
                          icon,
                          role: role,
                          semanticLabel: 'Send',
                          label: 'History',
                          onPressed: () {},
                        ),
                      ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    for (var i = 0; i < 60; i++) {
      controller.next();
      await tester.pump(const Duration(milliseconds: 600));
      expect(
        tester.takeException(),
        isNull,
        reason: '${controller.spec.name} (${controller.spec.family})',
      );
    }
  });
}
