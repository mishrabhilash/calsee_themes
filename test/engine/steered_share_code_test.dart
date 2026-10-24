import 'package:calsee_themes/engine/families.dart';
import 'package:calsee_themes/engine/share_code.dart';
import 'package:calsee_themes/engine/theme_intent.dart';
import 'package:calsee_themes/engine/theme_spec.dart';
import 'package:test/test.dart';

List<ThemeIntent> get intents => [
  ThemeIntent(colors: const [IntentColor.green]),
  ThemeIntent(
    brightness: ThemeBrightness.dark,
    colors: const [IntentColor.navy, IntentColor.gold, IntentColor.maroon],
    chroma: IntentChroma.vivid,
    harmony: HarmonyScheme.duotone,
  ),
  ThemeIntent(hueRange: (350, 20), chroma: IntentChroma.muted),
  ThemeIntent(harmony: HarmonyScheme.monochrome),
  ThemeIntent(brightness: ThemeBrightness.light),
];

/// The 10-symbol-only check every build before 2.0.0 runs.
String? legacyNormalize(String input) {
  final s = input.toUpperCase().replaceAll(RegExp(r'[\s-]'), '');
  return s.length == 10 ? s : null;
}

void main() {
  test('round-trips every field', () {
    for (final intent in intents) {
      for (final centred in [false, true]) {
        final code = encodeSteeredShareCode(
          ThemeFamily.neoPop.id,
          4,
          0xC0FFEE11,
          intent,
          centred: centred,
        );
        expect(code, matches(RegExp(r'^([0-9A-Z]{5}-){4}[0-9A-Z]{5}$')));
        final p = decodeShareCode(code)!;
        expect(p.familyId, ThemeFamily.neoPop.id);
        expect(p.engineVersion, 4);
        expect(p.seed, 0xC0FFEE11);
        expect(p.intent, intent);
        expect(p.centred, centred);
        expect(encodePayload(p), code);
        expect(shareCodeStatus(code), ShareCodeStatus.valid);
      }
    }
  });

  test('families and name are not in the code', () {
    final code = encodeSteeredShareCode(
      1,
      4,
      9,
      ThemeIntent(
        families: const [ThemeFamily.retro],
        colors: const [IntentColor.red],
        name: 'Ember',
      ),
    );
    expect(
      decodeShareCode(code)!.intent,
      ThemeIntent(colors: const [IntentColor.red]),
    );
  });

  test('every single-symbol change and neighbour swap is caught', () {
    const alphabet = crockfordAlphabet;
    final code = encodeSteeredShareCode(
      ThemeFamily.claymorphism.id,
      4,
      0x12345678,
      intents[1],
    ).replaceAll('-', '');
    for (var i = 0; i < code.length; i++) {
      for (final ch in alphabet.split('')) {
        if (ch == code[i]) continue;
        final mutated = code.replaceRange(i, i + 1, ch);
        expect(decodeShareCode(mutated), isNull, reason: mutated);
        expect(shareCodeStatus(mutated), ShareCodeStatus.invalid);
      }
    }
    for (var i = 0; i + 1 < code.length; i++) {
      if (code[i] == code[i + 1]) continue;
      final swapped =
          code.substring(0, i) + code[i + 1] + code[i] + code.substring(i + 2);
      expect(decodeShareCode(swapped), isNull, reason: swapped);
    }
  });

  test('a newer format reads as needs-update, not invalid', () {
    // Re-encode with format 2 and a valid CRC.
    final code = encodeSteeredShareCode(1, 4, 1, intents[0]).replaceAll(
      '-',
      '',
    );
    final bits = <int>[];
    for (final ch in code.split('')) {
      final v = crockfordAlphabet.indexOf(ch);
      for (var b = 4; b >= 0; b--) {
        bits.add((v >> b) & 1);
      }
    }
    bits
      ..[2] = 1
      ..[3] = 0; // format 0001 → 0010
    final crc = crc16(bits.sublist(0, 109));
    for (var b = 0; b < 16; b++) {
      bits[109 + b] = (crc >> (15 - b)) & 1;
    }
    final sb = StringBuffer();
    for (var i = 0; i < 125; i += 5) {
      var v = 0;
      for (var b = 0; b < 5; b++) {
        v = v * 2 + bits[i + b];
      }
      sb.write(crockfordAlphabet[v]);
    }
    final newer = sb.toString();
    expect(decodeShareCode(newer), isNull);
    expect(shareCodeStatus(newer), ShareCodeStatus.needsUpdate);
  });

  test('older builds reject steered codes outright', () {
    final code = encodeSteeredShareCode(1, 4, 1, intents[0]);
    expect(legacyNormalize(code), isNull);
  });

  test('plain codes are unchanged', () {
    expect(encodeShareCode(1, 1, 0xDEADBEEF), hasLength(11));
    expect(shareCodeStatus(encodeShareCode(1, 1, 7)), ShareCodeStatus.valid);
    expect(shareCodeStatus('hello'), ShareCodeStatus.invalid);
    expect(decodeShareCode(encodeShareCode(1, 1, 7))!.intent, isNull);
  });

  test('links carry an optional name', () {
    final code = encodeSteeredShareCode(1, 4, 5, intents[0]);
    final link = formatThemeDeepLink(code, name: 'Moss & Fern');
    expect(link, startsWith('calsee://t/$code?name='));
    expect(parseThemeDeepLink(link)!.name, 'Moss & Fern');
    final web = formatThemeWebLink(code, name: 'Moss');
    expect(web, 'https://calsee.tech/t/$code?name=Moss');
    expect(parseThemeDeepLink(web)!.intent, intents[0]);
    expect(parseThemeDeepLink(formatThemeDeepLink(code))!.name, isNull);
    // Short codes format as before.
    final short = encodeShareCode(1, 1, 7);
    expect(formatThemeDeepLink(short), 'calsee://t/$short');
  });
}
