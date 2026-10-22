/// Deterministic procedural theme names (research theme-engine.md §10,
/// Recommendation 12): `Colour Material`, `Mood Colour`,
/// `Colour Time/Place` and `Material Mood-noun`.
///
/// The colour word follows the real OKLCH hue bucket of the theme's
/// dominant accent (the operator face). Every list has a fixed size, so a
/// bad word is replaced in place and only names using that slot change.
/// Word lists are part of `engineVersion`. English only in v1; names are
/// recomputed on the receiving device, so localisation never breaks share
/// codes.
///
/// Curation rules: no words for people, skin, ethnicity, nationality,
/// religion, body parts, drugs, weapons or violence, and no trademarks. A
/// unit test enumerates every combination against [isBlockedName].
library;

import 'package:calsee_themes/engine/families.dart';
import 'package:calsee_themes/engine/oklab.dart';
import 'package:calsee_themes/engine/rng.dart';

/// Name patterns with their integer weights.
enum NamePattern {
  colourMaterial(40),
  moodColour(30),
  colourTimePlace(20),
  materialMoodNoun(10);

  const NamePattern(this.weight);

  /// Sampling weight.
  final int weight;
}

/// Accents with OKLCH chroma below this use [neutralWords].
const double neutralChromaThreshold = 0.04;

/// Words per hue bucket (fixed).
const int colourSlots = 8;

/// 12 hue buckets of 30°, bucket 0 centred on 0° (345°–15°), each exactly
/// [colourSlots] words.
const List<List<String>> colourWords = [
  // 345–15: reds / roses
  [
    'Rose',
    'Coral',
    'Cherry',
    'Ruby',
    'Scarlet',
    'Garnet',
    'Poppy',
    'Cranberry',
  ],
  // 15–45: red-oranges
  [
    'Ember',
    'Paprika',
    'Terracotta',
    'Persimmon',
    'Vermilion',
    'Rust',
    'Brick',
    'Chili',
  ],
  // 45–75: oranges
  [
    'Mango',
    'Apricot',
    'Tangerine',
    'Amber',
    'Copper',
    'Papaya',
    'Marmalade',
    'Pumpkin',
  ],
  // 75–105: golds
  [
    'Honey',
    'Saffron',
    'Brass',
    'Mustard',
    'Marigold',
    'Butterscotch',
    'Turmeric',
    'Goldenrod',
  ],
  // 105–135: yellow-greens
  [
    'Citron',
    'Lime',
    'Pistachio',
    'Olive',
    'Chartreuse',
    'Lemon',
    'Kiwi',
    'Moss',
  ],
  // 135–165: greens
  ['Jade', 'Mint', 'Basil', 'Fern', 'Emerald', 'Clover', 'Sage', 'Matcha'],
  // 165–195: teals
  [
    'Lagoon',
    'Seafoam',
    'Teal',
    'Verdigris',
    'Spruce',
    'Pine',
    'Juniper',
    'Eucalyptus',
  ],
  // 195–225: cyans
  [
    'Glacier',
    'Aqua',
    'Cerulean',
    'Frost',
    'Tide',
    'Opal',
    'Turquoise',
    'Arctic',
  ],
  // 225–255: blues
  [
    'Denim',
    'Azure',
    'Sapphire',
    'Harbor',
    'Sky',
    'Cornflower',
    'Steel',
    'Delft',
  ],
  // 255–285: deep blues
  [
    'Cobalt',
    'Indigo',
    'Ultramarine',
    'Iris',
    'Navy',
    'Marine',
    'Bluebell',
    'Periwinkle',
  ],
  // 285–315: violets
  [
    'Violet',
    'Amethyst',
    'Lavender',
    'Orchid',
    'Grape',
    'Plum',
    'Lilac',
    'Wisteria',
  ],
  // 315–345: magentas
  [
    'Fuchsia',
    'Magenta',
    'Peony',
    'Mulberry',
    'Raspberry',
    'Hibiscus',
    'Berry',
    'Flamingo',
  ],
];

/// Neutral colour words (accent chroma < [neutralChromaThreshold]).
const List<String> neutralWords = [
  'Basalt',
  'Graphite',
  'Slate',
  'Chalk',
  'Pebble',
  'Ash',
  'Linen',
  'Cloud',
  'Ink',
  'Smoke',
  'Pewter',
  'Flint',
  'Oyster',
  'Fog',
  'Charcoal',
  'Silver',
];

