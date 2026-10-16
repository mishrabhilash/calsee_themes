import 'dart:ui' show lerpDouble;

import 'package:calsee_themes/chrome_style.dart';
import 'package:calsee_themes/display_face.dart';
import 'package:calsee_themes/key_face.dart';
import 'package:calsee_themes/key_role.dart';
import 'package:calsee_themes/render/fonts.dart';
import 'package:material_ui/material_ui.dart';

export 'package:calsee_themes/chrome_style.dart' show ChromeStyle;
export 'package:calsee_themes/display_face.dart';
export 'package:calsee_themes/key_face.dart';
export 'package:calsee_themes/key_role.dart';

/// Everything the calculator widgets read for their look: resolved colours,
/// key shape, type and the press-motion subset. M3 produces it from a
/// `ThemeSpec`; M2 has `PlainTheme`.
///
/// Immutable and lerpable ([CalcThemeData.lerp]) for theme transitions.
/// Read it with `CalcTheme.of`.
@immutable
final class CalcThemeData {
  new({
    required this.brightness,
    required this.background,
    required this.displayText,
    required this.previewText,
    required this.errorText,
    required this.caret,
    required this.focusRing,
    required this.digitKey,
    required this.operatorKey,
    required this.equalsKey,
    required this.functionKey,
    this.keyCornerFraction = 0.3,
    this.displayFontFamily,
    this.displayWeight,
    this.keyFontFamily,
    SpringDescription? pressIn,
    SpringDescription? release,
    this.releaseAlt,
    this.pressScale = 0.95,
    this.pressedOverlayOpacity = 0.12,
    this.hoverOverlayOpacity = 0.08,
    this.keyFace = const PlainKeyFace(),
    this.focusRingWidth = 2,
    this.backdrop,
    DisplayEntry? displayEntry,
    this.releaseHaptic = false,
    this.displayFace,
    this.accessiblePreviewText,
    this.chrome,
  }) : displayEntry = displayEntry ?? DisplayEntry.none,
       pressIn = pressIn ?? effectsFast,
       release = release ?? effectsDefault;

  /// Interpolates every channel ([t] = 0 gives [a], 1 gives [b]). Discrete
  /// values (brightness, fonts, springs) switch at t = 0.5.
  factory lerp(CalcThemeData a, CalcThemeData b, double t) {
    if (identical(a, b)) return a;
    T pick<T>(T x, T y) => t < 0.5 ? x : y;
    Color color(Color x, Color y) => Color.lerp(x, y, t)!;
    double number(double x, double y) => lerpDouble(x, y, t)!;
    return CalcThemeData(
      brightness: pick(a.brightness, b.brightness),
      background: color(a.background, b.background),
      displayText: color(a.displayText, b.displayText),
      previewText: color(a.previewText, b.previewText),
      errorText: color(a.errorText, b.errorText),
      caret: color(a.caret, b.caret),
      focusRing: color(a.focusRing, b.focusRing),
      digitKey: KeyStyle.lerp(a.digitKey, b.digitKey, t),
      operatorKey: KeyStyle.lerp(a.operatorKey, b.operatorKey, t),
      equalsKey: KeyStyle.lerp(a.equalsKey, b.equalsKey, t),
      functionKey: KeyStyle.lerp(a.functionKey, b.functionKey, t),
      keyCornerFraction: number(a.keyCornerFraction, b.keyCornerFraction),
      displayFontFamily: pick(a.displayFontFamily, b.displayFontFamily),
      displayWeight: pick(a.displayWeight, b.displayWeight),
      keyFontFamily: pick(a.keyFontFamily, b.keyFontFamily),
      pressIn: pick(a.pressIn, b.pressIn),
      release: pick(a.release, b.release),
      releaseAlt: pick(a.releaseAlt, b.releaseAlt),
      pressScale: number(a.pressScale, b.pressScale),
      pressedOverlayOpacity: number(
        a.pressedOverlayOpacity,
        b.pressedOverlayOpacity,
      ),
      hoverOverlayOpacity: number(a.hoverOverlayOpacity, b.hoverOverlayOpacity),
      keyFace: pick(a.keyFace, b.keyFace),
      focusRingWidth: number(a.focusRingWidth, b.focusRingWidth),
      backdrop: pick(a.backdrop, b.backdrop),
      displayEntry: pick(a.displayEntry, b.displayEntry),
      releaseHaptic: pick(a.releaseHaptic, b.releaseHaptic),
      displayFace: switch ((a.displayFace, b.displayFace)) {
        (final x?, final y?) => x.lerpTo(y, t),
        (final x, final y) => pick(x, y),
      },
      accessiblePreviewText:
          a.accessiblePreviewText == null && b.accessiblePreviewText == null
          ? null
          : color(a.secondaryText, b.secondaryText),
      chrome: pick(a.chrome, b.chrome),
    );
  }

