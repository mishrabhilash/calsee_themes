/// Steering hints for generated themes (engine v4): a small, bounded,
/// JSON-friendly description of the look a host wants ("playful
/// greenery" → light, green and lime, vivid, analogous).
///
/// The package never sees the user's words. A host turns them into a
/// [ThemeIntent] however it likes (an on-device model, mood chips, a
/// keyword table) and the generator narrows its seeded draws to the
/// intent. Every guardrail still runs, so an intent can change how a
/// theme feels but never make its keys unreadable.
///
/// - [ThemeIntent.parse] / [ThemeIntent.fromJson] accept anything and never
///   throw: unknown keys and values are dropped and reported.
/// - [ThemeIntent.vocabulary] is the field and value list as data, with a
///   one-line description each; [ThemeIntent.jsonSchema] and
///   [ThemeIntent.promptFragment] are generated from it.
/// - [ThemeIntent.reportFor] lists the hints a family cannot honour.
///
/// Pure Dart (no Flutter, no `dart:math`).
library;

import 'dart:convert';

import 'package:calsee_themes/engine/bauhaus.dart'
    show bauhausSteeredEqualsApartTenths;
import 'package:calsee_themes/engine/families.dart';
import 'package:calsee_themes/engine/theme_spec.dart';
import 'package:meta/meta.dart';

/// The families that honour steering at the newest engine version: every
/// enabled family (engine v5). [ThemeIntent.reportFor] lists the hints a
/// family can't follow.
const Set<ThemeFamily> steerableFamilies = {
  ThemeFamily.m3Expressive,
  ThemeFamily.liquidGlass,
  ThemeFamily.neoPop,
  ThemeFamily.neumorphism,
  ThemeFamily.retro,
  ThemeFamily.neoBrutalism,
  ThemeFamily.claymorphism,
  ThemeFamily.y2kChrome,
  ThemeFamily.paperInk,
  ThemeFamily.cyberpunk,
  ThemeFamily.vaporwave,
  ThemeFamily.bauhaus,
};

/// The families that honoured steering at engine v4 (2.0.0); the others
/// took only the intent's name.
const Set<ThemeFamily> _steerableAtV4 = {
  ThemeFamily.m3Expressive,
  ThemeFamily.neoPop,
  ThemeFamily.claymorphism,
};

/// Whether [family] follows an intent's colours at [engineVersion]
/// (otherwise it takes only the name).
bool familySteerableAt(ThemeFamily family, int engineVersion) {
  if (engineVersion < firstSteerableEngineVersion) return false;
  if (engineVersion == firstSteerableEngineVersion) {
    return _steerableAtV4.contains(family);
  }
  return steerableFamilies.contains(family);
}

/// The families that honour an intent's harmony.
const Set<ThemeFamily> _harmonyFamilies = {
  ThemeFamily.m3Expressive,
  ThemeFamily.neoPop,
};

/// The first engine version that understands a [ThemeIntent].
const int firstSteerableEngineVersion = 4;

// ----------------------------------------------------------------- values --

/// How colourful a steered theme is.
enum IntentChroma {
  muted('muted', 'soft, greyed, calm colours'),
  balanced('balanced', 'moderate colour, neither soft nor loud'),
  vivid('vivid', 'bright, saturated, punchy colours');

  const IntentChroma(this.word, this.description);

  /// The vocabulary word (stable; stored in JSON and share codes).
  final String word;

  /// One line for prompts and schema descriptions.
  final String description;
}

