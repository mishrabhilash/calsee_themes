/// How a [ThemeIntent] narrows one generator attempt (engine v4). Internal:
/// the generator and the family builders call it; hosts use
/// `ThemeIntent`.
///
/// Steering never removes a draw from the palette stream, so the rest of
/// a theme keeps its seeded variety: brightness and the harmony scheme are
/// drawn and then overridden, chroma ranges are narrowed before they are
/// sampled, and steered hues come from their own `palette…/intent`
/// sub-stream. A centred attempt (the first theme of a steered feed)
/// puts each narrowed choice at the middle of its range.
///
/// Engine v5 steers the families with their own palettes by
/// `Steering.recolour`: the family builds its usual theme (with the
/// intent's brightness), then every colour turns by the hue that puts the
/// theme's accent (Claymorphism: its body) on the intent's colour, and
/// chroma scales to the intent's level. Lightness never changes, so each
/// family keeps its character; the generator's repair then re-solves
/// labels.
library;

import 'dart:convert';

import 'package:calsee_themes/engine/contrast.dart' show luminanceArgb;
import 'package:calsee_themes/engine/families.dart';
import 'package:calsee_themes/engine/heroes.dart';
import 'package:calsee_themes/engine/oklab.dart';
import 'package:calsee_themes/engine/rng.dart';
import 'package:calsee_themes/engine/theme_intent.dart';
import 'package:calsee_themes/engine/theme_spec.dart';

/// One attempt's steering.
final class Steering {
  Steering(
    this.intent, {
    this.centred = false,
    this.tonal = false,
    this.v4Leans = false,
  });

  final ThemeIntent intent;
  final bool centred;

  /// Read colour leans the engine v4 way (any colour, not just the first).
  final bool v4Leans;

  /// The brightness the intent asks for, explicitly or by a colour's lean.
  ThemeBrightness? get brightness =>
      v4Leans ? intent.v4Brightness : intent.effectiveBrightness;

  /// The chroma the intent asks for, explicitly or by a colour's lean.
  IntentChroma? get chroma =>
      v4Leans ? intent.v4Chroma : intent.effectiveChroma;

  /// Keep the drawn harmony tonal (monochrome or analogous) when the
  /// intent sets none, so one colour reads through the whole theme
  /// (engine v5, M3 Expressive).
  final bool tonal;

  /// The brightness to use instead of the drawn one, when [def] can draw
  /// it; null keeps the draw.
  ThemeBrightness? brightnessFor(FamilyDefinition def) {
    final want = brightness;
    return want != null && brightnessAllowed(def, want) ? want : null;
  }

  /// The harmony scheme to use instead of the drawn one, when [schemes]
  /// offers it; null keeps the draw.
  HarmonyScheme? schemeFor(
    List<Weighted<HarmonyScheme>> schemes, {
    HarmonyScheme? drawn,
  }) {
    final want = intent.harmony;
    if (want == null) {
      if (!tonal || drawn == null) return null;
      return drawn == HarmonyScheme.monochrome
          ? drawn
          : HarmonyScheme.analogous;
    }
    return schemes.any((w) => w.value == want && w.weight > 0) ? want : null;
  }

