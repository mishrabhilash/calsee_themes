/// The theme generator (spec §5.2; research theme-engine.md Recommendations
/// 5–8, 11 and §12; motion brief §2.5).
///
/// `ThemeGenerator.generate(seed, family, engineVersion, accessible:)` is a
/// pure function: every draw comes from a named [Rng] sub-stream of the
/// seed, every colour is computed with the bit-exact maths in `oklab.dart`,
/// and the result passes `validateTheme` on its final ARGB. If a candidate
/// fails and cannot be repaired, the generator retries with palette
/// sub-streams `palette/retry/1…` and finally falls back to a hero.
///
/// Pipeline (one attempt):
///
/// 1. `palette` stream: brightness, harmony scheme, base hue h0 (tenths of
///    a degree) and per-role hue offsets with ±10° jitter.
/// 2. Per-role OKLCH lightness and chroma from the family's role ranges,
///    chroma as a fraction of `maxChroma(L, h)` where the range is
///    relative; dark digit faces stay ≥ background + 0.10; operator and `=`
///    share-hue schemes keep ≥ 0.08 lightness between them; bile hues
///    (88–110°, C > 0.05, L < 0.70) rotate out of the band; the Accessible
///    lock moves mid-tone faces to where 7:1 labels exist.
/// 3. Faces → ARGB; labels solved with `repairPair` (4.5:1, or 7:1 under
///    the Accessible lock; 7:1 on dark faces when reachable).
/// 4. `background` stream: solid / gradient / pattern; then display,
///    preview, error and accent colours solved against every backdrop.
/// 5. `shape`, `style`, `type`, `motion` and `name` streams.
///
/// Engine v4 adds steering: a `ThemeIntent` narrows the palette draws of
/// the steerable families (steering.dart) without removing any draw.
library;

import 'package:calsee_themes/engine/bauhaus.dart';
import 'package:calsee_themes/engine/claymorphism.dart';
import 'package:calsee_themes/engine/contrast.dart';
import 'package:calsee_themes/engine/cvd.dart';
import 'package:calsee_themes/engine/cyberpunk.dart';
import 'package:calsee_themes/engine/families.dart';
import 'package:calsee_themes/engine/guardrails.dart';
import 'package:calsee_themes/engine/heroes.dart';
import 'package:calsee_themes/engine/liquid_glass.dart';
import 'package:calsee_themes/engine/names.dart';
import 'package:calsee_themes/engine/neo_brutalism.dart';
import 'package:calsee_themes/engine/neumorphism.dart';
import 'package:calsee_themes/engine/oklab.dart';
import 'package:calsee_themes/engine/paper_ink.dart';
import 'package:calsee_themes/engine/retro.dart';
import 'package:calsee_themes/engine/rng.dart';
import 'package:calsee_themes/engine/steering.dart';
import 'package:calsee_themes/engine/theme_intent.dart';
import 'package:calsee_themes/engine/theme_spec.dart';
import 'package:calsee_themes/engine/vaporwave.dart';
import 'package:calsee_themes/engine/y2k_aero.dart';

/// The newest generator version. Share codes and persisted themes carry
/// the version they were made with.
///
/// - v1: Milestone 3.
/// - v2: M3 review — light themes keep digit keys ≥ 0.04 below the
///   background and function keys ≥ 0.05 below the digits; the disliked
///   (bile) band widens to 75–115° and is re-checked on final colours;
///   Accessible light accents leave the yellows before going dark; NeoPOP
///   accents sit at their hue's chroma cusp and its function keys are
///   near-neutral. v1 themes still reproduce exactly (golden fixtures).
///   M4 adds Neumorphism to v2 (no bump: other families' v2 output is
///   unchanged; pinned by fixtures/neumorphism_v2.json).
/// - v3: one pocket Retro theme in three plays the 8-bit chiptune pack
///   (sound stream only; no visual change). Pinned by
///   fixtures/retro_v3.json.
/// - v4: steering (`ThemeIntent`; M3 Expressive, NeoPOP and Claymorphism
///   honour it). Unsteered v4 output equals v3 apart from the version
///   number; pinned by fixtures/generator_v4.json and
///   fixtures/steered_v4.json.
/// - v5: every family follows a `ThemeIntent`'s colours, brightness and
///   chroma (families with their own palettes turn their hues to the
///   intent; Claymorphism's body follows the colour fully). Unsteered and
///   steered M3 Expressive / NeoPOP output equals v4 apart from the
///   version number; pinned by fixtures/*_v5.json and
///   fixtures/steered_v5.json.
const int currentEngineVersion = 5;

/// Generator versions this build can reproduce exactly.
const Set<int> supportedEngineVersions = {1, 2, 3, 4, 5};

/// Families whose own draws steering narrows (brightness, chroma and
/// harmony) before their colours turn to the intent.
const Set<ThemeFamily> steeredDrawFamilies = {
  ThemeFamily.m3Expressive,
  ThemeFamily.neoPop,
  ThemeFamily.claymorphism,
};

