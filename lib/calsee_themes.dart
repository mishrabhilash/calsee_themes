/// Infinite, seeded themes from the Calsee calculator: an endless feed of
/// generated themes in a dozen visual families (Claymorphism, Liquid
/// Glass, NeoPOP, Retro, Cyberpunk, ...), with key, backdrop and display
/// renderers that draw them.
///
/// Wrap a screen in a `CalseeScope`, build it from `CalseeBackdrop`,
/// `CalseeKey`, `CalseeDisplayPanel` and `CalseeReadout`, and let users
/// swipe a `CalseeSwipeArea` for the next theme. Read colours and fonts
/// anywhere below with `CalcTheme.of`.
library;

export 'calc_theme.dart' show AnimatedCalcTheme, CalcTheme;
export 'calc_theme_data.dart' show CalcThemeData;
export 'engine/families.dart' show ThemeFamily;
export 'engine/share_code.dart';
export 'engine/theme_feed.dart' show FeedEntry, themeOfTheDay;
export 'engine/theme_spec.dart' show ThemeBrightness, ThemeSpec;
export 'key_face.dart' show KeyStyle;
export 'key_role.dart' show KeyRole;
export 'widgets/calsee_key.dart';
export 'widgets/calsee_scope.dart';
export 'widgets/calsee_surfaces.dart';