/// A named colour a host (or its model) can ask for. Each maps to an
/// OKLCH hue range; some also lean the theme dark, light or muted when the
/// intent does not say otherwise.
///
/// [code] is stable (share codes store it): add colours at the end, never
/// renumber.
enum IntentColor {
  red(0, 'red', 220, 340, 'true red'),
  coral(1, 'coral', 350, 450, 'pinkish orange-red'),
  orange(2, 'orange', 480, 650, 'orange'),
  amber(3, 'amber', 680, 820, 'deep yellow-orange'),
  yellow(4, 'yellow', 1000, 1100, 'yellow'),
  lime(5, 'lime', 1180, 1320, 'yellow-green'),
  green(6, 'green', 1350, 1520, 'leafy green'),
  mint(7, 'mint', 1550, 1700, 'fresh blue-green'),
  teal(8, 'teal', 1750, 1900, 'green-blue'),
  cyan(9, 'cyan', 1920, 2100, 'bright aqua blue'),
  sky(10, 'sky', 2150, 2350, 'light sky blue'),
  blue(11, 'blue', 2450, 2650, 'true blue'),
  indigo(12, 'indigo', 2680, 2820, 'deep violet-blue'),
  violet(13, 'violet', 2850, 3000, 'blue-purple'),
  purple(14, 'purple', 3020, 3180, 'purple'),
  magenta(15, 'magenta', 3200, 3380, 'hot purple-pink'),
  pink(16, 'pink', 3420, 3580, 'pink'),
  brown(
    17,
    'brown',
    400,
    620,
    'coffee and wood browns',
    leanBrightness: ThemeBrightness.dark,
    leanChroma: IntentChroma.muted,
  ),
  sand(
    18,
    'sand',
    750,
    950,
    'beige, sand and cream',
    leanBrightness: ThemeBrightness.light,
    leanChroma: IntentChroma.muted,
  ),
  grey(
    19,
    'grey',
    0,
    3599,
    'neutral greys with little colour',
    leanChroma: IntentChroma.muted,
    neutral: true,
  ),
  navy(
    20,
    'navy',
    2550,
    2680,
    'dark navy blue',
    leanBrightness: ThemeBrightness.dark,
  ),
  olive(
    21,
    'olive',
    1000,
    1180,
    'muted khaki green',
    leanChroma: IntentChroma.muted,
  ),
  lavender(
    22,
    'lavender',
    2850,
    3100,
    'pale soft purple',
    leanBrightness: ThemeBrightness.light,
    leanChroma: IntentChroma.muted,
  ),
  peach(
    23,
    'peach',
    450,
    650,
    'pale soft orange',
    leanBrightness: ThemeBrightness.light,
    leanChroma: IntentChroma.muted,
  ),
  gold(24, 'gold', 850, 980, 'warm gold'),
  maroon(
    25,
    'maroon',
    150,
    280,
    'dark wine red',
    leanBrightness: ThemeBrightness.dark,
  );

  const IntentColor(
    this.code,
    this.word,
    this.loTenths,
    this.hiTenths,
    this.description, {
    this.leanBrightness,
    this.leanChroma,
    this.neutral = false,
  });

  /// Stable numeric code (0–31).
  final int code;

  /// The vocabulary word.
  final String word;

  /// OKLCH hue range in tenths of a degree, inclusive.
  final int loTenths;
  final int hiTenths;

  /// One line for prompts and schema descriptions.
  final String description;

  /// Brightness this colour implies when the intent sets none.
  final ThemeBrightness? leanBrightness;

  /// Chroma this colour implies when the intent sets none.
  final IntentChroma? leanChroma;

  /// Whether this is a neutral (no hue of its own): it quiets the base
  /// surfaces instead of choosing their hue.
  final bool neutral;

  /// Looks a colour up by [code]; null if unknown.
  static IntentColor? fromCode(int code) {
    for (final c in values) {
      if (c.code == code) return c;
    }
    return null;
  }
}

/// Vocabulary words for the harmony schemes (stable).
const Map<HarmonyScheme, String> harmonyWords = {
  HarmonyScheme.monochrome: 'mono',
  HarmonyScheme.analogous: 'analogous',
  HarmonyScheme.complementary: 'complementary',
  HarmonyScheme.splitComplementary: 'split',
  HarmonyScheme.triadic: 'triad',
  HarmonyScheme.duotone: 'duotone',
};

const Map<HarmonyScheme, String> _harmonyDescriptions = {
  HarmonyScheme.monochrome: 'one hue in several shades',
  HarmonyScheme.analogous: 'neighbouring hues, gentle and natural',
  HarmonyScheme.complementary: 'opposite hues, strong contrast',
  HarmonyScheme.splitComplementary: 'a hue and the two beside its opposite',
  HarmonyScheme.triadic: 'three evenly spaced hues, playful',
  HarmonyScheme.duotone: 'two bold hues on tinted surfaces',
};