/// Thrown for an `engineVersion` this build cannot reproduce (newer than
/// [currentEngineVersion]): show "update the app to open this theme".
final class UnsupportedEngineVersion implements Exception {
  const UnsupportedEngineVersion(this.engineVersion);

  final int engineVersion;

  @override
  String toString() => 'UnsupportedEngineVersion($engineVersion)';
}

/// Generates [ThemeSpec]s. Stateless and const; two instances always
/// produce identical output.
final class ThemeGenerator {
  const ThemeGenerator({this.maxAttempts = 4});

  /// Palette attempts (attempt 0 plus `palette/retry/1…`) before the hero
  /// fallback.
  final int maxAttempts;

  /// The theme for ([seed], [family], [engineVersion]) — and the Accessible
  /// lock when [accessible] (labels and display text ≥ 7:1).
  ///
  /// Throws [UnsupportedEngineVersion] for versions this build cannot
  /// reproduce, and [ArgumentError] for [ThemeFamily.plain] and for
  /// families [engineVersion] has not shipped (their placeholder
  /// definitions are not frozen, so their output would not be a pure
  /// function of the version).
  ///
  /// [seedHueTenths] (0–3599, M3 Expressive only) is the Android "Match my
  /// wallpaper" variant (spec §5.3 #1): it replaces the palette stream's
  /// base-hue draw (every other draw is unchanged), the result is marked
  /// [ThemeVariant.wallpaper], and every guardrail runs exactly as for a
  /// generated theme.
  ///
  /// [intent] (engine v4+) steers the theme: steerable families narrow
  /// their palette draws to it, every family takes its name, and the result
  /// is marked [ThemeVariant.steered]. [intentCentred] puts each narrowed
  /// choice at the middle of its range (the first theme of a steered
  /// feed). An empty intent is no intent. When every attempt fails, the
  /// fallback is the hero closest to the intent.
  ThemeSpec generate(
    int seed,
    ThemeFamily family,
    int engineVersion, {
    bool accessible = false,
    int? seedHueTenths,
    ThemeIntent? intent,
    bool intentCentred = false,
  }) {
    if (!supportedEngineVersions.contains(engineVersion)) {
      throw UnsupportedEngineVersion(engineVersion);
    }
    if (family == ThemeFamily.plain) {
      throw ArgumentError.value(family, 'family', 'plain is never generated');
    }
    if (!familyShippedAt(family, engineVersion)) {
      throw ArgumentError.value(
        family,
        'family',
        'not shipped at engine version $engineVersion',
      );
    }
    if (seedHueTenths != null && family != ThemeFamily.m3Expressive) {
      throw ArgumentError.value(
        family,
        'family',
        'only Material 3 Expressive has a wallpaper variant',
      );
    }
    final steering = _steering(
      intent,
      intentCentred,
      engineVersion,
      seedHueTenths,
    );
    final s = seed & 0xFFFFFFFF;
    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      final candidate = buildCandidate(
        s,
        family,
        engineVersion,
        attempt: attempt,
        accessible: accessible,
        seedHueTenths: seedHueTenths,
        intent: steering?.intent,
        intentCentred: intentCentred,
      );
      final fixed = repairTheme(candidate);
      if (fixed != null) return fixed;
    }
    if (steering != null && engineVersion >= 5) {
      // Before a hero: the family's own theme with only its accents
      // turned to the intent (the family's colour rules then hold).
      for (var attempt = 0; attempt < maxAttempts; attempt++) {
        final candidate = _candidate(
          s,
          family,
          engineVersion,
          attempt: attempt,
          accessible: accessible,
          seedHueTenths: seedHueTenths,
          intent: steering.intent,
          intentCentred: intentCentred,
          accentsOnly: true,
        );
        final fixed = repairTheme(candidate);
        if (fixed != null) return fixed;
      }
    }
    if (steering != null) {
      return heroForAccessible(
        steering.closestHero(s, family),
        accessible: accessible,
      );
    }
    return heroFallback(s, family, accessible: accessible);
  }

  /// The steering for [intent], or null for no (or an empty) intent.
  static Steering? _steering(
    ThemeIntent? intent,
    bool centred,
    int engineVersion,
    int? seedHueTenths,
  ) {
    final i = intent?.forEntry;
    if (i == null || i.isEmpty) return null;
    if (engineVersion < firstSteerableEngineVersion) {
      throw ArgumentError.value(
        engineVersion,
        'engineVersion',
        'steering needs engine version $firstSteerableEngineVersion+',
      );
    }
    if (seedHueTenths != null) {
      throw ArgumentError('a theme is either wallpaper or steered');
    }
    return Steering(
      i,
      centred: centred,
      v4Leans: engineVersion == firstSteerableEngineVersion,
    );
  }

  /// One unvalidated attempt (tests and diagnostics; [generate] adds repair,
  /// retries and the hero fallback).
  ThemeSpec buildCandidate(
    int seed,
    ThemeFamily family,
    int engineVersion, {
    int attempt = 0,
    bool accessible = false,
    int? seedHueTenths,
    ThemeIntent? intent,
    bool intentCentred = false,
  }) => _candidate(
    seed,
    family,
    engineVersion,
    attempt: attempt,
    accessible: accessible,
    seedHueTenths: seedHueTenths,
    intent: intent,
    intentCentred: intentCentred,
  );

  /// [buildCandidate], or with [accentsOnly] the v5 fallback that turns
  /// only the accents.
  ThemeSpec _candidate(
    int seed,
    ThemeFamily family,
    int engineVersion, {
    required int attempt,
    required bool accessible,
    required int? seedHueTenths,
    required ThemeIntent? intent,
    required bool intentCentred,
    bool accentsOnly = false,
  }) {
    final shipped =
        familyDefinitionAt(family, engineVersion) ??
        (throw ArgumentError.value(
          family,
          'family',
          'not shipped at engine version $engineVersion',
        ));
    final steering = _steering(
      intent,
      intentCentred,
      engineVersion,
      seedHueTenths,
    );
    if (steering == null) {
      return _build(
        seed,
        family,
        shipped,
        engineVersion,
        attempt: attempt,
        accessible: accessible,
        seedHueTenths: seedHueTenths,
      );
    }
    if (!familySteerableAt(family, engineVersion)) {
      // Not steerable at this version: the family's own theme, with the
      // intent's name.
      final spec = _build(
        seed,
        family,
        shipped,
        engineVersion,
        attempt: attempt,
        accessible: accessible,
      );
      return spec.copyWith(
        variant: ThemeVariant.steered,
        intent: steering.intent.forSpec,
        intentCentred: steering.centred,
        name: steering.nameOr(() => spec.name),
      );
    }
    final paletteTag = attempt == 0
        ? RngTag.palette
        : RngTag.sub(RngTag.palette, 'retry', attempt);
    if (engineVersion >= 5) {
      // Engine v5: the family builds its own theme, then turns to the
      // intent's colours (the first on the accent, the second on `=`).
      // M3 Expressive, NeoPOP and Claymorphism first steer their own draws
      // (brightness, chroma, harmony) without the hues; the others take
      // the intent's brightness and scale chroma afterwards.
      final drawSteered = steeredDrawFamilies.contains(family);
      // A colour without a harmony keeps M3 Expressive tonal (its digits
      // and surfaces then share the colour's hue family).
      final base = steering.withoutHues(
        tonal:
            family == ThemeFamily.m3Expressive &&
            (steering.intent.colors.isNotEmpty ||
                steering.intent.hueRange != null),
      );
      final spec = _build(
        seed,
        family,
        drawSteered ? base.revise(shipped) : steering.withBrightness(shipped),
        engineVersion,
        attempt: attempt,
        accessible: accessible,
        steering: drawSteered ? base : null,
      );
      final turned = steering.recolour(
        spec,
        Rng.stream(seed, recolourTag(paletteTag)),
        bodyAnchor: family == ThemeFamily.claymorphism,
        scaleChroma: !drawSteered,
        accentsOnly: accentsOnly,
        honoursHarmony: drawSteered && family != ThemeFamily.claymorphism,
        // Families with their own palettes read as the colour: their other
        // accents keep 20 % of their distance from it. Bauhaus keeps its
        // two accents a full primary apart.
        pullPermille: switch (family) {
          ThemeFamily.bauhaus ||
          ThemeFamily.m3Expressive ||
          ThemeFamily.neoPop => 1000,
          // Claymorphism's candy keys take its body's colour (a part-way
          // pull lands between hues: orange and teal make olive).
          ThemeFamily.claymorphism => 0,
          _ => 200,
        },
        // Bauhaus accents stay strong under a muted or grey intent.
        keyChromaFloor: family == ThemeFamily.bauhaus ? 0.1 : null,
        // Its operator and `=` stay two different colours.
        // Y2K gels keep their lightness (the gel floor and rims rely on
        // it).
        keepLightness: family == ThemeFamily.y2kChrome,
        // Cyberpunk's neon stays neon in any colour.
        neon: family == ThemeFamily.cyberpunk,
        minEqualsApartTenths: family == ThemeFamily.bauhaus
            ? bauhausSteeredEqualsApartTenths
            : 0,
      );
      return turned.copyWith(
        variant: ThemeVariant.steered,
        intent: steering.intent.forSpec,
        intentCentred: steering.centred,
        name: steering.nameOr(
          () => generateThemeName(
            rng: Rng.stream(seed, RngTag.name),
            accentArgb: turned.palette.operator.face,
            family: family,
            dark: turned.isDark,
          ),
        ),
      );
    }
    return _build(
      seed,
      family,
      steering.revise(shipped),
      engineVersion,
      attempt: attempt,
      accessible: accessible,
      steering: steering,
    );
  }

  /// One attempt from [def] (the shipped definition, or its steered
  /// revision); [steering] reaches only the builders that steer their own
  /// draws (M3 Expressive, NeoPOP, Claymorphism).
  ThemeSpec _build(
    int seed,
    ThemeFamily family,
    FamilyDefinition def,
    int engineVersion, {
    required int attempt,
    required bool accessible,
    int? seedHueTenths,
    Steering? steering,
  }) {
    // The six families of the 2026-10 round each build their own palette,
    // background scene, shape, style, type and motion from the same named
    // streams (their own files).
    if (family == ThemeFamily.claymorphism) {
      return buildClaymorphismCandidate(
        seed,
        def,
        engineVersion,
        attempt: attempt,
        accessible: accessible,
        steering: steering,
      );
    }
    if (family == ThemeFamily.y2kChrome) {
      return buildY2kAeroCandidate(
        seed,
        def,
        engineVersion,
        attempt: attempt,
        accessible: accessible,
      );
    }
    if (family == ThemeFamily.paperInk) {
      return buildPaperInkCandidate(
        seed,
        def,
        engineVersion,
        attempt: attempt,
        accessible: accessible,
      );
    }
    if (family == ThemeFamily.cyberpunk) {
      return buildCyberpunkCandidate(
        seed,
        def,
        engineVersion,
        attempt: attempt,
        accessible: accessible,
      );
    }
    if (family == ThemeFamily.vaporwave) {
      return buildVaporwaveCandidate(
        seed,
        def,
        engineVersion,
        attempt: attempt,
        accessible: accessible,
      );
    }
    if (family == ThemeFamily.bauhaus) {
      return buildBauhausCandidate(
        seed,
        def,
        engineVersion,
        attempt: attempt,
        accessible: accessible,
      );
    }
    if (family == ThemeFamily.neoBrutalism) {
      // Neo-brutalism builds its own palette (ink outlines and hard
      // shadow, saturated flat fills, outlined display card;
      // neo_brutalism.dart) from the same named streams.
      return buildNeoBrutalCandidate(
        seed,
        def,
        engineVersion,
        attempt: attempt,
        accessible: accessible,
      );
    }
    if (family == ThemeFamily.liquidGlass) {
      // Liquid Glass builds its own palette (vivid mesh, translucent glass
      // tints solved on their composites, display backing; liquid_glass.dart)
      // from the same named streams.
      return buildGlassCandidate(
        seed,
        def,
        engineVersion,
        attempt: attempt,
        accessible: accessible,
      );
    }
    if (family == ThemeFamily.retro) {
      // Retro builds its own palette (plastic body, keycaps, LCD / VFD
      // panel and segments; retro.dart) from the same named streams.
      return buildRetroCandidate(
        seed,
        def,
        engineVersion,
        attempt: attempt,
        accessible: accessible,
      );
    }
    final paletteTag = attempt == 0
        ? RngTag.palette
        : RngTag.sub(RngTag.palette, 'retry', attempt);
    if (def.keyStyle.kind == KeyStyleKind.soft) {
      // Neumorphism builds its own palette (surface-coloured keys, soft
      // shadow pair, solved rims); other families never reach this.
      return buildNeumorphicCandidate(
        seed,
        def,
        engineVersion,
        paletteTag: paletteTag,
        accessible: accessible,
      );
    }
    final p = Rng.stream(seed, paletteTag);
    final drawnBrightness = p.pickWeighted(def.brightnessWeights) == 0
        ? ThemeBrightness.dark
        : ThemeBrightness.light;
    final brightness = steering?.brightnessFor(def) ?? drawnBrightness;
    final dark = brightness == ThemeBrightness.dark;
    final ranges = def.ranges(brightness);
    final drawnScheme = pickWeightedValue(p, def.schemes);
    final scheme =
        steering?.schemeFor(def.schemes, drawn: drawnScheme) ?? drawnScheme;
    final ir = steering == null
        ? null
        : Rng.stream(seed, intentTag(paletteTag));
    final steeredH0 = ir == null ? null : steering!.baseHue(ir);
    var hues = _Hues.draw(
      scheme,
      p,
      h0Override: seedHueTenths == null
          ? steeredH0
          : _wrapTenths(seedHueTenths),
    );
    if (ir != null) {
      hues = hues.withAccents(
        steering!.accentHue(ir, 0),
        steering.accentHue(ir, 1),
      );
    }
    final lim = accessible
        ? GuardrailLimits.accessible
        : GuardrailLimits.standard;
    final bile = def.bile;
    final faces = _sampleFaces(
      p,
      ranges,
      scheme,
      hues,
      bile,
      dark: dark,
      accessible: accessible,
    );

    // Labels.
    final policy = lim.labelPolicy;
    final labelChroma = p.nextIntIn(10, ranges.labelMaxChromaMilli) / 1000;
    KeyColors key(Lch face, double edgeShade) {
      final start = face.l < 0.58 ? 0.97 : 0.17;
      var pair = repairPair(face, (
        l: start,
        c: labelChroma,
        h: face.h,
      ), policy: policy);
      if (bile.recheckFinal) {
        // Label repair may have moved the face into the disliked band:
        // check the final colour and re-solve with the hue rotated out.
        final f = argbToOklch(pair.face);
        final hue = (f.h * 10).round() % 3600;
        final rotated = bile.apply(hue, f.l, f.c);
        if (rotated != hue) {
          final moved = (l: f.l, c: f.c, h: rotated / 10);
          pair = repairPair(moved, (
            l: start,
            c: labelChroma,
            h: moved.h,
          ), policy: policy);
        }
      }
      final f = pair.faceLch;
      final edgeL = f.l + edgeShade;
      return KeyColors(
        face: pair.face,
        label: pair.label,
        edge: oklchToArgb(
          edgeL < 0 ? 0 : (edgeL > 1 ? 1 : edgeL),
          f.c * 0.85,
          f.h,
        ),
      );
    }

    final extruded = def.keyStyle.kind == KeyStyleKind.extruded;
    final edgeShade = extruded
        ? -def.keyStyle.edgeShadePermille / 1000
        : (dark ? 0.08 : -0.08);
    final digit = key(faces.digit, edgeShade);
    final function = key(faces.function, edgeShade);
    final operator = key(faces.operator, edgeShade);
    final equals = key(faces.equals, edgeShade);

    final s = faces.surface;
    final surfaceArgb = oklchToArgb(s.l, s.c, s.h);
    final background = _background(
      Rng.stream(seed, RngTag.background),
      def,
      faces.background,
      hues,
      dark: dark,
    );
    final bgArgb = background.base;

    // Display texts against every backdrop.
    final draft = Palette(
      background: bgArgb,
      surface: surfaceArgb,
      displayText: 0,
      previewText: 0,
      error: 0,
      caret: 0,
      focusRing: 0,
      accent: 0,
      digit: digit,
      operator: operator,
      equals: equals,
      function: function,
      shadow: 0,
      highlight: 0,
      seedColor: operator.face,
    );
    final backdrops = [surfaceArgb, ...backgroundSamples(background)];
    int text(double l, double c, double hDeg, double target) =>
        solveOnAll(oklchToArgb(l, c, hDeg), backdrops, target) ??
        blackOrWhite(surfaceArgb);
    final h0 = hues.h0 / 10;
    final displayText = text(dark ? 0.97 : 0.17, 0.012, h0, lim.displayRatio);
    final previewTarget = lim.previewRatio < ratioText
        ? ratioText
        : lim.previewRatio;
    final previewText = text(dark ? 0.80 : 0.42, 0.03, h0, previewTarget);
    final error = text(dark ? 0.72 : 0.50, 0.16, 25, lim.displayRatio);
    final opH = hues.operator / 10;
    final accentL = dark ? 0.80 : 0.50;
    final accentC = _chroma(p, ranges.accentChroma, accentL, opH);
    final accent = text(accentL, accentC, opH, lim.caretRatio);

    final palette = draft.copyWith(
      displayText: displayText,
      previewText: previewText,
      error: error,
      caret: accent,
      focusRing: accent,
      accent: accent,
      shadow: extruded ? 0xB3000000 : (dark ? 0x52000000 : 0x29000000),
      highlight: dark ? 0x14FFFFFF : 0x66FFFFFF,
    );

    // Motion (shared with the extruded style's depth).
    final motion = def.motionRanges.vary(
      def.motion,
      Rng.stream(seed, RngTag.motion),
    );
    final (keyShape, cue) = _shape(Rng.stream(seed, RngTag.shape), def);
    final keyStyle = _style(Rng.stream(seed, RngTag.style), def, motion);
    final type = _type(Rng.stream(seed, RngTag.type), def);
    String generatedName() => generateThemeName(
      rng: Rng.stream(seed, RngTag.name),
      accentArgb: operator.face,
      family: family,
      dark: dark,
    );
    final name = steering?.nameOr(generatedName) ?? generatedName();

    return ThemeSpec(
      seed: seed,
      family: family,
      engineVersion: engineVersion,
      variant: seedHueTenths != null
          ? ThemeVariant.wallpaper
          : (steering != null ? ThemeVariant.steered : ThemeVariant.generated),
      seedHueTenths: seedHueTenths == null ? null : _wrapTenths(seedHueTenths),
      intent: steering?.intent.forSpec,
      intentCentred: steering?.centred ?? false,
      brightness: brightness,
      accessible: accessible,
      palette: palette,
      keyShape: keyShape,
      keyStyle: keyStyle,
      type: type,
      background: background,
      motion: motion,
      sound: def.sound,
      name: name,
      nonColourOperatorCue: cue,
    );
  }
}

