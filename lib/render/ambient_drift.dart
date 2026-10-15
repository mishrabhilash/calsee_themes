/// Ambient background drift (motion brief §4.13: the Liquid Glass
/// family's "vivid animated background", spec §5.3 #2).
///
/// A drifting backdrop (`BackgroundSpec.driftPeriodMs > 0`) moves on a
/// cycle of ≥ 40 s. It decelerates to a stop over 2 s once 8 s pass
/// without input, resumes over 1 s on the next touch, and is off when
/// ambient motion is off (Reduce Motion, effects tier off). When off, the
/// background shows a static frame, and glass keeps refracting it.
///
/// [AmbientClock] is the shared drift time painters read at paint time;
/// [AmbientDrift] drives it with one ticker that only runs while a
/// drifting backdrop is showing and moving.
library;

import 'package:calsee_themes/calc_theme_data.dart';
import 'package:calsee_themes/render/background_painter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// The drift time (seconds of motion so far). Notifies on every advance.
final class AmbientClock extends ChangeNotifier {
  new();

  /// The app-wide clock.
  static final AmbientClock instance = AmbientClock();

  double _seconds = 0;

  /// Drift seconds elapsed (not wall time: it slows and stops with idle).
  double get seconds => _seconds;

  /// Advances the clock by [dt] seconds.
  void advance(double dt) {
    if (dt <= 0) return;
    _seconds += dt;
    notifyListeners();
  }

  /// Back to 0 (tests and goldens).
  void reset() {
    _seconds = 0;
    notifyListeners();
  }
}

/// Drives [AmbientClock] while [theme]'s backdrop drifts and [enabled].
class AmbientDrift extends StatefulWidget {
  const new({
    required this.theme,
    required this.enabled,
    required this.child,
    this.clock,
    super.key,
  });

  /// The per-frame theme (its backdrop decides whether anything drifts).
  final ValueListenable<CalcThemeData> theme;

  /// Ambient motion allowed (not Reduce Motion, effects tier not off).
  final bool enabled;

  /// The clock to drive ([AmbientClock.instance] by default).
  final AmbientClock? clock;

  final Widget child;

  /// Idle time before the drift winds down.
  static const Duration idle = Duration(seconds: 8);

  /// Wind-down and wind-up times.
  static const double stopSeconds = 2;
  static const double startSeconds = 1;

  /// Whether [data]'s backdrop drifts.
  static bool drifts(CalcThemeData data) => switch (data.backdrop) {
    final SpecBackdrop b => b.spec.driftPeriodMs > 0,
    _ => false,
  };

  @override
  State<AmbientDrift> createState() => _AmbientDriftState();
}

class _AmbientDriftState extends State<AmbientDrift>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker(_tick);
  Duration _last = Duration.zero;
  Duration _lastInput = Duration.zero;
  double _speed = 0;
  bool _active = true;

  AmbientClock get _clock => widget.clock ?? AmbientClock.instance;

  @override
  void initState() {
    super.initState();
    widget.theme.addListener(_update);
    _update();
  }

  @override
  void didUpdateWidget(AmbientDrift oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.theme != widget.theme) {
      oldWidget.theme.removeListener(_update);
      widget.theme.addListener(_update);
    }
    _update();
  }

  @override
  void dispose() {
    widget.theme.removeListener(_update);
    _ticker.dispose();
    super.dispose();
  }

  bool get _allowed =>
      widget.enabled && AmbientDrift.drifts(widget.theme.value);

  void _update() {
    if (!_allowed) {
      _speed = 0;
      if (_ticker.isActive) _ticker.stop();
      return;
    }
    if (_active && !_ticker.isActive) _start();
  }

  void _start() {
    _last = Duration.zero;
    _lastInput = Duration.zero;
    _ticker.start();
  }

  void _poke(PointerDownEvent _) {
    _active = true;
    if (!_allowed) return;
    if (_ticker.isActive) {
      _lastInput = _last;
    } else {
      _start();
    }
  }

  void _tick(Duration elapsed) {
    final dt = (elapsed - _last).inMicroseconds / 1e6;
    _last = elapsed;
    final idle = elapsed - _lastInput >= AmbientDrift.idle;
    if (idle) {
      _speed -= dt / AmbientDrift.stopSeconds;
      if (_speed <= 0) {
        _speed = 0;
        _active = false;
        _ticker.stop();
        return;
      }
    } else if (_speed < 1) {
      _speed = (_speed + dt / AmbientDrift.startSeconds).clamp(0.0, 1.0);
    }
    _clock.advance(dt * _speed);
  }

  @override
  Widget build(BuildContext context) => Listener(
    behavior: HitTestBehavior.translucent,
    onPointerDown: _poke,
    child: widget.child,
  );
}
