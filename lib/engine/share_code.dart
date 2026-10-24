/// Share codes and deep links (research theme-engine.md §11,
/// Recommendation 13).
///
/// 50 bits = family (5) + engineVersion (6) + seed (32) + CRC-7 (7), as 10
/// Crockford base32 symbols shown `XXXXX-XXXXX`. CRC polynomial
/// x⁷ + x³ + 1 (0x09) is primitive, so every single-symbol substitution and
/// every transposition of two different symbols is detected. Decoding is
/// case-insensitive, maps `O → 0` and `I`/`L → 1`, and ignores hyphens and
/// spaces. Deep link: `calsee://t/CODE` (lowercase scheme and host,
/// because Android matches them case-sensitively); web form
/// `https://calsee.tech/t/CODE` (parsed only; App Links / Universal Links
/// verification is pending, docs/release/README.md).
///
/// Steered themes (engine v4) use a longer, versioned code: 125 bits as 25
/// symbols shown `XXXXX-XXXXX-XXXXX-XXXXX-XXXXX`:
///
/// | bits | field |
/// |---|---|
/// | 4 | format ([steeredCodeFormat]; a newer one reads as "needs update") |
/// | 5, 6, 32 | family, engineVersion, seed (as above) |
/// | 1 | centred |
/// | 2 | brightness (0 none, 1 light, 2 dark) |
/// | 2 | chroma (0 none, 1 muted, 2 balanced, 3 vivid) |
/// | 3 | harmony (0 none, then [steeredHarmonies] order) |
/// | 2 + 3 × 5 | colour count and `IntentColor.code`s |
/// | 1 + 9 + 9 | hue range flag, from and to degrees |
/// | 18 | reserved (zero) |
/// | 16 | CRC-16/CCITT (x¹⁶ + x¹² + x⁵ + 1) over the 109 bits before it |
///
/// The CRC catches every single-symbol error and every swap of two
/// neighbouring symbols. A steered code carries the theme's intent but not
/// its families (the family is in the code) or its name (links may add
/// `?name=`). Builds before 2.0.0 accept only 10-symbol codes, so they
/// reject a steered code as invalid; they never open the wrong theme.
library;

import 'package:calsee_themes/engine/families.dart' show HarmonyScheme;
import 'package:calsee_themes/engine/theme_intent.dart';
import 'package:calsee_themes/engine/theme_spec.dart' show ThemeBrightness;
import 'package:meta/meta.dart';

/// Crockford base32 alphabet (no I, L, O, U).
const String crockfordAlphabet = '0123456789ABCDEFGHJKMNPQRSTVWXYZ';

/// Family field value for hero themes (seed = hero id).
const int shareFamilyHero = 31;

/// Reserved family field value.
const int shareFamilyReserved = 30;

/// Deep-link scheme (lowercase).
const String deepLinkScheme = 'calsee';

/// Pre-release placeholder scheme, still accepted when parsing so links
/// made by development builds keep working.
const String legacyDeepLinkScheme = 'infinitecalc';

/// Web hosts whose `https://<host>/t/CODE` links are theme links.
const Set<String> deepLinkWebHosts = {'calsee.tech', 'www.calsee.tech'};

/// Deep-link host for themes (lowercase).
const String deepLinkThemeHost = 't';

/// Format number of steered (25-symbol) codes.
const int steeredCodeFormat = 1;

/// Harmony order in steered codes (stable: append only).
const List<HarmonyScheme> steeredHarmonies = [
  HarmonyScheme.monochrome,
  HarmonyScheme.analogous,
  HarmonyScheme.complementary,
  HarmonyScheme.splitComplementary,
  HarmonyScheme.triadic,
  HarmonyScheme.duotone,
];

const int _shortLength = 10;
const int _longLength = 25;

/// What a typed or pasted code is.
enum ShareCodeStatus {
  /// Decodes ([decodeShareCode] returns a payload).
  valid,

  /// Mistyped, damaged, or not a code.
  invalid,

  /// A well-formed code from a newer app (an unknown steered format):
  /// "update the app to open this theme".
  needsUpdate,
}

/// Decoded share-code payload.
@immutable
final class SharePayload {
  const SharePayload({
    required this.familyId,
    required this.engineVersion,
    required this.seed,
    this.intent,
    this.centred = false,
    this.name,
  });

  /// Stable family id (`ThemeFamily.id`), or [shareFamilyHero].
  final int familyId;

  /// Generator version, 0–63.
  final int engineVersion;