// ------------------------------------------------------------------ hues --

int _wrapTenths(int t) => t % 3600;

/// Per-role hues in tenths of a degree (research §5.2).
final class _Hues {
  const _Hues({
    required this.h0,
    required this.digit,
    required this.function,
    required this.operator,
    required this.equals,
  });

  /// Draws h0 and the scheme's offsets, each with ±10° jitter. The h0
  /// draw is always consumed; [h0Override] (the wallpaper hue) replaces
  /// its value.
  factory _Hues.draw(HarmonyScheme scheme, Rng p, {int? h0Override}) {
    final drawn = p.nextHueTenths();
    final h0 = h0Override ?? drawn;
    int j() => p.nextJitterTenths(100);
    int at(int offset) => _wrapTenths(h0 + offset + j());
    switch (scheme) {
      case HarmonyScheme.monochrome:
        return _Hues(h0: h0, digit: h0, function: h0, operator: h0, equals: h0);
      case HarmonyScheme.analogous:
        final op = at(300);
        final eq = at(-300);
        return _Hues(h0: h0, digit: h0, function: h0, operator: op, equals: eq);
      case HarmonyScheme.complementary:
        final op = at(1800);
        final eq = at(1800);
        return _Hues(h0: h0, digit: h0, function: h0, operator: op, equals: eq);
      case HarmonyScheme.splitComplementary:
        final op = at(1500);
        final eq = at(2100);
        return _Hues(h0: h0, digit: h0, function: h0, operator: op, equals: eq);
      case HarmonyScheme.triadic:
        final op = at(1200);
        final eq = at(2400);
        return _Hues(h0: h0, digit: h0, function: eq, operator: op, equals: eq);
      case HarmonyScheme.duotone:
        final b = p.nextChance(1, 2) ? 1200 : 1800;
        final op = at(b);
        final eq = _wrapTenths(op + j());
        return _Hues(h0: h0, digit: h0, function: h0, operator: op, equals: eq);
    }
  }

