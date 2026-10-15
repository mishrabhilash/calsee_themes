import 'package:calsee_themes/engine/contrast.dart';
import 'package:calsee_themes/engine/cvd.dart';
import 'package:calsee_themes/engine/guardrails.dart';
import 'package:calsee_themes/engine/heroes.dart';
import 'package:calsee_themes/engine/theme_spec.dart';
import 'package:test/test.dart';

/// Electric Mango (a known-good hero) as a base to break.
ThemeSpec get good => heroById(5)!;

Set<GuardrailRule> rulesOf(ThemeSpec spec) => {
  for (final v in validateTheme(spec)) v.rule,
};

void main() {
  test('a good theme has no violations and repair returns it unchanged', () {
    expect(validateTheme(good), isEmpty);
    expect(identical(repairTheme(good), good), isTrue);
  });

  group('label contrast', () {
    test('4.5:1 floor, never rounded', () {
      // #767676 on white is 4.54:1; #777777 is 4.48:1.
      final ok = good.copyWith(
        palette: good.palette.copyWith(
          digit: const KeyColors(
            face: 0xFFFFFFFF,
            label: 0xFF767676,
            edge: 0xFF000000,
          ),
        ),
      );
      final bad = good.copyWith(
        palette: good.palette.copyWith(
          digit: const KeyColors(
            face: 0xFFFFFFFF,
            label: 0xFF777777,
            edge: 0xFF000000,
          ),
        ),
      );
      expect(rulesOf(ok), isNot(contains(GuardrailRule.digitLabel)));
      expect(rulesOf(bad), contains(GuardrailRule.digitLabel));
    });

    test('every key group is checked and repaired', () {
      const grey = KeyColors(face: 0xFF808080, label: 0xFF909090, edge: 0);
      final broken = good.copyWith(
        palette: good.palette.copyWith(
          operator: grey,
          equals: grey.copyWith(face: 0xFF20E0B0),
          function: grey.copyWith(face: 0xFF3B3B3B, label: 0xFF505050),
        ),
      );
      expect(
        rulesOf(broken),
        containsAll([
          GuardrailRule.operatorLabel,
          GuardrailRule.equalsLabel,
          GuardrailRule.functionLabel,
        ]),
      );
      final fixed = repairTheme(broken);
      expect(fixed, isNotNull);
      expect(validateTheme(fixed!), isEmpty);
      final p = fixed.palette;
      for (final k in [p.digit, p.operator, p.equals, p.function]) {
        expect(contrastRatio(k.label, k.face), greaterThanOrEqualTo(4.5));
      }
    });

    test('Accessible lock requires 7:1 and repair reaches it', () {
      final locked = good.copyWith(accessible: true);
      // Voltage Pink's operator label is 6.7:1: fine normally, not locked.
      final pink = heroById(6)!;
      expect(validateTheme(pink), isEmpty);
      expect(
        rulesOf(pink.copyWith(accessible: true)),
        contains(GuardrailRule.operatorLabel),
      );
      for (final spec in [locked, pink.copyWith(accessible: true)]) {
        final fixed = repairTheme(spec)!;
        final p = fixed.palette;
        for (final k in [p.digit, p.operator, p.equals, p.function]) {
          expect(contrastRatio(k.label, k.face), greaterThanOrEqualTo(7));
        }
        for (final b in displayBackdrops(fixed)) {
          expect(contrastRatio(p.displayText, b), greaterThanOrEqualTo(7));
        }
      }
    });
  });

  group('display texts', () {
    test('checked against surface, every gradient stop and pattern ink', () {
      final spec = good.copyWith(
        background: const BackgroundSpec(
          kind: BackgroundKind.pattern,
          colors: [0xFF0D0D0D, 0xFF202020],
          pattern: BackgroundPattern.dots,
          patternColor: 0xFFFFFFFF,
          patternOpacityPermille: 100,
        ),
      );
      final backdrops = displayBackdrops(spec);
      // surface + 2 stops + 2 ink composites.
      expect(backdrops, hasLength(5));
      expect(backdrops.first, spec.palette.surface);
      expect(backdrops, containsAll([0xFF0D0D0D, 0xFF202020]));
    });

    test('a dim display text on a light gradient stop fails and repairs', () {
      final spec = good.copyWith(
        palette: good.palette.copyWith(previewText: 0xFF6A6A6A),
        background: const BackgroundSpec(
          kind: BackgroundKind.linearGradient,
          colors: [0xFF0D0D0D, 0xFF2A2A2A],
        ),
      );
      expect(rulesOf(spec), contains(GuardrailRule.previewText));
      final fixed = repairTheme(spec)!;
      for (final b in displayBackdrops(fixed)) {
        expect(
          contrastRatio(fixed.palette.previewText, b),
          greaterThanOrEqualTo(3),
        );
      }
    });

    test('focus ring and caret need 3:1', () {
      final spec = good.copyWith(
        palette: good.palette.copyWith(
          caret: 0xFF303030,
          focusRing: 0xFF262626,
        ),
      );
      expect(
        rulesOf(spec),
        containsAll([GuardrailRule.caret, GuardrailRule.focusRing]),
      );
      expect(validateTheme(repairTheme(spec)!), isEmpty);
    });
  });

  group('operator distinctness', () {
    // Research §6.2: green digits vs red operators of similar lightness are
    // one colour to a deuteranope.
    ThemeSpec redGreen({OperatorCue cue = OperatorCue.none}) => good.copyWith(
      nonColourOperatorCue: cue,
      palette: good.palette.copyWith(
        digit: const KeyColors(
          face: 0xFF4C8C4A,
          label: 0xFF000000,
          edge: 0xFF000000,
        ),
        operator: const KeyColors(
          face: 0xFFB5524A,
          label: 0xFF000000,
          edge: 0xFF000000,
        ),
      ),
    );

    test('similar-lightness red/green operator fails', () {
      expect(contrastRatio(0xFFB5524A, 0xFF4C8C4A), lessThan(1.5));
      final v = validateTheme(redGreen());
      expect(v.map((e) => e.rule), contains(GuardrailRule.operatorVsDigit));
    });

    test('a recorded non-colour cue waives the colour rule', () {
      final v = validateTheme(redGreen(cue: OperatorCue.shape));
      expect(
        v.map((e) => e.rule),
        isNot(contains(GuardrailRule.operatorVsDigit)),
      );
    });

    test('repair moves the operator face away from the digit face', () {
      final fixed = repairTheme(redGreen())!;
      final op = fixed.palette.operator.face;
      final digit = fixed.palette.digit.face;
      expect(contrastRatio(op, digit), greaterThanOrEqualTo(1.5));
      expect(minCvdDeltaE(op, digit), greaterThanOrEqualTo(0.08));
      expect(validateTheme(fixed), isEmpty);
    });

    test('= must differ from operators by ΔEOK ≥ 0.05', () {
      final spec = good.copyWith(
        palette: good.palette.copyWith(
          equals: good.palette.operator.copyWith(face: 0xFFFFB500),
        ),
      );
      expect(rulesOf(spec), contains(GuardrailRule.equalsVsOperator));
      final fixed = repairTheme(spec)!;
      expect(
        minCvdDeltaE(fixed.palette.equals.face, fixed.palette.operator.face),
        greaterThanOrEqualTo(0.05),
      );
    });
  });

  test('solveOnAll reaches the target on every backdrop or returns null', () {
    const backdrops = [0xFF101010, 0xFF303030, 0xFF202028];
    final solved = solveOnAll(0xFF505050, backdrops, 4.5)!;
    for (final b in backdrops) {
      expect(contrastRatio(solved, b), greaterThanOrEqualTo(4.5));
    }
    // Black and white backdrops together: nothing reaches 4.5 on both.
    expect(solveOnAll(0xFF808080, const [0xFF000000, 0xFFFFFFFF], 4.5), isNull);
  });

  test('limits', () {
    expect(GuardrailLimits.forSpec(good), same(GuardrailLimits.standard));
    expect(
      GuardrailLimits.forSpec(good.copyWith(accessible: true)),
      same(GuardrailLimits.accessible),
    );
    expect(GuardrailLimits.accessible.labelPolicy.minRatio, ratioAccessible);
    expect(GuardrailLimits.standard.labelPolicy.minRatio, ratioText);
  });
}