const Map<ThemeFamily, String> _familyDescriptions = {
  ThemeFamily.m3Expressive: 'Material 3 Expressive: tonal, shape-morphing keys',
  ThemeFamily.liquidGlass: 'translucent frosted glass over a vivid mesh',
  ThemeFamily.neoPop: 'dark base, bright flat colours, hard 3D edges',
  ThemeFamily.neumorphism: 'soft extruded keys in one surface colour',
  ThemeFamily.retro: 'vintage pocket and desk calculators',
  ThemeFamily.neoBrutalism: 'bold flat fills, black outlines, hard shadows',
  ThemeFamily.claymorphism: 'puffy, rounded, candy-like clay keys',
  ThemeFamily.y2kChrome: 'Y2K chrome and glossy Frutiger Aero',
  ThemeFamily.paperInk: 'paper sheet with inked keys',
  ThemeFamily.cyberpunk: 'neon on black, glitchy and electric',
  ThemeFamily.vaporwave: 'pastel sunset, retro grid, 80s haze',
  ThemeFamily.bauhaus: 'primary colours and geometric shapes',
};

// ------------------------------------------------------------- vocabulary --

/// How a vocabulary field takes values.
enum IntentFieldKind {
  /// One value from [IntentField.values].
  oneOf,

  /// A list of distinct values from [IntentField.values], at most
  /// [IntentField.maxItems].
  listOf,

  /// Free text, at most [IntentField.maxWords] words.
  text,
}

/// One allowed value of a vocabulary field.
@immutable
final class IntentValue {
  const IntentValue(this.value, this.description, {this.steerable = true});

  /// The word to emit.
  final String value;

  /// One line saying what it means.
  final String description;

  /// For `families` values: whether the family honours steering in this
  /// build ([steerableFamilies]). Always true for other fields.
  final bool steerable;
}

/// One field of the intent vocabulary.
@immutable
final class IntentField {
  const IntentField({
    required this.name,
    required this.kind,
    required this.description,
    this.values = const [],
    this.maxItems = 1,
    this.maxWords = 0,
  });

  /// The JSON key.
  final String name;
  final IntentFieldKind kind;

  /// One line saying what the field controls.
  final String description;

  /// Allowed values ([IntentFieldKind.oneOf] and [IntentFieldKind.listOf]).
  final List<IntentValue> values;

  /// List cap ([IntentFieldKind.listOf]).
  final int maxItems;

  /// Word cap ([IntentFieldKind.text]).
  final int maxWords;
}

/// One hint a family cannot honour, from [ThemeIntent.reportFor].
@immutable
final class IntentNote {
  const IntentNote(this.field, this.value, this.reason);

  /// The intent field (`brightness`, `harmony`, …).
  final String field;

  /// The value that is not honoured.
  final String value;

  /// Why, in a few words (e.g. "dark-only family").
  final String reason;

  @override
  bool operator ==(Object other) =>
      other is IntentNote &&
      other.field == field &&
      other.value == value &&
      other.reason == reason;

  @override
  int get hashCode => Object.hash(field, value, reason);

  @override
  String toString() => 'IntentNote($field: $value, $reason)';
}

/// [ThemeIntent.parse] output: the intent plus what was dropped.
@immutable
final class IntentParseResult {
  const IntentParseResult(this.intent, this.dropped);

  final ThemeIntent intent;

  /// Human-readable descriptions of ignored input (unknown keys, unknown
  /// values, wrong types, unparseable text). Empty when everything was
  /// used.
  final List<String> dropped;
}

// ----------------------------------------------------------------- intent --

/// Steering hints for generated themes. Every field is optional; an empty
/// intent means an ordinary unsteered theme.
///
/// Immutable, with value equality. Build one in code, or from model output
/// with [ThemeIntent.parse] / [ThemeIntent.fromJson].
@immutable
final class ThemeIntent {
  /// An intent. Lists are de-duplicated and capped; disabled families are
  /// dropped; [name] is trimmed to [maxNameWords] words.
  ThemeIntent({
    Iterable<ThemeFamily> families = const [],
    this.brightness,
    Iterable<IntentColor> colors = const [],
    this.chroma,
    this.harmony,
    (int, int)? hueRange,
    String? name,
  }) : families = List.unmodifiable(
         _distinct([
           for (final f in families)
             if (f.enabled) f,
         ]),
       ),
       colors = List.unmodifiable(_distinct(colors).take(maxColors)),
       hueRange = hueRange == null
           ? null
           : (_wrapDeg(hueRange.$1), _wrapDeg(hueRange.$2)),
       name = _cleanName(name);

  /// Lenient: never throws. See [parseJson] for what was dropped.
  factory ThemeIntent.fromJson(Object? json) => parseJson(json).intent;

