import 'dart:async';

import 'package:calsee_themes/calsee_themes.dart';
import 'package:calsee_themes_example/gallery/code_view.dart';
import 'package:calsee_themes_example/gallery/examples/backdrop_example.dart';
import 'package:calsee_themes_example/gallery/examples/custom_key_example.dart';
import 'package:calsee_themes_example/gallery/examples/display_example.dart';
import 'package:calsee_themes_example/gallery/examples/feed_example.dart';
import 'package:calsee_themes_example/gallery/examples/icon_keys_example.dart';
import 'package:calsee_themes_example/gallery/examples/keys_example.dart';
import 'package:calsee_themes_example/gallery/examples/share_example.dart';
import 'package:calsee_themes_example/gallery/examples/surface_example.dart';
import 'package:calsee_themes_example/gallery/examples/swipe_example.dart';
import 'package:calsee_themes_example/gallery/examples/theme_data_example.dart';
import 'package:calsee_themes_example/gallery/previews.dart';
import 'package:calsee_themes_example/main.dart';
import 'package:flutter/widgets.dart';

/// One element of the gallery: a live example and its source.
class GalleryEntry {
  const GalleryEntry({
    required this.route,
    required this.title,
    required this.summary,
    required this.source,
    required this.builder,
    required this.preview,
    this.height = 520,
  });

  /// URL path, e.g. `/keys` (the page is at `#/keys`).
  final String route;
  final String title;
  final String summary;

  /// Asset path of the example's source file.
  final String source;
  final WidgetBuilder builder;

  /// A small live preview for the home page's card.
  final WidgetBuilder preview;

  /// Height of the live example.
  final double height;
}

const _examples = 'lib/gallery/examples';

final galleryEntries = <GalleryEntry>[
  GalleryEntry(
    route: '/feed',
    title: 'Theme feed',
    summary:
        'CalseeScope themes everything below it. Its controller moves '
        'through the endless feed, filters families and turns on '
        'accessible themes.',
    source: '$_examples/feed_example.dart',
    builder: (_) => const FeedExample(),
    preview: feedPreview,
    height: 420,
  ),
  GalleryEntry(
    route: '/backdrop',
    title: 'Backdrop and text',
    summary:
        "CalseeBackdrop paints the theme's background and ambient artwork. "
        'CalseeTextColors keeps your text readable on it.',
    source: '$_examples/backdrop_example.dart',
    builder: (_) => const BackdropExample(),
    preview: backdropPreview,
    height: 360,
  ),
  GalleryEntry(
    route: '/keys',
    title: 'Keys',
    summary:
        "CalseeKey.text draws a button with the theme's key face and spring "
        'press. The role picks the face: equals for the primary action.',
    source: '$_examples/keys_example.dart',
    builder: (_) => const KeysExample(),
    preview: keysPreview,
  ),
  GalleryEntry(
    route: '/icon-keys',
    title: 'Icon keys',
    summary:
        "CalseeKey.icon shows an icon in the key's label colour, with an "
        'optional label under it.',
    source: '$_examples/icon_keys_example.dart',
    builder: (_) => const IconKeysExample(),
    preview: iconKeysPreview,
    height: 280,
  ),
  GalleryEntry(
    route: '/custom-keys',
    title: 'Custom key content',
    summary:
        "A CalseeKey builder puts any widget on a themed key, using the face's "
        'label colour and the key size.',
    source: '$_examples/custom_key_example.dart',
    builder: (_) => const CustomKeyExample(),
    preview: customKeysPreview,
    height: 200,
  ),
  GalleryEntry(
    route: '/display',
    title: 'Display and readout',
    summary:
        "CalseeDisplayPanel draws the family's display (an LCD, a clay well, "
        'glass). CalseeReadout shows an amount or score in the display font.',
    source: '$_examples/display_example.dart',
    builder: (_) => const DisplayExample(),
    preview: displayPreview,
    height: 300,
  ),
  GalleryEntry(
    route: '/surfaces',
    title: 'Surfaces',
    summary:
        'CalseeSurface wears a key face at rest, for cards and tiles that '
        "aren't buttons.",
    source: '$_examples/surface_example.dart',
    builder: (_) => const SurfaceExample(),
    preview: surfacesPreview,
    height: 380,
  ),
  GalleryEntry(
    route: '/swipe',
    title: 'Swipe for a theme',
    summary:
        'CalseeSwipeArea changes the theme on a swipe: left for the next, '
        'right for the exact previous one.',
    source: '$_examples/swipe_example.dart',
    builder: (_) => const SwipeExample(),
    preview: swipePreview,
    height: 280,
  ),
  GalleryEntry(
    route: '/theme-data',
    title: 'Your own widgets',
    summary:
        "CalcTheme.of gives the theme's colours, fonts and key styles for "
        'anything you draw yourself.',
    source: '$_examples/theme_data_example.dart',
    builder: (_) => const ThemeDataExample(),
    preview: themeDataPreview,
    height: 380,
  ),
  GalleryEntry(
    route: '/share',
    title: 'Share codes',
    summary:
        'Every theme has a short share code, and themeOfTheDay gives everyone '
        'the same theme on a given day.',
    source: '$_examples/share_example.dart',
    builder: (_) => const ShareExample(),
    preview: sharePreview,
    height: 300,
  ),
  GalleryEntry(
    route: '/payment',
    title: 'A whole screen',
    summary:
        'A payment keypad built from these pieces. The payment logic is '
        'ordinary app code that knows nothing about themes.',
    source: 'lib/main.dart',
    builder: (_) => const PayScreen(),
    preview: (_) => const FittedBox(
      child: SizedBox(width: 390, height: 720, child: PayScreen()),
    ),
    height: 720,
  ),
];

