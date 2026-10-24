import 'dart:convert';

import 'package:calsee_themes/engine/generator.dart';
import 'package:calsee_themes/engine/share_code.dart';
import 'package:calsee_themes/engine/theme_feed.dart';
import 'package:calsee_themes/engine/theme_intent.dart';
import 'package:calsee_themes/engine/theme_spec.dart';
import 'package:test/test.dart';

final ThemeIntent greenery = ThemeIntent(
  brightness: ThemeBrightness.light,
  colors: const [IntentColor.green, IntentColor.lime],
  chroma: IntentChroma.vivid,
  name: 'Playful Greenery',
);

void main() {
  group('steer', () {
    test('moves to a centred steered theme; back returns', () {
      final feed = ThemeFeed(feedSeed: 5);
      feed.next();
      final before = feed.current;
      final first = feed.steer(greenery);
      expect(first.intent, greenery.forEntry);
      expect(first.centred, isTrue);
      expect(first.engineVersion, currentEngineVersion);
      expect(steerableFamilies, contains(first.family));
      expect(feed.previous(), before);
      expect(feed.next(), first);
    });

    test('later themes are steered, not centred, never heroes', () {
      final feed = ThemeFeed(feedSeed: 77)..steer(greenery);
      for (var i = 0; i < 40; i++) {
        final e = feed.next()!;
        expect(e.isHero, isFalse);
        expect(e.intent, greenery.forEntry);
        expect(e.centred, isFalse);
        expect(steerableFamilies, contains(e.family));
        final spec = e.resolve();
        expect(spec.variant, ThemeVariant.steered);
        expect(spec.name, 'Playful Greenery');
      }
    });

    test('upcoming predicts next while steered', () {
      final feed = ThemeFeed(feedSeed: 3)..steer(greenery);
      final predicted = feed.upcoming(5);
      expect([for (var i = 0; i < 5; i++) feed.next()], predicted);
    });

    test('a fresh feed can start steered', () {
      final feed = ThemeFeed(feedSeed: 9, intent: greenery);
      expect(feed.current.intent, greenery.forEntry);
      expect(feed.current.centred, isTrue);
      expect(feed.history, hasLength(1));
    });

    test('null stops steering without moving', () {
      final feed = ThemeFeed(feedSeed: 4)..steer(greenery);
      final steered = feed.current;
      expect(feed.steer(null), steered);
      expect(feed.intent, isNull);
      expect(feed.next()!.intent, isNull);
    });

    test('intent families pick the families, within the filter', () {
      final feed = ThemeFeed(
        feedSeed: 11,
        filter: FeedFilter.only(const [
          ThemeFamily.neoPop,
          ThemeFamily.bauhaus,
        ]),
      );
      feed.steer(
        ThemeIntent(
          families: const [ThemeFamily.bauhaus, ThemeFamily.retro],
          colors: const [IntentColor.red],
        ),
      );
      expect(feed.steeredFamilies, [ThemeFamily.bauhaus]);
      for (var i = 0; i < 10; i++) {
        expect(feed.next()!.family, ThemeFamily.bauhaus);
      }
      // No intent families: the filter's steerable ones.
      feed.steer(ThemeIntent(colors: const [IntentColor.red]));
      expect(feed.steeredFamilies, [ThemeFamily.neoPop]);
    });

    test('a name-only intent steers names, not colours', () {
      final feed = ThemeFeed(feedSeed: 6)..steer(ThemeIntent(name: 'Mine'));
      final spec = feed.current.resolve();
      expect(spec.name, 'Mine');
      expect(spec.variant, ThemeVariant.steered);
    });

    test('a families-only intent changes families but not themes', () {
      final feed = ThemeFeed(feedSeed: 6)
        ..steer(ThemeIntent(families: const [ThemeFamily.retro]));
      expect(feed.current.family, ThemeFamily.retro);
      expect(feed.current.intent, isNull);
    });
  });

  group('persistence', () {
    test('a steered feed round-trips through JSON', () {
      final feed = ThemeFeed(feedSeed: 21)
        ..next()
        ..steer(greenery)
        ..next()
        ..next();
      final json = jsonDecode(jsonEncode(feed.toJson()));
      final back = ThemeFeed.fromJson(json);
      expect(back.history, feed.history);
      expect(back.cursor, feed.cursor);
      expect(back.intent, feed.intent);
      expect(back.upcoming(4), feed.upcoming(4));
    });

    test('feed JSON without an intent loads unchanged', () {
      final feed = ThemeFeed(feedSeed: 8)..next();
      final json = feed.toJson();
      expect(json.containsKey('intent'), isFalse);
      final back = ThemeFeed.fromJson(json);
      expect(back.intent, isNull);
      expect(back.upcoming(), feed.upcoming());
    });

    test('entries round-trip; steered recipes below v4 are refused', () {
      final e = FeedEntry.generated(
        seed: 1,
        family: ThemeFamily.neoPop,
        intent: greenery.forEntry,
        centred: true,
      );
      expect(FeedEntry.fromJson(jsonDecode(jsonEncode(e.toJson()))), e);
      final old = {...e.toJson(), 'engineVersion': 3};
      expect(FeedEntry.fromJson(old), isNull);
      final plain = FeedEntry.fromJson({
        'kind': 'generated',
        'seed': 1,
        'family': ThemeFamily.neoPop.id,
        'engineVersion': 3,
      });
      expect(plain, isNotNull);
      expect(plain!.toJson().containsKey('intent'), isFalse);
    });

    test('ofSpec regenerates the same steered spec', () {
      for (final name in [null, 'Fern']) {
        final entry = FeedEntry.generated(
          seed: 1234,
          family: ThemeFamily.claymorphism,
          intent: ThemeIntent(colors: const [IntentColor.mint], name: name),
        );
        final spec = entry.resolve();
        expect(FeedEntry.ofSpec(spec).resolve(), spec);
      }
    });

    test('the cache keeps steered and plain entries apart', () {
      final cache = ThemeCache();
      const plain = FeedEntry.generated(seed: 1, family: ThemeFamily.neoPop);
      final steered = FeedEntry.generated(
        seed: 1,
        family: ThemeFamily.neoPop,
        intent: ThemeIntent(colors: const [IntentColor.teal]),
      );
      expect(cache.specFor(plain), isNot(cache.specFor(steered)));
      expect(cache.specFor(steered).variant, ThemeVariant.steered);
    });
  });

  group('share codes', () {
    test('steered entries share and reopen the same theme', () {
      final feed = ThemeFeed(feedSeed: 31)..steer(greenery);
      for (var i = 0; i < 8; i++) {
        final entry = feed.next()!;
        final code = entry.shareCode;
        expect(code.length, 29); // 25 symbols, 4 hyphens
        final link = formatThemeDeepLink(code, name: greenery.name);
        final payload = parseThemeDeepLink(link)!;
        expect(payload.name, 'Playful Greenery');
        final back = FeedEntry.fromSharePayload(payload)!;
        expect(back, entry);
        expect(back.resolve(), entry.resolve());
      }
    });

    test('without the name, the theme reopens with a generated name', () {
      final entry = FeedEntry.generated(
        seed: 77,
        family: ThemeFamily.m3Expressive,
        intent: greenery.forEntry,
      );
      final back = FeedEntry.fromSharePayload(
        decodeShareCode(entry.shareCode)!,
      )!;
      final a = entry.resolve();
      final b = back.resolve();
      expect(b.palette, a.palette);
      expect(b.name, isNot('Playful Greenery'));
    });

    test('plain and hero entries keep the short code', () {
      const plain = FeedEntry.generated(seed: 5, family: ThemeFamily.retro);
      expect(plain.shareCode.length, 11);
      expect(
        FeedEntry.fromSharePayload(decodeShareCode(plain.shareCode)!),
        plain,
      );
      const hero = FeedEntry.hero(1);
      expect(
        FeedEntry.fromSharePayload(decodeShareCode(hero.shareCode)!),
        hero,
      );
    });
  });
}