  /// 32-bit seed (hero id for heroes).
  final int seed;

  /// The steering intent of a steered code (without families or name);
  /// null for a plain code.
  final ThemeIntent? intent;

  /// Whether a steered theme was generated centred on its intent.
  final bool centred;

  /// The theme name a link carried (`?name=`); never part of the code.
  final String? name;

  /// Whether this names a hand-crafted hero theme.
  bool get isHero => familyId == shareFamilyHero;

  /// This payload with [name] set.
  SharePayload withName(String? name) => SharePayload(
    familyId: familyId,
    engineVersion: engineVersion,
    seed: seed,
    intent: intent,
    centred: centred,
    name: name,
  );

  @override
  bool operator ==(Object other) =>
      other is SharePayload &&
      other.familyId == familyId &&
      other.engineVersion == engineVersion &&
      other.seed == seed &&
      other.intent == intent &&
      other.centred == centred &&
      other.name == name;

  @override
  int get hashCode =>
      Object.hash(familyId, engineVersion, seed, intent, centred, name);

  @override
  String toString() =>
      'SharePayload(family: $familyId, v$engineVersion, '
      'seed: 0x${seed.toRadixString(16)}'
      '${intent == null ? '' : ', $intent'}${centred ? ', centred' : ''})';
}

void _pushBits(List<int> out, int v, int n) {
  for (var i = n - 1; i >= 0; i--) {
    out.add((v >>> i) & 1); // v < 2^32, safe on the web
  }
}

int _readBits(List<int> bits, int from, int n) {
  var v = 0;
  for (var i = from; i < from + n; i++) {
    v = v * 2 + bits[i];
  }
  return v;
}

/// CRC-7, polynomial x⁷ + x³ + 1 (0x09), MSB-first, init 0, over [bits]
/// (each 0 or 1).
int crc7(List<int> bits) {
  var crc = 0;
  for (final b in bits) {
    final top = ((crc >> 6) & 1) ^ b;
    crc = (crc << 1) & 0x7F;
    if (top == 1) crc ^= 0x09;
  }
  return crc;
}

/// Encodes a payload as `XXXXX-XXXXX`. [familyId] 0–31, [engineVersion]
/// 0–63; [seed] is taken modulo 2^32.
String encodeShareCode(int familyId, int engineVersion, int seed) {
  if (familyId < 0 || familyId > 31) {
    throw RangeError.range(familyId, 0, 31, 'familyId');
  }
  if (engineVersion < 0 || engineVersion > 63) {
    throw RangeError.range(engineVersion, 0, 63, 'engineVersion');
  }
  final bits = <int>[];
  _pushBits(bits, familyId, 5);
  _pushBits(bits, engineVersion, 6);
  _pushBits(bits, seed & 0xFFFFFFFF, 32);
  _pushBits(bits, crc7(bits), 7);
  final sb = StringBuffer();
  for (var i = 0; i < 50; i += 5) {
    if (i == 25) sb.write('-');
    sb.write(crockfordAlphabet[_readBits(bits, i, 5)]);
  }
  return sb.toString();
}

/// CRC-16/CCITT, polynomial x¹⁶ + x¹² + x⁵ + 1 (0x1021), MSB-first,
/// init 0, over [bits] (each 0 or 1).
int crc16(List<int> bits) {
  var crc = 0;
  for (final b in bits) {
    final top = ((crc >> 15) & 1) ^ b;
    crc = (crc << 1) & 0xFFFF;
    if (top == 1) crc ^= 0x1021;
  }
  return crc;
}