  /// The empty intent (no steering).
  static final ThemeIntent none = ThemeIntent();

  /// Most colours one intent can name.
  static const int maxColors = 3;

  /// Most words in [name].
  static const int maxNameWords = 3;

  /// Most characters in [name].
  static const int maxNameLength = 32;

  /// Families to draw from (empty: let the feed choose).
  final List<ThemeFamily> families;

  /// Light or dark; null for either.
  final ThemeBrightness? brightness;

  /// Up to [maxColors] colours. The first is the theme's accent (the
  /// operators; Claymorphism's body), and the rest of the palette turns
  /// with it; with no [harmony], the second colours the `=` key and the
  /// third the function keys (engine v5; at v4 the first set the base hue
  /// and the others the operator and `=` hues).
  final List<IntentColor> colors;

  /// How colourful; null for the family's usual range.
  final IntentChroma? chroma;

  /// Colour harmony; null for the family's usual mix.
  final HarmonyScheme? harmony;

  /// A precise base hue range in degrees (from, to), clockwise, wrapping
  /// past 360. Wins over the first colour for the base hue. Not part of
  /// the model vocabulary.
  final (int, int)? hueRange;

  /// The theme's display name (at most [maxNameWords] words); null for a
  /// generated name.
  final String? name;

  /// Whether this intent changes how themes are generated (anything but
  /// [families] and [name]).
  bool get steersColour =>
      brightness != null ||
      colors.isNotEmpty ||
      chroma != null ||
      harmony != null ||
      hueRange != null;

  /// Whether this intent changes anything at all.
  bool get isEmpty => !steersColour && name == null && families.isEmpty;

  /// [brightness], or the first colour's lean (navy leans dark).
  ThemeBrightness? get effectiveBrightness =>
      brightness ?? (colors.isEmpty ? null : colors.first.leanBrightness);

  /// [chroma], or the first colour's lean (lavender leans muted).
  IntentChroma? get effectiveChroma =>
      chroma ?? (colors.isEmpty ? null : colors.first.leanChroma);

  /// The leans as engine v4 (2.0.0) read them: the first colour that has
  /// one, in any position. Kept so v4 themes reproduce.
  ThemeBrightness? get v4Brightness {
    if (brightness != null) return brightness;
    for (final c in colors) {
      if (c.leanBrightness != null) return c.leanBrightness;
    }
    return null;
  }

  /// See [v4Brightness].
  IntentChroma? get v4Chroma {
    if (chroma != null) return chroma;
    for (final c in colors) {
      if (c.leanChroma != null) return c.leanChroma;
    }
    return null;
  }

  /// The part of this intent that shapes one generated theme: everything
  /// but [families] (the feed's business). Feed entries store this.
  ThemeIntent get forEntry => families.isEmpty
      ? this
      : ThemeIntent(
          brightness: brightness,
          colors: colors,
          chroma: chroma,
          harmony: harmony,
          hueRange: hueRange,
          name: name,
        );

  /// [forEntry] without [name] (the spec stores its name itself). Specs
  /// and share codes store this.
  ThemeIntent get forSpec => families.isEmpty && name == null
      ? this
      : ThemeIntent(
          brightness: brightness,
          colors: colors,
          chroma: chroma,
          harmony: harmony,
          hueRange: hueRange,
        );

  /// This intent with [name] replaced (null clears it).
  ThemeIntent withName(String? name) => ThemeIntent(
    families: families,
    brightness: brightness,
    colors: colors,
    chroma: chroma,
    harmony: harmony,
    hueRange: hueRange,
    name: name,
  );

  /// Canonical JSON: fixed key order, absent fields left out.
  Map<String, Object?> toJson() => {
    if (families.isNotEmpty) 'families': [for (final f in families) f.name],
    if (brightness != null) 'brightness': brightness!.name,
    if (colors.isNotEmpty) 'colors': [for (final c in colors) c.word],
    if (chroma != null) 'chroma': chroma!.word,
    if (harmony != null) 'harmony': harmonyWords[harmony],
    if (hueRange != null) 'hueRange': [hueRange!.$1, hueRange!.$2],
    'name': ?name,
  };

