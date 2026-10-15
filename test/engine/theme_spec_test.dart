import 'dart:convert';

import 'package:calsee_themes/engine/families.dart';
import 'package:calsee_themes/engine/rng.dart';
import 'package:calsee_themes/engine/theme_spec.dart';
import 'package:test/test.dart';

ThemeSpec sampleSpec({int seed = 0xDEADBEEF, String name = 'Mango Midnight'}) {
  const key = KeyColors(face: 0xFF333333, label: 0xFFF5F5F5, edge: 0xFF111111);
  return ThemeSpec(
    seed: seed,
    family: ThemeFamily.neoPop,
    engineVersion: 1,
    brightness: ThemeBrightness.dark,
    palette: const Palette(
      background: 0xFF101010,
      surface: 0xFF181818,
      displayText: 0xFFFFFFFF,
      previewText: 0xFFB0B0B0,
      error: 0xFFFF8A80,
      caret: 0xFFFF9F0A,
      focusRing: 0xFFFFD180,
      accent: 0xFFFF9F0A,
      digit: key,
      operator: KeyColors(
        face: 0xFFFF9F0A,
        label: 0xFF000000,
        edge: 0xFFB36B00,
      ),
      equals: KeyColors(face: 0xFF00E5FF, label: 0xFF000000, edge: 0xFF0090A0),
      function: KeyColors(
        face: 0xFF5A5A5A,
        label: 0xFFFFFFFF,
        edge: 0xFF2A2A2A,
      ),
      shadow: 0x99000000,
      highlight: 0x33FFFFFF,
      seedColor: 0xFFFF9F0A,
    ),
    keyShape: const KeyShapeSpec(
      kind: KeyShapeKind.roundedRect,
      cornerPermille: 40,
      operatorKind: KeyShapeKind.circle,
    ),
    keyStyle: const KeyStyleSpec(
      kind: KeyStyleKind.extruded,
      extrudeDepthCdp: 400,
      edgeShadePermille: 180,
    ),
    type: const TypeSpec(
      displayFont: FontIds.spaceGrotesk,
      keyFont: FontIds.spaceGrotesk,
      displayWeight: 600,
      keyWeight: 650,
      operatorWeight: 700,
      slashedZero: true,
    ),
    background: const BackgroundSpec(
      kind: BackgroundKind.pattern,
      colors: [0xFF101010, 0xFF202020],
      angleTenths: 1350,
      pattern: BackgroundPattern.dots,
      patternColor: 0x1FFFFFFF,
      patternScaleCdp: 1200,
      patternOpacityPermille: 120,
    ),
    motion: neoPopDefinition.motion.copyWith(depthCdp: 400),
    sound: SoundPackId.pop,
    name: name,
    nonColourOperatorCue: OperatorCue.shape,
  );
}