  /// [def] with every role's chroma range narrowed to the intent's chroma
  /// level (and the base roles quietened for a neutral first colour).
  FamilyDefinition revise(FamilyDefinition def) {
    final level = chroma;
    final neutral = intent.colors.isNotEmpty && intent.colors.first.neutral;
    if (level == null && !neutral && !centred) return def;
    ChromaRange accent(ChromaRange r) => _narrow(r, level);
    ChromaRange base(ChromaRange r) =>
        neutral ? _neutral(r) : _narrow(r, level);
    RoleRange role(RoleRange r, ChromaRange Function(ChromaRange) f) =>
        RoleRange(r.lMilli, f(r.chroma));
    RoleRanges ranges(RoleRanges r) => RoleRanges(
      background: role(r.background, base),
      surfaceOffsetMilli: r.surfaceOffsetMilli,
      surfaceChroma: base(r.surfaceChroma),
      digit: role(r.digit, base),
      digitDuotoneChroma: base(r.digitDuotoneChroma),
      function: role(r.function, base),
      operator: role(r.operator, accent),
      operatorMonochromeL: r.operatorMonochromeL,
      equals: role(r.equals, accent),
      labelStartLMilli: r.labelStartLMilli,
      labelMaxChromaMilli: r.labelMaxChromaMilli,
      accentChroma: accent(r.accentChroma),
      minDigitAboveBackgroundMilli: r.minDigitAboveBackgroundMilli,
      minDigitBelowBackgroundMilli: r.minDigitBelowBackgroundMilli,
      minFunctionBelowDigitMilli: r.minFunctionBelowDigitMilli,
      accentCuspOffsetMilli: r.accentCuspOffsetMilli,
      accentCuspClampMilli: r.accentCuspClampMilli,
    );
    return def.revise(dark: ranges(def.dark), light: ranges(def.light));
  }

  /// The steered base hue (tenths), drawn from [r]; null when the intent
  /// sets no base hue. Always draws once when steering hues, so the accent
  /// draws keep their place.
  int? baseHue(Rng r) {
    final range = _baseRange();
    final v = r.nextU32();
    return range == null ? null : _pick(range, v);
  }

  /// The steered operator (`index` 0) or `=` (`index` 1) hue (tenths),
  /// drawn from [r]; null when the intent names no accent colour, or names
  /// a harmony (which then places the accents).
  int? accentHue(Rng r, int index) {
    final v = r.nextU32();
    if (intent.harmony != null || intent.colors.length < 2) return null;
    final c = index == 0 || intent.colors.length < 3
        ? intent.colors[1]
        : intent.colors[2];
    if (c.neutral) return null;
    return _pick(_HueRange(c.loTenths, c.hiTenths), v);
  }

  /// The steered base hue range as (lo tenths, clockwise span tenths), or
  /// null when the intent sets no base hue.
  ({int lo, int span})? get baseRange {
    final r = _baseRange();
    return r == null ? null : (lo: r.lo, span: r.span);
  }

  /// A hue in the clockwise range (lo, span) from the 32-bit draw [u32]
  /// (its middle when [centred]).
  int pickIn(int lo, int span, int u32) => _pick(_HueRange.span(lo, span), u32);

  /// [def] with its brightness draw fixed to the intent's, when [def] can
  /// draw it (engine v5 families with their own palettes).
  FamilyDefinition withBrightness(FamilyDefinition def) {
    final b = brightnessFor(def);
    if (b == null) return def;
    return def.revise(
      brightnessWeights: b == ThemeBrightness.dark
          ? const [1, 0]
          : const [0, 1],
    );
  }

  /// This steering without its hues (colours and hue range), keeping the
  /// brightness and chroma they imply.
  /// With [tonal], the harmony stays tonal while the intent sets none.
  Steering withoutHues({bool tonal = false}) => Steering(
    ThemeIntent(
      brightness: brightness,
      chroma: chroma,
      harmony: intent.harmony,
      name: intent.name,
    ),
    centred: centred,
    tonal: tonal,
  );