class GalleryApp extends StatefulWidget {
  const GalleryApp({super.key});

  @override
  State<GalleryApp> createState() => _GalleryAppState();
}

class _GalleryAppState extends State<GalleryApp> {
  final _themes = CalseeThemeController(seed: 7);

  @override
  void initState() {
    super.initState();
    for (final entry in galleryEntries) {
      unawaited(loadSource(entry.source));
    }
  }

  @override
  void dispose() {
    _themes.dispose();
    super.dispose();
  }

  Route<void> _route(RouteSettings settings) {
    final entry = galleryEntries
        .where((e) => e.route == settings.name)
        .firstOrNull;
    return PageRouteBuilder<void>(
      settings: RouteSettings(name: entry?.route ?? '/'),
      pageBuilder: (context, _, _) =>
          entry == null ? const _HomePage() : _EntryPage(entry),
      transitionsBuilder: (context, animation, _, child) =>
          FadeTransition(opacity: animation, child: child),
    );
  }

  @override
  Widget build(BuildContext context) => WidgetsApp(
    title: 'calsee_themes gallery',
    color: const Color(0xFF000000),
    debugShowCheckedModeBanner: false,
    textStyle: const TextStyle(fontSize: 14),
    onGenerateRoute: _route,
    // The theme applies only where a page draws a widget inside
    // CalseeBackdrop; the gallery's own pages stay plain.
    builder: (context, navigator) => CalseeScope(
      controller: _themes,
      child: DefaultTextStyle.merge(
        style: TextStyle(color: _Palette.of(context).text),
        child: navigator!,
      ),
    ),
  );
}

/// The gallery's own plain colours, light or dark with the platform.
enum _Palette {
  light(
    background: Color(0xFFF6F6F7),
    surface: Color(0xFFFFFFFF),
    border: Color(0xFFE2E2E6),
    text: Color(0xFF18181B),
    muted: Color(0xFF63636E),
    button: Color(0xFFEDEDF0),
  ),
  dark(
    background: Color(0xFF111114),
    surface: Color(0xFF1A1A1F),
    border: Color(0xFF2C2C33),
    text: Color(0xFFEDEDF0),
    muted: Color(0xFF9B9BA6),
    button: Color(0xFF26262D),
  );

  const _Palette({
    required this.background,
    required this.surface,
    required this.border,
    required this.text,
    required this.muted,
    required this.button,
  });

  static _Palette of(BuildContext context) =>
      MediaQuery.platformBrightnessOf(context) == Brightness.dark
      ? dark
      : light;

  final Color background;
  final Color surface;
  final Color border;
  final Color text;
  final Color muted;
  final Color button;
}

/// A plain, clickable box.
class _Tappable extends StatelessWidget {
  const _Tappable({required this.child, this.onTap, this.label});

  final Widget child;
  final VoidCallback? onTap;
  final String? label;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    enabled: onTap != null,
    label: label,
    excludeSemantics: label != null,
    child: MouseRegion(
      cursor: onTap == null ? MouseCursor.defer : SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: child,
      ),
    ),
  );
}

class _Button extends StatelessWidget {
  const _Button(this.text, {required this.onTap, this.label});