  final int h0;
  final int digit;
  final int function;
  final int operator;
  final int equals;

  /// These hues with the operator and `=` hues replaced where given (the
  /// steered accent colours).
  _Hues withAccents(int? operator, int? equals) =>
      operator == null && equals == null
      ? this
      : _Hues(
          h0: h0,
          digit: digit,
          function: function,
          operator: operator ?? this.operator,
          equals: equals ?? this.equals,
        );
}

/// Whether operator and `=` share (roughly) one hue under [scheme].
bool _sharedAccentHue(HarmonyScheme scheme) =>
    scheme == HarmonyScheme.monochrome ||
    scheme == HarmonyScheme.complementary ||
    scheme == HarmonyScheme.duotone;

/// The lightness × 1000 (10-step grid) where hue [hDeg] reaches its
/// highest in-gamut chroma: the hue's cusp.
int _cuspLMilli(double hDeg) {
  var best = 500;
  var bestC = -1.0;
  for (var l = 50; l <= 950; l += 10) {
    final c = maxChroma(l / 1000, hDeg);
    if (c > bestC) {
      bestC = c;
      best = l;
    }
  }
  return best;
}

// ----------------------------------------------------------------- faces --

/// Chroma for [r] at (l, hDeg): absolute, or a fraction of maxChroma
/// capped (integer draws only).
double _chroma(Rng p, ChromaRange r, double l, double hDeg) =>
    _chromaAt(r, p.nextIntIn(r.lo, r.hi), l, hDeg);

