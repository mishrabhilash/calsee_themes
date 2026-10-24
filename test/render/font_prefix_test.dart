/// Fonts are registered only under `packages/calsee_themes/<family>`, so a
/// bare family name in `lib/` silently falls back to the platform font in
/// every app (1.1.1: Vaporwave's π and maths glyphs).
@TestOn('vm')
library;

import 'dart:io';

import 'package:calsee_themes/render/fonts.dart';
import 'package:calsee_themes/render/vaporwave/vaporwave_key_face.dart';
import 'package:test/test.dart';

/// The `family:` names declared in pubspec.yaml.
List<String> declaredFamilies() => [
  for (final m in RegExp(
    r'^\s*-\s*family:\s*(\S+)\s*$',
    multiLine: true,
  ).allMatches(File('pubspec.yaml').readAsStringSync()))
    m.group(1)!,
];

void main() {
  test('pubspec declares the bundled fonts', () {
    expect(declaredFamilies(), contains('RobotoFlex'));
  });

  test('no bare bundled family name in lib/', () {
    final families = declaredFamilies();
    final bare = RegExp(
      '[\'"](${families.map(RegExp.escape).join('|')})[\'"]',
    );
    final offenders = <String>[];
    for (final f in Directory('lib').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      final lines = f.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (bare.hasMatch(lines[i])) offenders.add('${f.path}:${i + 1}');
      }
    }
    expect(offenders, isEmpty, reason: 'use fontPackagePrefix');
  });

  test('every bundled family and fallback carries the prefix', () {
    for (final font in BundledFont.values) {
      final family = font.family;
      if (family != null) expect(family, startsWith(fontPackagePrefix));
    }
    for (final family in [...scriptFallbackFonts, ...vaporwaveFontFallback]) {
      expect(family, startsWith(fontPackagePrefix));
    }
  });
}