/// Encodes a steered theme as `XXXXX-XXXXX-XXXXX-XXXXX-XXXXX`: [familyId]
/// 0–29, [engineVersion] 0–63, [seed] modulo 2^32, and [intent]'s
/// generation fields (families and name are not stored).
String encodeSteeredShareCode(
  int familyId,
  int engineVersion,
  int seed,
  ThemeIntent intent, {
  bool centred = false,
}) {
  if (familyId < 0 || familyId >= shareFamilyReserved) {
    throw RangeError.range(familyId, 0, shareFamilyReserved - 1, 'familyId');
  }
  if (engineVersion < 0 || engineVersion > 63) {
    throw RangeError.range(engineVersion, 0, 63, 'engineVersion');
  }
  final bits = <int>[];
  _pushBits(bits, steeredCodeFormat, 4);
  _pushBits(bits, familyId, 5);
  _pushBits(bits, engineVersion, 6);
  _pushBits(bits, seed & 0xFFFFFFFF, 32);
  _pushBits(bits, centred ? 1 : 0, 1);
  _pushBits(bits, switch (intent.brightness) {
    null => 0,
    ThemeBrightness.light => 1,
    ThemeBrightness.dark => 2,
  }, 2);
  _pushBits(bits, intent.chroma == null ? 0 : intent.chroma!.index + 1, 2);
  final h = intent.harmony;
  _pushBits(bits, h == null ? 0 : steeredHarmonies.indexOf(h) + 1, 3);
  final colors = intent.colors;
  _pushBits(bits, colors.length, 2);
  for (var i = 0; i < ThemeIntent.maxColors; i++) {
    _pushBits(bits, i < colors.length ? colors[i].code : 0, 5);
  }
  final hr = intent.hueRange;
  _pushBits(bits, hr == null ? 0 : 1, 1);
  _pushBits(bits, hr?.$1 ?? 0, 9);
  _pushBits(bits, hr?.$2 ?? 0, 9);
  _pushBits(bits, 0, 18);
  _pushBits(bits, crc16(bits), 16);
  return _symbols(bits);
}

/// [bits] as Crockford symbols in hyphenated groups of five.
String _symbols(List<int> bits) {
  final sb = StringBuffer();
  for (var i = 0; i < bits.length; i += 5) {
    if (i > 0 && i % 25 == 0) sb.write('-');
    sb.write(crockfordAlphabet[_readBits(bits, i, 5)]);
  }
  return sb.toString();
}

/// Encodes [payload] (see [encodeShareCode] and [encodeSteeredShareCode]).
String encodePayload(SharePayload payload) => payload.intent == null
    ? encodeShareCode(payload.familyId, payload.engineVersion, payload.seed)
    : encodeSteeredShareCode(
        payload.familyId,
        payload.engineVersion,
        payload.seed,
        payload.intent!,
        centred: payload.centred,
      );

/// Normalises user input to the 10 (or, for steered codes, 25) canonical
/// symbols (upper case, `O → 0`, `I`/`L → 1`, hyphens and whitespace
/// dropped), or null if it contains a character outside the alphabet or
/// has the wrong length.
String? normalizeShareCode(String input) {
  final buf = StringBuffer();
  for (final rune in input.toUpperCase().runes) {
    final ch = String.fromCharCode(rune);
    if (ch == '-' || ch.trim().isEmpty) continue;
    final mapped = switch (ch) {
      'O' => '0',
      'I' || 'L' => '1',
      _ => ch,
    };
    if (!crockfordAlphabet.contains(mapped)) return null;
    buf.write(mapped);
  }
  final s = buf.toString();
  return s.length == _shortLength || s.length == _longLength ? s : null;
}

List<int> _bitsOf(String normalized) {
  final bits = <int>[];
  for (final unit in normalized.codeUnits) {
    _pushBits(bits, crockfordAlphabet.indexOf(String.fromCharCode(unit)), 5);
  }
  return bits;
}

/// Whether [input] is a valid code, a damaged one, or one from a newer app.
ShareCodeStatus shareCodeStatus(String input) {
  final s = normalizeShareCode(input);
  if (s == null) return ShareCodeStatus.invalid;
  if (s.length == _longLength) {
    final bits = _bitsOf(s);
    if (crc16(bits.sublist(0, 109)) != _readBits(bits, 109, 16)) {
      return ShareCodeStatus.invalid;
    }
    if (_readBits(bits, 0, 4) > steeredCodeFormat) {
      return ShareCodeStatus.needsUpdate;
    }
  }
  return decodeShareCode(input) == null
      ? ShareCodeStatus.invalid
      : ShareCodeStatus.valid;
}

/// Decodes a share code (plain or steered), or null when it is malformed,
/// fails its CRC, or is a steered format this build does not know (see
/// [shareCodeStatus]). Callers must still check the family id and that
/// [SharePayload.engineVersion] is not newer than the app's ("update the
/// app to open this theme").
SharePayload? decodeShareCode(String input) {
  final s = normalizeShareCode(input);
  if (s == null) return null;
  final bits = _bitsOf(s);
  if (s.length == _longLength) return _decodeSteered(bits);
  if (crc7(bits.sublist(0, 43)) != _readBits(bits, 43, 7)) return null;
  return SharePayload(
    familyId: _readBits(bits, 0, 5),
    engineVersion: _readBits(bits, 5, 6),
    seed: _readBits(bits, 11, 32),
  );
}