/// Chroma for the draw [v] (thousandths) of [r] at (l, hDeg).
double _chromaAt(ChromaRange r, int v, double l, double hDeg) {
  if (!r.relative) return v / 1000;
  final c = v / 1000 * maxChroma(l, hDeg);
  final cap = r.capMilli / 1000;
  return c < cap ? c : cap;
}

final class _Faces {
  const _Faces({
    required this.background,
    required this.surface,
    required this.digit,
    required this.function,
    required this.operator,
    required this.equals,
  });

  final Lch background;
  final Lch surface;
  final Lch digit;
  final Lch function;
  final Lch operator;
  final Lch equals;
}

/// Samples the OKLCH face colours (research §5.3).
_Faces _sampleFaces(
  Rng p,
  RoleRanges r,
  HarmonyScheme scheme,
  _Hues hues,
  BileRule bile, {
  required bool dark,
  required bool accessible,
}) {
  int deBile(int hueTenths, double l, double c) => bile.apply(hueTenths, l, c);
  final h0 = hues.h0 / 10;
  final bgL = r.background.lMilli.sample(p);
  final bgC = _chroma(p, r.background.chroma, bgL / 1000, h0);
  final surfL = bgL + r.surfaceOffsetMilli.sample(p);
  final surfC = _chroma(p, r.surfaceChroma, surfL / 1000, h0);

  var digitL = r.digit.lMilli.sample(p);
  if (dark && digitL < bgL + r.minDigitAboveBackgroundMilli) {
    digitL = bgL + r.minDigitAboveBackgroundMilli;
  }
  if (!dark &&
      r.minDigitBelowBackgroundMilli > 0 &&
      digitL > bgL - r.minDigitBelowBackgroundMilli) {
    digitL = bgL - r.minDigitBelowBackgroundMilli;
  }
  final digitRange = scheme == HarmonyScheme.duotone
      ? r.digitDuotoneChroma
      : r.digit.chroma;
  final digitC = _chroma(p, digitRange, digitL / 1000, hues.digit / 10);

  var fnL = r.function.lMilli.sample(p);
  if (!dark &&
      r.minFunctionBelowDigitMilli > 0 &&
      fnL > digitL - r.minFunctionBelowDigitMilli) {
    fnL = digitL - r.minFunctionBelowDigitMilli;
  }
  final fnC = _chroma(p, r.function.chroma, fnL / 1000, hues.function / 10);

  final opRange = scheme == HarmonyScheme.monochrome
      ? r.operatorMonochromeL
      : r.operator.lMilli;
  var opHue = hues.operator;
  var eqHue = hues.equals;
  final cuspOffset = r.accentCuspOffsetMilli;
  final cuspClamp = r.accentCuspClampMilli ?? const IntRange(0, 1000);
  var opL = cuspOffset == null
      ? opRange.sample(p)
      : cuspClamp.clamp(_cuspLMilli(opHue / 10) + cuspOffset.sample(p));
  var eqL = cuspOffset == null
      ? r.equals.lMilli.sample(p)
      : cuspClamp.clamp(_cuspLMilli(eqHue / 10) + cuspOffset.sample(p));
  final band = bile.accessibleLightAccentBand;
  if (accessible && !dark && band != null) {
    // Yellow cannot be dark: move accent hues out of the band before the
    // dark clamp below.
    int out(int h) => !band.contains(h)
        ? h
        : (h < (band.lo + band.hi) ~/ 2 ? band.lo - 50 : band.hi + 150);
    opHue = out(opHue);
    eqHue = out(eqHue);
  }
  if (accessible) {
    // 7:1 labels exist only on faces with Y ≤ 0.1 (white) or Y ≥ 0.3
    // (black): keep faces out of the mid-tones.
    if (dark) {
      if (opL < 710) opL = 710;
      if (eqL < 710) eqL = 710;
      if (fnL > 430) fnL = 430;
    } else {
      if (opL > 460) opL = 460;
      if (eqL > 440) eqL = 440;
    }
  }
  if (_sharedAccentHue(scheme) && (eqL - opL).abs() < 80) {
    final hi = accessible && !dark ? 440 : r.equals.lMilli.hi;
    eqL = opL + 80 <= hi ? opL + 80 : opL - 80;
  }
  final opC = _chroma(p, r.operator.chroma, opL / 1000, opHue / 10);
  final eqDraw = p.nextIntIn(r.equals.chroma.lo, r.equals.chroma.hi);
  var eqC = _chromaAt(r.equals.chroma, eqDraw, eqL / 1000, eqHue / 10);
  // `=` must stand out from the operators (ΔEOK ≥ 0.05 under CVD too):
  // when the draw lands too close, move it 0.08 in lightness.
  int argb(int lMilli, double c, int hueTenths) {
    final l = lMilli / 1000;
    return oklchToArgb(l, c, deBile(hueTenths, l, c) / 10);
  }

  if (minCvdDeltaE(argb(eqL, eqC, eqHue), argb(opL, opC, opHue)) < 0.065) {
    final hi = accessible && !dark ? 440 : r.equals.lMilli.hi;
    final lo = accessible ? (dark ? 710 : 300) : r.equals.lMilli.lo;
    eqL = eqL >= opL
        ? (opL + 80 <= hi ? opL + 80 : opL - 80)
        : (opL - 80 >= lo ? opL - 80 : opL + 80);
    eqC = _chromaAt(r.equals.chroma, eqDraw, eqL / 1000, eqHue / 10);
  }

  Lch lch(int lMilli, double c, int hueTenths) {
    final l = lMilli / 1000;
    return (l: l, c: c, h: deBile(hueTenths, l, c) / 10);
  }

  return _Faces(
    background: lch(bgL, bgC, hues.h0),
    surface: lch(surfL, surfC, hues.h0),
    digit: lch(digitL, digitC, hues.digit),
    function: lch(fnL, fnC, hues.function),
    operator: lch(opL, opC, opHue),
    equals: lch(eqL, eqC, eqHue),
  );
}

