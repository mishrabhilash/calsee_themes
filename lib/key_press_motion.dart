import 'dart:async';

import 'package:calsee_themes/calc_theme.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/widgets.dart';

/// Evaluates [inner] one frame ahead, so the first frame after touch-down
/// already moves (motion-flutter §1.4).
///
/// A ticker started outside a frame (pointer events arrive between frames)
/// evaluates its first frame at `elapsed = 0`; without the lead the press
/// would only start moving on the second frame.
final class LeadSimulation extends Simulation {
  new(this.inner, this.lead) : super(tolerance: inner.tolerance);

  /// The simulation being led.
  final Simulation inner;

  /// Seconds to evaluate ahead (one frame: `1 / refreshRate`).
  final double lead;

  @override
  double x(double time) => inner.x(time + lead);

  @override
  double dx(double time) => inner.dx(time + lead);

  @override
  bool isDone(double time) => inner.isDone(time + lead);

  @override
  String toString() => 'LeadSimulation($inner, lead: $lead)';
}

/// The animation channels of one key (motion brief §2.2, §4.1, §4.4).
///
/// - [press]: p, 0 at rest and the press amplitude when held (1 for touch,
///   0.5 for a physical key). Unbounded, so an underdamped theme spring may
///   overshoot; the painter accepts p outside [0, 1].
/// - [tint]: the pressed state layer, 0–1. Snapped on at touch-down so the
///   first frame already confirms the press; released on the release
///   spring. With Reduce Motion it fades on `effectsFast` and [press] jumps.
/// - [hover]: the desktop hover state layer, 0–1 on `effectsDefault`.
/// - [hold]: long-press progress, 0–1 linearly over [holdDuration]. The
///   painter shows the radial fill from [holdFillDelay].
///
/// Every spring is retargeted from the current value **and velocity**, so a
/// release mid-press turns around smoothly. Release starts no earlier than
/// [CalcThemeData.minPress] after the press began; callers commit input
/// immediately regardless.
final class KeyPressMotion implements KeyFaceMotionDetail {
  new({required TickerProvider vsync})
    : press = AnimationController.unbounded(vsync: vsync),
      scale = AnimationController.unbounded(vsync: vsync),
      tint = AnimationController(vsync: vsync),
      hover = AnimationController(vsync: vsync),
      hold = AnimationController(vsync: vsync, duration: holdDuration);

  /// Press depth p (see class docs).
  @override
  final AnimationController press;

  /// Press depth for the key's *scale* (the widget's press transform): the
  /// same as [press] on the way in; on release it follows the family's
  /// `release` spring (M3E 800/0.6, which may overshoot) while [press] —
  /// what painters read for corners and depth — may follow `releaseAlt`
  /// (M3E `effectsDefault`: corners never bounce; motion brief §2.3).
  @override
  final AnimationController scale;

  /// Where the current (or last) touch went down, as a fraction of the
  /// key's box; null for physical-key and screen-reader presses (set by
  /// the key before [down]). Liquid Glass lights its glow from here.
  @override
  Offset? touchFraction;

  /// Pressed state layer, 0–1.
  @override
  final AnimationController tint;

  /// Hover state layer, 0–1.
  @override
  final AnimationController hover;

  /// Long-press progress, 0–1 over [holdDuration].
  final AnimationController hold;

  /// Long-press hold time (motion brief §4.4).
  static const Duration holdDuration = Duration(milliseconds: 500);

  /// When the long-press radial fill starts to show (quick taps never
  /// see it).
  static const Duration holdFillDelay = Duration(milliseconds: 150);

  /// Spring stop tolerance (motion brief §6.2): stops ticking as soon as
  /// the motion is invisible, and lands exactly on the target.
  static const Tolerance tolerance = Tolerance(distance: 0.005, velocity: 0.05);

  /// Amplitude of a press driven by a physical key (motion brief §4.1).
  static const double keyboardAmplitude = 0.5;

  /// The long-press fill fraction now ([holdFillFraction] of [hold]).
  @override
  double get holdFill => holdFillFraction(hold.value);

  /// All channels, for a painter's `repaint`.
  @override
  late final Listenable listenable = Listenable.merge([
    press,
    tint,
    hover,
    hold,
  ]);

  bool _down = false;
  bool _minElapsed = true;
  bool _releasePending = false;
  Timer? _minPressTimer;
  SpringDescription? _releaseSpring;
  SpringDescription? _shapeSpring;
  bool _releaseReduced = false;
  double _amplitude = 1;

  /// Whether the key is held (release may still be pending for minPress).
  bool get isDown => _down;