  /// [spec] turned to the intent (engine v5): every colour's hue turns by
  /// the angle that puts the anchor (the most colourful of the operator,
  /// `=` and accent colours; the background when [bodyAnchor]) on the
  /// intent's base hue; a second colour turns the `=` key on its own and a
  /// third the function keys; a
  /// neutral first colour quietens everything; with [scaleChroma], chroma
  /// scales to the intent's level (capped to the gamut). Lightness and
  /// alpha are kept. [keyChromaFloor] keeps colourful key colours at
  /// least that colourful when chroma scales down. A second colour within
  /// [minEqualsApartTenths] of the first leaves `=` its own hue.
  /// [keepLightness] stops key colours moving in lightness; [neon] moves
  /// colourful key colours towards their hue's most saturated lightness.
  /// With
  /// [pullPermille]
  /// below 1000 every hue also moves
  /// towards its colour, keeping that share of its distance. A harmony
  /// the family [honoursHarmony] places the
  /// second and third colours' keys instead. With [accentsOnly] (the generator's fallback before
  /// a hero), only the operator, `=` and accent colours turn. Draws three
  /// times from [r].
  ThemeSpec recolour(
    ThemeSpec spec,
    Rng r, {
    bool bodyAnchor = false,
    bool scaleChroma = true,
    bool accentsOnly = false,
    bool honoursHarmony = true,
    int pullPermille = 1000,
    double? keyChromaFloor,
    int minEqualsApartTenths = 0,
    bool keepLightness = false,
    bool neon = false,
  }) {
    final byColour = intent.harmony == null || !honoursHarmony;
    final baseDraw = r.nextU32();
    final equalsDraw = r.nextU32();
    final functionDraw = r.nextU32();
    final p = spec.palette;
    final range = _baseRange();
    var turn = 0;
    int? target;
    if (range != null) {
      // The operators (four keys) carry the colour when they have one.
      final anchor = bodyAnchor && !accentsOnly
          ? p.background
          : (argbToOklch(p.operator.face | 0xFF000000).c >= 0.05
                ? p.operator.face
                : _mostColourful([p.operator.face, p.equals.face, p.accent]));
      target = _pick(range, baseDraw);
      turn = (target - _hueTenths(anchor)) % 3600;
    }
    var equalsTurn = turn;
    var equalsTarget = target;
    final colors = intent.colors;
    if (byColour && colors.length >= 2 && !colors[1].neutral) {
      equalsTarget = _pick(
        _HueRange(colors[1].loTenths, colors[1].hiTenths),
        equalsDraw,
      );
      equalsTurn = (equalsTarget - _hueTenths(p.equals.face)) % 3600;
      if (target != null &&
          _apart(target, equalsTarget) < minEqualsApartTenths) {
        // Too close to the first colour for this family: `=` keeps its own
        // hue, turned with the palette.
        equalsTurn = turn;
        equalsTarget = target;
      }
    }
    var functionTurn = turn;
    var functionTarget = target;
    if (byColour && colors.length >= 3 && !colors[2].neutral) {
      functionTarget = _pick(
        _HueRange(colors[2].loTenths, colors[2].hiTenths),
        functionDraw,
      );
      functionTurn = (functionTarget - _hueTenths(p.function.face)) % 3600;
    }
    var scale = 1000;
    if (scaleChroma) {
      scale = switch (chroma) {
        null => 1000,
        IntentChroma.muted => 500,
        IntentChroma.balanced => 850,
        IntentChroma.vivid => 1300,
      };
    }
    if (colors.isNotEmpty && colors.first.neutral && intent.hueRange == null) {
      scale = scale * 350 ~/ 1000;
    }
    if (turn == 0 && equalsTurn == 0 && functionTurn == 0 && scale == 1000) {
      return spec;
    }
    // Each key role's turn and the hue it pulls towards.
    (int, int?) of(String role) => switch (role) {
      'equals' => (equalsTurn, equalsTarget),
      'function' => (functionTurn, functionTarget),
      _ => (turn, target),
    };
    // Roles a colour of the intent is meant for: their faces take it even
    // when the family left them neutral.
    final named = <String>{
      if (target != null) 'operator',
      if (equalsTarget != target) 'equals',
      if (functionTarget != target) 'function',
    };
    final ownColour = <String>{
      for (final role in named)
        if (_neutralKey(p, role)) role,
    };

    int compute(
      int argb,
      String role, {
      required bool key,
      bool lift = false,
      bool face = false,
    }) {
      final alpha = argb & 0xFF000000;
      final lch = argbToOklch(argb | 0xFF000000);
      final (t, pullTo) = of(role);
      if (lch.c < 0.004 && !lift) return argb;
      var tenths = lift && pullTo != null
          ? pullTo
          : ((lch.h * 10).round() + t) % 3600;
      if (pullTo != null && pullPermille < 1000 && !lift) {
        // Draw the palette's other hues towards the colour, so a one-colour
        // intent reads as that colour in families with several accents.
        // Digits move less, keeping them apart from the operators.
        final keep = role == 'digit'
            ? pullPermille + (1000 - pullPermille) ~/ 2
            : pullPermille;
        var off = (tenths - pullTo) % 3600;
        if (off > 1800) off -= 3600;
        tenths = (pullTo + off * keep ~/ 1000) % 3600;
      }
      if (face &&
          key &&
          tenths > _goldTenths &&
          tenths <= _yellowHiTenths &&
          !_wantsGreenYellow) {
        // Yellow faces lean gold: a contrast repair that darkens them then
        // lands on gold, not olive.
        tenths = _goldTenths;
      }
      final h = tenths / 10;
      // A neutral key face the intent names a colour for takes real colour.
      final source = lift ? _liftChroma : lch.c;
      var c = source * scale / 1000;
      if (key) {
        // Colourful key colours stay visible when chroma scales down.
        final floor = keyChromaFloor ?? _keyChromaFloor;
        final keep = source < floor ? source : floor;
        if (c < keep) c = keep;
      }
      if (face && named.contains(role)) {
        // A key face a colour is named for shows it clearly (softly under
        // a muted intent).
        final least = chroma == IntentChroma.muted
            ? _keyChromaFloor
            : _namedFaceChroma;
        if (c < least) c = least;
      }
      var l = lch.l;
      if (neon && key && source >= _shiftMinChroma) {
        // Neon keys deepen towards where their hue is most saturated (its
        // cusp), never below 0.68 (slabs stay brighter than the plates and
        // visible on the dark scene).
        final cusp = _cuspL(h);
        final floor = cusp > _neonFloorL ? cusp : _neonFloorL;
        if (floor < l) l = floor;
      } else if (lift && !keepLightness) {
        // A neutral face given a colour sits where that hue is most
        // saturated (a black key turned orange would read brown), up to
        // 0.3 from where the family put it.
        final d = _cuspL(h) - l;
        l += d > 0.3 ? 0.3 : (d < -0.3 ? -0.3 : d);
      } else if (key && !keepLightness && source >= _shiftMinChroma) {
        // A key colour whose new hue can't hold its colour at this
        // lightness (a light neon turned red comes out pink) moves up to
        // 0.24 towards where it can; the repair re-solves its label.
        final want = c * 0.75;
        if (maxChroma(l, h) < want) {
          var best = l;
          var bestC = maxChroma(l, h);
          for (var step = 1; step <= 8 && bestC < want; step++) {
            for (final cand in [lch.l - step * 0.03, lch.l + step * 0.03]) {
              if (cand <= 0.05 || cand >= 0.97) continue;
              final m = maxChroma(cand, h);
              if (m > bestC) {
                best = cand;
                bestC = m;
              }
            }
          }
          l = best;
        }
        // Yellows go olive in the dark: keep them light.
        if (tenths >= _yellowLoTenths &&
            tenths <= _yellowHiTenths &&
            l < _yellowMinL) {
          l = l + 0.32 < _yellowMinL ? l + 0.32 : _yellowMinL;
        }
      }
      if (!key) {
        // Scene and backdrop colours keep their luminance, so every
        // contrast against them (and each family's scene bands) holds.
        l = _sameLuminance(argb | 0xFF000000, l, c, h);
      }
      // oklchToArgb maps out-of-gamut chroma to the gamut edge.
      return alpha | (oklchToArgb(l, c, h) & 0x00FFFFFF);
    }

    // Themes repeat colours (faces, edges, scene stops): convert each once.
    // The ink (the palette's shadow, which several families draw outlines
    // with) always turns as the ink, so outlines stay that ink.
    final ink = p.shadow;
    final memo = <(int, String, bool, bool, bool), int>{};
    int turned(
      int argb,
      String role, {
      required bool key,
      bool lift = false,
      bool face = false,
    }) {
      final isInk = argb == ink && !lift;
      final r = isInk ? '' : role;
      final k = !isInk && key;
      final f = !isInk && face;
      return memo[(argb, r, k, lift, f)] ??= compute(
        argb,
        r,
        key: k,
        lift: lift,
        face: f,
      );
    }

    const accentKeys = {'operator', 'equals', 'accent', 'caret', 'focusRing'};
    // [role]: the palette key role a colour belongs to; `inPalette`: a key
    // or text colour (not the background or scene).
    Object? walk(
      Object? v,
      String key,
      String role, {
      bool inPalette = false,
    }) {
      if (v is Map) {
        return <String, Object?>{
          for (final e in v.entries)
            e.key as String: walk(
              e.value,
              e.key as String,
              key == 'palette' ? e.key as String : role,
              inPalette:
                  inPalette ||
                  (key == 'palette' && !_sceneKeys.contains(e.key)),
            ),
        };
      }
      if (v is List) {
        return [for (final x in v) walk(x, key, role, inPalette: inPalette)];
      }
      if (v is String && key != 'name' && _hex.hasMatch(v)) {
        return argbToHex(
          turned(
            argbFromHex(v),
            role,
            key: inPalette,
            lift: key == 'face' && ownColour.contains(role),
            face: key == 'face',
          ),
        );
      }
      return v;
    }

    final json = jsonDecode(spec.toJsonString()) as Map<String, Object?>;
    if (accentsOnly) {
      final palette = json['palette']! as Map<String, Object?>;
      json['palette'] = {
        for (final e in palette.entries)
          e.key: accentKeys.contains(e.key)
              ? walk(e.value, e.key, e.key, inPalette: true)
              : e.value,
      };
      return ThemeSpec.fromJson(json);
    }
    final out = walk(json, '', '')! as Map<String, Object?>;
    final palette = out['palette']! as Map<String, Object?>;
    if (named.contains('equals') && !keepLightness) _separateEquals(palette);
    _darkenLightLabels(palette);
    return ThemeSpec.fromJson(out);
  }