/// Material / texture words per family (8 each); [genericMaterialWords]
/// for families without their own list.
const Map<ThemeFamily, List<String>> familyMaterialWords = {
  ThemeFamily.m3Expressive: [
    'Petal',
    'Bloom',
    'Ribbon',
    'Ripple',
    'Blossom',
    'Shell',
    'Felt',
    'Meringue',
  ],
  ThemeFamily.neoPop: [
    'Neon',
    'Volt',
    'Arcade',
    'Signal',
    'Pulse',
    'Circuit',
    'Flash',
    'Static',
  ],
  ThemeFamily.retro: [
    'Segment',
    'Quartz',
    'Memory',
    'Ticker',
    'Diode',
    'Bakelite',
    'Cassette',
    'Beige',
  ],
  ThemeFamily.neoBrutalism: [
    'Poster',
    'Rivet',
    'Slab',
    'Sticker',
    'Stencil',
    'Zine',
    'Concrete',
    'Marker',
  ],
  ThemeFamily.liquidGlass: [
    'Prism',
    'Lens',
    'Crystal',
    'Dewdrop',
    'Mirage',
    'Droplet',
    'Halo',
    'Sheen',
  ],
  ThemeFamily.neumorphism: [
    'Porcelain',
    'Pearl',
    'Clay',
    'Pillow',
    'Suede',
    'Cotton',
    'Plush',
    'Velour',
  ],
  ThemeFamily.claymorphism: [
    'Putty',
    'Dough',
    'Gumdrop',
    'Taffy',
    'Fondant',
    'Marzipan',
    'Gummy',
    'Nougat',
  ],
  ThemeFamily.y2kChrome: [
    'Bubble',
    'Chrome',
    'Gel',
    'Spritz',
    'Foil',
    'Glint',
    'Mirror',
    'Splash',
  ],
  ThemeFamily.paperInk: [
    'Quill',
    'Ledger',
    'Vellum',
    'Folio',
    'Nib',
    'Inkwell',
    'Foolscap',
    'Gazette',
  ],
  ThemeFamily.cyberpunk: [
    'Megacity',
    'Cipher',
    'Glitch',
    'Mainframe',
    'Wireframe',
    'Overdrive',
    'Firewall',
    'Proxy',
  ],
  ThemeFamily.vaporwave: [
    'Marina',
    'Plaza',
    'Dolphin',
    'Statue',
    'Fountain',
    'Atrium',
    'Lounge',
    'Sunset',
  ],
  ThemeFamily.bauhaus: [
    'Gouache',
    'Plywood',
    'Compass',
    'Atelier',
    'Weave',
    'Primer',
    'Typeface',
    'Facade',
  ],
};

/// Fallback material words (8).
const List<String> genericMaterialWords = [
  'Satin',
  'Silk',
  'Marble',
  'Glass',
  'Paper',
  'Enamel',
  'Ceramic',
  'Lacquer',
];

/// Mood adjectives (16).
const List<String> moodWords = [
  'Quiet',
  'Electric',
  'Velvet',
  'Sunday',
  'Lucky',
  'Gentle',
  'Bold',
  'Lazy',
  'Dreamy',
  'Crisp',
  'Cosmic',
  'Mellow',
  'Brave',
  'Breezy',
  'Cozy',
  'Wild',
];

/// Mood nouns (8).
const List<String> moodNouns = [
  'Hush',
  'Riot',
  'Echo',
  'Glow',
  'Dream',
  'Spark',
  'Drift',
  'Rhythm',
];

/// Time / place words for dark themes (8).
const List<String> darkTimePlaceWords = [
  'Midnight',
  'Nightfall',
  'Harbour',
  'Eclipse',
  'Lantern',
  'Nocturne',
  'Orbit',
  'Galaxy',
];

/// Time / place words for light themes (8).
const List<String> lightTimePlaceWords = [
  'Morning',
  'Meadow',
  'Daybreak',
  'Garden',
  'Seaside',
  'Orchard',
  'Noon',
  'Breeze',
];

/// Material words for [family].
List<String> materialWordsFor(ThemeFamily family) =>
    familyMaterialWords[family] ?? genericMaterialWords;

/// Hue bucket 0–11 of an OKLCH hue in degrees (bucket 0 = 345°–15°).
int hueBucket(double hueDeg) {
  var h = (hueDeg + 15) % 360;
  if (h < 0) h += 360;
  final b = h ~/ 30;
  return b > 11 ? 11 : b;
}

