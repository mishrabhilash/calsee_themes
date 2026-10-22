import 'package:calsee_themes/calc_theme.dart';
import 'package:calsee_themes/engine/theme_feed.dart';
import 'package:calsee_themes/engine/theme_spec.dart';
import 'package:calsee_themes/render/theme_resolver.dart';
import 'package:flutter/widgets.dart';

/// The endless feed of generated themes behind a [CalseeScope]: which theme
/// is showing, and moving to the next or exact previous one.
///
/// Themes are seeded and bit-exact: the same feed state shows the same
/// themes on every device. Save [toJson] (from [CalseeScope.onChanged]) and
/// pass it back as `savedState` to keep the user's place across launches.
class CalseeThemeController extends ChangeNotifier {
  /// A feed limited to [families] (all families when null or empty),
  /// restored from [savedState] when given, otherwise starting at [seed]
  /// (a random one when null).
  ///
  /// [accessible] keeps only themes that also pass the stricter contrast
  /// checks (the Accessible themes setting in Calsee).
  CalseeThemeController({
    Iterable<ThemeFamily>? families,
    Object? savedState,
    int? seed,
    bool accessible = false,
  }) : _feed = savedState == null
           ? ThemeFeed(feedSeed: seed ?? ThemeFeed.randomFeedSeed())
           : ThemeFeed.fromJson(savedState),
       _accessible = accessible {
    if (families != null) this.families = families;
  }

  final ThemeFeed _feed;
  final ThemeCache _cache = ThemeCache();
  bool _accessible;

  /// The theme showing now.
  ThemeSpec get spec => _cache.specFor(_feed.current, accessible: _accessible);

  /// The feed position of [spec] (for favourites or sharing).
  FeedEntry get entry => _feed.current;

  /// Whether [previous] has a theme to return to.
  bool get canGoBack => _feed.canGoBack;

  /// The families new themes come from.
  List<ThemeFamily> get families => _feed.filter.families;

  /// Limits new themes to [value] (all families when empty). The current
  /// theme moves on when its family is no longer allowed.
  set families(Iterable<ThemeFamily> value) {
    _feed.filter = value.isEmpty
        ? const FeedFilter.surpriseMe()
        : FeedFilter.only(value);
    if (!_feed.filter.allows(_feed.current.themeFamily)) _feed.next();
    notifyListeners();
  }

  /// Whether only themes passing the stricter contrast checks are shown.
  bool get accessible => _accessible;
  set accessible(bool value) {
    if (value == _accessible) return;
    _accessible = value;
    notifyListeners();
  }

  /// Shows the next theme (a new one, or forward again after [previous]).
  void next() {
    if (_feed.next() != null) notifyListeners();
  }

  /// Shows the exact previous theme.
  void previous() {
    if (_feed.previous() != null) notifyListeners();
  }

  /// Shows [entry] (a saved favourite, a share code, the theme of the day);
  /// [previous] then returns to where the user was.
  void jumpTo(FeedEntry entry) {
    _feed.jumpTo(entry);
    notifyListeners();
  }

  /// The feed state, JSON-encodable, for `savedState`.
  Object toJson() => _feed.toJson();
}

/// Themes everything below it with the current theme of a
/// [CalseeThemeController], animating between themes.
///
/// Wrap one screen or the whole app; nothing outside it changes. Read the
/// theme with [CalcTheme.of] and the controller with [CalseeScope.of].
class CalseeScope extends StatefulWidget {
  /// Themes [child]. Without a [controller], the scope makes one from
  /// [families], [savedState] and [seed].
  const CalseeScope({
    required this.child,
    this.controller,
    this.families,
    this.savedState,
    this.seed,
    this.onChanged,
    this.duration = const Duration(milliseconds: 420),
    this.curve = Curves.easeInOutCubic,
    super.key,
  });

  /// The themed subtree.
  final Widget child;

  /// The feed to show; owned by the caller.
  final CalseeThemeController? controller;

  /// Families to draw themes from (all when null); ignored with
  /// [controller].
  final Iterable<ThemeFamily>? families;

  /// A [CalseeThemeController.toJson] result to resume from; ignored with
  /// [controller].
  final Object? savedState;

  /// Where a fresh feed starts (random when null); ignored with
  /// [controller].
  final int? seed;

  /// Called with the feed state after every theme change, to persist it.
  final ValueChanged<Object>? onChanged;

  /// Length of the morph between themes.
  final Duration duration;

  /// Curve of the morph between themes.
  final Curve curve;

  /// The controller of the nearest scope.
  static CalseeThemeController of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<_CalseeInherited>();
    assert(scope != null, 'No CalseeScope above this widget.');
    return scope!.notifier!;
  }

  @override
  State<CalseeScope> createState() => _CalseeScopeState();
}

class _CalseeScopeState extends State<CalseeScope> {
  CalseeThemeController? _own;

  CalseeThemeController get _controller =>
      widget.controller ??
      (_own ??= CalseeThemeController(
        families: widget.families,
        savedState: widget.savedState,
        seed: widget.seed,
      ));

  @override
  void initState() {
    super.initState();
    _controller.addListener(_changed);
  }

  @override
  void didUpdateWidget(CalseeScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    final old = oldWidget.controller ?? _own;
    if (old != _controller) {
      old?.removeListener(_changed);
      _controller.addListener(_changed);
    }
  }

  void _changed() => widget.onChanged?.call(_controller.toJson());

  @override
  void dispose() {
    _controller.removeListener(_changed);
    _own?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _CalseeInherited(
    notifier: _controller,
    child: ListenableBuilder(
      listenable: _controller,
      builder: (context, child) => AnimatedCalcTheme(
        data: ThemeResolver.resolve(
          _controller.spec,
          highContrast: MediaQuery.highContrastOf(context),
        ),
        duration: widget.duration,
        curve: widget.curve,
        child: child!,
      ),
      child: widget.child,
    ),
  );
}

class _CalseeInherited extends InheritedNotifier<CalseeThemeController> {
  const _CalseeInherited({required super.notifier, required super.child});
}

/// The data of [spec] without a scope (a preview, a static screenshot).
CalcThemeData resolveTheme(ThemeSpec spec, {bool highContrast = false}) =>
    ThemeResolver.resolve(spec, highContrast: highContrast);