  /// A `=` given its own colour that sits within 0.1 lightness of the
  /// operators moves 0.1 away, towards its hue's saturated side (yellow
  /// up, blue down), so the two stay apart for every kind of vision.
  static void _separateEquals(Map<String, Object?> palette) {
    final op = palette['operator'];
    final eq = palette['equals'];
    if (op is! Map || eq is! Map) return;
    final o = argbToOklch(argbFromHex(op['face']) | 0xFF000000);
    final eqFace = argbFromHex(eq['face']);
    final e = argbToOklch(eqFace | 0xFF000000);
    if ((e.l - o.l).abs() >= _equalsApartL) return;
    final up = _cuspL(e.h) > o.l;
    var l = up ? o.l + _equalsApartL : o.l - _equalsApartL;
    if (l > 0.95 || l < 0.1) l = up ? o.l - _equalsApartL : o.l + _equalsApartL;
    if (l > 0.95 || l < 0.1) return;
    eq['face'] = argbToHex(
      (eqFace & 0xFF000000) | (oklchToArgb(l, e.c, e.h) & 0x00FFFFFF),
    );
  }

  /// A key whose face recolouring left light under a light label (a yellow
  /// kept clear of olive) takes a dark label of the face's hue, so the
  /// repair keeps the face light instead of darkening it.
  static void _darkenLightLabels(Map<String, Object?> palette) {
    for (final role in const ['digit', 'operator', 'equals', 'function']) {
      final k = palette[role];
      if (k is! Map) continue;
      final face = argbToOklch(argbFromHex(k['face']) | 0xFF000000);
      final label = argbFromHex(k['label']);
      final l = argbToOklch(label | 0xFF000000);
      if (face.l >= _lightFaceL && l.l >= _lightLabelL) {
        k['label'] = argbToHex(
          (label & 0xFF000000) | (oklchToArgb(0.2, 0.03, face.h) & 0x00FFFFFF),
        );
      }
    }
  }

