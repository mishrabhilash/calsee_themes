/// Steering (engine v4): unsteered v4 equals v3, steered themes honour
/// their intent and pass every guardrail, and steered output is pinned by
/// a golden fixture.
///
///     UPDATE_STEERED_GOLDENS=1 dart test test/engine/steering_test.dart
@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io';

import 'package:calsee_themes/engine/families.dart';
import 'package:calsee_themes/engine/generator.dart';
import 'package:calsee_themes/engine/guardrails.dart';
import 'package:calsee_themes/engine/oklab.dart';
import 'package:calsee_themes/engine/theme_intent.dart';
import 'package:calsee_themes/engine/theme_spec.dart';
import 'package:test/test.dart';

const gen = ThemeGenerator();

/// Hue (tenths) of [argb].
int hueOf(int argb) => (argbToOklch(argb).h * 10).round() % 3600;

/// Whether [hue] lies in [c]'s range, with [slack] tenths either side.
bool inRange(int hue, IntentColor c, {int slack = 0}) {
  final span = (c.hiTenths - c.loTenths) % 3600;
  return (hue - c.loTenths + slack) % 3600 <= span + 2 * slack;
}

/// Chroma of [argb].
double chromaOf(int argb) => argbToOklch(argb).c;

typedef SteeredCase = ({
  int seed,
  ThemeFamily family,
  Map<String, Object?> intent,
  bool accessible,
  bool centred,
});

const List<SteeredCase> steeredCases = [
  (
    seed: 0,
    family: ThemeFamily.m3Expressive,
    intent: {
      'brightness': 'light',
      'colors': ['green', 'lime'],
      'chroma': 'vivid',
      'harmony': 'analogous',
      'name': 'Playful Greenery',
    },
    accessible: false,
    centred: true,
  ),
  (
    seed: 0xDEADBEEF,
    family: ThemeFamily.m3Expressive,
    intent: {
      'colors': ['navy'],
    },
    accessible: false,
    centred: false,
  ),
  (
    seed: 12345,
    family: ThemeFamily.m3Expressive,
    intent: {
      'colors': ['grey', 'coral'],
    },
    accessible: true,
    centred: false,
  ),
  (
    seed: 7,
    family: ThemeFamily.neoPop,
    intent: {
      'colors': ['teal', 'coral', 'gold'],
      'chroma': 'balanced',
    },
    accessible: false,
    centred: false,
  ),
  (
    seed: 424242,
    family: ThemeFamily.neoPop,
    intent: {
      'harmony': 'duotone',
      'hueRange': [300, 330],
    },
    accessible: true,
    centred: true,
  ),
  (
    seed: 5,
    family: ThemeFamily.claymorphism,
    intent: {
      'colors': ['lavender'],
      'name': 'Soft Lilac',
    },
    accessible: false,
    centred: true,
  ),
  (
    seed: 0xA5A5A5A5,
    family: ThemeFamily.claymorphism,
    intent: {
      'colors': ['yellow'],
      'brightness': 'dark',
    },
    accessible: false,
    centred: false,
  ),
  (
    seed: 99,
    family: ThemeFamily.cyberpunk,
    intent: {
      'colors': ['red'],
      'name': 'Red Line',
    },
    accessible: false,
    centred: false,
  ),
];

