/// The AC key's own colours (`clear_key.dart`, `ThemeSpec.clearKey`).
///
/// The derivation is frozen for engine versions 1–5: clear_keys.json pins
/// its literal output for every family, the Accessible lock, steering and
/// heroes. Regenerate it only together with an engine version bump:
///
///     UPDATE_CLEAR_GOLDENS=1 dart test test/engine/clear_key_test.dart
@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io';

import 'package:calsee_themes/engine/clear_key.dart';
import 'package:calsee_themes/engine/contrast.dart';
import 'package:calsee_themes/engine/families.dart';
import 'package:calsee_themes/engine/generator.dart';
import 'package:calsee_themes/engine/heroes.dart';
import 'package:calsee_themes/engine/oklab.dart';
import 'package:calsee_themes/engine/theme_intent.dart';
import 'package:calsee_themes/engine/theme_spec.dart';
import 'package:test/test.dart';

const String fixturePath = 'test/engine/fixtures/clear_keys.json';

const ThemeGenerator gen = ThemeGenerator();

final List<ThemeFamily> enabled = [
  for (final f in ThemeFamily.values)
    if (f.enabled) f,
];

final List<ThemeIntent> intents = [
  ThemeIntent(colors: const [IntentColor.red]),
  ThemeIntent(colors: const [IntentColor.orange, IntentColor.pink]),
  ThemeIntent(chroma: IntentChroma.muted),
  ThemeIntent(
    colors: const [IntentColor.blue],
    brightness: ThemeBrightness.dark,
  ),
];

/// One pinned case: generator inputs (or a hero) and the expected colours.
Map<String, Object?> caseInputs({
  required ThemeFamily family,
  required int seed,
  int version = currentEngineVersion,
  bool accessible = false,
  ThemeIntent? intent,
  bool hero = false,
}) => {
  'family': family.id,
  'seed': seed,
  'engineVersion': version,
  'accessible': accessible,
  if (intent != null) 'intent': intent.toJson(),
  if (hero) 'hero': true,
};

ThemeSpec specOf(Map<String, Object?> c) {
  final family = ThemeFamily.fromId(c['family']! as int)!;
  final seed = c['seed']! as int;
  final accessible = c['accessible']! as bool;
  if (c['hero'] == true) {
    return heroFallback(seed, family, accessible: accessible);
  }
  return gen.generate(
    seed,
    family,
    c['engineVersion']! as int,
    accessible: accessible,
    intent: c['intent'] == null ? null : ThemeIntent.fromJson(c['intent']),
  );
}

List<Map<String, Object?>> pinnedCases() => [
  for (final f in enabled) ...[
    for (final seed in [1, 2, 3]) caseInputs(family: f, seed: seed),
    caseInputs(family: f, seed: 4, accessible: true),
    caseInputs(family: f, seed: 5, intent: intents[f.id % intents.length]),
    caseInputs(family: f, seed: 6, hero: true),
    caseInputs(family: f, seed: 7, hero: true, accessible: true),
    for (final v in supportedEngineVersions)
      if (v != currentEngineVersion && familyShippedAt(f, v))
        caseInputs(family: f, seed: 8, version: v),
  ],
];