  /// Motion brief `effectsFast` (3800/1.0): soft press-in.
  static final SpringDescription effectsFast =
      SpringDescription.withDampingRatio(mass: 1, stiffness: 3800);

  /// Motion brief `effectsDefault` (1600/1.0): release.
  static final SpringDescription effectsDefault =
      SpringDescription.withDampingRatio(mass: 1, stiffness: 1600);

  /// Release starts no earlier than this after touch-down, so a quick tap
  /// still shows a press (motion brief §2.2). Input commits at pointer-up
  /// regardless.
  static const Duration minPress = Duration(milliseconds: 40);

  /// Light or dark (drives system UI overlay style).
  final Brightness brightness;

  /// Calculator surface behind the display and keypad.
  final Color background;

  /// Expression and result text (≥ 3:1 on [background]; plain theme ≥ 4.5).
  final Color displayText;

  /// Live preview, indicators (M, DEG) and secondary text.
  final Color previewText;

  /// Under the Accessible theme lock (7:1 promise for display text), the
  /// colour of the live preview and the amount in words: [previewText]
  /// moved in OKLCH lightness until it is ≥ 7:1 on every display backdrop
  /// (the generator only holds [previewText] to 4.5:1 there). Null when
  /// the lock is off or the theme needs no change. Read [secondaryText].
  final Color? accessiblePreviewText;

  /// The live preview and amount-line colour: [accessiblePreviewText]
  /// under the Accessible lock, else [previewText].
  Color get secondaryText => accessiblePreviewText ?? previewText;

  /// The family's Material chrome recipe (settings, history, dialogs,
  /// sheets); null = stock Material 3 (the plain theme, the Accessible
  /// lock). Applied by [materialThemeFor].
  final ChromeStyle? chrome;

  /// Error message in the preview slot (≥ 4.5:1 on [background]).
  final Color errorText;

  /// Expression caret.
  final Color caret;

  /// Keyboard focus ring around keys.
  final Color focusRing;

  /// Digits, `.`, `±`.
  final KeyStyle digitKey;

  /// `+ − × ÷` and other binary operators.
  final KeyStyle operatorKey;

  /// `=`.
  final KeyStyle equalsKey;

  /// Everything else: ⌫/AC, `( )`, `%`, functions, memory, modes.
  final KeyStyle functionKey;

  /// Key corner radius as a fraction of the key's shorter side (0 = square,
  /// 0.5 = fully round). M3 adds real shapes.
  final double keyCornerFraction;

  /// Display font; null = platform default (with tabular figures).
  final String? displayFontFamily;

  /// The theme's display weight (CSS, `TypeSpec.displayWeight`), which a
  /// display without a [displayFace] sets on the font's `wght` axis; null
  /// = the display's own weights (the platform theme).
  final int? displayWeight;

  /// Key label font; null = platform default.
  final String? keyFontFamily;

  /// Press-in spring (touch-down → pressed).
  final SpringDescription pressIn;