// ------------------------------------------------------------ background --

BackgroundSpec _background(
  Rng b,
  FamilyDefinition def,
  Lch bg,
  _Hues hues, {
  required bool dark,
}) {
  final base = oklchToArgb(bg.l, bg.c, bg.h);
  final kind = pickWeightedValue(b, def.backgrounds);
  switch (kind) {
    case BackgroundKind.linearGradient:
      final range = (dark ? def.dark : def.light).background.lMilli;
      final l2 = range.clamp((bg.l * 1000).round() + b.nextIntIn(-40, 40));
      final h2 = _wrapTenths(hues.h0 + (b.nextChance(1, 2) ? 300 : -300));
      final c2 = bg.c + b.nextIntIn(0, 15) / 1000;
      final second = oklchToArgb(l2 / 1000, c2, h2 / 10);
      return BackgroundSpec(
        kind: kind,
        colors: List.unmodifiable([base, second]),
        angleTenths: b.nextInt(8) * 450,
      );
    case BackgroundKind.pattern:
      final patterns = [
        for (final w in def.patterns)
          if (w.value != BackgroundPattern.none) w,
      ];
      if (patterns.isEmpty) {
        return BackgroundSpec(
          kind: BackgroundKind.solid,
          colors: List.unmodifiable([base]),
        );
      }
      final pattern = pickWeightedValue(b, patterns);
      final ink = oklchToArgb(dark ? 0.92 : 0.25, 0.03, hues.operator / 10);
      return BackgroundSpec(
        kind: kind,
        colors: List.unmodifiable([base]),
        pattern: pattern,
        patternColor: ink,
        patternScaleCdp: 1200 + 200 * b.nextInt(7),
        patternOpacityPermille: b.nextIntIn(40, 90),
      );
    case BackgroundKind.solid:
    case BackgroundKind.radialGradient:
    case BackgroundKind.meshGradient:
    case BackgroundKind.noise:
    case BackgroundKind.shader:
    // Family scenes come only from their own families' builders.
    case BackgroundKind.claySoft:
    case BackgroundKind.aeroSky:
    case BackgroundKind.chromeHolo:
    case BackgroundKind.paperSheet:
    case BackgroundKind.cyberGrid:
    case BackgroundKind.vaporSunset:
    case BackgroundKind.bauhausComposition:
      return BackgroundSpec(
        kind: BackgroundKind.solid,
        colors: List.unmodifiable([base]),
      );
  }
}

