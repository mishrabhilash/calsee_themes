/// Steering at engine v5: every family follows an intent's colours,
/// keeps its character, and passes every guardrail; unsteered v5 equals
/// v4. Steered v5 output is pinned by a golden fixture.
///
///     UPDATE_STEERED_GOLDENS=1 dart test test/engine/steering_v5_test.dart
@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io';

import 'package:calsee_themes/engine/bauhaus.dart' show bauhausNeutralMaxChroma;
import 'package:calsee_themes/engine/contrast.dart' show luminanceArgb;
import 'package:calsee_themes/engine/generator.dart';
import 'package:calsee_themes/engine/guardrails.dart';
import 'package:calsee_themes/engine/oklab.dart';
import 'package:calsee_themes/engine/theme_intent.dart';
import 'package:calsee_themes/engine/theme_spec.dart';
import 'package:test/test.dart';

const gen = ThemeGenerator();

int hueOf(int argb) => (argbToOklch(argb | 0xFF000000).h * 10).round() % 3600;

double chromaOf(int argb) => argbToOklch(argb | 0xFF000000).c;

/// Whether [hue] lies in [c]'s range, with [slack] tenths either side.
bool inRange(int hue, IntentColor c, {int slack = 0}) {
  final span = (c.hiTenths - c.loTenths) % 3600;
  return (hue - c.loTenths + slack) % 3600 <= span + 2 * slack;
}

/// Whether [spec] wears [c] on a colourful accent (operator, `=` or accent
/// colour; Claymorphism: also its body).
bool wears(ThemeSpec spec, IntentColor c, {int slack = 80}) {
  final p = spec.palette;
  final keys = [p.operator.face, p.equals.face, p.accent];
  final body = p.background;
  return keys.any(
        (x) => chromaOf(x) > 0.04 && inRange(hueOf(x), c, slack: slack),
      ) ||
      // Claymorphism wears it on its pastel body.
      (spec.family == ThemeFamily.claymorphism &&
          chromaOf(body) > 0.02 &&
          inRange(hueOf(body), c, slack: slack));
}

typedef SteeredCase = ({
  int seed,
  ThemeFamily family,
  Map<String, Object?> intent,
  bool accessible,
  bool centred,
});

const List<SteeredCase> steeredV5Cases = [
  (
    seed: 1,
    family: ThemeFamily.cyberpunk,
    intent: {
      'colors': ['red'],
    },
    accessible: false,
    centred: true,
  ),
  (
    seed: 0xDEADBEEF,
    family: ThemeFamily.vaporwave,
    intent: {
      'colors': ['teal', 'pink'],
      'name': 'Lagoon Dusk',
    },
    accessible: false,
    centred: false,
  ),
  (
    seed: 2,
    family: ThemeFamily.liquidGlass,
    intent: {
      'colors': ['green'],
      'brightness': 'light',
    },
    accessible: true,
    centred: false,
  ),
  (
    seed: 3,
    family: ThemeFamily.neumorphism,
    intent: {
      'colors': ['lavender'],
    },
    accessible: false,
    centred: false,
  ),
  (
    seed: 4,
    family: ThemeFamily.retro,
    intent: {
      'colors': ['blue'],
      'chroma': 'vivid',
    },
    accessible: false,
    centred: false,
  ),
  (
    seed: 5,
    family: ThemeFamily.neoBrutalism,
    intent: {
      'colors': ['coral', 'teal', 'gold'],
    },
    accessible: false,
    centred: false,
  ),
  (
    seed: 6,
    family: ThemeFamily.y2kChrome,
    intent: {
      'colors': ['orange'],
    },
    accessible: false,
    centred: true,
  ),
  (
    seed: 7,
    family: ThemeFamily.paperInk,
    intent: {
      'colors': ['navy'],
    },
    accessible: true,
    centred: false,
  ),
  (
    seed: 8,
    family: ThemeFamily.bauhaus,
    intent: {
      'colors': ['green', 'purple'],
    },
    accessible: false,
    centred: false,
  ),
  (
    seed: 9,
    family: ThemeFamily.claymorphism,
    intent: {
      'colors': ['yellow'],
      'brightness': 'dark',
    },
    accessible: false,
    centred: false,
  ),
  (
    seed: 10,
    family: ThemeFamily.m3Expressive,
    intent: {
      'colors': ['green', 'lime'],
      'brightness': 'light',
      'chroma': 'vivid',
      'harmony': 'analogous',
      'name': 'Playful Greenery',
    },
    accessible: false,
    centred: true,
  ),
  (
    seed: 11,
    family: ThemeFamily.neoPop,
    intent: {
      'colors': ['grey', 'coral'],
    },
    accessible: false,
    centred: false,
  ),
];