  /// The lightness near [l] at which (c, hDeg) has [original]'s relative
  /// luminance (bisection; [l] when the hue keeps it already).
  static double _sameLuminance(int original, double l, double c, double hDeg) {
    final want = luminanceArgb(original);
    double y(double x) => luminanceArgb(oklchToArgb(x, c, hDeg));
    if ((y(l) - want).abs() < 0.0005) return l;
    // Within 0.3 of where the family put it; 12 halvings reach 0.0002.
    var lo = l - 0.3 < 0 ? 0.0 : l - 0.3;
    var hi = l + 0.3 > 1 ? 1.0 : l + 0.3;
    for (var i = 0; i < 12; i++) {
      final mid = (lo + hi) / 2;
      if (y(mid) < want) {
        lo = mid;
      } else {
        hi = mid;
      }
    }
    return (lo + hi) / 2;
  }

  /// Whether [role]'s key (face and label) carries no colour.
  static bool _neutralKey(Palette p, String role) {
    final k = switch (role) {
      'operator' => p.operator,
      'equals' => p.equals,
      'function' => p.function,
      _ => null,
    };
    if (k == null) return false;
    double c(int argb) => argbToOklch(argb | 0xFF000000).c;
    return c(k.face) < _neutralMaxChroma && c(k.label) < _labelColourChroma;
  }

