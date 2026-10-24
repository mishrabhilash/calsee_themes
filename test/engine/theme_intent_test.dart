import 'dart:convert';

import 'package:calsee_themes/engine/families.dart';
import 'package:calsee_themes/engine/theme_intent.dart';
import 'package:calsee_themes/engine/theme_spec.dart';
import 'package:test/test.dart';

void main() {
  group('parse', () {
    test('reads a clean intent', () {
      final r = ThemeIntent.parse(
        '{"families":["claymorphism","m3Expressive"],"brightness":"light",'
        '"colors":["green","lime"],"chroma":"vivid","harmony":"analogous",'
        '"name":"Playful Greenery"}',
      );
      expect(r.dropped, isEmpty);
      expect(
        r.intent,
        ThemeIntent(
          families: const [ThemeFamily.claymorphism, ThemeFamily.m3Expressive],
          brightness: ThemeBrightness.light,
          colors: const [IntentColor.green, IntentColor.lime],
          chroma: IntentChroma.vivid,
          harmony: HarmonyScheme.analogous,
          name: 'Playful Greenery',
        ),
      );
    });

    test('finds the object inside prose and code fences', () {
      final r = ThemeIntent.parse(
        'Sure! Here is the theme:\n```json\n{"colors": ["teal"]}\n```\n'
        'Hope that helps {not json}',
      );
      expect(r.intent.colors, [IntentColor.teal]);
      expect(r.dropped, isEmpty);
    });

    test('never throws on garbage', () {
      for (final raw in [
        '',
        'no json here',
        '{',
        '{"colors": [}',
        '[1, 2, 3]',
        '{"colors": {"a": 1}, "brightness": 7, "chroma": null}',
        '{"name": 42, "harmony": ["mono"]}',
        '{"hueRange": "blue"}',
      ]) {
        final r = ThemeIntent.parse(raw);
        expect(r.intent.steersColour, isFalse, reason: raw);
      }
      expect(ThemeIntent.parse('no json').dropped, ['no JSON object']);
      expect(ThemeIntent.parse('{"a": }').dropped, ['unparseable JSON']);
    });

    test('is case- and separator-insensitive, with synonyms', () {
      final r = ThemeIntent.parse(
        '{"Colours": "Gray, sea-foam and TEAL", "BRIGHTNESS": "Dark",'
        ' "saturation": "Pastel", "scheme": "split-complementary",'
        ' "Family": "neo_pop", "hue_range": [400, -20]}',
      );
      expect(r.intent.colors, [IntentColor.grey, IntentColor.teal]);
      expect(r.intent.brightness, ThemeBrightness.dark);
      expect(r.intent.chroma, IntentChroma.muted);
      expect(r.intent.harmony, HarmonyScheme.splitComplementary);
      expect(r.intent.families, [ThemeFamily.neoPop]);
      expect(r.intent.hueRange, (40, 340));
      expect(r.dropped, ['colors: sea-foam']);
    });

    test('drops unknown keys, values and disabled families', () {
      final r = ThemeIntent.parseJson({
        'families': ['pixel', 'bauhaus', 'nope'],
        'colors': ['green', 'chartreuse', 'green'],
        'mood': 'happy',
        'brightness': 'any',
      });
      expect(r.intent.families, [ThemeFamily.bauhaus]);
      expect(r.intent.colors, [IntentColor.green]);
      expect(r.intent.brightness, isNull);
      expect(
        r.dropped,
        containsAll([
          'families: pixel',
          'families: nope',
          'colors: chartreuse',
          'unknown key mood',
        ]),
      );
    });

    test('caps colours at three and names at three words', () {
      final r = ThemeIntent.parseJson({
        'colors': ['red', 'blue', 'green', 'pink'],
        'name': '  The   very long   theme name  ',
      });
      expect(r.intent.colors, [
        IntentColor.red,
        IntentColor.blue,
        IntentColor.green,
      ]);
      expect(r.dropped, ['colors: pink (more than 3)']);
      expect(r.intent.name, 'The very long');
      expect(
        ThemeIntent(name: 'Supercalifragilisticexpialidocious Dream').name,
        hasLength(lessThanOrEqualTo(ThemeIntent.maxNameLength)),
      );
      expect(ThemeIntent(name: '   ').name, isNull);
    });

    test('a single hue is ±15°', () {
      expect(ThemeIntent.parseJson({'hue': 100}).intent.hueRange, (85, 115));
      expect(
        ThemeIntent.parseJson({
          'hueRange': {'from': 350, 'to': 10},
        }).intent.hueRange,
        (350, 10),
      );
    });
  });

  group('json', () {
    test('round-trips canonically, absent fields left out', () {
      final i = ThemeIntent(
        families: const [ThemeFamily.neoPop],
        colors: const [IntentColor.navy, IntentColor.gold],
        harmony: HarmonyScheme.duotone,
        hueRange: (200, 230),
        name: 'Night Shift',
      );
      final json = i.toJson();
      expect(jsonEncode(json), jsonEncode(ThemeIntent.fromJson(json).toJson()));
      expect(ThemeIntent.fromJson(json), i);
      expect(ThemeIntent.fromJson(json).hashCode, i.hashCode);
      expect(json.keys, [
        'families',
        'colors',
        'harmony',
        'hueRange',
        'name',
      ]);
      expect(ThemeIntent.none.toJson(), isEmpty);
    });

    test('forEntry drops families, forSpec drops the name too', () {
      final i = ThemeIntent(
        families: const [ThemeFamily.neoPop],
        colors: const [IntentColor.red],
        name: 'Ember',
      );
      expect(
        i.forEntry,
        ThemeIntent(colors: const [IntentColor.red], name: 'Ember'),
      );
      expect(i.forSpec, ThemeIntent(colors: const [IntentColor.red]));
      expect(
        ThemeIntent(families: const [ThemeFamily.neoPop]).forEntry.isEmpty,
        true,
      );
    });
  });

  group('leanings', () {
    test('colours lean brightness and chroma only when unset', () {
      final navy = ThemeIntent(colors: const [IntentColor.navy]);
      expect(navy.effectiveBrightness, ThemeBrightness.dark);
      final lightNavy = ThemeIntent(
        colors: const [IntentColor.navy],
        brightness: ThemeBrightness.light,
      );
      expect(lightNavy.effectiveBrightness, ThemeBrightness.light);
      final lavender = ThemeIntent(colors: const [IntentColor.lavender]);
      expect(lavender.effectiveBrightness, ThemeBrightness.light);
      expect(lavender.effectiveChroma, IntentChroma.muted);
      final vividLavender = ThemeIntent(
        colors: const [IntentColor.lavender],
        chroma: IntentChroma.vivid,
      );
      expect(vividLavender.effectiveChroma, IntentChroma.vivid);
      expect(
        ThemeIntent(colors: const [IntentColor.olive]).effectiveBrightness,
        isNull,
      );
      expect(
        ThemeIntent(colors: const [IntentColor.olive]).effectiveChroma,
        IntentChroma.muted,
      );
    });
  });

  group('vocabulary', () {
    // Values are only ever added: this pin fails on a rename or removal.
    test('is pinned', () {
      final words = {
        for (final f in ThemeIntent.vocabulary)
          f.name: [for (final v in f.values) v.value],
      };
      expect(words.keys, [
        'families',
        'brightness',
        'colors',
        'chroma',
        'harmony',
        'name',
      ]);
      expect(words['brightness'], ['light', 'dark', 'any']);
      expect(words['chroma'], ['muted', 'balanced', 'vivid']);
      expect(words['harmony'], [
        'mono',
        'analogous',
        'complementary',
        'split',
        'triad',
        'duotone',
      ]);
      expect(words['colors'], [
        'red', 'coral', 'orange', 'amber', 'yellow', 'lime', 'green', //
        'mint', 'teal', 'cyan', 'sky', 'blue', 'indigo', 'violet',
        'purple', 'magenta', 'pink', 'brown', 'sand', 'grey', 'navy',
        'olive', 'lavender', 'peach', 'gold', 'maroon',
      ]);
      expect(words['families'], [
        for (final f in ThemeFamily.enabledFamilies) f.name,
      ]);
    });

    test('colour codes are stable and unique', () {
      for (final c in IntentColor.values) {
        expect(c.code, c.index, reason: c.word);
        expect(IntentColor.fromCode(c.code), c);
      }
      expect(IntentColor.values.length, lessThanOrEqualTo(32));
    });

    test('every value has a description; families carry steerable', () {
      for (final f in ThemeIntent.vocabulary) {
        expect(f.description, isNotEmpty);
        for (final v in f.values) {
          expect(v.description, isNotEmpty, reason: '${f.name}.${v.value}');
        }
      }
      final families = ThemeIntent.vocabulary.first.values;
      expect(
        {
          for (final v in families)
            if (v.steerable) v.value,
        },
        {for (final f in steerableFamilies) f.name},
      );
    });

    test('schema lists the vocabulary', () {
      final schema = ThemeIntent.jsonSchema();
      final props = schema['properties']! as Map<String, Object?>;
      expect(props.keys, [for (final f in ThemeIntent.vocabulary) f.name]);
      final families = props['families']! as Map<String, Object?>;
      expect((families['items']! as Map)['enum'], [
        for (final f in ThemeFamily.enabledFamilies)
          if (steerableFamilies.contains(f)) f.name,
      ]);
      final all = ThemeIntent.jsonSchema(steerableOnly: false);
      final allFamilies =
          (all['properties']! as Map<String, Object?>)['families']!
              as Map<String, Object?>;
      expect(
        (allFamilies['items']! as Map)['enum'],
        hasLength(ThemeFamily.enabledFamilies.length),
      );
      // Encodable as is.
      expect(() => jsonEncode(schema), returnsNormally);
    });

    test(
      'prompt fragment names every offered value and parses its example',
      () {
        final prompt = ThemeIntent.promptFragment();
        for (final f in ThemeIntent.vocabulary) {
          expect(prompt, contains(f.name));
          for (final v in f.values) {
            if (f.name == 'families' && !v.steerable) {
              expect(prompt, isNot(contains('  ${v.value}:')));
            } else {
              expect(prompt, contains('  ${v.value}:'));
            }
          }
        }
        final example = ThemeIntent.parse(prompt.split('greenery":').last);
        expect(example.dropped, isEmpty);
        expect(example.intent.colors, [IntentColor.green, IntentColor.lime]);
        // Small enough for a tight on-device context.
        expect(prompt.length, lessThan(2600));
      },
    );
  });

  group('reportFor', () {
    test('steerable families honour a plain intent', () {
      final i = ThemeIntent(
        colors: const [IntentColor.green, IntentColor.lime],
        brightness: ThemeBrightness.light,
        chroma: IntentChroma.vivid,
      );
      expect(i.reportFor(ThemeFamily.m3Expressive), isEmpty);
      expect(i.reportFor(ThemeFamily.claymorphism), isEmpty);
    });

    test('NeoPOP is dark-only and has no monochrome', () {
      final notes = ThemeIntent(
        brightness: ThemeBrightness.light,
        harmony: HarmonyScheme.monochrome,
      ).reportFor(ThemeFamily.neoPop);
      expect(notes, [
        const IntentNote('brightness', 'light', 'dark-only family'),
        const IntentNote('harmony', 'mono', 'not used by this family'),
      ]);
    });

    test('implied brightness is reported too', () {
      expect(
        ThemeIntent(
          colors: const [IntentColor.sand],
        ).reportFor(ThemeFamily.neoPop),
        [const IntentNote('brightness', 'light', 'dark-only family')],
      );
    });

    test('Claymorphism follows colours but keeps its own schemes', () {
      final notes = ThemeIntent(
        colors: const [IntentColor.yellow],
        brightness: ThemeBrightness.dark,
        harmony: HarmonyScheme.triadic,
      ).reportFor(ThemeFamily.claymorphism);
      expect(notes, [
        const IntentNote(
          'harmony',
          'triad',
          'family uses its own colour schemes',
        ),
      ]);
    });

    test('every family follows colours, brightness and chroma', () {
      final intent = ThemeIntent(
        colors: const [IntentColor.red, IntentColor.teal],
        brightness: ThemeBrightness.dark,
        chroma: IntentChroma.vivid,
        name: 'Rust',
      );
      for (final f in ThemeFamily.enabledFamilies) {
        if (f == ThemeFamily.neoPop) continue;
        expect(intent.reportFor(f), isEmpty, reason: f.name);
      }
    });

    test('families with their own palettes keep their own schemes', () {
      expect(
        ThemeIntent(
          colors: const [IntentColor.red],
          harmony: HarmonyScheme.triadic,
        ).reportFor(ThemeFamily.cyberpunk),
        [
          const IntentNote(
            'harmony',
            'triad',
            'family uses its own colour schemes',
          ),
        ],
      );
    });

    test('Bauhaus keeps strong, distinct accents', () {
      expect(
        ThemeIntent(
          colors: const [IntentColor.green, IntentColor.lime],
          chroma: IntentChroma.muted,
        ).reportFor(ThemeFamily.bauhaus),
        [
          const IntentNote(
            'colors',
            'lime',
            'too close to green for a second Bauhaus accent',
          ),
          const IntentNote('chroma', 'muted', 'Bauhaus accents stay strong'),
        ],
      );
      expect(
        ThemeIntent(
          colors: const [IntentColor.green, IntentColor.purple],
        ).reportFor(ThemeFamily.bauhaus),
        isEmpty,
      );
    });

    test('accent colours give way to an explicit harmony', () {
      final notes = ThemeIntent(
        colors: const [IntentColor.teal, IntentColor.coral, IntentColor.grey],
        harmony: HarmonyScheme.complementary,
      ).reportFor(ThemeFamily.m3Expressive);
      expect(notes, [
        const IntentNote(
          'colors',
          'coral',
          'harmony picks the accent colours',
        ),
        const IntentNote(
          'colors',
          'grey',
          'neutrals only quiet the base colour',
        ),
      ]);
    });
  });
}