  final String text;
  final VoidCallback? onTap;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final palette = _Palette.of(context);
    return _Tappable(
      onTap: onTap,
      label: label ?? text,
      child: Opacity(
        opacity: onTap == null ? 0.4 : 1,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: palette.button,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: palette.border),
          ),
          child: Text(
            text,
            style: TextStyle(
              color: palette.text,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

const Map<ThemeFamily, String> _familyNames = {
  ThemeFamily.m3Expressive: 'Material 3 Expressive',
  ThemeFamily.liquidGlass: 'Liquid Glass',
  ThemeFamily.neoPop: 'NeoPOP',
  ThemeFamily.neumorphism: 'Neumorphism',
  ThemeFamily.retro: 'Retro',
  ThemeFamily.neoBrutalism: 'Neo-brutalism',
  ThemeFamily.claymorphism: 'Claymorphism',
  ThemeFamily.y2kChrome: 'Y2K Aero',
  ThemeFamily.paperInk: 'Paper & Ink',
  ThemeFamily.cyberpunk: 'Cyberpunk',
  ThemeFamily.vaporwave: 'Vaporwave',
  ThemeFamily.bauhaus: 'Bauhaus',
};

/// Which theme the widgets wear, and buttons to change it.
class _ThemeControls extends StatelessWidget {
  const _ThemeControls();

  @override
  Widget build(BuildContext context) {
    final palette = _Palette.of(context);
    final themes = CalseeScope.of(context);
    final family = themes.spec.family;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Padding(
          padding: const EdgeInsets.only(right: 4),
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: 'Widget theme  ',
                  style: TextStyle(color: palette.muted),
                ),
                TextSpan(
                  text: themes.spec.name,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                TextSpan(
                  text: ' · ${_familyNames[family] ?? family.name}',
                  style: TextStyle(color: palette.muted),
                ),
              ],
            ),
          ),
        ),
        _Button(
          '‹',
          label: 'Previous theme',
          onTap: themes.canGoBack ? themes.previous : null,
        ),
        _Button('Next theme ›', label: 'Next theme', onTap: themes.next),
      ],
    );
  }
}

/// A plain page, at most [maxWidth] wide.
class _Page extends StatelessWidget {
  const _Page({required this.children});

  final List<Widget> children;

  static const maxWidth = 1100.0;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: _Palette.of(context).background,
    child: SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: maxWidth),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            ),
          ),
        ),
      ),
    ),
  );
}

/// [child] drawn in the current widget theme, on its backdrop.
class _Themed extends StatelessWidget {
  const _Themed({required this.child, this.radius = 16});

  final Widget child;
  final double radius;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    position: DecorationPosition.foreground,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: _Palette.of(context).border),
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: CalseeBackdrop(child: child),
    ),
  );
}

class _HomePage extends StatelessWidget {
  const _HomePage();

  @override
  Widget build(BuildContext context) {
    final palette = _Palette.of(context);
    return _Page(
      children: [
        const Text(
          'calsee_themes gallery',
          style: TextStyle(fontSize: 32, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        Text(
          'Every themed element, drawn live in the widget theme below. '
          'Change the theme to see each one in every family, and open an '
          'element to play with it and read its source.',
          style: TextStyle(color: palette.muted, fontSize: 15, height: 1.45),
        ),
        const SizedBox(height: 16),
        const _ThemeControls(),
        const SizedBox(height: 20),
        LayoutBuilder(
          builder: (context, constraints) => GridView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: (constraints.maxWidth / 330).floor().clamp(1, 3),
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              mainAxisExtent: 286,
            ),
            children: [
              for (final entry in galleryEntries) _Card(entry),
            ],
          ),
        ),
      ],
    );
  }
}

class _Card extends StatelessWidget {
  const _Card(this.entry);

  final GalleryEntry entry;

  @override
  Widget build(BuildContext context) {
    final palette = _Palette.of(context);
    return _Tappable(
      label: entry.title,
      onTap: () => Navigator.of(context).pushNamed(entry.route),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: palette.border),
        ),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: 176,
                child: _Themed(
                  radius: 10,
                  // A picture of the element: the card takes the taps.
                  // Previews lay out at one design size, scaled to the card.
                  child: IgnorePointer(
                    child: RepaintBoundary(
                      child: FittedBox(
                        child: SizedBox(
                          width: 340,
                          height: 200,
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Builder(builder: entry.preview),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 12, 8, 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      entry.summary,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: palette.muted,
                        fontSize: 13,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EntryPage extends StatelessWidget {
  const _EntryPage(this.entry);

  final GalleryEntry entry;

  @override
  Widget build(BuildContext context) {
    final palette = _Palette.of(context);
    final demo = SizedBox(
      height: entry.height,
      child: _Themed(child: Builder(builder: entry.builder)),
    );
    return _Page(
      children: [
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: _Tappable(
            label: 'All elements',
            // A deep link (#/keys) always has the home page below it.
            onTap: () => Navigator.of(context).pop(),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Text(
                '← All elements',
                style: TextStyle(
                  color: palette.muted,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          entry.title,
          style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        Text(
          entry.summary,
          style: TextStyle(color: palette.muted, fontSize: 15, height: 1.45),
        ),
        const SizedBox(height: 16),
        const _ThemeControls(),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final code = CodeView(path: entry.source);
            if (constraints.maxWidth < 860) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [demo, const SizedBox(height: 20), code],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(width: 420, child: demo),
                const SizedBox(width: 20),
                Expanded(child: code),
              ],
            );
          },
        ),
      ],
    );
  }
}
