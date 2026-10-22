import 'package:calsee_themes_example/gallery/app.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Whether a code panel showing [needle] is on screen.
bool _codeShown(WidgetTester tester, String needle) => tester
    .widgetList<RichText>(find.byType(RichText))
    .any((t) => t.text.toPlainText().contains(needle));

// The backdrops animate forever, so pump a fixed time instead of settling.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 20; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  testWidgets('every gallery page shows its source, across theme changes', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const GalleryApp());
    await _settle(tester);
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));

    // The home page's previews lay out in every family without overflow.
    for (var i = 0; i < 24; i++) {
      await tester.tap(find.bySemanticsLabel('Next theme').last);
      await _settle(tester);
    }

    for (final entry in galleryEntries) {
      const needle = "import 'package:";
      navigator.pushNamed(entry.route).ignore();
      await _settle(tester);
      expect(_codeShown(tester, needle), isTrue, reason: entry.route);

      // Change the theme 30 times: the source stays, and nothing overflows.
      for (var i = 0; i < 30; i++) {
        // The page below keeps its own theme bar; tap the top one.
        await tester.tap(find.bySemanticsLabel('Next theme').last);
        await _settle(tester);
        expect(_codeShown(tester, needle), isTrue, reason: '${entry.route} $i');
      }
      navigator.pop();
      await _settle(tester);
    }
  });
}