/// Colour words for an accent colour: its hue bucket, or [neutralWords].
List<String> colourWordsFor(int accentArgb) {
  final lch = argbToOklch(accentArgb);
  if (lch.c < neutralChromaThreshold) return neutralWords;
  return colourWords[hueBucket(lch.h)];
}

/// Two words that must never appear together (checked on the pair, in
/// either order).
const List<(String, String)> blockedBigrams = [
  ('bloody', ''),
  ('', 'bomb'),
  ('', 'blast'),
  ('dirty', ''),
  ('naked', ''),
  ('', 'gun'),
  ('', 'shot'),
];

/// Words that must never appear at all (curation guard).
const List<String> blockedWords = [
  'nude',
  'flesh',
  'skin',
  'indian',
  'gypsy',
  'oriental',
  'slave',
  'master',
  'bloody',
  'bomb',
  'gun',
  'blood',
  'kill',
  'dead',
  'death',
  'drug',
  'weed',
  'crack',
  'meth',
  'opium',
  'cocaine',
  'negro',
  'black',
  'white',
  'yellow',
  'red',
  'brown',
  'tan',
];

/// Offensive substrings that must not be **created** by joining two words
/// (a substring already inside one word, like "ass" in "Glass", is fine).
const List<String> blockedJoinSubstrings = [
  'ass',
  'anal',
  'anus',
  'arse',
  'butt',
  'cock',
  'cum',
  'cunt',
  'dick',
  'dildo',
  'fag',
  'fuck',
  'hell',
  'homo',
  'jizz',
  'kkk',
  'nazi',
  'nig',
  'nob',
  'penis',
  'piss',
  'poo',
  'porn',
  'rape',
  'sex',
  'shit',
  'slut',
  'spic',
  'tit',
  'turd',
  'twat',
  'vagina',
  'wank',
  'whore',
];

/// Blocked two-letter initials.
const List<String> blockedInitials = ['FU', 'KK'];

/// Whether the two-word name [first] [second] is blocked: a blocked word,
/// a blocked bigram, a blocked substring created by the join, or blocked
/// initials.
bool isBlockedName(String first, String second) {
  final a = first.toLowerCase();
  final b = second.toLowerCase();
  if (blockedWords.contains(a) || blockedWords.contains(b)) return true;
  if (a == b) return true;
  for (final (x, y) in blockedBigrams) {
    bool match(String p, String q) =>
        (x.isEmpty || p == x) && (y.isEmpty || q == y);
    if (match(a, b) || match(b, a)) return true;
  }
  for (final (p, q) in [(a, b), (b, a)]) {
    final joined = '$p$q';
    final boundary = p.length;
    for (final bad in blockedJoinSubstrings) {
      // Created by the join iff an occurrence spans the boundary.
      final from = boundary - bad.length + 1;
      final start = from < 0 ? 0 : from;
      final i = joined.indexOf(bad, start);
      if (i >= 0 && i < boundary) return true;
    }
  }
  final initials = '${first[0]}${second[0]}'.toUpperCase();
  return blockedInitials.contains(initials);
}

/// The name of a theme: deterministic from the `name` stream [rng], the
/// final palette's [accentArgb] (operator face), the [family] and whether
/// it is [dark].
String generateThemeName({
  required Rng rng,
  required int accentArgb,
  required ThemeFamily family,
  required bool dark,
}) {
  final colours = colourWordsFor(accentArgb);
  final materials = materialWordsFor(family);
  final places = dark ? darkTimePlaceWords : lightTimePlaceWords;
  for (var attempt = 0; attempt < 16; attempt++) {
    final pattern =
        NamePattern.values[rng.pickWeighted([
          for (final p in NamePattern.values) p.weight,
        ])];
    final (first, second) = switch (pattern) {
      NamePattern.colourMaterial => (rng.pick(colours), rng.pick(materials)),
      NamePattern.moodColour => (rng.pick(moodWords), rng.pick(colours)),
      NamePattern.colourTimePlace => (rng.pick(colours), rng.pick(places)),
      NamePattern.materialMoodNoun => (
        rng.pick(materials),
        rng.pick(moodNouns),
      ),
    };
    if (!isBlockedName(first, second)) return '$first $second';
  }
  return '${colours.first} ${materials.first}';
}