void main() {
  group('unsteered v4', () {
    test('equals v3 apart from the version number, every family', () {
      for (final f in ThemeFamily.enabledFamilies) {
        for (var s = 0; s < 40; s++) {
          final seed = s * 2654435761 & 0xFFFFFFFF;
          for (final accessible in [false, true]) {
            final v3 = gen.generate(seed, f, 3, accessible: accessible);
            final v4 = gen.generate(seed, f, 4, accessible: accessible);
            expect(
              v4,
              v3.copyWith(engineVersion: 4),
              reason: '${f.name} $seed',
            );
          }
        }
      }
    });

    test('an empty intent is no intent', () {
      final plain = gen.generate(3, ThemeFamily.m3Expressive, 4);
      expect(
        gen.generate(3, ThemeFamily.m3Expressive, 4, intent: ThemeIntent.none),
        plain,
      );
      expect(
        gen.generate(
          3,
          ThemeFamily.m3Expressive,
          4,
          intent: ThemeIntent(families: const [ThemeFamily.neoPop]),
        ),
        plain,
      );
    });
  });

  group('contract', () {
    test('steering needs engine v4', () {
      expect(
        () => gen.generate(
          1,
          ThemeFamily.m3Expressive,
          3,
          intent: ThemeIntent(colors: const [IntentColor.red]),
        ),
        throwsArgumentError,
      );
    });

    test('a theme is either wallpaper or steered', () {
      expect(
        () => gen.generate(
          1,
          ThemeFamily.m3Expressive,
          4,
          seedHueTenths: 1200,
          intent: ThemeIntent(colors: const [IntentColor.red]),
        ),
        throwsArgumentError,
      );
    });

    test('steered specs are marked, carry the intent, and round-trip', () {
      final intent = ThemeIntent(
        families: const [ThemeFamily.neoPop],
        colors: const [IntentColor.teal],
        name: 'Deep Lagoon',
      );
      final spec = gen.generate(11, ThemeFamily.neoPop, 4, intent: intent);
      expect(spec.variant, ThemeVariant.steered);
      expect(spec.intent, ThemeIntent(colors: const [IntentColor.teal]));
      expect(spec.name, 'Deep Lagoon');
      expect(spec.intentCentred, isFalse);
      expect(ThemeSpec.fromJson(spec.toJson()), spec);
      expect(ThemeSpec.fromJsonString(spec.toJsonString()), spec);
      final centred = gen.generate(
        11,
        ThemeFamily.neoPop,
        4,
        intent: intent,
        intentCentred: true,
      );
      expect(centred.intentCentred, isTrue);
      expect(centred, isNot(spec));
      expect(ThemeSpec.fromJson(centred.toJson()), centred);
    });

    test('deterministic', () {
      for (final c in steeredCases) {
        final intent = ThemeIntent.fromJson(c.intent);
        ThemeSpec run() => gen.generate(
          c.seed,
          c.family,
          4,
          intent: intent,
          accessible: c.accessible,
          intentCentred: c.centred,
        );
        expect(run().toJsonString(), run().toJsonString());
      }
    });

    test('non-steerable families keep their look and take the name', () {
      final plain = gen.generate(8, ThemeFamily.bauhaus, 4);
      final steered = gen.generate(
        8,
        ThemeFamily.bauhaus,
        4,
        intent: ThemeIntent(colors: const [IntentColor.green], name: 'Lawn'),
      );
      expect(steered.palette, plain.palette);
      expect(steered.name, 'Lawn');
      expect(steered.variant, ThemeVariant.steered);
    });

    test('without a name the generated name stays', () {
      final plain = gen.generate(21, ThemeFamily.m3Expressive, 4);
      final steered = gen.generate(
        21,
        ThemeFamily.m3Expressive,
        4,
        intent: ThemeIntent(chroma: IntentChroma.balanced),
      );
      expect(steered.name, isNotEmpty);
      expect(steered.variant, ThemeVariant.steered);
      expect(plain.variant, ThemeVariant.generated);
    });
  });

  group('honours the intent', () {
    const families = [
      ThemeFamily.m3Expressive,
      ThemeFamily.neoPop,
      ThemeFamily.claymorphism,
    ];

    test('every steered theme passes the guardrails', () {
      final intents = [
        for (final c in IntentColor.values)
          for (final b in [null, ...ThemeBrightness.values])
            ThemeIntent(colors: [c], brightness: b),
        for (final ch in IntentChroma.values)
          for (final h in HarmonyScheme.values)
            ThemeIntent(chroma: ch, harmony: h),
        ThemeIntent(colors: const [IntentColor.teal, IntentColor.coral]),
        ThemeIntent(hueRange: (350, 20), chroma: IntentChroma.vivid),
      ];
      for (final f in families) {
        for (var i = 0; i < intents.length; i++) {
          for (var s = 0; s < 6; s++) {
            final accessible = s.isOdd;
            final spec = gen.generate(
              s * 7919 + i,
              f,
              4,
              intent: intents[i],
              accessible: accessible,
              intentCentred: s == 0,
            );
            if (spec.variant == ThemeVariant.hero) continue;
            expect(
              validateTheme(
                spec,
                limits: accessible
                    ? GuardrailLimits.accessible
                    : GuardrailLimits.standard,
              ),
              isEmpty,
              reason: '${f.name} ${intents[i]} seed ${s * 7919 + i}',
            );
          }
        }
      }
    });

    test('rarely falls back to a hero', () {
      var fallbacks = 0;
      var total = 0;
      for (final f in families) {
        for (final c in IntentColor.values) {
          for (final b in ThemeBrightness.values) {
            for (var s = 0; s < 8; s++) {
              total++;
              final spec = gen.generate(
                s * 104729 + 3,
                f,
                4,
                intent: ThemeIntent(colors: [c], brightness: b),
              );
              if (spec.variant == ThemeVariant.hero) fallbacks++;
            }
          }
        }
      }
      expect(fallbacks, lessThan(total ~/ 100), reason: '$fallbacks/$total');
    });

    test('brightness wins where the family can draw it', () {
      for (final f in families) {
        for (final b in ThemeBrightness.values) {
          if (!brightnessAllowed(f.definition, b)) continue;
          for (var s = 0; s < 30; s++) {
            final spec = gen.generate(
              s,
              f,
              4,
              intent: ThemeIntent(brightness: b),
            );
            expect(spec.brightness, b, reason: '${f.name} $s');
          }
        }
      }
    });

    test('a colour leans brightness, but an explicit one wins', () {
      for (var s = 0; s < 20; s++) {
        expect(
          gen
              .generate(
                s,
                ThemeFamily.m3Expressive,
                4,
                intent: ThemeIntent(colors: const [IntentColor.navy]),
              )
              .brightness,
          ThemeBrightness.dark,
        );
        expect(
          gen
              .generate(
                s,
                ThemeFamily.m3Expressive,
                4,
                intent: ThemeIntent(
                  colors: const [IntentColor.navy],
                  brightness: ThemeBrightness.light,
                ),
              )
              .brightness,
          ThemeBrightness.light,
        );
      }
    });

    test('the base colour sets the M3E and NeoPOP base hue', () {
      for (final f in [ThemeFamily.m3Expressive, ThemeFamily.neoPop]) {
        for (final c in [
          IntentColor.green,
          IntentColor.blue,
          IntentColor.coral,
          IntentColor.purple,
        ]) {
          var hits = 0;
          for (var s = 0; s < 40; s++) {
            final spec = gen.generate(
              s,
              f,
              4,
              intent: ThemeIntent(colors: [c], chroma: IntentChroma.vivid),
            );
            if (inRange(hueOf(spec.palette.digit.face), c, slack: 60)) hits++;
          }
          expect(hits, greaterThan(30), reason: '${f.name} ${c.word} $hits');
        }
      }
    });

    test('accent colours set the operator hue', () {
      var hits = 0;
      for (var s = 0; s < 40; s++) {
        final spec = gen.generate(
          s,
          ThemeFamily.m3Expressive,
          4,
          intent: ThemeIntent(
            colors: const [IntentColor.teal, IntentColor.coral],
          ),
        );
        if (inRange(
          hueOf(spec.palette.operator.face),
          IntentColor.coral,
          slack: 80,
        )) {
          hits++;
        }
      }
      expect(hits, greaterThan(30), reason: '$hits');
    });

    test('Claymorphism keeps the body on its own anchors', () {
      var hits = 0;
      for (var s = 0; s < 40; s++) {
        final spec = gen.generate(
          s,
          ThemeFamily.claymorphism,
          4,
          intent: ThemeIntent(colors: const [IntentColor.mint]),
        );
        if (inRange(
          hueOf(spec.palette.background),
          IntentColor.mint,
          slack: 60,
        )) {
          hits++;
        }
      }
      expect(hits, greaterThan(30), reason: '$hits');
    });

    test('muted is quieter than vivid', () {
      for (final f in families) {
        var muted = 0.0;
        var vivid = 0.0;
        for (var s = 0; s < 40; s++) {
          double c(IntentChroma level) => chromaOf(
            gen
                .generate(
                  s,
                  f,
                  4,
                  intent: ThemeIntent(
                    colors: const [IntentColor.blue],
                    chroma: level,
                  ),
                )
                .palette
                .operator
                .face,
          );
          muted += c(IntentChroma.muted);
          vivid += c(IntentChroma.vivid);
        }
        expect(muted, lessThan(vivid * 0.85), reason: f.name);
      }
    });

    test('a grey base quiets the digit keys', () {
      var grey = 0.0;
      var plain = 0.0;
      for (var s = 0; s < 40; s++) {
        grey += chromaOf(
          gen
              .generate(
                s,
                ThemeFamily.m3Expressive,
                4,
                intent: ThemeIntent(
                  colors: const [IntentColor.grey],
                  brightness: ThemeBrightness.light,
                ),
              )
              .palette
              .digit
              .face,
        );
        plain += chromaOf(
          gen
              .generate(
                s,
                ThemeFamily.m3Expressive,
                4,
                intent: ThemeIntent(brightness: ThemeBrightness.light),
              )
              .palette
              .digit
              .face,
        );
      }
      expect(grey, lessThan(plain * 0.5));
    });

    test('an explicit harmony is used when the family has it', () {
      for (var s = 0; s < 20; s++) {
        final spec = gen.generate(
          s,
          ThemeFamily.m3Expressive,
          4,
          intent: ThemeIntent(
            colors: const [IntentColor.red],
            harmony: HarmonyScheme.monochrome,
          ),
        );
        // Monochrome: the operator sits on the base hue (± bile moves).
        final d =
            (hueOf(spec.palette.operator.face) - hueOf(spec.palette.digit.face))
                .abs() %
            3600;
        expect(d > 1800 ? 3600 - d : d, lessThan(200), reason: '$s');
      }
    });

    test('centred themes sit at the middle of the base colour', () {
      for (final f in [ThemeFamily.m3Expressive, ThemeFamily.neoPop]) {
        final spec = gen.generate(
          77,
          f,
          4,
          intent: ThemeIntent(colors: const [IntentColor.blue]),
          intentCentred: true,
        );
        final mid =
            (IntentColor.blue.loTenths + IntentColor.blue.hiTenths) ~/ 2;
        final d = (hueOf(spec.palette.digit.face) - mid).abs();
        expect(d, lessThan(120), reason: f.name);
      }
    });

    test('the fallback is the hero nearest the intent', () {
      const tiny = ThemeGenerator(maxAttempts: 0);
      final spec = tiny.generate(
        3,
        ThemeFamily.neoPop,
        4,
        intent: ThemeIntent(colors: const [IntentColor.yellow]),
      );
      expect(spec.variant, ThemeVariant.hero);
      expect(spec.family, ThemeFamily.neoPop);
      final light = tiny.generate(
        3,
        ThemeFamily.m3Expressive,
        4,
        intent: ThemeIntent(brightness: ThemeBrightness.light),
      );
      expect(light.brightness, ThemeBrightness.light);
    });
  });

  test('steered generation p99 < 2 ms', tags: 'perf', () {
    final intents = [
      ThemeIntent(colors: const [IntentColor.green, IntentColor.lime]),
      ThemeIntent(colors: const [IntentColor.navy], chroma: IntentChroma.muted),
      ThemeIntent(
        colors: const [IntentColor.yellow],
        brightness: ThemeBrightness.dark,
      ),
      ThemeIntent(harmony: HarmonyScheme.triadic, chroma: IntentChroma.vivid),
    ];
    const families = [
      ThemeFamily.m3Expressive,
      ThemeFamily.neoPop,
      ThemeFamily.claymorphism,
    ];
    for (var s = 0; s < 100; s++) {
      gen.generate(s, ThemeFamily.claymorphism, 4, intent: intents[s % 4]);
    }
    final times = <int>[];
    final sw = Stopwatch()..start();
    for (var s = 0; s < 400; s++) {
      for (final f in families) {
        for (final i in intents) {
          final t0 = sw.elapsedMicroseconds;
          gen.generate(s + 5000, f, 4, intent: i, accessible: s.isOdd);
          times.add(sw.elapsedMicroseconds - t0);
        }
      }
    }
    times.sort();
    final p99 = times[times.length * 99 ~/ 100];
    expect(p99, lessThan(2000), reason: 'p99 $p99 µs');
  });

  test('golden JSON fixture (steered v4)', () {
    const path = 'test/engine/fixtures/steered_v4.json';
    Map<String, Object?> caseJson(SteeredCase c) {
      final spec = gen.generate(
        c.seed,
        c.family,
        4,
        accessible: c.accessible,
        intent: ThemeIntent.fromJson(c.intent),
        intentCentred: c.centred,
      );
      return {
        'seed': c.seed,
        'family': c.family.id,
        'intent': c.intent,
        'accessible': c.accessible,
        'centred': c.centred,
        'hash': spec.stableHash.toRadixString(16).padLeft(8, '0'),
        'spec': spec.toJson(),
      };
    }

    final file = File(path);
    // Frozen: v4 is released (2.0.0); only the current version rewrites.
    if (Platform.environment['UPDATE_STEERED_GOLDENS'] == '1' &&
        currentEngineVersion == 4) {
      file.writeAsStringSync(
        '${const JsonEncoder.withIndent('  ').convert({
          'engineVersion': 4,
          'cases': [for (final c in steeredCases) caseJson(c)],
        })}\n',
      );
    }
    final fixture = jsonDecode(file.readAsStringSync()) as Map<String, Object?>;
    expect(fixture['engineVersion'], 4);
    final cases = (fixture['cases']! as List).cast<Map<String, Object?>>();
    expect(cases, hasLength(steeredCases.length));
    for (var i = 0; i < cases.length; i++) {
      final want = cases[i];
      final got = caseJson(steeredCases[i]);
      expect(
        jsonEncode(got['spec']),
        jsonEncode(want['spec']),
        reason: 'case $i',
      );
      expect(got['hash'], want['hash'], reason: 'case $i');
      expect(
        ThemeSpec.fromJson(want['spec']).toJsonString(),
        jsonEncode(want['spec']),
      );
    }
  });
}