const List<IntentColor> probeColours = [
  IntentColor.red,
  IntentColor.green,
  IntentColor.blue,
  IntentColor.yellow,
  IntentColor.purple,
  IntentColor.teal,
];

void main() {
  test('unsteered v5 equals v4 apart from the version number', () {
    for (final f in ThemeFamily.enabledFamilies) {
      for (var s = 0; s < 30; s++) {
        final seed = s * 2654435761 & 0xFFFFFFFF;
        for (final accessible in [false, true]) {
          expect(
            gen.generate(seed, f, 5, accessible: accessible),
            gen
                .generate(seed, f, 4, accessible: accessible)
                .copyWith(engineVersion: 5),
            reason: '${f.name} $seed',
          );
        }
      }
    }
  });

  test('every enabled family is steerable at v5, three at v4', () {
    for (final f in ThemeFamily.enabledFamilies) {
      expect(familySteerableAt(f, 5), isTrue, reason: f.name);
    }
    expect(
      {
        for (final f in ThemeFamily.enabledFamilies)
          if (familySteerableAt(f, 4)) f,
      },
      {ThemeFamily.m3Expressive, ThemeFamily.neoPop, ThemeFamily.claymorphism},
    );
    expect(steerableFamilies, ThemeFamily.enabledFamilies.toSet());
  });

  group('every family', () {
    test('wears the colour and passes every guardrail', () {
      for (final f in ThemeFamily.enabledFamilies) {
        var worn = 0;
        var made = 0;
        for (final c in probeColours) {
          for (var s = 0; s < 6; s++) {
            final accessible = s.isOdd;
            final spec = gen.generate(
              s * 7919 + c.code,
              f,
              5,
              intent: ThemeIntent(colors: [c]),
              accessible: accessible,
              intentCentred: s == 0,
            );
            if (spec.variant == ThemeVariant.hero) continue;
            made++;
            expect(spec.variant, ThemeVariant.steered);
            expect(
              validateTheme(
                spec,
                limits: accessible
                    ? GuardrailLimits.accessible
                    : GuardrailLimits.standard,
              ),
              isEmpty,
              reason: '${f.name} ${c.word} ${s * 7919 + c.code}',
            );
            if (wears(spec, c)) worn++;
          }
        }
        expect(worn, greaterThanOrEqualTo(made * 9 ~/ 10), reason: f.name);
      }
    });

    test('rarely falls back to a hero', () {
      for (final f in ThemeFamily.enabledFamilies) {
        var fallbacks = 0;
        var total = 0;
        for (final c in IntentColor.values) {
          for (final b in ThemeBrightness.values) {
            for (var s = 0; s < 3; s++) {
              total++;
              final spec = gen.generate(
                s * 104729 + c.code,
                f,
                5,
                intent: ThemeIntent(colors: [c], brightness: b),
              );
              if (spec.variant == ThemeVariant.hero) fallbacks++;
            }
          }
        }
        expect(fallbacks, lessThan(total * 4 ~/ 100), reason: f.name);
      }
    });

    test('takes the brightness when it can draw it', () {
      for (final f in ThemeFamily.enabledFamilies) {
        for (final b in ThemeBrightness.values) {
          if (!brightnessAllowed(f.definition, b)) continue;
          for (var s = 0; s < 10; s++) {
            final spec = gen.generate(
              s,
              f,
              5,
              intent: ThemeIntent(
                colors: const [IntentColor.blue],
                brightness: b,
              ),
            );
            if (spec.variant == ThemeVariant.hero) continue;
            expect(spec.brightness, b, reason: '${f.name} $s');
          }
        }
      }
    });

    test('muted is quieter than vivid', () {
      for (final f in ThemeFamily.enabledFamilies) {
        var muted = 0.0;
        var vivid = 0.0;
        for (var s = 0; s < 20; s++) {
          double c(IntentChroma level) => chromaOf(
            gen
                .generate(
                  s,
                  f,
                  5,
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
        expect(muted, lessThan(vivid), reason: f.name);
      }
    });

    test('a second colour sets the = key', () {
      for (final f in ThemeFamily.enabledFamilies) {
        var hits = 0;
        var made = 0;
        for (var s = 0; s < 12; s++) {
          final spec = gen.generate(
            s,
            f,
            5,
            intent: ThemeIntent(
              colors: const [IntentColor.teal, IntentColor.pink],
            ),
          );
          if (spec.variant == ThemeVariant.hero) continue;
          made++;
          final eq = spec.palette.equals.face;
          if (chromaOf(eq) < 0.04 ||
              inRange(hueOf(eq), IntentColor.pink, slack: 100)) {
            hits++;
          }
        }
        expect(hits, greaterThanOrEqualTo(made * 3 ~/ 4), reason: f.name);
      }
    });
  });

  group('places the colours', () {
    const pairs = [
      [IntentColor.red, IntentColor.blue],
      [IntentColor.orange, IntentColor.teal],
      [IntentColor.green, IntentColor.magenta],
      [IntentColor.cyan, IntentColor.magenta],
      [IntentColor.blue, IntentColor.gold],
    ];
    for (final f in ThemeFamily.enabledFamilies) {
      test('${f.name}: first on the operators, second on =', () {
        var first = 0;
        var second = 0;
        var made = 0;
        for (final pair in pairs) {
          for (var s = 0; s < 8; s++) {
            final spec = gen.generate(
              s * 977 + 1,
              f,
              5,
              intent: ThemeIntent(colors: pair),
            );
            if (spec.variant == ThemeVariant.hero) continue;
            made++;
            final p = spec.palette;
            bool on(int argb, IntentColor c, {double min = 0.04}) =>
                chromaOf(argb) > min && inRange(hueOf(argb), c, slack: 80);
            // Claymorphism wears the first colour on its body; Neumorphism's
            // operators share the key surface and carry it in their labels.
            final firstShown = switch (f) {
              ThemeFamily.claymorphism => on(
                p.background,
                pair[0],
                min: 0.02,
              ),
              ThemeFamily.neumorphism =>
                on(p.operator.face, pair[0]) || on(p.operator.label, pair[0]),
              _ => on(p.operator.face, pair[0]),
            };
            if (firstShown) first++;
            if (on(p.equals.face, pair[1]) ||
                (f == ThemeFamily.neumorphism && on(p.equals.label, pair[1]))) {
              second++;
            }
          }
        }
        expect(first, greaterThanOrEqualTo(made * 9 ~/ 10), reason: 'first');
        expect(second, greaterThanOrEqualTo(made * 85 ~/ 100), reason: '=');
      });
    }

    test('a neutral key a colour is meant for takes it', () {
      // Vaporwave's centred dark theme has a white `=`; Retro can draw
      // near-black operators.
      final vapor = gen.generate(
        3,
        ThemeFamily.vaporwave,
        5,
        intent: ThemeIntent.fromJson(const {
          'brightness': 'dark',
          'colors': ['cyan', 'magenta'],
          'chroma': 'vivid',
          'harmony': 'complementary',
        }),
        intentCentred: true,
      );
      expect(
        inRange(
          hueOf(vapor.palette.equals.face),
          IntentColor.magenta,
          slack: 100,
        ),
        isTrue,
      );
      expect(chromaOf(vapor.palette.equals.face), greaterThan(0.05));
      for (var s = 0; s < 8; s++) {
        final retro = gen.generate(
          s * 31 + 3,
          ThemeFamily.retro,
          5,
          intent: ThemeIntent.fromJson(const {
            'brightness': 'light',
            'colors': ['orange', 'brown', 'yellow'],
          }),
        );
        expect(
          chromaOf(retro.palette.operator.face),
          greaterThan(0.04),
          reason: '$s',
        );
        expect(
          inRange(
            hueOf(retro.palette.operator.face),
            IntentColor.orange,
            slack: 100,
          ),
          isTrue,
          reason: '$s',
        );
      }
    });

    test('muted keeps the colour visible', () {
      for (var s = 0; s < 8; s++) {
        final paper = gen.generate(
          s * 31 + 3,
          ThemeFamily.paperInk,
          5,
          intent: ThemeIntent.fromJson(const {
            'brightness': 'light',
            'colors': ['blue', 'sand'],
            'chroma': 'muted',
          }),
        );
        expect(
          chromaOf(paper.palette.operator.face),
          greaterThan(0.025),
          reason: '$s',
        );
      }
    });

    test('only the first colour leans brightness and chroma', () {
      final intent = ThemeIntent(
        colors: const [IntentColor.orange, IntentColor.brown],
      );
      expect(intent.effectiveChroma, isNull);
      expect(intent.v4Chroma, IntentChroma.muted);
    });
  });

  group('keeps the family', () {
    test('"red cyberpunk" is red neon, mostly dark', () {
      var red = 0;
      var dark = 0;
      for (var s = 0; s < 30; s++) {
        final spec = gen.generate(
          s,
          ThemeFamily.cyberpunk,
          5,
          intent: ThemeIntent(colors: const [IntentColor.red]),
        );
        expect(spec.background.kind, BackgroundKind.cyberGrid);
        if (inRange(
          hueOf(spec.palette.operator.face),
          IntentColor.red,
          slack: 80,
        )) {
          red++;
        }
        if (spec.isDark) dark++;
      }
      expect(red, greaterThan(25));
      expect(dark, greaterThan(15));
    });

    test('a warm Cyberpunk keeps its outlines in the warm hues', () {
      final intent = ThemeIntent.fromJson(const {
        'brightness': 'dark',
        'colors': ['red', 'coral', 'orange'],
        'harmony': 'analogous',
      });
      // Red 22° through orange 65°, with slack: no cyan or purple.
      bool warm(int argb) {
        final h = hueOf(argb);
        return h >= 3300 || h <= 950;
      }

      for (var s = 0; s < 12; s++) {
        final spec = gen.generate(
          s * 13 + 5,
          ThemeFamily.cyberpunk,
          5,
          intent: intent,
        );
        if (spec.variant == ThemeVariant.hero) continue;
        final p = spec.palette;
        for (final c in [p.digit.edge, p.function.edge, p.accent]) {
          if (chromaOf(c) < 0.05) continue;
          expect(warm(c), isTrue, reason: 'seed ${s * 13 + 5}: ${hueOf(c)}');
        }
      }
    });

    test('Bauhaus keeps neutral digits and two distinct accents', () {
      for (var s = 0; s < 30; s++) {
        final spec = gen.generate(
          s,
          ThemeFamily.bauhaus,
          5,
          intent: ThemeIntent(colors: const [IntentColor.green]),
        );
        if (spec.variant == ThemeVariant.hero) continue;
        final p = spec.palette;
        expect(chromaOf(p.digit.face), lessThan(bauhausNeutralMaxChroma));
        final d = (hueOf(p.operator.face) - hueOf(p.equals.face)).abs();
        expect(d > 1800 ? 3600 - d : d, greaterThanOrEqualTo(400));
      }
    });

    test('unsteered Bauhaus still needs primaries', () {
      final spec = gen.generate(3, ThemeFamily.bauhaus, 5);
      final green = spec.copyWith(
        palette: spec.palette.copyWith(
          operator: spec.palette.operator.copyWith(
            face: oklchToArgb(0.6, 0.15, 145),
          ),
        ),
      );
      expect(
        validateTheme(green).map((v) => v.rule),
        contains(GuardrailRule.bauhausPrimaries),
      );
    });

    test('Claymorphism follows the colour with its body', () {
      for (final b in ThemeBrightness.values) {
        var hits = 0;
        for (var s = 0; s < 20; s++) {
          final spec = gen.generate(
            s,
            ThemeFamily.claymorphism,
            5,
            intent: ThemeIntent(
              colors: const [IntentColor.green],
              brightness: b,
            ),
          );
          if (inRange(
                hueOf(spec.palette.background),
                IntentColor.green,
                slack: 60,
              ) ||
              wears(spec, IntentColor.green)) {
            hits++;
          }
        }
        expect(hits, greaterThan(16), reason: b.name);
      }
    });

    test('backgrounds keep their luminance: the family keeps its tones', () {
      for (final f in ThemeFamily.enabledFamilies) {
        if (f == ThemeFamily.m3Expressive ||
            f == ThemeFamily.neoPop ||
            f == ThemeFamily.claymorphism) {
          continue; // their own draws are steered first
        }
        final plain = gen.buildCandidate(12, f, 5);
        final steered = gen.buildCandidate(
          12,
          f,
          5,
          intent: ThemeIntent(colors: const [IntentColor.purple]),
        );
        expect(
          (luminanceArgb(steered.palette.background) -
                  luminanceArgb(plain.palette.background))
              .abs(),
          // 8-bit rounding of the turned colour.
          lessThan(0.005),
          reason: f.name,
        );
      }
    });

    test('steered names follow the colour', () {
      final spec = gen.generate(
        2,
        ThemeFamily.cyberpunk,
        5,
        intent: ThemeIntent(colors: const [IntentColor.green]),
      );
      final plain = gen.generate(2, ThemeFamily.cyberpunk, 5);
      expect(spec.name, isNot(plain.name));
      expect(
        gen
            .generate(
              2,
              ThemeFamily.cyberpunk,
              5,
              intent: ThemeIntent(
                colors: const [IntentColor.green],
                name: 'Toxic',
              ),
            )
            .name,
        'Toxic',
      );
    });
  });

  test('v4 steering is unchanged (2.0.0 themes reproduce)', () {
    final intent = ThemeIntent(colors: const [IntentColor.red]);
    final v4 = gen.generate(5, ThemeFamily.cyberpunk, 4, intent: intent);
    expect(
      v4.palette,
      gen.generate(5, ThemeFamily.cyberpunk, 4).palette,
      reason: 'v4 Cyberpunk took only the name',
    );
    expect(
      gen.generate(5, ThemeFamily.cyberpunk, 5, intent: intent).palette,
      isNot(v4.palette),
    );
  });

  test('steered v5 generation p99 < 2 ms', tags: 'perf', () {
    final intents = [
      ThemeIntent(colors: const [IntentColor.red]),
      ThemeIntent(colors: const [IntentColor.green, IntentColor.lime]),
      ThemeIntent(
        colors: const [IntentColor.navy],
        chroma: IntentChroma.muted,
      ),
      ThemeIntent(
        colors: const [IntentColor.yellow],
        brightness: ThemeBrightness.dark,
      ),
    ];
    for (final f in ThemeFamily.enabledFamilies) {
      for (var s = 0; s < 400; s++) {
        gen.generate(s, f, 5, intent: intents[s % 4], accessible: s.isOdd);
      }
    }
    final times = <int>[];
    final sw = Stopwatch()..start();
    for (var s = 0; s < 150; s++) {
      for (final f in ThemeFamily.enabledFamilies) {
        for (final i in intents) {
          final t0 = sw.elapsedMicroseconds;
          gen.generate(s + 5000, f, 5, intent: i, accessible: s.isOdd);
          times.add(sw.elapsedMicroseconds - t0);
        }
      }
    }
    times.sort();
    final p99 = times[times.length * 99 ~/ 100];
    expect(p99, lessThan(2000), reason: 'p99 $p99 µs');
  });

  test('golden JSON fixture (steered v5)', () {
    const path = 'test/engine/fixtures/steered_v5.json';
    Map<String, Object?> caseJson(SteeredCase c) {
      final spec = gen.generate(
        c.seed,
        c.family,
        5,
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
    if (Platform.environment['UPDATE_STEERED_GOLDENS'] == '1' &&
        currentEngineVersion == 5) {
      file.writeAsStringSync(
        '${const JsonEncoder.withIndent('  ').convert({
          'engineVersion': 5,
          'cases': [for (final c in steeredV5Cases) caseJson(c)],
        })}\n',
      );
    }
    final fixture = jsonDecode(file.readAsStringSync()) as Map<String, Object?>;
    expect(fixture['engineVersion'], 5);
    final cases = (fixture['cases']! as List).cast<Map<String, Object?>>();
    expect(cases, hasLength(steeredV5Cases.length));
    expect(
      {for (final c in steeredV5Cases) c.family},
      ThemeFamily.enabledFamilies.toSet(),
    );
    for (var i = 0; i < cases.length; i++) {
      final want = cases[i];
      final got = caseJson(steeredV5Cases[i]);
      expect(
        jsonEncode(got['spec']),
        jsonEncode(want['spec']),
        reason: 'case $i',
      );
      expect(got['hash'], want['hash'], reason: 'case $i');
      expect(ThemeSpec.fromJson(want['spec']), isA<ThemeSpec>());
    }
  });
}