  /// The hints [family] cannot honour (empty when it honours them all), at
  /// the newest engine version. Static: no theme is generated.
  List<IntentNote> reportFor(ThemeFamily family) {
    final notes = <IntentNote>[];
    if (!steerableFamilies.contains(family)) {
      const reason = 'family not steerable yet';
      if (brightness != null) {
        notes.add(IntentNote('brightness', brightness!.name, reason));
      }
      for (final c in colors) {
        notes.add(IntentNote('colors', c.word, reason));
      }
      if (chroma != null) notes.add(IntentNote('chroma', chroma!.word, reason));
      if (harmony != null) {
        notes.add(IntentNote('harmony', harmonyWords[harmony]!, reason));
      }
      if (hueRange != null) {
        notes.add(
          IntentNote('hueRange', '${hueRange!.$1}–${hueRange!.$2}', reason),
        );
      }
      return notes;
    }
    final def = family.definition;
    final want = effectiveBrightness;
    if (want != null && !brightnessAllowed(def, want)) {
      notes.add(
        IntentNote(
          'brightness',
          want.name,
          want == ThemeBrightness.light
              ? 'dark-only family'
              : 'light-only family',
        ),
      );
    }
    final h = harmony;
    final honoursHarmony = _harmonyFamilies.contains(family);
    if (h != null) {
      if (!honoursHarmony) {
        notes.add(
          IntentNote(
            'harmony',
            harmonyWords[h]!,
            'family uses its own colour schemes',
          ),
        );
      } else if (!def.schemes.any((w) => w.value == h && w.weight > 0)) {
        notes.add(
          IntentNote('harmony', harmonyWords[h]!, 'not used by this family'),
        );
      }
    }
    if (family == ThemeFamily.bauhaus &&
        colors.length >= 2 &&
        !colors[0].neutral &&
        !colors[1].neutral &&
        h == null) {
      int mid(IntentColor c) =>
          (c.loTenths + ((c.hiTenths - c.loTenths) % 3600) ~/ 2) % 3600;
      final d = (mid(colors[0]) - mid(colors[1])).abs() % 3600;
      if ((d > 1800 ? 3600 - d : d) < bauhausSteeredEqualsApartTenths) {
        notes.add(
          IntentNote(
            'colors',
            colors[1].word,
            'too close to ${colors[0].word} for a second Bauhaus accent',
          ),
        );
      }
    }
    if (family == ThemeFamily.bauhaus) {
      final level = effectiveChroma;
      final grey = colors.isNotEmpty && colors.first.neutral;
      if (level == IntentChroma.muted || grey) {
        notes.add(
          IntentNote(
            grey ? 'colors' : 'chroma',
            grey ? colors.first.word : level!.word,
            'Bauhaus accents stay strong',
          ),
        );
      }
    }
    for (final c in colors.skip(1)) {
      if (c.neutral) {
        notes.add(
          IntentNote('colors', c.word, 'neutrals only quiet the base colour'),
        );
      } else if (h != null && honoursHarmony) {
        notes.add(
          IntentNote('colors', c.word, 'harmony picks the accent colours'),
        );
      }
    }
    return notes;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ThemeIntent &&
          _listEquals(other.families, families) &&
          other.brightness == brightness &&
          _listEquals(other.colors, colors) &&
          other.chroma == chroma &&
          other.harmony == harmony &&
          other.hueRange == hueRange &&
          other.name == name;

  @override
  int get hashCode => Object.hash(
    Object.hashAll(families),
    brightness,
    Object.hashAll(colors),
    chroma,
    harmony,
    hueRange,
    name,
  );

  @override
  String toString() => 'ThemeIntent(${jsonEncode(toJson())})';

  // ---------------------------------------------------------- vocabulary --

  /// The fields and values a host (or its model) may use, as data. Values
  /// are only ever added, never renamed.
  static final List<IntentField> vocabulary = List.unmodifiable([
    IntentField(
      name: 'families',
      kind: IntentFieldKind.listOf,
      description: 'visual styles to draw themes from',
      maxItems: 3,
      values: [
        for (final f in ThemeFamily.enabledFamilies)
          IntentValue(
            f.name,
            _familyDescriptions[f] ?? f.name,
            steerable: steerableFamilies.contains(f),
          ),
      ],
    ),
    const IntentField(
      name: 'brightness',
      kind: IntentFieldKind.oneOf,
      description: 'light or dark overall',
      values: [
        IntentValue('light', 'light backgrounds, dark text'),
        IntentValue('dark', 'dark backgrounds, light text'),
        IntentValue('any', 'either'),
      ],
    ),
    IntentField(
      name: 'colors',
      kind: IntentFieldKind.listOf,
      description: 'main colours, most important first',
      maxItems: maxColors,
      values: [
        for (final c in IntentColor.values) IntentValue(c.word, c.description),
      ],
    ),
    IntentField(
      name: 'chroma',
      kind: IntentFieldKind.oneOf,
      description: 'how colourful',
      values: [
        for (final c in IntentChroma.values) IntentValue(c.word, c.description),
      ],
    ),
    IntentField(
      name: 'harmony',
      kind: IntentFieldKind.oneOf,
      description: 'how the colours relate',
      values: [
        for (final e in harmonyWords.entries)
          IntentValue(e.value, _harmonyDescriptions[e.key]!),
      ],
    ),
    const IntentField(
      name: 'name',
      kind: IntentFieldKind.text,
      description: 'a short evocative theme name',
      maxWords: maxNameWords,
    ),
  ]);

  /// A JSON Schema (draft 2020-12) for model output, generated from
  /// [vocabulary]. With [steerableOnly], `families` offers only
  /// [steerableFamilies].
  static Map<String, Object?> jsonSchema({bool steerableOnly = true}) {
    List<String> words(IntentField f) => [
      for (final v in f.values)
        if (!steerableOnly || v.steerable) v.value,
    ];
    return {
      r'$schema': 'https://json-schema.org/draft/2020-12/schema',
      'type': 'object',
      'additionalProperties': false,
      'properties': {
        for (final f in vocabulary)
          f.name: switch (f.kind) {
            IntentFieldKind.oneOf => {
              'description': f.description,
              'type': 'string',
              'enum': words(f),
            },
            IntentFieldKind.listOf => {
              'description': f.description,
              'type': 'array',
              'items': {'type': 'string', 'enum': words(f)},
              'maxItems': f.maxItems,
              'uniqueItems': true,
            },
            IntentFieldKind.text => {
              'description': '${f.description}, at most ${f.maxWords} words',
              'type': 'string',
              'maxLength': maxNameLength,
            },
          },
      },
    };
  }

  /// Compact prompt text describing the output format, generated from
  /// [vocabulary] (for models without schema-constrained output). With
  /// [steerableOnly], `families` offers only [steerableFamilies].
  static String promptFragment({bool steerableOnly = true}) {
    final b = StringBuffer()
      ..writeln(
        'Reply with one JSON object describing a calculator theme that '
        'matches the words. Every field is optional: leave out what the '
        'words do not suggest. Use only these values.',
      );
    for (final f in vocabulary) {
      final values = [
        for (final v in f.values)
          if (!steerableOnly || v.steerable) v,
      ];
      switch (f.kind) {
        case IntentFieldKind.oneOf:
          b.writeln('- ${f.name} (${f.description}): one of');
        case IntentFieldKind.listOf:
          b.writeln(
            '- ${f.name} (${f.description}): up to ${f.maxItems} of',
          );
        case IntentFieldKind.text:
          b.writeln(
            '- ${f.name}: ${f.description}, at most ${f.maxWords} words',
          );
      }
      for (final v in values) {
        b.writeln('  ${v.value}: ${v.description}');
      }
    }
    b.write(
      'Example for "playful greenery": '
      '${jsonEncode({
        'brightness': 'light',
        'colors': ['green', 'lime'],
        'chroma': 'vivid',
        'harmony': 'analogous',
        'name': 'Playful Greenery',
      })}',
    );
    return b.toString();
  }

  // -------------------------------------------------------------- parsing --

  /// Parses model output: the first JSON object in [raw] (surrounding
  /// prose and code fences are ignored), then [parseJson]. Never throws.
  static IntentParseResult parse(String raw) {
    final object = _firstJsonObject(raw);
    if (object == null) {
      return IntentParseResult(ThemeIntent.none, const ['no JSON object']);
    }
    Object? decoded;
    try {
      decoded = jsonDecode(object);
    } on FormatException {
      return IntentParseResult(ThemeIntent.none, const ['unparseable JSON']);
    }
    return parseJson(decoded);
  }

  /// Reads a decoded JSON value leniently: keys and words are matched
  /// case-insensitively (ignoring spaces, `-` and `_`), a few synonyms are
  /// accepted, single values stand in for lists, and everything unusable
  /// is dropped and listed. Never throws.
  static IntentParseResult parseJson(Object? json) {
    final dropped = <String>[];
    if (json is! Map) {
      if (json != null) dropped.add('not a JSON object');
      return IntentParseResult(ThemeIntent.none, List.unmodifiable(dropped));
    }
    final families = <ThemeFamily>[];
    ThemeBrightness? brightness;
    final colors = <IntentColor>[];
    IntentChroma? chroma;
    HarmonyScheme? harmony;
    (int, int)? hueRange;
    String? name;

    for (final entry in json.entries) {
      final key = entry.key is String ? _norm(entry.key as String) : '';
      final value = entry.value;
      switch (key) {
        case 'families' || 'family' || 'style' || 'styles':
          for (final v in _list(value)) {
            final f = _family(v);
            if (f == null) {
              dropped.add('families: $v');
            } else {
              families.add(f);
            }
          }
        case 'brightness' || 'mode' || 'tone':
          final w = value is String ? _norm(value) : null;
          switch (w) {
            case 'light' || 'bright' || 'day':
              brightness = ThemeBrightness.light;
            case 'dark' || 'night':
              brightness = ThemeBrightness.dark;
            case 'any' || 'either' || 'auto' || 'none':
              brightness = null;
            default:
              dropped.add('brightness: $value');
          }
        case 'colors' || 'colours' || 'color' || 'colour' || 'palette':
          for (final v in _list(value, splitText: true)) {
            final c = _color(v);
            if (c == null) {
              dropped.add('colors: $v');
            } else {
              colors.add(c);
            }
          }
        case 'chroma' || 'saturation' || 'intensity' || 'vibrancy':
          final c = value is String ? _chroma(_norm(value)) : null;
          if (c == null) {
            dropped.add('chroma: $value');
          } else {
            chroma = c;
          }
        case 'harmony' || 'scheme':
          final h = value is String ? _harmony(_norm(value)) : null;
          if (h == null) {
            dropped.add('harmony: $value');
          } else {
            harmony = h;
          }
        case 'huerange' || 'hue':
          final r = _hueRange(value);
          if (r == null) {
            dropped.add('hueRange: $value');
          } else {
            hueRange = r;
          }
        case 'name' || 'title':
          final n = value is String ? _cleanName(value) : null;
          if (n == null) {
            dropped.add('name: $value');
          } else {
            name = n;
          }
        default:
          dropped.add('unknown key ${entry.key}');
      }
    }
    final distinctColors = _distinct(colors);
    for (final c in distinctColors.skip(maxColors)) {
      dropped.add('colors: ${c.word} (more than $maxColors)');
    }
    return IntentParseResult(
      ThemeIntent(
        families: families,
        brightness: brightness,
        colors: distinctColors,
        chroma: chroma,
        harmony: harmony,
        hueRange: hueRange,
        name: name,
      ),
      List.unmodifiable(dropped),
    );
  }
}

