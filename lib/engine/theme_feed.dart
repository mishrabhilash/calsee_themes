/// The swipe feed (spec §5.2, §6.1, §6.2; design doc `theme_feed.dart`):
/// a history stack where back returns the exact previous theme, next /
/// previous, a hero every 8–12 new themes (seeded), a family filter, a
/// 3-ahead prefetch hook, the lock, and the theme of the day.
///
/// Pure Dart and deterministic: the feed stores [FeedEntry] recipes, not
/// specs. Step `k` of a feed (the k-th *new* theme) is a pure function of
/// (feed seed, k, filter at the time), so [ThemeFeed.upcoming] can predict
/// exactly what [ThemeFeed.next] will return. State round-trips through
/// [ThemeFeed.toJson] / [ThemeFeed.fromJson] for persistence.
///
/// Engine v4 adds steering: [ThemeFeed.steer] sets a `ThemeIntent`, and
/// every new theme after it is generated under it (no heroes), the first
/// one centred on the intent. Entries carry their intent, so history keeps
/// working after the intent changes.
library;

import 'dart:math' show Random;

import 'package:calsee_themes/engine/families.dart';
import 'package:calsee_themes/engine/generator.dart';
import 'package:calsee_themes/engine/heroes.dart';
import 'package:calsee_themes/engine/rng.dart';
import 'package:calsee_themes/engine/share_code.dart';
import 'package:calsee_themes/engine/theme_intent.dart';
import 'package:calsee_themes/engine/theme_spec.dart';
import 'package:meta/meta.dart';

// ---------------------------------------------------------------- entries --

/// A reproducible recipe for one theme: a generated (seed, family,
/// engineVersion [, intent, centred]) or a hero id.
@immutable
final class FeedEntry {
  /// A generated theme; [intent] (engine v4+) steers it, [centred] puts
  /// it at the middle of the intent's ranges.
  const FeedEntry.generated({
    required int this.seed,
    required ThemeFamily this.family,
    this.engineVersion = currentEngineVersion,
    this.intent,
    this.centred = false,
  }) : heroId = null;

  /// A hand-crafted hero.
  const FeedEntry.hero(int this.heroId)
    : seed = null,
      family = null,
      engineVersion = currentEngineVersion,
      intent = null,
      centred = false;

  /// The entry for [spec] (heroes by id, everything else by recipe). A
  /// steered spec's entry takes [ThemeSpec.name] as its intent's name, so
  /// it regenerates the same spec.
  factory FeedEntry.ofSpec(ThemeSpec spec) =>
      spec.variant == ThemeVariant.hero && spec.heroId != null
      ? FeedEntry.hero(spec.heroId!)
      : FeedEntry.generated(
          seed: spec.seed,
          family: spec.family,
          engineVersion: spec.engineVersion,
          intent: spec.variant == ThemeVariant.steered && spec.intent != null
              ? spec.intent!.withName(spec.name)
              : null,
          centred: spec.intentCentred,
        );

  /// Parses [toJson] output; null for entries this build cannot reproduce
  /// (unknown family or hero, a family the recipe's version never
  /// shipped, newer engine version).
  static FeedEntry? fromJson(Object? json) {
    if (json is! Map) return null;
    final kind = json['kind'];
    if (kind == 'hero') {
      final id = json['heroId'];
      if (id is! int || heroById(id) == null) return null;
      return FeedEntry.hero(id);
    }
    if (kind == 'generated') {
      final seed = json['seed'];
      final familyId = json['family'];
      final version = json['engineVersion'];
      if (seed is! int || familyId is! int || version is! int) return null;
      final family = ThemeFamily.fromId(familyId);
      if (family == null || family == ThemeFamily.plain) return null;
      if (!supportedEngineVersions.contains(version)) return null;
      // A recipe for a family that version never shipped cannot be
      // reproduced (placeholder definitions change when it ships).
      if (!familyShippedAt(family, version)) return null;
      final rawIntent = json['intent'];
      final intent = rawIntent == null
          ? null
          : ThemeIntent.fromJson(rawIntent).forEntry;
      if (intent != null && version < firstSteerableEngineVersion) {
        return null;
      }
      return FeedEntry.generated(
        seed: seed & 0xFFFFFFFF,
        family: family,
        engineVersion: version,
        intent: intent == null || intent.isEmpty ? null : intent,
        centred: intent != null && json['centred'] == true,
      );
    }
    return null;
  }