// ------------------------------------------------- shape / style / type --

(KeyShapeSpec, OperatorCue) _shape(Rng s, FamilyDefinition def) {
  final kind = pickWeightedValue(s, def.shapes);
  final corner = def.cornerPermille.sampleStep(s, 10);
  M3eShape? m3e;
  M3eShape? opM3e;
  var cue = def.nonColourOperatorCue;
  if (kind == KeyShapeKind.m3eMorph && def.m3eShapes.isNotEmpty) {
    m3e = pickWeightedValue(s, def.m3eShapes);
    // One theme in three gives operators their own shape: a non-colour cue.
    if (s.nextChance(1, 3)) {
      final others = [
        for (final w in def.m3eShapes)
          if (w.value != m3e) w,
      ];
      if (others.isNotEmpty) {
        opM3e = pickWeightedValue(s, others);
        cue = OperatorCue.shape;
      }
    }
  }
  final pressed = def.pressedCornerPermille;
  return (
    KeyShapeSpec(
      kind: kind,
      cornerPermille: corner,
      m3eShape: m3e,
      morphTo: pressed == null ? null : KeyShapeKind.roundedRect,
      morphCornerPermille: pressed,
      operatorKind: opM3e == null ? null : KeyShapeKind.m3eMorph,
      operatorM3eShape: opM3e,
    ),
    cue,
  );
}

KeyStyleSpec _style(Rng st, FamilyDefinition def, MotionSpec motion) {
  final kind = pickWeightedValue(st, def.styles);
  final base = def.keyStyle.copyWith(kind: kind);
  return kind == KeyStyleKind.extruded
      ? base.copyWith(extrudeDepthCdp: motion.depthCdp)
      : base;
}

TypeSpec _type(Rng t, FamilyDefinition def) {
  final displayFont = pickWeightedValue(t, def.displayFonts);
  final keyFont = pickWeightedValue(t, def.keyFonts);
  final displayWeight = def.displayWeight.sampleStep(t, 50);
  final keyWeight = def.keyWeight.sampleStep(t, 50);
  final opWeight = keyWeight + def.operatorWeightBonus.sampleStep(t, 50);
  return TypeSpec(
    displayFont: displayFont,
    keyFont: keyFont,
    displayWeight: displayWeight,
    keyWeight: keyWeight,
    operatorWeight: opWeight > 900 ? 900 : opWeight,
  );
}