  /// Release spring (pressed → rest): scale, squish and depth.
  final SpringDescription release;

  /// Release spring of the key's *shape* channel (corner morph), when it
  /// differs from [release]: M3 Expressive releases its corners on
  /// `effectsDefault` (no bounce, as Compose does) while the scale rides
  /// 800/0.6 (motion brief §2.3, §2.6 `Motion.releaseAlt`). Null: corners
  /// follow [release]. The state layer (an effects channel) never
  /// overshoots and always releases on an effects spring.
  final SpringDescription? releaseAlt;

  /// Key scale when fully pressed.
  final double pressScale;

  /// Opacity of the key's state layer on a pressed key (the renderers'
  /// layer is contrast-safe: it moves the face away from its label).
  final double pressedOverlayOpacity;

  /// Opacity of the key's state layer on a hovered key.
  final double hoverOverlayOpacity;

  /// Stroke width of [focusRing] (high-contrast themes draw it heavier).
  final double focusRingWidth;

  /// Draws the key faces (M3 swaps in ThemeSpec-driven renderers).
  final KeyFaceRenderer keyFace;

  /// Paints the calculator background (gradients, patterns); null means a
  /// plain [background] fill.
  final CalcBackdrop? backdrop;

  /// How a new display glyph enters (motion brief §2.3 "Display entry").
  final DisplayEntry displayEntry;

  /// Whether a key-up also fires `HapticIntent.keyRelease` (NeoPOP,
  /// Retro; motion brief §2.3).
  final bool releaseHaptic;

  /// How the display draws its glyphs and panel (Retro: a 7-segment LCD);
  /// null = the display font on the background, no panel.
  final DisplayFace? displayFace;

  /// The colour display text sits on: the [displayFace] panel, or the
  /// [background].
  Color get displayBackdrop => displayFace?.panelColor ?? background;

  /// Icons and secondary text drawn straight on the [background] (the
  /// toolbar): [previewText], or — when a [displayFace] puts the display
  /// text on its own panel, so [previewText] is solved against the panel
  /// only — the [focusRing] colour, which is ≥ 3:1 on every background
  /// sample.
  Color get chromeForeground => displayFace == null ? previewText : focusRing;

  /// The emphasised counterpart of [chromeForeground] (the lock badge's
  /// flash): [displayText], or black / white on the background.
  Color get chromeEmphasis => displayFace == null
      ? displayText
      : (background.computeLuminance() > 0.179
            ? const Color(0xFF000000)
            : const Color(0xFFFFFFFF));

  /// The face spec for a key with [role].
  KeyFaceSpec keyFaceSpec(
    KeyRole role, {
    bool reduceMotion = false,
    int artSeed = 0,
  }) => KeyFaceSpec(
    role: role,
    style: keyStyle(role),
    cornerFraction: keyCornerFraction,
    pressedOverlayOpacity: pressedOverlayOpacity,
    hoverOverlayOpacity: hoverOverlayOpacity,
    reduceMotion: reduceMotion,
    artSeed: artSeed,
  );

  /// The style for keys with [role].
  KeyStyle keyStyle(KeyRole role) => switch (role) {
    KeyRole.digit || KeyRole.decimal || KeyRole.sign => digitKey,
    KeyRole.operator => operatorKey,
    KeyRole.equals => equalsKey,
    KeyRole.function ||
    KeyRole.constant ||
    KeyRole.paren ||
    KeyRole.clear ||
    KeyRole.backspace ||
    KeyRole.percent ||
    KeyRole.memory ||
    KeyRole.mode => functionKey,
  };