  /// The entry a decoded share code (or link) names, or null when this
  /// build cannot reproduce it (unknown family or hero, unshipped family,
  /// newer engine version). A link's name becomes the steered intent's.
  static FeedEntry? fromSharePayload(SharePayload payload) {
    if (payload.isHero) {
      return heroById(payload.seed) == null
          ? null
          : FeedEntry.hero(payload.seed);
    }
    final intent = payload.intent;
    return fromJson({
      'kind': 'generated',
      'seed': payload.seed,
      'family': payload.familyId,
      'engineVersion': payload.engineVersion,
      'intent':
          ?(payload.name == null ? intent : intent?.withName(payload.name))
              ?.toJson(),
      'centred': payload.centred,
    });
  }

  /// This entry's share code: plain for heroes and unsteered themes, the
  /// longer steered form for steered ones (its name is not in the code;
  /// pass it to `formatThemeDeepLink`).
  String get shareCode {
    if (heroId != null) {
      return encodeShareCode(shareFamilyHero, engineVersion, heroId!);
    }
    final i = intent;
    return i == null
        ? encodeShareCode(family!.id, engineVersion, seed!)
        : encodeSteeredShareCode(
            family!.id,
            engineVersion,
            seed!,
            i,
            centred: centred,
          );
  }

  /// 32-bit seed (generated entries).
  final int? seed;

  /// Family (generated entries).
  final ThemeFamily? family;

  /// Generator version (generated entries).
  final int engineVersion;

  /// Hero id (hero entries).
  final int? heroId;

  /// The steering intent (generated entries, engine v4+), without
  /// families; null when unsteered.
  final ThemeIntent? intent;

  /// Whether a steered entry is generated centred on its intent.
  final bool centred;

  bool get isHero => heroId != null;

  /// The theme's family (a hero's own family for hero entries).
  ThemeFamily get themeFamily => family ?? heroById(heroId!)!.family;

  /// Builds the theme. Prefer [ThemeCache.specFor], which memoises.
  ThemeSpec resolve({
    bool accessible = false,
    ThemeGenerator generator = const ThemeGenerator(),
  }) {
    if (heroId != null) {
      final hero =
          heroById(heroId!) ?? (throw StateError('unknown hero $heroId'));
      return heroForAccessible(hero, accessible: accessible);
    }
    return generator.generate(
      seed!,
      family!,
      engineVersion,
      accessible: accessible,
      intent: intent,
      intentCentred: centred,
    );
  }

  Map<String, Object?> toJson() => heroId != null
      ? {'kind': 'hero', 'heroId': heroId}
      : {
          'kind': 'generated',
          'seed': seed,
          'family': family!.id,
          'engineVersion': engineVersion,
          'intent': ?intent?.toJson(),
          if (intent != null && centred) 'centred': true,
        };

  @override
  bool operator ==(Object other) =>
      other is FeedEntry &&
      other.seed == seed &&
      other.family == family &&
      other.engineVersion == engineVersion &&
      other.heroId == heroId &&
      other.intent == intent &&
      other.centred == centred;

  @override
  int get hashCode =>
      Object.hash(seed, family, engineVersion, heroId, intent, centred);

  @override
  String toString() => heroId != null
      ? 'FeedEntry.hero($heroId)'
      : 'FeedEntry(${family!.name}, 0x${seed!.toRadixString(16)}, '
            'v$engineVersion${intent == null ? '' : ', $intent'}'
            '${centred ? ', centred' : ''})';
}

// ----------------------------------------------------------------- filter --

/// Which families the feed draws from (spec §6.1): "Surprise me" (every
/// enabled family) or a chosen set.
@immutable
final class FeedFilter {
  /// Every enabled family.
  const FeedFilter.surpriseMe() : _families = null;

