import 'package:calsee_themes/engine/families.dart';
import 'package:calsee_themes/engine/names.dart';
import 'package:calsee_themes/engine/oklab.dart';
import 'package:calsee_themes/engine/rng.dart';
import 'package:test/test.dart';

void main() {
  final allColours = [for (final b in colourWords) ...b, ...neutralWords];
  final allMaterials = {
    ...genericMaterialWords,
    for (final l in familyMaterialWords.values) ...l,
  }.toList();
  final allPlaces = [...darkTimePlaceWords, ...lightTimePlaceWords];

  test('lists have fixed sizes and no duplicates', () {
    expect(colourWords, hasLength(12));
    for (final b in colourWords) {
      expect(b, hasLength(colourSlots));
    }
    expect(neutralWords, hasLength(16));
    expect(genericMaterialWords, hasLength(8));
    for (final l in familyMaterialWords.values) {
      expect(l, hasLength(8));
    }
    expect(moodWords, hasLength(16));
    expect(moodNouns, hasLength(8));
    expect(darkTimePlaceWords, hasLength(8));
    expect(lightTimePlaceWords, hasLength(8));
    final every = [
      ...allColours,
      ...allMaterials,
      ...moodWords,
      ...moodNouns,
      ...allPlaces,
    ];
    for (final w in every) {
      expect(w, matches(RegExp(r'^[A-Z][a-z]+$')), reason: w);
    }
    expect(allColours.toSet(), hasLength(allColours.length));
  });

  test('weights sum to 100', () {
    expect(NamePattern.values.fold<int>(0, (s, p) => s + p.weight), 100);
  });

  test('every combination passes the blocklist', () {
    final pairs = <(String, String)>[];
    for (final family in ThemeFamily.values) {
      final materials = materialWordsFor(family);
      for (final colours in [...colourWords, neutralWords]) {
        for (final c in colours) {
          for (final m in materials) {
            pairs.add((c, m));
          }
          for (final mood in moodWords) {
            pairs.add((mood, c));
          }
          for (final p in allPlaces) {
            pairs.add((c, p));
          }
        }
      }
      for (final m in materials) {
        for (final n in moodNouns) {
          pairs.add((m, n));
        }
      }
    }
    final unique = pairs.toSet();
    expect(unique.length, greaterThan(5000));
    final blocked = [
      for (final (a, b) in unique)
        if (isBlockedName(a, b)) '$a $b',
    ];
    expect(blocked, isEmpty);
  });

  test('the blocklist itself works', () {
    expect(isBlockedName('Ash', 'Hole'), isFalse); // "hole" is not listed
    expect(isBlockedName('Grass', 'Moss'), isFalse); // "ass" inside a word
    expect(isBlockedName('Bra', 'Ssy'), isTrue); // "ass" created by the join
    expect(isBlockedName('Pi', 'Ssy'), isTrue);
    expect(isBlockedName('Bloody', 'Rose'), isTrue);
    expect(isBlockedName('Cherry', 'Bomb'), isTrue);
    expect(isBlockedName('Nude', 'Linen'), isTrue);
    expect(isBlockedName('Fern', 'Ultra'), isTrue); // initials FU
    expect(isBlockedName('Mint', 'Mint'), isTrue);
    expect(isBlockedName('Mango', 'Midnight'), isFalse);
  });

  test('no word is on the blocked word list', () {
    for (final w in [
      ...allColours,
      ...allMaterials,
      ...moodWords,
      ...moodNouns,
      ...allPlaces,
    ]) {
      expect(blockedWords, isNot(contains(w.toLowerCase())), reason: w);
    }
  });

  test('hue buckets', () {
    expect(hueBucket(0), 0);
    expect(hueBucket(14.9), 0);
    expect(hueBucket(15), 1);
    expect(hueBucket(344.9), 11);
    expect(hueBucket(345), 0);
    expect(hueBucket(359.9), 0);
    // Real colours land in their landmark buckets (research §5.1).
    expect(colourWordsFor(0xFFFF0000), colourWords[1]); // red h 29°
    expect(colourWordsFor(0xFFFF8000), colourWords[2]); // orange 53°
    expect(colourWordsFor(0xFF00FF00), colourWords[5]); // green 142°
    expect(colourWordsFor(0xFF0000FF), colourWords[9]); // blue 264°
    expect(colourWordsFor(0xFFFF00FF), colourWords[11]); // magenta 328°
    expect(colourWordsFor(0xFF808080), neutralWords);
    expect(colourWordsFor(oklchToArgb(0.6, 0.03, 200)), neutralWords);
  });

  test('deterministic and uses the accent hue', () {
    for (var seed = 0; seed < 500; seed++) {
      for (final family in ThemeFamily.enabledFamilies) {
        String name() => generateThemeName(
          rng: Rng.stream(seed, RngTag.name),
          accentArgb: 0xFFFF9F0A,
          family: family,
          dark: seed.isEven,
        );
        final a = name();
        expect(name(), a);
        final words = a.split(' ');
        expect(words, hasLength(2));
        expect(isBlockedName(words[0], words[1]), isFalse);
        final colourWord = words.where(colourWords[2].contains);
        final hasColour = colourWord.isNotEmpty;
        final isMaterialNoun =
            materialWordsFor(family).contains(words[0]) &&
            moodNouns.contains(words[1]);
        expect(hasColour || isMaterialNoun, isTrue, reason: a);
        if (!seed.isEven) {
          expect(darkTimePlaceWords, isNot(contains(words[1])));
        }
      }
    }
  });

  test('known names are stable (part of engineVersion 1)', () {
    final names = [
      for (var seed = 0; seed < 6; seed++)
        generateThemeName(
          rng: Rng.stream(seed, RngTag.name),
          accentArgb: oklchToArgb(0.7, 0.18, (seed * 60).toDouble()),
          family: seed.isEven ? ThemeFamily.m3Expressive : ThemeFamily.neoPop,
          dark: seed.isOdd,
        ),
    ];
    expect(names, kKnownNames);
  });
}

const List<String> kKnownNames = [
  'Gentle Cherry',
  'Cosmic Apricot',
  'Kiwi Ribbon',
  'Spruce Flash',
  'Ripple Riot',
  'Lavender Neon',
];