  /// Whether a release is waiting for [CalcThemeData.minPress].
  bool get releasePending => _releasePending;

  /// The amplitude of the current (or last) press.
  double get amplitude => _amplitude;

  /// Hold fill progress for a hold value [t] (0–1 over [holdDuration]):
  /// 0 until [holdFillDelay], then linear to 1 at [holdDuration].
  static double holdFillFraction(double t) {
    final total = holdDuration.inMicroseconds;
    final delay = holdFillDelay.inMicroseconds;
    return ((t * total - delay) / (total - delay)).clamp(0.0, 1.0);
  }

  /// One frame at [refreshRate] Hz, in seconds (60 Hz when unknown).
  static double frameLead(double refreshRate) =>
      refreshRate.isFinite && refreshRate > 0 ? 1 / refreshRate : 1 / 60;

  static SpringSimulation _spring(
    SpringDescription spring,
    AnimationController c,
    double target,
  ) => SpringSimulation(
    spring,
    c.value,
    target,
    c.velocity,
    snapToEnd: true,
    tolerance: tolerance,
  );

  /// Presses the key to [amplitude] on the [spring] (`pressIn`), one
  /// [lead] (seconds) ahead so the first frame moves. Snaps the tint on.
  ///
  /// With [reduceMotion], p jumps to [amplitude] and the tint fades in on
  /// `effectsFast` instead (motion brief §2.2.5).
  void down({
    required SpringDescription spring,
    required double lead,
    double amplitude = 1,
    bool reduceMotion = false,
  }) {
    _down = true;
    _releasePending = false;
    _amplitude = amplitude;
    _minElapsed = false;
    _minPressTimer?.cancel();
    _minPressTimer = Timer(CalcThemeData.minPress, _onMinPress);
    if (reduceMotion) {
      press.value = amplitude;
      scale.value = amplitude;
      tint.animateWith(
        LeadSimulation(_spring(CalcThemeData.effectsFast, tint, 1), lead),
      );
    } else {
      tint.value = 1;
      press.animateWith(
        LeadSimulation(_spring(spring, press, amplitude), lead),
      );
      scale.animateWith(
        LeadSimulation(_spring(spring, scale, amplitude), lead),
      );
    }
  }

  /// Releases the key on the [spring] (`release`), no earlier than
  /// [CalcThemeData.minPress] after [down]. With [reduceMotion], p jumps to
  /// 0 and the tint fades out on `effectsFast`.
  void up({
    required SpringDescription spring,
    SpringDescription? shapeSpring,
    bool reduceMotion = false,
  }) {
    if (!_down) return;
    _releaseSpring = spring;
    _shapeSpring = shapeSpring;
    _releaseReduced = reduceMotion;
    if (_minElapsed) {
      _release();
    } else {
      _releasePending = true;
    }
  }

  void _onMinPress() {
    _minPressTimer = null;
    _minElapsed = true;
    if (_releasePending) _release();
  }

  void _release() {
    _down = false;
    _releasePending = false;
    final spring = _releaseSpring ?? CalcThemeData.effectsDefault;
    if (_releaseReduced) {
      press.value = 0;
      scale.value = 0;
      tint.animateWith(_spring(CalcThemeData.effectsFast, tint, 0));
    } else {
      scale.animateWith(_spring(spring, scale, 0));
      press.animateWith(_spring(_shapeSpring ?? spring, press, 0));
      // The state layer is an effects channel: it never overshoots
      // (motion brief §2.1), whatever the scale spring does.
      tint.animateWith(_spring(CalcThemeData.effectsDefault, tint, 0));
    }
  }

  /// Fades the hover state layer in or out on `effectsDefault`.
  void setHovered({required bool hovered}) {
    final target = hovered ? 1.0 : 0.0;
    if (hover.value == target && !hover.isAnimating) return;
    hover.animateWith(_spring(CalcThemeData.effectsDefault, hover, target));
  }

  /// Starts the long-press fill from empty.
  void startHold() {
    hold.value = 0;
    hold.forward();
  }

  /// Stops the long-press fill where it is; it fades out with the tint.
  void stopHold() => hold.stop();

  /// Shows the long-press fill as complete (the long press fired).
  void completeHold() => hold.value = 1;

  /// Clears the long-press fill instantly.
  void resetHold() => hold.value = 0;

  /// Releases timers and controllers.
  void dispose() {
    _minPressTimer?.cancel();
    press.dispose();
    scale.dispose();
    tint.dispose();
    hover.dispose();
    hold.dispose();
  }
}