void main() {
  group('ThemeSpec', () {
    test('JSON round trip is exact', () {
      final spec = sampleSpec();
      final text = spec.toJsonString();
      final back = ThemeSpec.fromJsonString(text);
      expect(back, spec);
      expect(back.toJsonString(), text);
      expect(back.hashCode, spec.hashCode);
      // Through a generic decode (ints may arrive as doubles from JS JSON).
      final generic = jsonDecode(text) as Map<String, Object?>;
      expect(ThemeSpec.fromJson(generic), spec);
    });

    test('round trip of every family motion base and nullable fields', () {
      for (final f in ThemeFamily.values) {
        final d = f.definition;
        final spec = sampleSpec().copyWith(
          family: f,
          motion: d.motion,
          keyShape: const KeyShapeSpec(
            kind: KeyShapeKind.m3eMorph,
            cornerPermille: 500,
            m3eShape: M3eShape.cookie6Sided,
            morphTo: KeyShapeKind.roundedRect,
            morphCornerPermille: 300,
          ),
          variant: ThemeVariant.hero,
          heroId: 3,
          accessible: true,
        );
        expect(ThemeSpec.fromJsonString(spec.toJsonString()), spec);
      }
    });

    test('every sound pack id round-trips (M5 appended mechTactile, wood)', () {
      for (final id in SoundPackId.values) {
        final spec = sampleSpec().copyWith(sound: id);
        expect(ThemeSpec.fromJsonString(spec.toJsonString()).sound, id);
      }
      // Appended, never reordered: the M4 ids keep their positions.
      expect(SoundPackId.typewriter.index, 8);
      expect(SoundPackId.mechTactile.index, 9);
      expect(SoundPackId.wood.index, 10);
    });

    test('stableHash is pinned (platform- and run-independent)', () {
      final spec = sampleSpec();
      expect(spec.stableHash, spec.hashCode);
      expect(stableHash32(''), 0x811C9DC5);
      expect(stableHash32('a'), 0xE40C292C); // FNV-1a test vector
      expect(spec.stableHash.toRadixString(16), kSampleHash);
    });

    test('== and hash change with any field', () {
      final a = sampleSpec();
      expect(a == sampleSpec(), isTrue);
      final variants = [
        sampleSpec(seed: 1),
        sampleSpec(name: 'Other'),
        a.copyWith(engineVersion: 2),
        a.copyWith(accessible: true),
        a.copyWith(brightness: ThemeBrightness.light),
        a.copyWith(palette: a.palette.copyWith(caret: 0xFF000001)),
        a.copyWith(
          palette: a.palette.copyWith(
            digit: a.palette.digit.copyWith(label: 0xFFEEEEEE),
          ),
        ),
        a.copyWith(keyShape: a.keyShape.copyWith(cornerPermille: 41)),
        a.copyWith(keyStyle: a.keyStyle.copyWith(extrudeDepthCdp: 500)),
        a.copyWith(type: a.type.copyWith(lcd: true)),
        a.copyWith(background: a.background.copyWith(colors: [0xFF101010])),
        a.copyWith(motion: a.motion.copyWith(depthCdp: 500)),
        a.copyWith(effects: const EffectsSpec(kind: EffectKind.grain)),
        a.copyWith(sound: SoundPackId.tick),
        a.copyWith(nonColourOperatorCue: OperatorCue.none),
        a.copyWith(family: ThemeFamily.m3Expressive),
      ];
      for (final v in variants) {
        expect(v == a, isFalse);
        expect(v.toJsonString() == a.toJsonString(), isFalse);
        expect(v.hashCode == a.hashCode, isFalse);
      }
    });

    test('fromJson rejects bad input with FormatException', () {
      final good = sampleSpec().toJson();
      Map<String, Object?> mutate(String k, Object? v) =>
          jsonDecode(jsonEncode(good)) as Map<String, Object?>..[k] = v;
      expect(
        () => ThemeSpec.fromJson(mutate('format', 99)),
        throwsFormatException,
      );
      expect(
        () => ThemeSpec.fromJson(mutate('family', 29)),
        throwsFormatException,
      );
      expect(
        () => ThemeSpec.fromJson(mutate('sound', 'nope')),
        throwsFormatException,
      );
      expect(
        () => ThemeSpec.fromJson(mutate('seed', 'x')),
        throwsFormatException,
      );
      expect(
        () => ThemeSpec.fromJson(mutate('palette', 3)),
        throwsFormatException,
      );
      expect(() => ThemeSpec.fromJson('nope'), throwsFormatException);
      expect(() => argbFromHex('12345'), throwsFormatException);
      expect(argbFromHex('#FF00ff00'), 0xFF00FF00);
    });

    test('spring tokens', () {
      expect(SpringTokens.hardPress.toJson(), [10000, 1000]);
      expect(
        SpringToken.fromJson(const [800, 600]),
        SpringTokens.expressiveFast,
      );
      expect(SpringTokens.expressiveFast.dampingRatio, 0.6);
      expect(
        SpringTokens.scale(MotionScheme.standard).$2,
        SpringTokens.standardNormal,
      );
      expect(() => SpringToken.fromJson(const [1]), throwsFormatException);
    });
  });

  group('families', () {
    test('ids are stable, unique and fit 5 bits below 30', () {
      expect(
        {for (final f in ThemeFamily.values) f.name: f.id},
        {
          'plain': 0,
          'm3Expressive': 1,
          'liquidGlass': 2,
          'neoPop': 3,
          'neumorphism': 4,
          'retro': 5,
          'neoBrutalism': 6,
          'claymorphism': 7,
          'pixel': 8,
          'aurora': 9,
          'y2kChrome': 10,
          'paperInk': 11,
          'terminal': 12,
          'cyberpunk': 13,
          'vaporwave': 14,
          'bauhaus': 15,
        },
      );
      for (final f in ThemeFamily.values) {
        expect(ThemeFamily.fromId(f.id), f);
      }
      expect(ThemeFamily.fromId(31), isNull);
      expect(ThemeFamily.enabledFamilies, [
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
      ]);
    });

    test('every family has a well-formed definition', () {
      for (final f in ThemeFamily.values) {
        final d = f.definition;
        expect(d.family, f);
        expect(d.brightnessWeights, hasLength(2));
        void positive<T>(List<Weighted<T>> w) {
          expect(w, isNotEmpty);
          expect(w.every((x) => x.weight >= 0), isTrue);
          expect(w.fold<int>(0, (s, x) => s + x.weight), greaterThan(0));
        }

        positive(d.schemes);
        positive(d.shapes);
        positive(d.styles);
        positive(d.displayFonts);
        positive(d.keyFonts);
        positive(d.backgrounds);
        positive(d.patterns);
        positive(d.effects);
        if (d.shapes.any((s) => s.value == KeyShapeKind.m3eMorph)) {
          positive(d.m3eShapes);
        }
        for (final r in [d.dark, d.light]) {
          for (final role in [
            r.background,
            r.digit,
            r.function,
            r.operator,
            r.equals,
          ]) {
            expect(role.lMilli.lo <= role.lMilli.hi, isTrue);
            expect(role.lMilli.lo >= 0 && role.lMilli.hi <= 1000, isTrue);
            expect(role.chroma.lo <= role.chroma.hi, isTrue);
          }
        }
        expect(d.cornerPermille.lo >= 0 && d.cornerPermille.hi <= 500, isTrue);
      }
    });

    test('enabled families follow the motion brief §2.3', () {
      const m3 = m3ExpressiveDefinition;
      expect(m3.motion.pressIn, SpringTokens.effectsFast);
      expect(m3.motion.release, const SpringToken(800, 600));
      expect(m3.motion.releaseAlt, SpringTokens.effectsDefault);
      expect(m3.motion.scalePermille, 970);
      expect(m3.motion.cornerPermille, 300);
      expect(m3.pressedCornerPermille, 300);
      expect(m3.cornerPermille.let, (500, 500));
      expect(m3.motion.entryScalePermille, 850);
      expect(m3.motion.stateLayerSnap, isTrue);
      expect(m3.sound, SoundPackId.softTap);
      const np = neoPopDefinition;
      expect(np.motion.pressIn, SpringTokens.hardPress);
      expect(np.motion.release, SpringTokens.effectsDefault);
      expect(np.motion.entryOffsetCdp, -600);
      expect(np.motion.releaseHaptic, isTrue);
      expect(np.motion.impact, ImpactStyle.rigid);
      expect(np.brightnessWeights, [1, 0]); // dark base
      expect(np.sound, SoundPackId.pop);
    });

    test('seeded motion variation stays in bounds', () {
      for (final f in ThemeFamily.values) {
        final d = f.definition;
        for (var seed = 0; seed < 300; seed++) {
          final m = d.motionRanges.vary(
            d.motion,
            Rng.stream(seed, RngTag.motion),
          );
          expect(m.pressIn, d.motion.pressIn); // never varied
          final z = m.release.zetaPermille;
          final k = m.release.stiffness;
          expect(
            z,
            inInclusiveRange(MotionRanges.minZetaFor10PercentOvershoot, 1000),
          );
          expect(z * z * k * 360 * 360 >= 16000000000000, isTrue);
          final depth = d.motionRanges.depthCdp;
          if (depth != null) {
            expect(depth.contains(m.depthCdp), isTrue);
            expect(m.depthCdp % 100, 0);
          }
        }
      }
      final depths = {
        for (var s = 0; s < 200; s++)
          neoPopDefinition.motionRanges
              .vary(neoPopDefinition.motion, Rng.stream(s, RngTag.motion))
              .depthCdp,
      };
      expect(depths, {300, 400, 500});
    });

    test('weighted picks follow integer weights', () {
      final r = Rng.stream(5, 'pick');
      final counts = <HarmonyScheme, int>{};
      for (var i = 0; i < 11000; i++) {
        final s = pickWeightedValue(r, neoPopDefinition.schemes);
        counts[s] = (counts[s] ?? 0) + 1;
      }
      expect(counts[HarmonyScheme.monochrome], isNull);
      expect(counts[HarmonyScheme.complementary], closeTo(4000, 300));
    });
  });
}

extension on IntRange {
  (int, int) get let => (lo, hi);
}

const String kSampleHash = '9ae64cb9';
