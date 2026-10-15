import 'package:calsee_themes/engine/families.dart';
import 'package:calsee_themes/engine/rng.dart';
import 'package:calsee_themes/engine/share_code.dart';
import 'package:test/test.dart';

void main() {
  test('known answer (research §11.1)', () {
    expect(encodeShareCode(4, 1, 0xDEADBEEF), '40XXB-DYXZ0');
    expect(
      decodeShareCode('40XXB-DYXZ0'),
      const SharePayload(familyId: 4, engineVersion: 1, seed: 0xDEADBEEF),
    );
  });

  test('round trip for every family, version and many seeds', () {
    final r = Rng.stream(1, 'share');
    final families = [
      for (final f in ThemeFamily.values) f.id,
      shareFamilyHero,
      shareFamilyReserved,
    ];
    for (final fam in families) {
      for (var v = 0; v < 64; v++) {
        for (final seed in [0, 1, 0xFFFFFFFF, r.nextU32(), r.nextU32()]) {
          final code = encodeShareCode(fam, v, seed);
          expect(
            code,
            matches(RegExp(r'^[0-9A-HJKMNP-TV-Z]{5}-[0-9A-HJKMNP-TV-Z]{5}$')),
          );
          final p = decodeShareCode(code)!;
          expect((p.familyId, p.engineVersion, p.seed), (fam, v, seed));
        }
      }
    }
    expect(decodeShareCode(encodeShareCode(31, 1, 7))!.isHero, isTrue);
  });

  test('case-insensitive, aliases, separators', () {
    const code = '40XXB-DYXZ0';
    final want = decodeShareCode(code);
    expect(decodeShareCode('40xxb-dyxz0'), want);
    expect(decodeShareCode('4OXXB DYXZO'), want); // O → 0
    expect(decodeShareCode('40XXBDYXZ0'), want);
    expect(decodeShareCode(' 40XX-B-DYXZ0 '), want);
    var seed = 0;
    while (!encodeShareCode(1, 1, seed).contains('1')) {
      seed++;
    }
    final withOne = encodeShareCode(1, 1, seed);
    expect(
      decodeShareCode(withOne.replaceAll('1', 'l')),
      decodeShareCode(withOne),
    );
    expect(
      decodeShareCode(withOne.replaceAll('1', 'I')),
      decodeShareCode(withOne),
    );
  });

  test('malformed input never throws', () {
    for (final bad in [
      '',
      'ABC',
      '40XXB-DYXZ',
      '40XXB-DYXZ00',
      '40XXB-DYXZU',
      '40XXB-DYXZ!',
      'ÄÖÜ',
    ]) {
      expect(decodeShareCode(bad), isNull, reason: bad);
    }
    expect(() => encodeShareCode(32, 0, 0), throwsRangeError);
    expect(() => encodeShareCode(0, 64, 0), throwsRangeError);
  });

  test('every single-symbol substitution is detected', () {
    final r = Rng.stream(2, 'subst');
    var checked = 0;
    for (var n = 0; n < 2000; n++) {
      final code = encodeShareCode(
        r.nextInt(32),
        r.nextInt(64),
        r.nextU32(),
      ).replaceAll('-', '');
      for (var pos = 0; pos < 10; pos++) {
        for (final ch in crockfordAlphabet.split('')) {
          if (ch == code[pos]) continue;
          final mutated = code.replaceRange(pos, pos + 1, ch);
          expect(decodeShareCode(mutated), isNull, reason: '$code → $mutated');
          checked++;
        }
      }
    }
    expect(checked, 2000 * 10 * 31);
  });

  test('every transposition of two different symbols is detected', () {
    final r = Rng.stream(3, 'transpose');
    var checked = 0;
    for (var n = 0; n < 2000; n++) {
      final code = encodeShareCode(
        r.nextInt(32),
        r.nextInt(64),
        r.nextU32(),
      ).replaceAll('-', '');
      for (var i = 0; i < 10; i++) {
        for (var j = i + 1; j < 10; j++) {
          if (code[i] == code[j]) continue;
          final chars = code.split('');
          final t = chars[i];
          chars[i] = chars[j];
          chars[j] = t;
          expect(decodeShareCode(chars.join()), isNull);
          checked++;
        }
      }
    }
    expect(checked, greaterThan(80000));
  });

  test('crc7 of the empty message is 0; known polynomial', () {
    expect(crc7([]), 0);
    // The message x^0 (one 1 bit) is shifted by x^7: x^7 mod p = x^3 + 1.
    expect(crc7([1]), 0x09);
  });

  group('deep links', () {
    test('format and parse', () {
      final link = formatThemeDeepLink('40xxbdyxz0');
      expect(link, 'calsee://t/40XXB-DYXZ0');
      expect(
        parseThemeDeepLink(link),
        const SharePayload(familyId: 4, engineVersion: 1, seed: 0xDEADBEEF),
      );
      expect(parseThemeDeepLink('calsee://t/40xxb-dyxz0'), isNotNull);
      expect(parseThemeDeepLink('calsee://t/40XXB-DYXZ1'), isNull);
      expect(parseThemeDeepLink('calsee://x/40XXB-DYXZ0'), isNull);
      expect(parseThemeDeepLink('other://t/40XXB-DYXZ0'), isNull);
      expect(parseThemeDeepLink('calsee://t/'), isNull);
      expect(parseThemeDeepLink('not a link'), isNull);
      expect(() => formatThemeDeepLink('bad'), throwsFormatException);
    });

    test('web links on calsee.tech', () {
      final web = formatThemeWebLink('40xxbdyxz0');
      expect(web, 'https://calsee.tech/t/40XXB-DYXZ0');
      const payload = SharePayload(
        familyId: 4,
        engineVersion: 1,
        seed: 0xDEADBEEF,
      );
      expect(parseThemeDeepLink(web), payload);
      expect(
        parseThemeDeepLink('https://www.calsee.tech/t/40xxb-dyxz0'),
        payload,
      );
      expect(parseThemeDeepLink('https://example.com/t/40XXB-DYXZ0'), isNull);
      expect(parseThemeDeepLink('http://calsee.tech/t/40XXB-DYXZ0'), isNull);
      expect(parseThemeDeepLink('https://calsee.tech/x/40XXB-DYXZ0'), isNull);
      expect(parseThemeDeepLink('https://calsee.tech/t/40XXB-DYXZ1'), isNull);
      expect(() => formatThemeWebLink('bad'), throwsFormatException);
    });

    test('still parses the pre-release infinitecalc scheme', () {
      expect(
        parseThemeDeepLink('infinitecalc://t/40XXB-DYXZ0'),
        const SharePayload(familyId: 4, engineVersion: 1, seed: 0xDEADBEEF),
      );
      expect(parseThemeDeepLink('infinitecalc://x/40XXB-DYXZ0'), isNull);
    });
  });
}
