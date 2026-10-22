import 'package:calsee_themes/calc_theme_data.dart';
import 'package:flutter/widgets.dart';

/// The one M2 theme: quiet neutrals with a blue accent, light and dark,
/// following the system brightness.
///
/// Guardrails (spec §5.4, checked by `test/themes/plain_theme_test.dart`):
/// - every key label ≥ 4.5:1 on its key fill;
/// - display text ≥ 3:1 (actually ≥ 4.5:1) on the background, as are the
///   preview and error text;
/// - operators and `=` differ from digits by more than colour: a heavier
///   label weight, and `=` has a strongly contrasting fill.
abstract final class PlainTheme {
  /// Accent used for `=`, the caret and Material chrome.
  static const Color _accentLight = Color(0xFF2F5BD3);
  static const Color _accentDark = Color(0xFF8AB4FF);

  /// Light variant.
  static final CalcThemeData light = CalcThemeData(
    brightness: Brightness.light,
    background: const Color(0xFFFAFBFC),
    displayText: const Color(0xFF111418),
    previewText: const Color(0xFF5A616B),
    errorText: const Color(0xFFB3261E),
    caret: _accentLight,
    focusRing: _accentLight,
    digitKey: const KeyStyle(fill: Color(0xFFE6E9EE), label: Color(0xFF111418)),
    functionKey: const KeyStyle(
      fill: Color(0xFFD3D8E0),
      label: Color(0xFF111418),
      labelWeight: FontWeight.w500,
    ),
    operatorKey: const KeyStyle(
      fill: Color(0xFFD3DFFF),
      label: Color(0xFF1A3FA6),
      labelWeight: FontWeight.w600,
    ),
    equalsKey: const KeyStyle(
      fill: _accentLight,
      label: Color(0xFFFFFFFF),
      labelWeight: FontWeight.w600,
    ),
  );

  /// Dark variant.
  static final CalcThemeData dark = CalcThemeData(
    brightness: Brightness.dark,
    background: const Color(0xFF0E1013),
    displayText: const Color(0xFFF2F4F7),
    previewText: const Color(0xFFA3AAB5),
    errorText: const Color(0xFFFFB4AB),
    caret: _accentDark,
    focusRing: _accentDark,
    digitKey: const KeyStyle(fill: Color(0xFF2A2E35), label: Color(0xFFF2F4F7)),
    functionKey: const KeyStyle(
      fill: Color(0xFF3D424B),
      label: Color(0xFFF2F4F7),
      labelWeight: FontWeight.w500,
    ),
    operatorKey: const KeyStyle(
      fill: Color(0xFF213258),
      label: Color(0xFFB5CCFF),
      labelWeight: FontWeight.w600,
    ),
    equalsKey: const KeyStyle(
      fill: _accentDark,
      label: Color(0xFF0B1B3A),
      labelWeight: FontWeight.w600,
    ),
  );

  /// High-contrast light variant (platform High Contrast / Increase
  /// Contrast, spec §4.4): key fills ≥ 3:1 against the background (the
  /// keys' extent is visible), labels ≥ 4.5:1 on their fills, `=` ≥ 3:1
  /// against the digit keys, preview and error text ≥ 7:1, a black,
  /// heavier focus ring.
  static final CalcThemeData highContrastLight = CalcThemeData(
    brightness: Brightness.light,
    background: const Color(0xFFFFFFFF),
    displayText: const Color(0xFF000000),
    previewText: const Color(0xFF2B2F36),
    errorText: const Color(0xFF8C1D18),
    caret: const Color(0xFF0B2A8C),
    focusRing: const Color(0xFF000000),
    focusRingWidth: 3,
    digitKey: const KeyStyle(fill: Color(0xFF6B6B6B), label: Color(0xFFFFFFFF)),
    functionKey: const KeyStyle(
      fill: Color(0xFF3D3D3D),
      label: Color(0xFFFFFFFF),
      labelWeight: FontWeight.w500,
    ),
    operatorKey: const KeyStyle(
      fill: Color(0xFF1A3A9E),
      label: Color(0xFFFFFFFF),
      labelWeight: FontWeight.w600,
    ),
    equalsKey: const KeyStyle(
      fill: Color(0xFF000000),
      label: Color(0xFFFFFFFF),
      labelWeight: FontWeight.w600,
    ),
  );

  /// High-contrast dark variant (see [highContrastLight]): light key faces
  /// on black, a yellow, heavier focus ring.
  static final CalcThemeData highContrastDark = CalcThemeData(
    brightness: Brightness.dark,
    background: const Color(0xFF000000),
    displayText: const Color(0xFFFFFFFF),
    previewText: const Color(0xFFD5D9E0),
    errorText: const Color(0xFFFFB4AB),
    caret: const Color(0xFFFFE14D),
    focusRing: const Color(0xFFFFE14D),
    focusRingWidth: 3,
    digitKey: const KeyStyle(fill: Color(0xFF8A8F99), label: Color(0xFF000000)),
    functionKey: const KeyStyle(
      fill: Color(0xFFD5D9E0),
      label: Color(0xFF000000),
      labelWeight: FontWeight.w500,
    ),
    operatorKey: const KeyStyle(
      fill: Color(0xFF9CC0FF),
      label: Color(0xFF000000),
      labelWeight: FontWeight.w600,
    ),
    equalsKey: const KeyStyle(
      fill: Color(0xFFFFFFFF),
      label: Color(0xFF000000),
      labelWeight: FontWeight.w600,
    ),
  );

  /// [light] or [dark] ([highContrastLight] / [highContrastDark] when
  /// [highContrast]); null means light.
  static CalcThemeData of(Brightness? brightness, {bool highContrast = false}) {
    final dark = brightness == Brightness.dark;
    if (highContrast) return dark ? highContrastDark : highContrastLight;
    return dark ? PlainTheme.dark : light;
  }
}