  /// Only [families] (disabled ones are ignored; empty → surprise me).
  factory FeedFilter.only(Iterable<ThemeFamily> families) {
    final chosen = <ThemeFamily>{
      for (final f in families)
        if (f.enabled) f,
    }.toList()..sort((a, b) => a.id.compareTo(b.id));
    return chosen.isEmpty
        ? const FeedFilter.surpriseMe()
        : FeedFilter._(List.unmodifiable(chosen));
  }

  const FeedFilter._(this._families);

  /// Parses [toJson] output (unknown input → surprise me).
  factory FeedFilter.fromJson(Object? json) {
    if (json is Map && json['families'] is List) {
      return FeedFilter.only([
        for (final id in json['families'] as List)
          if (id is int) ?ThemeFamily.fromId(id),
      ]);
    }
    return const FeedFilter.surpriseMe();
  }

  final List<ThemeFamily>? _families;

  /// Whether this is "Surprise me".
  bool get isSurpriseMe => _families == null;

  /// Allowed families in id order.
  List<ThemeFamily> get families => _families ?? ThemeFamily.enabledFamilies;

  bool allows(ThemeFamily family) => families.contains(family);

  Map<String, Object?> toJson() => _families == null
      ? {'surprise': true}
      : {
          'families': [for (final f in _families) f.id],
        };

  @override
  bool operator ==(Object other) {
    if (other is! FeedFilter) return false;
    final a = _families;
    final b = other._families;
    if (a == null || b == null) return a == b;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode =>
      _families == null ? 0 : Object.hashAll(_families.map((f) => f.id));

  @override
  String toString() => _families == null
      ? 'FeedFilter.surpriseMe()'
      : 'FeedFilter.only(${_families.map((f) => f.name).join(', ')})';
}

// ------------------------------------------------------------------- feed --

/// Callback with the next themes the feed will show (prefetch them).
typedef PrefetchHook = void Function(List<FeedEntry> upcoming);

/// The swipe feed. Mutable; one per app (the theme controller owns it).
final class ThemeFeed {
  /// A new feed for [feedSeed] (use [randomFeedSeed] on first launch and
  /// persist it). The first theme is [initial], or step 0 of the feed.
  ///
  /// With [intent], the feed starts steered: step 0 is the intent's
  /// centred theme.
  ThemeFeed({
    required int feedSeed,
    FeedFilter filter = const FeedFilter.surpriseMe(),
    FeedEntry? initial,
    ThemeIntent? intent,
    this.maxHistory = defaultMaxHistory,
    this.prefetchCount = 3,
    this.onPrefetch,
  }) : _filter = filter,
       feedSeed = feedSeed & 0xFFFFFFFF {
    if (intent != null && !intent.isEmpty) {
      _intent = intent;
      _intentStep = 0;
    }
    if (initial != null) {
      _history.add(initial);
    } else {
      _history.add(entryAt(0));
      _steps = 1;
    }
  }

  /// Restores [toJson] output. Entries this build cannot reproduce are
  /// dropped; an unusable state starts a fresh feed (same seed if known).
  factory ThemeFeed.fromJson(
    Object? json, {
    int maxHistory = defaultMaxHistory,
    int prefetchCount = 3,
    PrefetchHook? onPrefetch,
  }) {
    final j = json is Map ? json : const <String, Object?>{};
    final seed = j['feedSeed'] is int ? j['feedSeed'] as int : randomFeedSeed();
    final feed = ThemeFeed(
      feedSeed: seed,
      filter: FeedFilter.fromJson(j['filter']),
      maxHistory: maxHistory,
      prefetchCount: prefetchCount,
      onPrefetch: onPrefetch,
    );
    final raw = j['history'];
    final history = <FeedEntry>[];
    final savedCursor = j['cursor'] is int ? j['cursor'] as int : 0;
    // A dropped current entry falls back to the nearest earlier one.
    var cursor = savedCursor;
    if (raw is List) {
      for (var i = 0; i < raw.length; i++) {
        final e = FeedEntry.fromJson(raw[i]);
        if (e != null) {
          history.add(e);
        } else if (i <= savedCursor) {
          cursor--;
        }
      }
    }
    if (history.isNotEmpty) {
      feed._history
        ..clear()
        ..addAll(history);
      feed._cursor = cursor.clamp(0, history.length - 1);
      final steps = j['steps'];
      feed._steps = steps is int && steps >= 0 ? steps : 0;
      feed._trim();
    }
    feed.locked = j['locked'] == true;
    final intent = j['intent'] == null
        ? null
        : ThemeIntent.fromJson(j['intent']);
    final intentStep = j['intentStep'];
    if (intent != null && !intent.isEmpty && intentStep is int) {
      feed
        .._intent = intent
        .._intentStep = intentStep;
    }
    return feed;
  }