  /// Whether [other] differs from this theme only in what painters read
  /// live during a transition (colours, opacities, corner fraction, press
  /// scale, focus-ring width, backdrop, the key face's *shape*): widgets
  /// built from `CalcTheme.layoutOf` need no rebuild.
  bool sameLayout(CalcThemeData other) =>
      identical(this, other) ||
      (other.brightness == brightness &&
          other.displayFontFamily == displayFontFamily &&
          other.displayWeight == displayWeight &&
          other.keyFontFamily == keyFontFamily &&
          other.digitKey.labelWeight == digitKey.labelWeight &&
          other.operatorKey.labelWeight == operatorKey.labelWeight &&
          other.equalsKey.labelWeight == equalsKey.labelWeight &&
          other.functionKey.labelWeight == functionKey.labelWeight &&
          (other.digitKey.outline == null) == (digitKey.outline == null) &&
          _sameSpring(other.pressIn, pressIn) &&
          _sameSpring(other.release, release) &&
          _sameOptionalSpring(other.releaseAlt, releaseAlt) &&
          other.keyFace.layoutFace == keyFace.layoutFace &&
          other.displayEntry == displayEntry &&
          other.releaseHaptic == releaseHaptic &&
          other.displayFace.runtimeType == displayFace.runtimeType);

  static bool _sameSpring(SpringDescription a, SpringDescription b) =>
      a.mass == b.mass && a.stiffness == b.stiffness && a.damping == b.damping;

  static bool _sameOptionalSpring(SpringDescription? a, SpringDescription? b) =>
      a == null || b == null ? a == b : _sameSpring(a, b);

  @override
  bool operator ==(Object other) =>
      other is CalcThemeData &&
      other.brightness == brightness &&
      other.background == background &&
      other.displayText == displayText &&
      other.previewText == previewText &&
      other.errorText == errorText &&
      other.caret == caret &&
      other.focusRing == focusRing &&
      other.digitKey == digitKey &&
      other.operatorKey == operatorKey &&
      other.equalsKey == equalsKey &&
      other.functionKey == functionKey &&
      other.keyCornerFraction == keyCornerFraction &&
      other.displayFontFamily == displayFontFamily &&
      other.displayWeight == displayWeight &&
      other.keyFontFamily == keyFontFamily &&
      _sameSpring(other.pressIn, pressIn) &&
      _sameSpring(other.release, release) &&
      _sameOptionalSpring(other.releaseAlt, releaseAlt) &&
      other.pressScale == pressScale &&
      other.pressedOverlayOpacity == pressedOverlayOpacity &&
      other.hoverOverlayOpacity == hoverOverlayOpacity &&
      other.keyFace == keyFace &&
      other.focusRingWidth == focusRingWidth &&
      other.backdrop == backdrop &&
      other.displayEntry == displayEntry &&
      other.releaseHaptic == releaseHaptic &&
      other.displayFace == displayFace &&
      other.accessiblePreviewText == accessiblePreviewText &&
      other.chrome == chrome;

  @override
  int get hashCode => Object.hashAll([
    brightness,
    background,
    displayText,
    previewText,
    errorText,
    caret,
    focusRing,
    digitKey,
    operatorKey,
    equalsKey,
    functionKey,
    keyCornerFraction,
    displayFontFamily,
    displayWeight,
    keyFontFamily,
    pressIn.mass,
    pressIn.stiffness,
    pressIn.damping,
    release.mass,
    release.stiffness,
    release.damping,
    releaseAlt?.stiffness,
    releaseAlt?.damping,
    pressScale,
    pressedOverlayOpacity,
    hoverOverlayOpacity,
    keyFace,
    focusRingWidth,
    backdrop,
    displayEntry,
    releaseHaptic,
    displayFace,
    accessiblePreviewText,
    chrome,
  ]);
}

/// Paints a theme's calculator background (M3 `BackgroundSpec`s); the
/// implementations live in `lib/themes/render/background_painter.dart`.
@immutable
abstract class CalcBackdrop {
  const new();