// ---------------------------------------------------------------- helpers --

/// Whether [def] ever draws [b].
bool brightnessAllowed(FamilyDefinition def, ThemeBrightness b) {
  final w = def.brightnessWeights;
  final i = b == ThemeBrightness.dark ? 0 : 1;
  return i < w.length && w[i] > 0;
}

int _wrapDeg(int d) => d % 360;

List<T> _distinct<T>(Iterable<T> items) {
  final seen = <T>{};
  return [
    for (final i in items)
      if (seen.add(i)) i,
  ];
}

bool _listEquals<T>(List<T> a, List<T> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

String? _cleanName(String? raw) {
  if (raw == null) return null;
  final words = raw
      .trim()
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty)
      .take(ThemeIntent.maxNameWords)
      .join(' ');
  if (words.isEmpty) return null;
  return words.length <= ThemeIntent.maxNameLength
      ? words
      : words.substring(0, ThemeIntent.maxNameLength).trimRight();
}

/// Lower case without spaces, `-` and `_`.
String _norm(String s) => s.toLowerCase().replaceAll(RegExp(r'[\s_\-]'), '');

List<Object?> _list(Object? value, {bool splitText = false}) {
  if (value is List) return value;
  if (value is String && splitText) {
    return value
        .split(RegExp(r'\s*(?:,|/|&|\band\b|\bwith\b)\s*'))
        .where((s) => s.trim().isNotEmpty)
        .toList();
  }
  return value == null ? const [] : [value];
}