  /// A fresh random feed seed (`Random.secure`; never used for generation
  /// itself, only to pick where this install's feed starts).
  static int randomFeedSeed() {
    int raw;
    try {
      raw = Random.secure().nextInt(0xFFFFFFFF);
    } on Object {
      // Some JS hosts (e.g. Node test runners) have no usable crypto source.
      raw =
          fmix32(DateTime.now().microsecondsSinceEpoch & 0xFFFFFFFF) %
          0xFFFFFFFF;
    }
    return raw + 1;
  }

  static const int defaultMaxHistory = 100;

  /// Smallest and largest number of new themes between heroes.
  static const int heroGapMin = 8;
  static const int heroGapMax = 12;

  /// JSON layout version. Steering added optional keys (`intent`,
  /// `intentStep`) without a bump: older builds ignore them.
  static const int jsonFormat = 1;

  final int feedSeed;

  /// History cap (oldest entries are dropped).
  final int maxHistory;

  /// How many entries [onPrefetch] receives.
  final int prefetchCount;

  /// Called after every move or filter change with [upcoming].
  PrefetchHook? onPrefetch;

  /// While locked, [next] and [previous] do nothing and return null (the
  /// UI rubber-bands). [jumpTo] (an explicit apply) still works.
  bool locked = false;

  FeedFilter _filter;
  final List<FeedEntry> _history = [];
  int _cursor = 0;
  int _steps = 0;
  ThemeIntent? _intent;
  int _intentStep = 0;
  final List<int> _heroSteps = [];
  Rng? _heroGaps;
  List<int>? _heroOrder;

  /// The current theme.
  FeedEntry get current => _history[_cursor];

  /// History, oldest first (unmodifiable view).
  List<FeedEntry> get history => List.unmodifiable(_history);

  /// Index of [current] in [history].
  int get cursor => _cursor;

  /// New themes drawn so far (the next new theme is step [steps]).
  int get steps => _steps;

  FeedFilter get filter => _filter;

  /// Changes the family filter. Themes already in the history stay; new
  /// themes come from [value].
  set filter(FeedFilter value) {
    if (value == _filter) return;
    _filter = value;
    _notify();
  }

  /// The steering intent new themes follow; null when unsteered.
  ThemeIntent? get intent => _intent;

  /// Steers new themes by [intent] (engine v4) and moves to the first of
  /// them, centred on the intent (forward history is dropped, as with
  /// [jumpTo]; back returns to where the user was). Steered steps have no
  /// heroes and draw from [steeredFamilies]. A null or empty intent stops
  /// steering without moving. Works while [locked] (an explicit apply).
  FeedEntry steer(ThemeIntent? intent) {
    if (intent == null || intent.isEmpty) {
      if (_intent != null) {
        _intent = null;
        _notify();
      }
      return current;
    }
    _intent = intent;
    _intentStep = _steps;
    _history
      ..removeRange(_cursor + 1, _history.length)
      ..add(entryAt(_steps));
    _steps++;
    _cursor++;
    _trim();
    _notify();
    return current;
  }

  /// The families steered steps draw from: the intent's families allowed
  /// by the filter (the intent's own when none is); with no intent
  /// families, the filter's [steerableFamilies] (the whole filter when
  /// none is steerable).
  List<ThemeFamily> get steeredFamilies {
    final base = _filter.families;
    final asked = _intent?.families ?? const <ThemeFamily>[];
    if (asked.isNotEmpty) {
      final both = [
        for (final f in base)
          if (asked.contains(f)) f,
      ];
      return both.isNotEmpty ? both : asked;
    }
    final steerable = [
      for (final f in base)
        if (steerableFamilies.contains(f)) f,
    ];
    return steerable.isNotEmpty ? steerable : base;
  }

