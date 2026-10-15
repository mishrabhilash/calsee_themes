import 'package:calsee_themes/engine/contrast.dart';
import 'package:calsee_themes/engine/guardrails.dart';
import 'package:calsee_themes/engine/heroes.dart';
import 'package:calsee_themes/engine/theme_spec.dart';
import 'package:test/test.dart';

void main() {
  test('at least three heroes per enabled family', () {
    for (final f in ThemeFamily.enabledFamilies) {
      expect(heroesFor(f).length, greaterThanOrEqualTo(3), reason: f.name);
    }
  });

  test('ids are unique, positive and look-up-able; names are unique', () {
    final ids = <int>{};
    final names = <String>{};
    for (final h in heroThemes) {
      expect(h.variant, ThemeVariant.hero);
      expect(h.heroId, isNotNull);
      expect(h.heroId, greaterThan(0));
      expect(ids.add(h.heroId!), isTrue, reason: 'duplicate id ${h.heroId}');
      expect(names.add(h.name), isTrue, reason: 'duplicate ${h.name}');
      expect(heroById(h.heroId!), same(h));
      expect(h.family.enabled, isTrue);
      expect(h.accessible, isFalse);
      expect(h.name.split(' '), hasLength(greaterThanOrEqualTo(2)));
    }
    expect(heroById(9999), isNull);
  });

  for (final h in heroThemes) {
    group('hero ${h.heroId} "${h.name}"', () {
      test('passes every guardrail', () {
        expect(validateTheme(h), isEmpty);
      });

      test('repairs to the Accessible lock (7:1)', () {
        final a = heroForAccessible(h);
        expect(a.accessible, isTrue);
        expect(a.heroId, h.heroId);
        expect(validateTheme(a), isEmpty);
        final p = a.palette;
        for (final k in [p.digit, p.operator, p.equals, p.function]) {
          expect(contrastRatio(k.label, k.face), greaterThanOrEqualTo(7));
        }
        expect(heroForAccessible(h, accessible: false), same(h));
      });

      test('follows its family', () {
        final def = h.family.definition;
        if (h.family == ThemeFamily.retro) {
          // Desk calculators may click instead of beep (motion brief §2.3).
          expect(h.sound, anyOf(def.sound, SoundPackId.mechClicky));
          expect(h.type.lcd, isTrue);
          expect(h.palette.lcdGhost, isNotNull);
          expect(h.keyStyle.extrudeDepthCdp, h.motion.depthCdp);
          expect(h.motion.depthCdp, inInclusiveRange(200, 300));
        } else {
          expect(h.sound, def.sound);
        }
        expect(h.keyStyle.kind, def.keyStyle.kind);
        expect(h.motion.verb, def.motion.verb);
        expect(h.motion.pressIn, def.motion.pressIn, reason: 'never varied');
        if (h.family == ThemeFamily.neoPop) {
          expect(h.isDark, isTrue);
          expect(h.keyStyle.extrudeDepthCdp, h.motion.depthCdp);
          expect(h.motion.depthCdp, inInclusiveRange(300, 500));
        }
        if (h.family == ThemeFamily.m3Expressive) {
          expect(h.keyShape.kind, KeyShapeKind.m3eMorph);
          expect(h.keyShape.morphCornerPermille, 300);
        }
        if (h.nonColourOperatorCue == OperatorCue.shape) {
          expect(h.keyShape.operatorM3eShape, isNotNull);
          expect(h.keyShape.operatorM3eShape, isNot(h.keyShape.m3eShape));
        }
      });

      test('round-trips through JSON', () {
        expect(ThemeSpec.fromJsonString(h.toJsonString()), h);
      });
    });
  }

  test('fallback is deterministic and stays in the family', () {
    for (final f in ThemeFamily.enabledFamilies) {
      for (var seed = 0; seed < 20; seed++) {
        final a = heroFallback(seed, f);
        expect(a.family, f);
        expect(heroFallback(seed, f), same(a));
        expect(heroFallback(seed, f, accessible: true).accessible, isTrue);
      }
    }
    // A family without heroes falls back to any hero.
    expect(heroFallback(3, ThemeFamily.pixel).variant, ThemeVariant.hero);
  });
}