ThemeFamily? _family(Object? v) {
  if (v is int) {
    final f = ThemeFamily.fromId(v);
    return f != null && f.enabled ? f : null;
  }
  if (v is! String) return null;
  final w = _norm(v);
  const aliases = {
    'm3': ThemeFamily.m3Expressive,
    'material': ThemeFamily.m3Expressive,
    'material3': ThemeFamily.m3Expressive,
    'clay': ThemeFamily.claymorphism,
    'glass': ThemeFamily.liquidGlass,
    'y2k': ThemeFamily.y2kChrome,
    'paper': ThemeFamily.paperInk,
    'brutalism': ThemeFamily.neoBrutalism,
  };
  final alias = aliases[w];
  if (alias != null) return alias;
  for (final f in ThemeFamily.values) {
    if (f.enabled && _norm(f.name) == w) return f;
  }
  return null;
}

IntentColor? _color(Object? v) {
  if (v is int) return IntentColor.fromCode(v);
  if (v is! String) return null;
  final w = _norm(v);
  const aliases = {
    'gray': IntentColor.grey,
    'silver': IntentColor.grey,
    'beige': IntentColor.sand,
    'cream': IntentColor.sand,
    'aqua': IntentColor.cyan,
    'turquoise': IntentColor.teal,
    'emerald': IntentColor.green,
    'forest': IntentColor.green,
    'rose': IntentColor.pink,
    'lilac': IntentColor.lavender,
    'crimson': IntentColor.red,
    'scarlet': IntentColor.red,
    'tan': IntentColor.sand,
    'khaki': IntentColor.olive,
  };
  final alias = aliases[w];
  if (alias != null) return alias;
  for (final c in IntentColor.values) {
    if (c.word == w) return c;
  }
  // Plurals and "-ish" ("greens", "bluish").
  for (final c in IntentColor.values) {
    if (w == '${c.word}s' || w == '${c.word}ish') return c;
  }
  return null;
}