  bool get canGoBack => !locked && _cursor > 0;

  bool get canGoForward => !locked;

  /// Moves to the next theme: replays the history forward after [previous],
  /// otherwise draws a new one. Null while [locked].
  FeedEntry? next() {
    if (locked) return null;
    if (_cursor < _history.length - 1) {
      _cursor++;
    } else {
      _history.add(entryAt(_steps));
      _steps++;
      _cursor++;
      _trim();
    }
    _notify();
    return current;
  }

  /// Moves back to the exact previous theme. Null while [locked] or at the
  /// start of the history.
  FeedEntry? previous() {
    if (!canGoBack) return null;
    _cursor--;
    _notify();
    return current;
  }

  /// Applies [entry] (favourite, share code, theme of the day): drops any
  /// forward history and pushes it, so back returns to where the user was.
  FeedEntry jumpTo(FeedEntry entry) {
    if (entry != current) {
      _history
        ..removeRange(_cursor + 1, _history.length)
        ..add(entry);
      _cursor++;
      _trim();
    }
    _notify();
    return current;
  }

  /// The next [count] entries [next] would return, in order (pure; does not
  /// move the feed). The prefetch hook.
  List<FeedEntry> upcoming([int count = 3]) => [
    for (var i = 1; i <= count; i++)
      if (_cursor + i < _history.length)
        _history[_cursor + i]
      else
        entryAt(_steps + _cursor + i - _history.length),
  ];

  /// The entry for new-theme step [step] under the current filter: a hero
  /// on hero steps (every 8–12 steps, seeded), otherwise a generated theme
  /// whose seed and family come from `Rng.stream(feedSeed, 'feed/step/k')`.
  ///
  /// While steering, steps from the one [steer] started at are generated
  /// under the intent from [steeredFamilies] (that first step centred),
  /// with no heroes.
  FeedEntry entryAt(int step) {
    final intent = _intent;
    if (intent != null && step >= _intentStep) {
      final families = steeredFamilies;
      final r = Rng.stream(feedSeed, RngTag.sub(RngTag.feed, 'step', step));
      final seed = r.nextU32();
      final family = families[r.nextInt(families.length)];
      final recipe = intent.forEntry;
      return recipe.isEmpty
          ? FeedEntry.generated(seed: seed, family: family)
          : FeedEntry.generated(
              seed: seed,
              family: family,
              intent: recipe,
              centred: step == _intentStep,
            );
    }
    final families = _filter.families;
    final heroIndex = _heroIndexAt(step);
    if (heroIndex != null) {
      final order = _heroOrderIds();
      final allowed = [
        for (final id in order)
          if (families.contains(heroById(id)!.family)) id,
      ];
      if (allowed.isNotEmpty) {
        return FeedEntry.hero(allowed[heroIndex % allowed.length]);
      }
    }
    final r = Rng.stream(feedSeed, RngTag.sub(RngTag.feed, 'step', step));
    final seed = r.nextU32();
    final family = families[r.nextInt(families.length)];
    return FeedEntry.generated(seed: seed, family: family);
  }

  /// Whether step [step] is a hero slot.
  bool isHeroStep(int step) => _heroIndexAt(step) != null;

  int? _heroIndexAt(int step) {
    if (step <= 0) return null;
    final gaps = _heroGaps ??= Rng.stream(
      feedSeed,
      RngTag.sub(RngTag.feed, 'heroGap'),
    );
    while (_heroSteps.isEmpty || _heroSteps.last < step) {
      final last = _heroSteps.isEmpty ? 0 : _heroSteps.last;
      _heroSteps.add(last + gaps.nextIntIn(heroGapMin, heroGapMax));
    }
    // Binary search.
    var lo = 0;
    var hi = _heroSteps.length - 1;
    while (lo <= hi) {
      final mid = (lo + hi) >> 1;
      final v = _heroSteps[mid];
      if (v == step) return mid;
      if (v < step) {
        lo = mid + 1;
      } else {
        hi = mid - 1;
      }
    }
    return null;
  }

