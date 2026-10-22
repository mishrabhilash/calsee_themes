// Renders the README / pub.dev illustrations: the demo once per family,
// and the frames of a theme swipe. Not part of the test suite; run
//   flutter test screenshots/screenshots_test.dart --update-goldens
// from example/, then `python3 screenshots/compose.py`.
@Tags(['screenshots'])
library;

import 'dart:io';

import 'package:calsee_themes/calsee_themes.dart';
import 'package:calsee_themes/render/fonts.dart';
import 'package:calsee_themes_example/main.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

const _size = Size(390, 844);

Future<void> _loadFonts() async {
  for (final MapEntry(key: family, value: asset) in bundledFontAssets.entries) {
    await (FontLoader(family)..addFont(rootBundle.load(asset))).load();
  }
  // Text the demo leaves to the platform font, and the backspace icon.
  final cache = '${Platform.environment['FLUTTER_ROOT']}/bin/cache/artifacts';
  Future<ByteData> file(String path) async =>
      ByteData.sublistView(await File('$cache/$path').readAsBytes());
  await (FontLoader(
    'MaterialIcons',
  )..addFont(file('material_fonts/MaterialIcons-Regular.otf'))).load();
  await (FontLoader('Roboto')
        ..addFont(file('material_fonts/Roboto-Regular.ttf'))
        ..addFont(file('material_fonts/Roboto-Medium.ttf')))
      .load();
}

Widget _app(CalseeThemeController controller) => WidgetsApp(
  color: const Color(0xFF000000),
  debugShowCheckedModeBanner: false,
  builder: (context, _) => DefaultTextStyle(
    style: const TextStyle(fontFamily: 'Roboto'),
    child: CalseeScope(controller: controller, child: const MathsGameScreen()),
  ),
);

Future<void> _type(WidgetTester tester, String keys) async {
  for (final k in keys.split('')) {
    await tester.tap(find.bySemanticsLabel(k == '<' ? 'Delete' : k).last);
    await tester.pump(const Duration(milliseconds: 300));
  }
}

void main() {
  setUpAll(_loadFonts);

  for (final family in ThemeFamily.enabledFamilies) {
    testWidgets('family ${family.name}', (tester) async {
      tester.view
        ..physicalSize = _size * 3
        ..devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final controller = CalseeThemeController(
        families: [family],
        seed: 7,
      );
      await tester.pumpWidget(_app(controller));
      await _type(tester, '12');
      await tester.pump(const Duration(seconds: 2));
      await expectLater(
        find.byType(MathsGameScreen),
        matchesGoldenFile('out/family_${family.name}.png'),
      );
    });
  }

  testWidgets('swipe frames', (tester) async {
    tester.view
      ..physicalSize = _size * 2
      ..devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final controller = CalseeThemeController(
      families: const [
        ThemeFamily.claymorphism,
        ThemeFamily.liquidGlass,
        ThemeFamily.neoPop,
        ThemeFamily.retro,
        ThemeFamily.cyberpunk,
        ThemeFamily.paperInk,
      ],
      seed: 11,
    );
    await tester.pumpWidget(_app(controller));
    await _type(tester, '12');
    await tester.pump(const Duration(seconds: 1));
    var frame = 0;
    Future<void> shoot() => expectLater(
      find.byType(MathsGameScreen),
      matchesGoldenFile(
        'out/swipe/frame_${(frame++).toString().padLeft(3, '0')}.png',
      ),
    );
    for (var theme = 0; theme < 5; theme++) {
      for (var hold = 0; hold < 8; hold++) {
        await shoot();
        await tester.pump(const Duration(milliseconds: 100));
      }
      controller.next();
      for (var t = 0; t < 420; t += 60) {
        await tester.pump(const Duration(milliseconds: 60));
        await shoot();
      }
    }
  });
}