void main() {
  test('pinned AC colours (clear_keys.json)', () {
    final cases = [
      for (final c in pinnedCases())
        {...c, 'clear': clearKeyColors(specOf(c)).toJson()},
    ];
    final file = File(fixturePath);
    if (Platform.environment['UPDATE_CLEAR_GOLDENS'] == '1') {
      file.writeAsStringSync(
        '${const JsonEncoder.withIndent('  ').convert({'cases': cases})}\n',
      );
    }
    final pinned =
        (jsonDecode(file.readAsStringSync()) as Map)['cases'] as List;
    expect(pinned, hasLength(cases.length));
    for (final p in pinned.cast<Map<String, Object?>>()) {
      final spec = specOf(p);
      expect(
        spec.clearKey,
        KeyColors.fromJson(p['clear']),
        reason: '${spec.family.name} seed ${p['seed']} v${p['engineVersion']}',
      );
    }
  });

  test('every family has a passing AC key in every kind of theme', () {
    var themes = 0;
    final y2kScores = <double>[];
    void check(ThemeSpec spec, String what) {
      themes++;
      final clear = spec.clearKey;
      final violations = clearKeyViolations(spec, clear);
      final reason = '$what ${spec.family.name} seed ${spec.seed}: $violations';
      // Labels and the family's own rules always hold.
      expect(violations.where((v) => v != 'distinct'), isEmpty, reason: reason);
      final score = clearKeyDistinctness(spec, clear);
      if (spec.family == ThemeFamily.y2kChrome) {
        // Y2K gels stay in a light band (L ≥ 0.735): see clear_key.dart.
        y2kScores.add(score);
        expect(score, greaterThanOrEqualTo(clearFallbackScore), reason: reason);
      } else if (spec.variant == ThemeVariant.steered) {
        expect(score, greaterThanOrEqualTo(0.9), reason: reason);
      } else {
        expect(violations, isEmpty, reason: reason);
      }
    }

    for (final f in enabled) {
      for (var seed = 1; seed <= 24; seed++) {
        for (final accessible in [false, true]) {
          check(
            gen.generate(seed, f, currentEngineVersion, accessible: accessible),
            'v5',
          );
          check(
            gen.generate(
              seed,
              f,
              currentEngineVersion,
              accessible: accessible,
              intent: intents[seed % intents.length],
            ),
            'steered',
          );
        }
      }
      for (var seed = 0; seed < heroesFor(f).length; seed++) {
        check(heroFallback(seed, f), 'hero');
        check(heroFallback(seed, f, accessible: true), 'accessible hero');
      }
      for (final v in supportedEngineVersions) {
        if (familyShippedAt(f, v)) check(gen.generate(9, f, v), 'v$v');
      }
    }
    expect(themes, greaterThan(1000));
    final y2kPassing = y2kScores.where((s) => s >= 1).length;
    expect(y2kPassing / y2kScores.length, greaterThan(0.75));
  });

  test('the Accessible lock holds AC labels to 7:1', () {
    for (final f in enabled) {
      for (var seed = 1; seed <= 6; seed++) {
        final spec = gen.generate(
          seed,
          f,
          currentEngineVersion,
          accessible: true,
        );
        final clear = spec.clearKey;
        if (((clear.face >>> 24) & 0xFF) == 255) {
          expect(
            contrastRatio(clear.label, clear.face),
            greaterThanOrEqualTo(ratioAccessible),
            reason: '${f.name} $seed',
          );
        }
        expect(clearKeyViolations(spec, clear), isNot(contains('label')));
      }
    }
  });

  test('AC is a warm alert colour in most themes', () {
    var warm = 0;
    var total = 0;
    for (final f in enabled) {
      if (f == ThemeFamily.bauhaus) continue; // Bauhaus uses its primaries.
      for (var seed = 1; seed <= 20; seed++) {
        final h = argbToOklch(
          gen.generate(seed, f, currentEngineVersion).clearKey.face,
        ).h;
        total++;
        if (h >= 340 || h <= 75) warm++;
      }
    }
    expect(warm / total, greaterThan(0.75));
  });

  test('AC colours are deterministic and outside the spec JSON', () {
    for (final f in enabled) {
      final a = gen.generate(42, f, currentEngineVersion);
      final b = ThemeSpec.fromJson(jsonDecode(jsonEncode(a.toJson())));
      expect(b.clearKey, a.clearKey, reason: f.name);
      expect(jsonEncode(a.toJson()), isNot(contains('clear')));
      expect(a.toJson()['palette'], b.toJson()['palette']);
    }
  });

  test('Bauhaus AC is one of its primaries, never the accent mark', () {
    for (var seed = 1; seed <= 12; seed++) {
      final spec = gen.generate(
        seed,
        ThemeFamily.bauhaus,
        currentEngineVersion,
      );
      final h = argbToOklch(spec.clearKey.face).h;
      final near = [31, 90, 266].any((p) => (h - p).abs() < 12);
      expect(near, isTrue, reason: 'seed $seed hue $h');
    }
  });

  test('glass AC keeps the template alpha when it can', () {
    var translucent = 0;
    for (var seed = 1; seed <= 12; seed++) {
      final spec = gen.generate(
        seed,
        ThemeFamily.liquidGlass,
        currentEngineVersion,
      );
      final a = (spec.clearKey.face >>> 24) & 0xFF;
      if (a == (spec.palette.operator.face >>> 24) & 0xFF) translucent++;
    }
    expect(translucent, 12);
  });

  test('ink and rim edges stay; face-following edges turn', () {
    for (final f in enabled) {
      final spec = gen.generate(3, f, currentEngineVersion);
      final template = switch (clearTemplateOf(f)) {
        ClearTemplate.operator => spec.palette.operator,
        ClearTemplate.equals => spec.palette.equals,
      };
      if (!clearEdgeTracksFace(f)) {
        expect(spec.clearKey.edge, template.edge, reason: f.name);
      }
    }
  });
}
