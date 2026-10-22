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
library;

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

/// Decoded share-code payload.
@immutable
final class SharePayload {
  const SharePayload({
    required this.familyId,
    required this.engineVersion,
    required this.seed,
  });

  /// Stable family id (`ThemeFamily.id`), or [shareFamilyHero].
  final int familyId;

  /// Generator version, 0–63.
  final int engineVersion;

  /// 32-bit seed (hero id for heroes).
  final int seed;

  /// Whether this names a hand-crafted hero theme.
  bool get isHero => familyId == shareFamilyHero;

  @override
  bool operator ==(Object other) =>
      other is SharePayload &&
      other.familyId == familyId &&
      other.engineVersion == engineVersion &&
      other.seed == seed;

  @override
  int get hashCode => Object.hash(familyId, engineVersion, seed);

  @override
  String toString() =>
      'SharePayload(family: $familyId, v$engineVersion, '
      'seed: 0x${seed.toRadixString(16)})';
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

/// Encodes [payload] (see [encodeShareCode]).
String encodePayload(SharePayload payload) =>
    encodeShareCode(payload.familyId, payload.engineVersion, payload.seed);

/// Normalises user input to the 10 canonical symbols (upper case, `O → 0`,
/// `I`/`L → 1`, hyphens and whitespace dropped), or null if it contains a
/// character outside the alphabet or has the wrong length.
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
  return s.length == 10 ? s : null;
}

/// Decodes a share code, or null when it is malformed or fails the CRC.
/// Callers must still check the family id and that [SharePayload.
/// engineVersion] is not newer than the app's ("update the app to open
/// this theme").
SharePayload? decodeShareCode(String input) {
  final s = normalizeShareCode(input);
  if (s == null) return null;
  final bits = <int>[];
  for (final unit in s.codeUnits) {
    _pushBits(bits, crockfordAlphabet.indexOf(String.fromCharCode(unit)), 5);
  }
  if (crc7(bits.sublist(0, 43)) != _readBits(bits, 43, 7)) return null;
  return SharePayload(
    familyId: _readBits(bits, 0, 5),
    engineVersion: _readBits(bits, 5, 6),
    seed: _readBits(bits, 11, 32),
  );
}

/// Formats the deep link for [code]: `calsee://t/XXXXX-XXXXX`.
String formatThemeDeepLink(String code) {
  final s = normalizeShareCode(code);
  if (s == null) throw FormatException('Invalid share code', code);
  return '$deepLinkScheme://$deepLinkThemeHost/'
      '${s.substring(0, 5)}-${s.substring(5)}';
}

/// Formats the web form of the link for [code]:
/// `https://calsee.tech/t/XXXXX-XXXXX`.
String formatThemeWebLink(String code) {
  final s = normalizeShareCode(code);
  if (s == null) throw FormatException('Invalid share code', code);
  return 'https://${deepLinkWebHosts.first}/$deepLinkThemeHost/'
      '${s.substring(0, 5)}-${s.substring(5)}';
}

/// Parses a theme deep link (`calsee://t/CODE`, or the pre-release
/// `infinitecalc://t/CODE`; scheme and host lowercase, the code may be any
/// case) or a web link (`https://calsee.tech/t/CODE`). Returns null for
/// anything else or a bad code.
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
  return code == null ? null : decodeShareCode(code);
}
