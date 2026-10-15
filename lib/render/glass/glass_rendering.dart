/// How glass surfaces render on this device (motion brief §6.1 outputs
/// `glassMode` and `effectsTier`; spec §4.4 Reduce Transparency, §5.4
/// graceful degradation). Resolved by `motionPreferencesProvider` and fed
/// to the theme resolver, so renderers get it at construction and never
/// read platform state while painting.
library;

import 'package:flutter/foundation.dart';

/// Glass translucency (motion brief §6.1 `glassMode`).
enum GlassMode {
  /// Full glass: the tint over the live background, refraction hints.
  glass,

  /// Frosted: the tint over a mostly diffused background (the frost
  /// underlay at ≥ 60 %), no refraction hints. Lower-tier devices.
  frosted,

  /// Solid tint (Reduce Transparency, spec §4.4): opaque faces and panel,
  /// each the glass tint composited over the background's base colour.
  solid,
}

/// Effects budget (motion brief §6.1 `effectsTier`).
enum EffectsTier {
  /// Every static gradient (specular, caustic, edge lensing, shadow) and
  /// the animated glow and ambient drift.
  full,

  /// Over the raster budget: flat tints and rims only (no gradients, no
  /// shadow), the glow as a flat wash; no ambient drift.
  lite,

  /// Reduce Motion: nothing animates (no drift; the press glow is a
  /// discrete 50 % wash), static artwork kept.
  off,
}

/// The glass rendering configuration a theme is resolved with.
@immutable
final class GlassRendering {
  const new({this.mode = GlassMode.glass, this.tier = EffectsTier.full});

  /// Full glass, full effects.
  static const GlassRendering standard = GlassRendering();

  final GlassMode mode;
  final EffectsTier tier;

  /// Whether static gradient artwork is drawn.
  bool get gradients => tier != EffectsTier.lite;

  @override
  bool operator ==(Object other) =>
      other is GlassRendering && other.mode == mode && other.tier == tier;

  @override
  int get hashCode => Object.hash(mode, tier);

  @override
  String toString() => 'GlassRendering(${mode.name}, ${tier.name})';
}
