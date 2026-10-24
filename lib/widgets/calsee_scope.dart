import 'dart:async';

import 'package:calsee_themes/calc_theme.dart';
import 'package:calsee_themes/engine/theme_feed.dart';
import 'package:calsee_themes/engine/theme_intent.dart';
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
  ///
  /// [intent] steers new themes (see [intent]); a fresh feed then starts
  /// on the intent's centred theme. A restored feed already steered by an
  /// equal intent stays where it was.
  CalseeThemeController({
    Iterable<ThemeFamily>? families,
    Object? savedState,
    int? seed,
    bool accessible = false,
    ThemeIntent? intent,
  }) : _feed = savedState == null
           ? ThemeFeed(
               feedSeed: seed ?? ThemeFeed.randomFeedSeed(),
               intent: intent,
             )
           : ThemeFeed.fromJson(savedState),
       _accessible = accessible {
    if (families != null) this.families = families;
    if (savedState != null && intent != null && intent != _feed.intent) {
      _feed.steer(intent);
    }
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

  /// The intent new themes are steered by; null for the ordinary feed.
  ThemeIntent? get intent => _feed.intent;

  /// Steers new themes by [value] and shows the first of them, centred on
  /// it (back returns to the theme before). Null or an empty intent goes
  /// back to the ordinary feed without changing the current theme.
  ///
  /// Only some families honour steering (`steerableFamilies`); with no
  /// families in the intent, the feed draws from those.
  set intent(ThemeIntent? value) {
    final empty = value == null || value.isEmpty;
    if (empty ? _feed.intent == null : value == _feed.intent) return;
    _feed.steer(value);
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

  /// The specs [next] would show, generated now (cached for the commit).
  List<ThemeSpec> _upcoming(int count) => [
    for (final entry in _feed.upcoming(count))
      _cache.specFor(entry, accessible: _accessible),
  ];
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
    this.intent,
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

  /// Steers the feed ([CalseeThemeController.intent]); ignored with
  /// [controller]. Later changes are applied too.
  final ThemeIntent? intent;

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

  /// Themes prepared ahead of a change: the next ones in the feed.
  static const _prefetchCount = 2;

  Timer? _prefetchTimer;
  bool _highContrast = false;

  CalseeThemeController get _controller =>
      widget.controller ??
      (_own ??= CalseeThemeController(
        families: widget.families,
        savedState: widget.savedState,
        seed: widget.seed,
        intent: widget.intent,
      ));

  @override
  void initState() {
    super.initState();
    _controller.addListener(_changed);
    KeyCellSizes.instance.addListener(_schedulePrefetch);
    _schedulePrefetch();
  }

  /// Prepares the next themes once the current transition has settled, so
  /// the frame that shows a theme doesn't build its key art and shapes.
  void _schedulePrefetch() {
    _prefetchTimer?.cancel();
    _prefetchTimer = Timer(
      widget.duration + const Duration(milliseconds: 100),
      () => _prefetchStep(0),
    );
  }

  /// One theme per event-loop turn, so frames can run in between.
  void _prefetchStep(int index) {
    if (!mounted) return;
    final upcoming = _controller._upcoming(_prefetchCount);
    if (index >= upcoming.length) return;
    final sizes = KeyCellSizes.instance.sizes;
    final current = ThemeResolver.resolve(
      _controller.spec,
      highContrast: _highContrast,
    );
    final next = ThemeResolver.resolve(
      upcoming[index],
      highContrast: _highContrast,
    );
    next.keyFace.prepare(sizes);
    if (current.keyFace case final LerpableKeyFace face) {
      face.prepareLerp(next.keyFace, sizes);
    }
    _prefetchTimer = Timer(Duration.zero, () => _prefetchStep(index + 1));
  }

  @override
  void didUpdateWidget(CalseeScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    final old = oldWidget.controller ?? _own;
    if (old != _controller) {
      old?.removeListener(_changed);
      _controller.addListener(_changed);
    }
    if (widget.controller == null && widget.intent != oldWidget.intent) {
      _controller.intent = widget.intent;
    }
  }

  void _changed() {
    widget.onChanged?.call(_controller.toJson());
    _schedulePrefetch();
  }

  @override
  void dispose() {
    _prefetchTimer?.cancel();
    KeyCellSizes.instance.removeListener(_schedulePrefetch);
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
          highContrast: _highContrast = MediaQuery.highContrastOf(context),
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
