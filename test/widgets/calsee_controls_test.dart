import 'package:calsee_themes/calsee_themes.dart';
import 'package:flutter/rendering.dart' show SemanticsProperties;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app(Widget child, {Iterable<ThemeFamily>? families, int seed = 1}) =>
    WidgetsApp(
      color: const Color(0xFF000000),
      builder: (context, _) => CalseeScope(
        seed: seed,
        families: families,
        child: CalseeBackdrop(
          child: Overlay(
            initialEntries: [
              OverlayEntry(
                builder: (context) => Center(
                  child: SizedBox(width: 360, child: child),
                ),
              ),
            ],
          ),
        ),
      ),
    );

// Two frames: implicit animations start on the first and finish by the
// second.
Future<void> _settle(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump(const Duration(milliseconds: 600));
}

/// The semantics a control of [type] declares (its outermost Semantics).
SemanticsProperties _semantics(WidgetTester tester, Type type) => tester
    .widget<Semantics>(
      find
          .descendant(of: find.byType(type), matching: find.byType(Semantics))
          .first,
    )
    .properties;

void main() {
  testWidgets('checkbox toggles from the box and its label', (tester) async {
    var value = false;
    await tester.pumpWidget(
      _app(
        StatefulBuilder(
          builder: (context, setState) => CalseeCheckbox(
            value: value,
            label: 'Remember me',
            onChanged: (v) => setState(() => value = v),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Remember me'));
    await _settle(tester);
    expect(value, isTrue);
    final box = _semantics(tester, CalseeCheckbox);
    expect(box.label, 'Remember me');
    expect(box.checked, isTrue);
    await tester.tap(find.byType(CalseeKey));
    await _settle(tester);
    expect(value, isFalse);
  });

  testWidgets('a disabled checkbox ignores taps', (tester) async {
    await tester.pumpWidget(
      _app(const CalseeCheckbox(value: false, label: 'Off', onChanged: null)),
    );
    await tester.tap(find.text('Off'));
    await _settle(tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets('radio buttons choose their value', (tester) async {
    var group = 'card';
    await tester.pumpWidget(
      _app(
        StatefulBuilder(
          builder: (context, setState) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final method in ['card', 'upi'])
                CalseeRadio<String>(
                  value: method,
                  groupValue: group,
                  label: method,
                  onChanged: (v) => setState(() => group = v),
                ),
            ],
          ),
        ),
      ),
    );
    await tester.tap(find.text('upi'));
    await _settle(tester);
    expect(group, 'upi');
  });

  testWidgets('switch toggles and reports its state', (tester) async {
    var on = false;
    await tester.pumpWidget(
      _app(
        StatefulBuilder(
          builder: (context, setState) => CalseeSwitch(
            value: on,
            label: 'Haptics',
            onChanged: (v) => setState(() => on = v),
          ),
        ),
      ),
    );
    await tester.tap(find.byType(CalseeKey));
    await _settle(tester);
    expect(on, isTrue);
    final toggle = _semantics(tester, CalseeSwitch);
    expect(toggle.label, 'Haptics');
    expect(toggle.toggled, isTrue);
  });

  testWidgets('segmented control calls back with the tapped value', (
    tester,
  ) async {
    int? chosen;
    await tester.pumpWidget(
      _app(
        CalseeSegmented<int>(
          options: const [(1, 'Day'), (7, 'Week'), (30, 'Month')],
          selected: 1,
          onChanged: (v) => chosen = v,
        ),
      ),
    );
    await tester.tap(find.bySemanticsLabel('Week'));
    await _settle(tester);
    expect(chosen, 7);
  });

  testWidgets('slider follows taps and snaps to divisions', (tester) async {
    double? value;
    await tester.pumpWidget(
      _app(
        CalseeSlider(
          value: 0,
          max: 100,
          divisions: 10,
          onChanged: (v) => value = v,
        ),
      ),
    );
    final box = tester.getRect(find.byType(CalseeSlider));
    await tester.tapAt(box.center);
    await _settle(tester);
    expect(value, 50);
    await tester.tapAt(box.centerRight - const Offset(1, 0));
    await _settle(tester);
    expect(value, 100);
  });

  testWidgets('dropdown opens a list and chooses an item', (tester) async {
    String? chosen;
    await tester.pumpWidget(
      _app(
        StatefulBuilder(
          builder: (context, setState) => CalseeDropdown<String>(
            items: const [('inr', 'Rupee'), ('usd', 'Dollar')],
            value: chosen,
            hint: 'Currency',
            onChanged: (v) => setState(() => chosen = v),
          ),
        ),
      ),
    );
    expect(find.text('Dollar'), findsNothing);
    await tester.tap(find.text('Currency'));
    await _settle(tester);
    await tester.tap(find.text('Dollar'));
    await _settle(tester);
    expect(chosen, 'usd');
    expect(find.text('Rupee'), findsNothing);
  });

  testWidgets('expandable opens and closes its child', (tester) async {
    final changes = <bool>[];
    await tester.pumpWidget(
      _app(
        CalseeExpandable(
          title: 'Details',
          onExpansionChanged: changes.add,
          child: const SizedBox(height: 80, child: Text('Fee: none')),
        ),
      ),
    );
    final closed = tester.getSize(find.byType(CalseeExpandable)).height;
    await tester.tap(find.text('Details'));
    await _settle(tester);
    final open = tester.getSize(find.byType(CalseeExpandable)).height;
    expect(open, greaterThan(closed + 79));
    await tester.tap(find.text('Details'));
    await _settle(tester);
    expect(changes, [true, false]);
    expect(tester.getSize(find.byType(CalseeExpandable)).height, closed);
  });

  testWidgets('text field takes input and hides its hint', (tester) async {
    final typed = <String>[];
    await tester.pumpWidget(
      _app(CalseeTextField(hint: 'Add a note', onChanged: typed.add)),
    );
    expect(find.text('Add a note'), findsOneWidget);
    await tester.enterText(find.byType(EditableText), 'Dinner');
    await _settle(tester);
    expect(typed.last, 'Dinner');
    expect(find.text('Add a note'), findsNothing);
  });

  testWidgets('every control lays out in every family', (tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    for (final family in ThemeFamily.enabledFamilies) {
      for (var seed = 0; seed < 3; seed++) {
        await tester.pumpWidget(
          _app(
            families: [family],
            seed: seed,
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CalseeCheckbox(value: true, label: 'On', onChanged: (_) {}),
                const CalseeCheckbox(value: false, onChanged: null),
                CalseeRadio<int>(
                  value: 1,
                  groupValue: 1,
                  label: 'One',
                  onChanged: (_) {},
                ),
                CalseeSwitch(value: true, label: 'On', onChanged: (_) {}),
                const CalseeSwitch(value: false, onChanged: null),
                CalseeSegmented<int>(
                  options: const [(1, 'Day'), (7, 'Week'), (30, 'Month')],
                  selected: 7,
                  onChanged: (_) {},
                ),
                CalseeSlider(value: 0.3, onChanged: (_) {}),
                CalseeDropdown<int>(
                  items: const [(1, 'One'), (2, 'Two')],
                  value: 2,
                  onChanged: (_) {},
                ),
                const CalseeExpandable(
                  title: 'More',
                  initiallyExpanded: true,
                  child: SizedBox(height: 20),
                ),
                const CalseeTextField(hint: 'Note'),
              ],
            ),
          ),
        );
        await _settle(tester);
        expect(tester.takeException(), isNull, reason: '$family seed $seed');
      }
    }
  });
}