  static final RegExp _hex = RegExp(r'^[0-9a-f]{8}$');

  /// Palette colours that belong to the scene, not the keys.
  static const Set<String> _sceneKeys = {
    'background',
    'surface',
    'shadow',
    'highlight',
    'seedColor',
  };

  /// How far apart in lightness a separately coloured `=` stays from the
  /// operators.
  static const double _equalsApartL = 0.1;

  /// A face and label this light can't carry each other.
  static const double _lightFaceL = 0.7;
  static const double _lightLabelL = 0.62;

  /// A key face below this chroma is neutral (white, grey, black).
  static const double _neutralMaxChroma = 0.03;

  /// A label at or above this chroma already shows a colour.
  static const double _labelColourChroma = 0.05;

  /// The hue (tenths) yellow key faces lean to.
  static const int _goldTenths = 950;

  /// Whether the intent asks for a green-yellow (olive, lime) itself.
  bool get _wantsGreenYellow => intent.colors.any(
    (c) => c == IntentColor.olive || c == IntentColor.lime,
  );

  /// The least chroma of a key face a colour is named for.
  static const double _namedFaceChroma = 0.09;

  /// The chroma a neutral key face takes for its colour.
  static const double _liftChroma = 0.12;

  /// The least chroma a colourful key colour keeps when chroma scales
  /// down (or its own, if lower).
  static const double _keyChromaFloor = 0.06;

  /// Yellows (tenths of hue) on keys stay at least this light.
  static const int _yellowLoTenths = 800;
  static const int _yellowHiTenths = 1150;
  static const double _yellowMinL = 0.72;

  /// The lowest lightness a neon key colour deepens to.
  static const double _neonFloorL = 0.68;

  /// The least chroma of a key colour that may move in lightness.
  static const double _shiftMinChroma = 0.08;

  /// The lightness (0.40–0.90, 0.02 grid) where [hDeg] is most saturated.
  static double _cuspL(double hDeg) {
    var best = 0.6;
    var bestC = -1.0;
    for (var i = 0; i <= 25; i++) {
      final l = 0.40 + i * 0.02;
      final c = maxChroma(l, hDeg);
      if (c > bestC) {
        bestC = c;
        best = l;
      }
    }
    return best;
  }

  /// Shortest distance between two hues (tenths).
  static int _apart(int a, int b) {
    final d = (a - b).abs() % 3600;
    return d > 1800 ? 3600 - d : d;
  }

  static int _hueTenths(int argb) =>
      (argbToOklch(argb | 0xFF000000).h * 10).round() % 3600;