IntentChroma? _chroma(String w) => switch (w) {
  'muted' || 'soft' || 'subtle' || 'pastel' || 'calm' => IntentChroma.muted,
  'balanced' || 'medium' || 'moderate' || 'normal' => IntentChroma.balanced,
  'vivid' || 'bold' || 'bright' || 'saturated' || 'loud' => IntentChroma.vivid,
  _ => null,
};

HarmonyScheme? _harmony(String w) => switch (w) {
  'mono' ||
  'monochrome' ||
  'monochromatic' ||
  'tonal' => HarmonyScheme.monochrome,
  'analogous' || 'analogue' || 'analog' => HarmonyScheme.analogous,
  'complementary' ||
  'complement' ||
  'contrasting' => HarmonyScheme.complementary,
  'split' ||
  'splitcomplementary' ||
  'splitcomplement' => HarmonyScheme.splitComplementary,
  'triad' || 'triadic' => HarmonyScheme.triadic,
  'duotone' || 'twotone' => HarmonyScheme.duotone,
  _ => null,
};

(int, int)? _hueRange(Object? v) {
  int? deg(Object? x) => x is num && x.isFinite ? x.round() : null;
  if (v is num) {
    final d = deg(v);
    return d == null ? null : (d - 15, d + 15);
  }
  if (v is List && v.length == 2) {
    final a = deg(v[0]);
    final b = deg(v[1]);
    return a == null || b == null ? null : (a, b);
  }
  if (v is Map) {
    final a = deg(v['from'] ?? v['min'] ?? v['start']);
    final b = deg(v['to'] ?? v['max'] ?? v['end']);
    return a == null || b == null ? null : (a, b);
  }
  return null;
}

/// The first balanced `{…}` in [s] (string-aware), or null.
String? _firstJsonObject(String s) {
  final start = s.indexOf('{');
  if (start < 0) return null;
  var depth = 0;
  var inString = false;
  var escaped = false;
  for (var i = start; i < s.length; i++) {
    final ch = s[i];
    if (inString) {
      if (escaped) {
        escaped = false;
      } else if (ch == r'\') {
        escaped = true;
      } else if (ch == '"') {
        inString = false;
      }
      continue;
    }
    if (ch == '"') {
      inString = true;
    } else if (ch == '{') {
      depth++;
    } else if (ch == '}') {
      depth--;
      if (depth == 0) return s.substring(start, i + 1);
    }
  }
  return null;
}