SharePayload? _decodeSteered(List<int> bits) {
  if (crc16(bits.sublist(0, 109)) != _readBits(bits, 109, 16)) return null;
  if (_readBits(bits, 0, 4) != steeredCodeFormat) return null;
  if (_readBits(bits, 91, 18) != 0) return null;
  final familyId = _readBits(bits, 4, 5);
  if (familyId >= shareFamilyReserved) return null;
  final brightness = switch (_readBits(bits, 48, 2)) {
    0 => null,
    1 => ThemeBrightness.light,
    2 => ThemeBrightness.dark,
    _ => null,
  };
  if (_readBits(bits, 48, 2) == 3) return null;
  final chromaBits = _readBits(bits, 50, 2);
  final harmonyBits = _readBits(bits, 52, 3);
  if (harmonyBits > steeredHarmonies.length) return null;
  final count = _readBits(bits, 55, 2);
  if (count > ThemeIntent.maxColors) return null;
  final colors = <IntentColor>[];
  for (var i = 0; i < count; i++) {
    final c = IntentColor.fromCode(_readBits(bits, 57 + 5 * i, 5));
    if (c == null) return null;
    colors.add(c);
  }
  final hasHue = _readBits(bits, 72, 1) == 1;
  final from = _readBits(bits, 73, 9);
  final to = _readBits(bits, 82, 9);
  if (hasHue && (from >= 360 || to >= 360)) return null;
  final intent = ThemeIntent(
    brightness: brightness,
    chroma: chromaBits == 0 ? null : IntentChroma.values[chromaBits - 1],
    harmony: harmonyBits == 0 ? null : steeredHarmonies[harmonyBits - 1],
    colors: colors,
    hueRange: hasHue ? (from, to) : null,
  );
  return SharePayload(
    familyId: familyId,
    engineVersion: _readBits(bits, 9, 6),
    seed: _readBits(bits, 15, 32),
    intent: intent,
    centred: _readBits(bits, 47, 1) == 1,
  );
}

/// [normalized] in hyphenated groups of five.
String _grouped(String normalized) {
  final groups = [
    for (var i = 0; i < normalized.length; i += 5)
      normalized.substring(i, i + 5),
  ];
  return groups.join('-');
}

String _nameQuery(String? name) => name == null || name.trim().isEmpty
    ? ''
    : '?${Uri(queryParameters: {'name': name.trim()}).query}';

/// Formats the deep link for [code]: `calsee://t/XXXXX-XXXXX` (steered
/// codes have five groups). [name] adds `?name=` (steered themes'
/// display names travel this way).
String formatThemeDeepLink(String code, {String? name}) {
  final s = normalizeShareCode(code);
  if (s == null) throw FormatException('Invalid share code', code);
  return '$deepLinkScheme://$deepLinkThemeHost/${_grouped(s)}'
      '${_nameQuery(name)}';
}

/// Formats the web form of the link for [code]:
/// `https://calsee.tech/t/XXXXX-XXXXX` (and [name] as `?name=`).
String formatThemeWebLink(String code, {String? name}) {
  final s = normalizeShareCode(code);
  if (s == null) throw FormatException('Invalid share code', code);
  return 'https://${deepLinkWebHosts.first}/$deepLinkThemeHost/'
      '${_grouped(s)}${_nameQuery(name)}';
}

/// Parses a theme deep link (`calsee://t/CODE`, or the pre-release
/// `infinitecalc://t/CODE`; scheme and host lowercase, the code may be any
/// case) or a web link (`https://calsee.tech/t/CODE`). Returns null for
/// anything else or a bad code. A `name` query parameter becomes
/// [SharePayload.name] (trimmed to `ThemeIntent.maxNameWords` words).
SharePayload? parseThemeDeepLink(String link) {
  final uri = Uri.tryParse(link.trim());
  if (uri == null) return null;
  String? code;
  if ((uri.scheme == deepLinkScheme || uri.scheme == legacyDeepLinkScheme) &&
      uri.host == deepLinkThemeHost) {
    final segs = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    if (segs.length == 1) code = segs.single;
  } else if (uri.scheme == 'https' && deepLinkWebHosts.contains(uri.host)) {
    final segs = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    if (segs.length == 2 && segs[0] == deepLinkThemeHost) code = segs[1];
  }
  if (code == null) return null;
  final payload = decodeShareCode(code);
  if (payload == null) return null;
  final name = ThemeIntent(name: uri.queryParameters['name']).name;
  return name == null ? payload : payload.withName(name);
}