  /// A painter filling the whole calculator surface. Inside
  /// [textSafeArea] (the display text) it keeps the display legible: a
  /// solid surface behind the text, no pattern. Scene art in the toolbar
  /// row keeps clear of [toolbarExclusion] (the mode button). With
  /// [reduceMotion] any drift is frozen.
  CustomPainter painter({
    Rect? textSafeArea,
    Rect? toolbarExclusion,
    bool reduceMotion = false,
  });
}

/// How a newly typed display glyph enters (motion brief §2.3, §4.2).
enum DisplayEntryKind {
  /// No movement (M2 plain; every family under Reduce Motion fades).
  none,

  /// Scale from [DisplayEntry.startScale] to 1 (M3 Expressive pop).
  pop,

  /// Translate from [DisplayEntry.startOffset] dp above to 0 (NeoPOP).
  drop,

  /// Translate from [DisplayEntry.startOffset] dp below to 0, with a fade.
  rise,

  /// No movement: the glyph's segments switch on, a linear fade over
  /// [DisplayEntry.duration] (Retro LCD: 30 ms).
  segments,

  /// Ink bleeding into paper (motion brief §2.3 Paper & ink): a linear
  /// fade over [DisplayEntry.duration] while the glyph settles from
  /// [DisplayEntry.startScale] to 1 about its baseline.
  bleed,

  /// A terminal glyph (motion brief §2.3 Terminal): fully lit at once,
  /// blooming from [DisplayEntry.startScale] (115 %) to 1 over
  /// [DisplayEntry.duration] (60 ms).
  glyph,
}

/// A family's display glyph entry: start scale / offset and its spring.
@immutable
final class DisplayEntry {
  const new({
    this.kind = DisplayEntryKind.none,
    this.startScale = 1,
    this.startOffset = 0,
    this.spring,
    this.duration,
  });

  /// No entry movement.
  static const DisplayEntry none = DisplayEntry();

  /// Entry kind.
  final DisplayEntryKind kind;

  /// Scale at t = 0 (pop: 0.85).
  final double startScale;

  /// Vertical offset at t = 0 in dp (drop: −6, i.e. above).
  final double startOffset;

  /// Spring that drives t from 0 to 1 (null: the theme's release spring).
  final SpringDescription? spring;

  /// Linear duration instead of [spring] ([DisplayEntryKind.segments],
  /// [DisplayEntryKind.bleed], [DisplayEntryKind.glyph]).
  final Duration? duration;

  /// Scale at progress [t] (may overshoot 1 on a bouncy spring).
  double scaleAt(double t) => startScale + (1 - startScale) * t;

  /// Vertical offset in dp at progress [t].
  double offsetAt(double t) => startOffset * (1 - t);

  @override
  bool operator ==(Object other) =>
      other is DisplayEntry &&
      other.kind == kind &&
      other.startScale == startScale &&
      other.startOffset == startOffset &&
      other.duration == duration &&
      other.spring?.mass == spring?.mass &&
      other.spring?.stiffness == spring?.stiffness &&
      other.spring?.damping == spring?.damping;

  @override
  int get hashCode => Object.hash(
    kind,
    startScale,
    startOffset,
    duration,
    spring?.mass,
    spring?.stiffness,
    spring?.damping,
  );
}

/// Material chrome (app bars, sheets, dialogs, settings) that follows any
/// [CalcThemeData]: the accent is the `=` key's fill, surfaces use the
/// calculator background, and a family's [CalcThemeData.chrome] adds its
/// type, shapes, edges and surfaces ([applyChrome]).
ThemeData materialThemeFor(CalcThemeData calc) {
  final scheme = ColorScheme.fromSeed(
    seedColor: calc.equalsKey.fill,
    brightness: calc.brightness,
  ).copyWith(surface: calc.background, error: calc.errorText);
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: calc.background,
    // Hindi amount words in settings and history: the bundled Devanagari.
    fontFamilyFallback: scriptFallbackFonts,
  );
  final chrome = calc.chrome;
  return chrome == null ? base : applyChrome(base, calc, chrome);
}
