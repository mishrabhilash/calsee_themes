/// Golden JSON fixtures, one per supported engine version (design doc
/// "Rules": any change to generator output needs an engineVersion bump
/// plus a fixture proving old versions still reproduce).
///
/// Writes only the fixture of [currentEngineVersion], and only together
/// with an engineVersion bump (older fixtures are frozen):
///
///     UPDATE_ENGINE_GOLDENS=1 dart test test/themes/engine/generator_golden_test.dart
@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io';

import 'package:calsee_themes/engine/generator.dart';
import 'package:calsee_themes/engine/theme_spec.dart';
import 'package:test/test.dart';

import 'generator_golden_cases.dart';

String fixturePath(int version) =>
    'test/engine/fixtures/generator_v$version.json';

void main() {
  const gen = ThemeGenerator();
  for (final version in supportedEngineVersions) {
    test('fixture v$version', () => checkFixture(gen, version));
  }
}

void checkFixture(ThemeGenerator gen, int version) {
  Map<String, Object?> caseJson(GoldenCase c) {
    final spec = gen.generate(
      c.seed,
      c.family,
      version,
      accessible: c.accessible,
    );
    return {
      'seed': c.seed,
      'family': c.family.id,
      'accessible': c.accessible,
      'hash': spec.stableHash.toRadixString(16).padLeft(8, '0'),
      'spec': spec.toJson(),
    };
  }

  {
    final file = File(fixturePath(version));
    if (Platform.environment['UPDATE_ENGINE_GOLDENS'] == '1' &&
        version == currentEngineVersion) {
      file
        ..createSync(recursive: true)
        ..writeAsStringSync(
          '${const JsonEncoder.withIndent('  ').convert({
            'engineVersion': version,
            'cases': [for (final c in goldenCases) caseJson(c)],
          })}\n',
        );
    }
    final fixture = jsonDecode(file.readAsStringSync()) as Map<String, Object?>;
    expect(fixture['engineVersion'], version);
    final cases = (fixture['cases']! as List).cast<Map<String, Object?>>();
    expect(cases, hasLength(goldenCases.length));
    for (var i = 0; i < cases.length; i++) {
      final want = cases[i];
      final c = goldenCases[i];
      expect(want['seed'], c.seed);
      final spec = gen.generate(
        c.seed,
        c.family,
        version,
        accessible: c.accessible,
      );
      // Byte-identical canonical JSON and the stable hash.
      expect(
        spec.toJsonString(),
        jsonEncode(want['spec']),
        reason: 'case $i (${c.family.name}, ${c.seed})',
      );
      expect(spec.stableHash.toRadixString(16).padLeft(8, '0'), want['hash']);
      // And the stored JSON decodes back to the same spec.
      expect(ThemeSpec.fromJson(want['spec']), spec);
    }
  }
}
