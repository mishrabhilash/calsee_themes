import 'dart:convert';

import 'package:calsee_themes/engine/generator.dart';
import 'package:calsee_themes/engine/guardrails.dart';
import 'package:calsee_themes/engine/heroes.dart';
import 'package:calsee_themes/engine/theme_feed.dart';
import 'package:calsee_themes/engine/theme_spec.dart';
import 'package:test/test.dart';

void main() {
  group('history', () {
    test('back returns the exact previous themes; forward replays', () {
      final feed = ThemeFeed(feedSeed: 1);
      final seen = [feed.current];
      for (var i = 0; i < 30; i++) {
        seen.add(feed.next()!);
      }
      expect(feed.history, seen);
      for (var i = seen.length - 2; i >= 0; i--) {
        expect(feed.previous(), seen[i]);
      }
      expect(feed.previous(), isNull, reason: 'start of history');
      expect(feed.canGoBack, isFalse);
      final steps = feed.steps;
      for (var i = 1; i < seen.length; i++) {
        expect(feed.next(), seen[i], reason: 'replay, not a new theme');
      }
      expect(feed.steps, steps);
      final fresh = feed.next()!;
      expect(feed.steps, steps + 1);
      expect(fresh, isNot(seen.last));
    });

    test('same feed seed → same sequence; different seeds differ', () {
      List<FeedEntry> run(int seed) {
        final f = ThemeFeed(feedSeed: seed);
        return [f.current, for (var i = 0; i < 40; i++) f.next()!];
      }

      expect(run(99), run(99));
      expect(run(99), isNot(run(100)));
    });

    test('history is capped; the cursor follows', () {
      final feed = ThemeFeed(feedSeed: 2, maxHistory: 10);
      for (var i = 0; i < 25; i++) {
        feed.next();
      }
      expect(feed.history, hasLength(10));
      expect(feed.cursor, 9);
      expect(feed.current, feed.history.last);
      for (var i = 0; i < 9; i++) {
        expect(feed.previous(), isNotNull);
      }
      expect(feed.previous(), isNull);
    });

    test('jumpTo drops forward history and back returns', () {
      final feed = ThemeFeed(feedSeed: 3);
      final a = feed.next()!;
      feed
        ..next()
        ..next()
        ..previous()
        ..previous();
      expect(feed.current, a);
      const shared = FeedEntry.hero(2);
      expect(feed.jumpTo(shared), shared);
      expect(feed.history.last, shared);
      expect(feed.previous(), a);
      // Jumping to the current entry is a no-op.
      final len = feed.history.length;
      feed.jumpTo(feed.current);
      expect(feed.history, hasLength(len));
    });
  });

  group('heroes', () {
    test('a hero every 8–12 new themes, seeded', () {
      for (var seed = 0; seed < 50; seed++) {
        final feed = ThemeFeed(feedSeed: seed);
        final heroSteps = <int>[];
        for (var step = 1; step <= 200; step++) {
          final e = feed.next()!;
          expect(e.isHero, feed.isHeroStep(step));
          if (e.isHero) heroSteps.add(step);
        }
        expect(heroSteps.first, inInclusiveRange(8, 12));
        for (var i = 1; i < heroSteps.length; i++) {
          expect(heroSteps[i] - heroSteps[i - 1], inInclusiveRange(8, 12));
        }
      }
    });

    test('heroes cycle without repeats until all were shown', () {
      final feed = ThemeFeed(feedSeed: 11);
      final heroes = <int>[];
      while (heroes.length < heroThemes.length * 2) {
        final e = feed.next()!;
        if (e.isHero) heroes.add(e.heroId!);
      }
      final firstRound = heroes.take(heroThemes.length).toSet();
      expect(firstRound, hasLength(heroThemes.length));
    });

    test('hero order differs between feeds', () {
      List<int> order(int seed) {
        final f = ThemeFeed(feedSeed: seed);
        final out = <int>[];
        while (out.length < 4) {
          final e = f.next()!;
          if (e.isHero) out.add(e.heroId!);
        }
        return out;
      }

      final orders = {for (var s = 0; s < 20; s++) order(s).join(',')};
      expect(orders.length, greaterThan(5));
    });
  });

  // M5: the cadence holds for every enabled family, whatever their number;
  // a family's heroes join the rotation as soon as they are in
  // `heroThemes`, and the family filter applies to heroes too.
  group('heroes across families', () {
    final enabled = ThemeFamily.enabledFamilies;
    final enabledHeroes = {
      for (final h in heroThemes)
        if (enabled.contains(h.family)) h.heroId!,
    };

    test("surprise me: one round meets every enabled family's heroes", () {
      for (var seed = 0; seed < 10; seed++) {
        final feed = ThemeFeed(feedSeed: seed);
        final round = <int>[];
        var step = 0;
        var lastHero = 0;
        while (round.length < enabledHeroes.length) {
          step++;
          final e = feed.next()!;
          if (!e.isHero) continue;
          expect(step - lastHero, inInclusiveRange(8, 12));
          lastHero = step;
          round.add(e.heroId!);
        }
        expect(round.toSet(), enabledHeroes, reason: 'feed $seed');
        expect(
          {for (final id in round) heroById(id)!.family},
          {
            for (final f in enabled)
              if (heroesFor(f).isNotEmpty) f,
          },
        );
      }
    });

    for (final family in enabled) {
      test('${family.name} only: its heroes every 8–12 themes', () {
        final own = {for (final h in heroesFor(family)) h.heroId!};
        final feed = ThemeFeed(
          feedSeed: 21 + family.id,
          filter: FeedFilter.only([family]),
        );
        final heroSteps = <int>[];
        final seen = <int>{};
        for (var step = 1; step <= 150; step++) {
          final e = feed.next()!;
          expect(e.themeFamily, family);
          if (e.isHero) {
            heroSteps.add(step);
            seen.add(e.heroId!);
          }
        }
        if (own.isEmpty) {
          // A family without heroes gets generated themes on hero steps.
          expect(heroSteps, isEmpty);
          return;
        }
        expect(seen, own);
        expect(heroSteps.first, inInclusiveRange(8, 12));
        for (var i = 1; i < heroSteps.length; i++) {
          expect(heroSteps[i] - heroSteps[i - 1], inInclusiveRange(8, 12));
        }
      });
    }

    test('a two-family filter draws heroes from both, and only them', () {
      if (enabled.length < 2) return;
      final pair = [enabled.first, enabled.last];
      final feed = ThemeFeed(feedSeed: 99, filter: FeedFilter.only(pair));
      final heroFamilies = <ThemeFamily>{};
      for (var i = 0; i < 200; i++) {
        final e = feed.next()!;
        expect(pair, contains(e.themeFamily));
        if (e.isHero) heroFamilies.add(e.themeFamily);
      }
      expect(heroFamilies, {
        for (final f in pair)
          if (heroesFor(f).isNotEmpty) f,
      });
    });
  });

  group('filter', () {
    test('surprise me draws every enabled family', () {
      final feed = ThemeFeed(feedSeed: 5);
      final families = <ThemeFamily>{};
      // Uniform over the enabled families: 300 draws leave a 12-family set
      // incomplete with probability < 1e-10.
      for (var i = 0; i < 300; i++) {
        families.add(feed.next()!.themeFamily);
      }
      expect(families, ThemeFamily.enabledFamilies.toSet());
    });

    test('a chosen family limits new themes and heroes', () {
      final feed = ThemeFeed(
        feedSeed: 6,
        filter: FeedFilter.only(const [ThemeFamily.neoPop]),
      );
      for (var i = 0; i < 100; i++) {
        expect(feed.next()!.themeFamily, ThemeFamily.neoPop);
      }
    });

    test('changing the filter keeps history and affects only new themes', () {
      final feed = ThemeFeed(feedSeed: 7);
      for (var i = 0; i < 10; i++) {
        feed.next();
      }
      final before = feed.history;
      for (var i = 0; i < 5; i++) {
        feed.previous();
      }
      feed.filter = FeedFilter.only(const [ThemeFamily.m3Expressive]);
      expect(feed.history, before);
      // Replays keep their families; new themes follow the filter.
      for (var i = 0; i < 5; i++) {
        expect(feed.next(), before[before.length - 5 + i]);
      }
      for (var i = 0; i < 30; i++) {
        expect(feed.next()!.themeFamily, ThemeFamily.m3Expressive);
      }
    });

    test('disabled families are ignored; empty means surprise me', () {
      expect(FeedFilter.only(const [ThemeFamily.pixel]).isSurpriseMe, isTrue);
      expect(FeedFilter.only(const []).isSurpriseMe, isTrue);
      final f = FeedFilter.only(const [
        ThemeFamily.neoPop,
        ThemeFamily.m3Expressive,
        ThemeFamily.neoPop,
      ]);
      expect(f.families, [ThemeFamily.m3Expressive, ThemeFamily.neoPop]);
      expect(FeedFilter.fromJson(f.toJson()), f);
      expect(
        FeedFilter.fromJson(const FeedFilter.surpriseMe().toJson()),
        const FeedFilter.surpriseMe(),
      );
      expect(FeedFilter.fromJson('junk').isSurpriseMe, isTrue);
    });
  });

  group('prefetch', () {
    test('upcoming(3) is exactly what next() returns', () {
      final feed = ThemeFeed(feedSeed: 8);
      for (var i = 0; i < 40; i++) {
        final ahead = feed.upcoming();
        expect(ahead, hasLength(3));
        expect(feed.next(), ahead.first);
        if (i % 7 == 3) {
          feed
            ..previous()
            ..previous();
          final replay = feed.upcoming();
          expect(feed.next(), replay[0]);
          expect(feed.next(), replay[1]);
          expect(feed.next(), replay[2]);
        }
      }
    });

    test('upcoming does not move the feed', () {
      final feed = ThemeFeed(feedSeed: 9);
      final json = jsonEncode(feed.toJson());
      feed.upcoming(10);
      expect(jsonEncode(feed.toJson()), json);
    });

    test('the hook fires after every move and filter change', () {
      final calls = <List<FeedEntry>>[];
      final feed = ThemeFeed(feedSeed: 10, onPrefetch: calls.add)..next();
      expect(calls, hasLength(1));
      expect(calls.last, feed.upcoming());
      feed.previous();
      feed.filter = FeedFilter.only(const [ThemeFamily.neoPop]);
      feed.jumpTo(const FeedEntry.hero(5));
      expect(calls, hasLength(4));
      expect(calls.last, feed.upcoming());
    });

    test('ThemeCache memoises and evicts least recently used', () {
      final cache = ThemeCache(capacity: 3);
      final feed = ThemeFeed(feedSeed: 12);
      cache.prefetch(feed.upcoming());
      expect(cache.length, 3);
      final e = feed.next()!;
      expect(cache.contains(e), isTrue);
      final spec = cache.specFor(e);
      expect(identical(cache.specFor(e), spec), isTrue);
      expect(spec, e.resolve());
      cache.specFor(const FeedEntry.hero(1));
      expect(cache.length, 3);
      expect(cache.contains(e), isTrue, reason: 'recently used');
      expect(
        cache.specFor(e, accessible: true).accessible,
        isTrue,
        reason: 'accessible specs are cached separately',
      );
    });
  });

  group('lock', () {
    test('locked feeds do not move', () {
      final feed = ThemeFeed(feedSeed: 13)
        ..next()
        ..locked = true;
      final current = feed.current;
      expect(feed.next(), isNull);
      expect(feed.previous(), isNull);
      expect(feed.canGoBack, isFalse);
      expect(feed.canGoForward, isFalse);
      expect(feed.current, current);
      feed.locked = false;
      expect(feed.previous(), isNotNull);
    });
  });

  group('persistence', () {
    test('toJson/fromJson restores the exact state and future', () {
      final feed = ThemeFeed(
        feedSeed: 14,
        filter: FeedFilter.only(const [ThemeFamily.neoPop]),
      );
      for (var i = 0; i < 23; i++) {
        feed.next();
      }
      feed
        ..previous()
        ..previous()
        ..locked = true;
      final restored = ThemeFeed.fromJson(
        jsonDecode(jsonEncode(feed.toJson())),
      );
      expect(restored.toJson(), feed.toJson());
      expect(restored.current, feed.current);
      expect(restored.locked, isTrue);
      feed.locked = false;
      restored.locked = false;
      for (var i = 0; i < 30; i++) {
        expect(restored.next(), feed.next());
      }
      for (var i = 0; i < 30; i++) {
        expect(restored.previous(), feed.previous());
      }
    });

    test('drops entries this build cannot reproduce', () {
      final json = {
        'feedSeed': 15,
        'steps': 4,
        'cursor': 2,
        'history': [
          {'kind': 'hero', 'heroId': 1},
          {'kind': 'hero', 'heroId': 9999},
          {
            'kind': 'generated',
            'seed': 5,
            'family': ThemeFamily.neoPop.id,
            'engineVersion': 99,
          },
          {
            'kind': 'generated',
            'seed': 6,
            'family': ThemeFamily.neoPop.id,
            'engineVersion': 1,
          },
        ],
      };
      final feed = ThemeFeed.fromJson(json);
      expect(feed.history, hasLength(2));
      expect(feed.cursor, 0);
      expect(feed.current, const FeedEntry.hero(1));
      expect(ThemeFeed.fromJson('garbage').history, hasLength(1));
    });

    test('entries round-trip and resolve to passing specs', () {
      final feed = ThemeFeed(feedSeed: 16);
      for (var i = 0; i < 40; i++) {
        final e = feed.next()!;
        expect(FeedEntry.fromJson(jsonDecode(jsonEncode(e.toJson()))), e);
        for (final accessible in [false, true]) {
          final spec = e.resolve(accessible: accessible);
          expect(validateTheme(spec), isEmpty);
          expect(FeedEntry.ofSpec(e.resolve()), e);
        }
      }
    });
  });

  group('theme of the day', () {
    test('stable for a date, regardless of time of day', () {
      final morning = themeOfTheDay(DateTime(2026, 10, 4, 0, 0, 1));
      final night = themeOfTheDay(DateTime(2026, 10, 4, 23, 59, 59));
      expect(night, morning);
      expect(themeOfTheDay(DateTime(2026, 10, 5)), isNot(morning));
      expect(morning.engineVersion, dailyEngineVersion);
      expect(dailyFamilies, contains(morning.themeFamily));
    });

    test('local day index counts calendar days', () {
      expect(localDayIndex(DateTime(1970)), 0);
      expect(localDayIndex(DateTime(1970, 1, 2, 23)), 1);
      expect(localDayIndex(DateTime(2026, 10, 4)), 20730);
    });

    test('pinned values (shared by every install and platform)', () {
      final e = themeOfTheDay(DateTime(2026, 10, 4));
      expect(e, themeOfTheDay(DateTime.utc(2026, 10, 4, 12)));
      expect(e.toJson(), {
        'kind': 'generated',
        'seed': e.seed,
        'family': e.family!.id,
        'engineVersion': 1,
      });
      expect(validateTheme(e.resolve()), isEmpty);
      // Different days cover both families.
      final families = {
        for (var d = 0; d < 30; d++)
          themeOfTheDay(DateTime(2026, 1, 1 + d)).themeFamily,
      };
      expect(families, dailyFamilies.toSet());
    });
  });

  test('random feed seeds are 32-bit', () {
    for (var i = 0; i < 20; i++) {
      final s = ThemeFeed.randomFeedSeed();
      expect(s, inInclusiveRange(1, 0xFFFFFFFF));
    }
    expect(currentEngineVersion, 4);
  });
}