  static int _mostColourful(List<int> colours) {
    var best = colours.first;
    var bestC = -1.0;
    for (final c in colours) {
      final chroma = argbToOklch(c | 0xFF000000).c;
      if (chroma > bestC) {
        best = c;
        bestC = chroma;
      }
    }
    return best;
  }

  /// The theme's name: the intent's, else [generated].
  String nameOr(String Function() generated) => intent.name ?? generated();

  _HueRange? _baseRange() {
    final hr = intent.hueRange;
    if (hr != null) return _HueRange(hr.$1 * 10, hr.$2 * 10);
    if (intent.colors.isEmpty) return null;
    final c = intent.colors.first;
    return c.neutral ? null : _HueRange(c.loTenths, c.hiTenths);
  }

  int _pick(_HueRange range, int u32) {
    final span = range.span;
    final offset = centred ? span ~/ 2 : u32 % (span + 1);
    return (range.lo + offset) % 3600;
  }

  ChromaRange _narrow(ChromaRange r, IntentChroma? level) {
    var lo = r.lo;
    var hi = r.hi;
    final third = (hi - lo) ~/ 3;
    switch (level) {
      case null:
        break;
      case IntentChroma.muted:
        lo = lo * 45 ~/ 100;
        hi = hi * 55 ~/ 100;
      case IntentChroma.balanced:
        lo += third;
        hi -= third;
      case IntentChroma.vivid:
        lo = hi - third;
    }
    if (hi < lo) hi = lo;
    if (centred) lo = hi = (lo + hi) ~/ 2;
    return _withBounds(r, lo, hi);
  }

  ChromaRange _neutral(ChromaRange r) {
    final hi = r.hi * 20 ~/ 100;
    final lo = r.lo * 15 ~/ 100 > hi ? hi : r.lo * 15 ~/ 100;
    return centred
        ? _withBounds(r, (lo + hi) ~/ 2, (lo + hi) ~/ 2)
        : _withBounds(r, lo, hi);
  }

  static ChromaRange _withBounds(ChromaRange r, int lo, int hi) => r.relative
      ? ChromaRange.rel(lo, hi, r.capMilli)
      : ChromaRange.abs(lo, hi);

  /// The deterministic last resort for a steered ([seed], [family]) when
  /// every attempt fails: the hero closest to the intent (brightness
  /// first, then base hue), preferring the family's own heroes.
  ThemeSpec closestHero(int seed, ThemeFamily family) {
    var pool = heroesFor(family);
    if (pool.isEmpty) pool = heroThemes;
    final want = brightness;
    final range = _baseRange();
    final target = range == null ? null : (range.lo + range.span ~/ 2) % 3600;
    int score(ThemeSpec h) {
      var s = 0;
      if (want != null && h.brightness != want) s += 10000;
      if (target != null) {
        final hue = (argbToOklch(h.palette.seedColor).h * 10).round() % 3600;
        final d = (hue - target).abs();
        s += d > 1800 ? 3600 - d : d;
      }
      return s;
    }

    final start = (seed & 0xFFFFFFFF) % pool.length;
    var best = pool[start];
    var bestScore = score(best);
    for (var i = 1; i < pool.length; i++) {
      final h = pool[(start + i) % pool.length];
      final s = score(h);
      if (s < bestScore) {
        best = h;
        bestScore = s;
      }
    }
    return best;
  }
}

/// A clockwise hue range in tenths of a degree, possibly wrapping past 0.
final class _HueRange {
  const _HueRange(this.lo, int hi) : span = (hi - lo) % 3600;

  const _HueRange.span(this.lo, this.span);

  final int lo;

  /// Tenths from [lo] to the inclusive end, clockwise.
  final int span;
}

/// The palette sub-stream steered hues come from for [paletteTag].
String intentTag(String paletteTag) => RngTag.sub(paletteTag, 'intent');

/// The palette sub-stream [Steering.recolour] draws from (engine v5).
String recolourTag(String paletteTag) => RngTag.sub(paletteTag, 'recolour');