  /// Every hero id in a seeded order (Fisher–Yates), so each feed meets the
  /// heroes in its own sequence without repeats until all were shown.
  List<int> _heroOrderIds() => _heroOrder ??= () {
    final ids = [for (final h in heroThemes) h.heroId!];
    final r = Rng.stream(feedSeed, RngTag.sub(RngTag.feed, 'heroOrder'));
    for (var i = ids.length - 1; i > 0; i--) {
      final j = r.nextInt(i + 1);
      final t = ids[i];
      ids[i] = ids[j];
      ids[j] = t;
    }
    return ids;
  }();

  void _trim() {
    final excess = _history.length - maxHistory;
    if (excess > 0) {
      _history.removeRange(0, excess);
      _cursor -= excess;
      if (_cursor < 0) _cursor = 0;
    }
  }

  void _notify() => onPrefetch?.call(upcoming(prefetchCount));

  Map<String, Object?> toJson() => {
    'format': jsonFormat,
    'feedSeed': feedSeed,
    'steps': _steps,
    'cursor': _cursor,
    'history': [for (final e in _history) e.toJson()],
    'filter': _filter.toJson(),
    'locked': locked,
    if (_intent != null) 'intent': _intent!.toJson(),
    if (_intent != null) 'intentStep': _intentStep,
  };
}

// ------------------------------------------------------- theme of the day --

/// Generator version the theme of the day uses: fixed, so every app
/// version that has it shows the same theme on the same date (research
/// §11.3). Bump deliberately.
const int dailyEngineVersion = 1;

/// Families the theme of the day rotates through under
/// [dailyEngineVersion] (fixed: enabling new families must not change past
/// or future days of this version).
const List<ThemeFamily> dailyFamilies = [
  ThemeFamily.m3Expressive,
  ThemeFamily.neoPop,
];

/// Days since 1970-01-01 of the **local** calendar date of [local] (flips
/// at local midnight; exact on the web).
int localDayIndex(DateTime local) =>
    DateTime.utc(local.year, local.month, local.day).millisecondsSinceEpoch ~/
    Duration.millisecondsPerDay;

/// The theme everyone gets on [localDate]'s calendar day:
/// `Rng.stream(localDayIndex, 'daily')`.
FeedEntry themeOfTheDay(DateTime localDate) {
  final r = Rng.stream(localDayIndex(localDate), RngTag.daily);
  final seed = r.nextU32();
  final family = dailyFamilies[r.nextInt(dailyFamilies.length)];
  return FeedEntry.generated(
    seed: seed,
    family: family,
    // Explicit on purpose: stays 1 when currentEngineVersion moves on.
    engineVersion: dailyEngineVersion,
  );
}

// ------------------------------------------------------------------ cache --

/// A small LRU of resolved specs, so prefetched themes are ready when the
/// user swipes (generation is < 2 ms, but a commit frame should not pay it).
final class ThemeCache {
  ThemeCache({this.capacity = 16, this.generator = const ThemeGenerator()});

  final int capacity;
  final ThemeGenerator generator;
  final Map<(FeedEntry, bool), ThemeSpec> _lru = {};

  /// Number of cached specs.
  int get length => _lru.length;

  /// The spec for [entry] (generated on a miss).
  ThemeSpec specFor(FeedEntry entry, {bool accessible = false}) {
    final key = (entry, accessible);
    final hit = _lru.remove(key);
    if (hit != null) return _lru[key] = hit;
    final spec = entry.resolve(accessible: accessible, generator: generator);
    _lru[key] = spec;
    while (_lru.length > capacity) {
      _lru.remove(_lru.keys.first);
    }
    return spec;
  }

  /// Whether [entry] is cached.
  bool contains(FeedEntry entry, {bool accessible = false}) =>
      _lru.containsKey((entry, accessible));

  /// Resolves every entry (e.g. from [ThemeFeed.onPrefetch]).
  void prefetch(Iterable<FeedEntry> entries, {bool accessible = false}) {
    for (final e in entries) {
      specFor(e, accessible: accessible);
    }
  }

  void clear() => _lru.clear();
}
