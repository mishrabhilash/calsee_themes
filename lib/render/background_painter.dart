/// Calculator backgrounds from a [BackgroundSpec] (spec §5.1 Background):
/// solid, linear/radial gradients and overlay patterns.
///
/// - **Cheap:** gradient shaders and pattern pictures are cached per
///   (spec, size) in a small LRU ([BackgroundCache]); a repaint is one rect
///   draw plus at most one picture draw.
/// - **Legible:** inside the display's `textSafeArea` the painter lays the
///   background without its pattern, fading out below it, so nothing busy
///   ever sits behind display text (spec §5.4). The guardrails check
///   display text against every colour stop (and the surface).
/// - Mesh gradients (Liquid Glass) are a base plus soft radial blobs
///   (glass/mesh_painter.dart) that drift on `driftPeriodMs` with the
///   shared [AmbientClock] (frozen under Reduce Motion). Noise and shader
///   kinds fall back to a linear gradient of their colours until their
///   families ship.
/// - Family scenes (Claymorphism, Y2K / Frutiger Aero, Paper & ink,
///   Cyberpunk, Vaporwave, Bauhaus) each own a [BackgroundKind] and paint
///   themselves through [backgroundScenePainters]; they keep the text area
///   calm on their own.
library;

import 'dart:collection';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:calsee_themes/calc_theme_data.dart';
import 'package:calsee_themes/engine/theme_spec.dart';
import 'package:calsee_themes/render/ambient_drift.dart';
import 'package:calsee_themes/render/bauhaus/bauhaus_scene.dart';
import 'package:calsee_themes/render/claymorphism/claymorphism_scene.dart';
import 'package:calsee_themes/render/cyberpunk/cyberpunk_scene.dart';
import 'package:calsee_themes/render/glass/mesh_painter.dart';
import 'package:calsee_themes/render/paper_ink/paper_ink_scene.dart';
import 'package:calsee_themes/render/vaporwave/vaporwave_scene.dart';
import 'package:calsee_themes/render/y2k_aero/y2k_aero_scene.dart';
import 'package:flutter/widgets.dart';

/// The [CalcBackdrop] for a [BackgroundSpec].
final class SpecBackdrop extends CalcBackdrop {
  const SpecBackdrop({
    required this.spec,
    required this.surface,
    this.patternFade = 1,
  });

  /// What to paint.
  final BackgroundSpec spec;

  /// The palette `surface` (part of equality; the text area now shows
  /// the un-patterned background instead).
  final Color surface;

  /// Extra opacity on the pattern, 0–1: a theme transition cross-fades one
  /// pattern out and the next in without re-rasterising the pattern tile.
  final double patternFade;

  /// Whether this paints anything beyond a flat colour.
  bool get isPlain =>
      spec.kind == BackgroundKind.solid &&
      spec.pattern == BackgroundPattern.none;

  @override
  BackgroundPainter painter({
    Rect? textSafeArea,
    Rect? toolbarExclusion,
    bool reduceMotion = false,
  }) => BackgroundPainter(
    spec: spec,
    surface: surface,
    textSafeArea: textSafeArea,
    toolbarExclusion: toolbarExclusion,
    patternFade: patternFade,
    reduceMotion: reduceMotion,
  );

  @override
  bool operator ==(Object other) =>
      other is SpecBackdrop &&
      other.spec == spec &&
      other.surface == surface &&
      other.patternFade == patternFade;

  @override
  int get hashCode => Object.hash(spec, surface, patternFade);
}

/// Small LRU of gradient shaders and pattern pictures.
final class BackgroundCache {
  BackgroundCache({this.capacity = 8});

  /// The app-wide cache.
  static final BackgroundCache instance = BackgroundCache();

  /// Entries kept per kind.
  final int capacity;

  final LinkedHashMap<(BackgroundSpec, Size), ui.Shader> _shaders =
      LinkedHashMap();
  final LinkedHashMap<(BackgroundSpec, Size), ui.Picture> _pictures =
      LinkedHashMap();

  final LinkedHashMap<Object, ui.Picture> _scenePictures = LinkedHashMap();

  /// Times a shader or picture was built (tests).
  int builds = 0;

  /// A family scene's cached picture for [key] (value equality: e.g. a
  /// record of the spec, the size and the text-safe area), built by
  /// [build] on a miss; evicted pictures are disposed.
  ui.Picture scenePicture(Object key, ui.Picture Function() build) {
    final hit = _scenePictures.remove(key);
    if (hit != null) return _scenePictures[key] = hit;
    builds++;
    final picture = _scenePictures[key] = build();
    while (_scenePictures.length > capacity) {
      _scenePictures.remove(_scenePictures.keys.first)?.dispose();
    }
    return picture;
  }

  /// The cached shader for [spec] at [size], built by [build] on a miss.
  ui.Shader shader(BackgroundSpec spec, Size size, ui.Shader Function() build) {
    final key = (spec, size);
    final hit = _shaders.remove(key);
    if (hit != null) return _shaders[key] = hit;
    builds++;
    final shader = _shaders[key] = build();
    while (_shaders.length > capacity) {
      _shaders.remove(_shaders.keys.first);
    }
    return shader;
  }

  /// The cached picture for [spec] at [size], built by [build] on a miss.
  ui.Picture picture(
    BackgroundSpec spec,
    Size size,
    ui.Picture Function() build,
  ) {
    final key = (spec, size);
    final hit = _pictures.remove(key);
    if (hit != null) return _pictures[key] = hit;
    builds++;
    final picture = _pictures[key] = build();
    while (_pictures.length > capacity) {
      _pictures.remove(_pictures.keys.first)?.dispose();
    }
    return picture;
  }

  /// Drops (and disposes) everything.
  void clear() {
    _shaders.clear();
    for (final p in _pictures.values) {
      p.dispose();
    }
    _pictures.clear();
    for (final p in _scenePictures.values) {
      p.dispose();
    }
    _scenePictures.clear();
    builds = 0;
  }
}

/// What a family scene painter is given (see [backgroundScenePainters]).
final class BackgroundScene {
  BackgroundScene({
    required this.spec,
    required this.textSafeArea,
    required this.driftSeconds,
    required this.clockSeconds,
    required this.reduceMotion,
    required this.patternFade,
    required this.cache,
    required this.paintFallback,
    this.toolbarExclusion,
  });

  /// The scene's spec (its family documents each field's meaning).
  final BackgroundSpec spec;

  /// Display text area to keep calm (null: none).
  final Rect? textSafeArea;

  /// Chrome in the toolbar row of [textSafeArea] that a scene drawing art
  /// there must leave clear (null: none), in the same coordinates: the
  /// mode button (m7-design §6). Bauhaus starts its masthead after it.
  final Rect? toolbarExclusion;

  /// Drift time: 0 under Reduce Motion or when `driftPeriodMs` is 0.
  final double driftSeconds;

  /// The ambient clock (0 under Reduce Motion), read even when
  /// `driftPeriodMs` is 0: a same-family transition drops the drift period,
  /// and a scene that animates can hold its phase through it.
  final double clockSeconds;

  /// Reduce Motion: nothing animates.
  final bool reduceMotion;

  /// Extra opacity on the scene's overlay pattern, 0–1 (a transition
  /// cross-fading one pattern out and the next in).
  final double patternFade;

  /// The shared shader and picture cache ([BackgroundCache.scenePicture]).
  final BackgroundCache cache;

  /// Paints [spec] as a plain gradient of its colours (malformed specs).
  final void Function(Canvas canvas, Size size) paintFallback;
}

/// Paints one family scene over the whole canvas.
typedef BackgroundScenePainter =
    void Function(Canvas canvas, Size size, BackgroundScene scene);

/// Family scene kind → its painter (each family's render directory).
const Map<BackgroundKind, BackgroundScenePainter> backgroundScenePainters = {
  BackgroundKind.claySoft: paintClaymorphismScene,
  BackgroundKind.aeroSky: paintY2kAeroScene,
  BackgroundKind.chromeHolo: paintY2kAeroScene,
  BackgroundKind.paperSheet: paintPaperInkScene,
  BackgroundKind.cyberGrid: paintCyberpunkScene,
  BackgroundKind.vaporSunset: paintVaporwaveScene,
  BackgroundKind.bauhausComposition: paintBauhausScene,
};

/// The family scene [backdrop] paints (a key of
/// [backgroundScenePainters]), or null for anything else: no backdrop, a
/// plain colour, gradients, patterns and meshes. Chrome that sits over a
/// scene's art checks it (the toolbar's mode button: Bauhaus's masthead,
/// Vaporwave's sun).
BackgroundKind? backdropSceneKind(CalcBackdrop? backdrop) {
  if (backdrop is! SpecBackdrop) return null;
  final kind = backdrop.spec.kind;
  return backgroundScenePainters.containsKey(kind) ? kind : null;
}

/// Paints a [BackgroundSpec] over the whole canvas.
class BackgroundPainter extends CustomPainter {
  BackgroundPainter({
    required this.spec,
    required this.surface,
    this.textSafeArea,
    this.toolbarExclusion,
    this.patternFade = 1,
    this.reduceMotion = false,
    this.driftSeconds,
    BackgroundCache? cache,
  }) : cache = cache ?? BackgroundCache.instance;

  /// Freezes a drifting background at its first frame.
  final bool reduceMotion;

  /// Drift time to paint at; null reads [AmbientClock.instance].
  final double? driftSeconds;

  /// The drift time this paint uses (0 under Reduce Motion).
  double get currentDriftSeconds => reduceMotion || spec.driftPeriodMs <= 0
      ? 0
      : driftSeconds ?? AmbientClock.instance.seconds;

  /// Extra pattern opacity, 0–1 (see [SpecBackdrop.patternFade]).
  final double patternFade;

  /// What to paint.
  final BackgroundSpec spec;

  /// The palette `surface` (not painted; see [SpecBackdrop.surface]).
  final Color surface;

  /// Display text area to keep legible (null: none).
  final Rect? textSafeArea;

  /// Toolbar chrome a scene keeps its art clear of
  /// ([BackgroundScene.toolbarExclusion]; null: none).
  final Rect? toolbarExclusion;

  /// Shader / picture cache.
  final BackgroundCache cache;

  /// Height of the fade below [textSafeArea], dp.
  static const double safeFade = 24;

  /// Highest pattern ink opacity (patterns stay texture, not content).
  static const double maxPatternOpacity = 0.25;

  List<Color> get _colors => [
    for (final c in spec.colors) Color(c),
    if (spec.colors.isEmpty) const Color(0xFF000000),
  ];

  bool get _patterned =>
      spec.kind == BackgroundKind.pattern ||
      spec.pattern != BackgroundPattern.none;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    if (spec.kind == BackgroundKind.meshGradient) {
      paintMesh(
        canvas,
        size,
        spec,
        currentDriftSeconds,
        shaderFor: (argb) => cache.shader(
          BackgroundSpec(
            kind: BackgroundKind.radialGradient,
            colors: List.unmodifiable([argb]),
          ),
          Size.zero,
          () => meshBlobShader(Color(argb)),
        ),
      );
      return;
    }
    final scene = backgroundScenePainters[spec.kind];
    if (scene != null) {
      scene(
        canvas,
        size,
        BackgroundScene(
          spec: spec,
          textSafeArea: textSafeArea,
          toolbarExclusion: toolbarExclusion,
          driftSeconds: currentDriftSeconds,
          clockSeconds: reduceMotion
              ? 0
              : driftSeconds ?? AmbientClock.instance.seconds,
          reduceMotion: reduceMotion,
          patternFade: patternFade.clamp(0.0, 1.0),
          cache: cache,
          paintFallback: _paintGradient,
        ),
      );
      return;
    }
    final rect = Offset.zero & size;
    final colors = _colors;
    final paint = Paint()..color = colors.first;
    if (colors.length > 1 && spec.kind != BackgroundKind.pattern) {
      paint.shader = cache.shader(spec, size, () => _gradient(size, colors));
    }
    canvas.drawRect(rect, paint);

    final fade = patternFade.clamp(0.0, 1.0);
    // Pattern tiles and pictures depend only on the pattern fields, so a
    // transition that lerps the colours underneath reuses them.
    final patternKey = BackgroundSpec(
      kind: BackgroundKind.pattern,
      colors: const [0],
      pattern: spec.pattern,
      patternColor: spec.patternColor,
      patternScaleCdp: spec.patternScaleCdp,
      patternOpacityPermille: spec.patternOpacityPermille,
    );
    switch (spec.pattern) {
      case BackgroundPattern.none:
        break;
      case _ when fade <= 0:
        break;
      case BackgroundPattern.dots ||
          BackgroundPattern.grid ||
          BackgroundPattern.stripes ||
          BackgroundPattern.checker:
        // One tiled-shader draw, whatever the screen size; the paint's
        // alpha modulates the shader.
        canvas.drawRect(
          rect,
          Paint()
            ..shader = cache.shader(patternKey, Size.zero, _tileShader)
            ..color = Color.fromRGBO(0, 0, 0, fade),
        );
      case BackgroundPattern.halftone || BackgroundPattern.waves:
        final picture = cache.picture(patternKey, size, () => _pattern(size));
        if (fade < 1) {
          canvas
            ..saveLayer(rect, Paint()..color = Color.fromRGBO(0, 0, 0, fade))
            ..drawPicture(picture)
            ..restore();
        } else {
          canvas.drawPicture(picture);
        }
    }

    // Only patterns need the plain backing: gradients are smooth, and
    // display text contrast is checked against every colour stop.
    final safe = textSafeArea;
    if (safe != null && _patterned) {
      final area = safe.intersect(rect);
      if (!area.isEmpty) {
        // The background without its pattern (the same base paint), so
        // the text area matches the colours around it.
        canvas.drawRect(area, paint);
        final fade = Rect.fromLTWH(
          area.left,
          area.bottom,
          area.width,
          safeFade,
        );
        canvas
          ..saveLayer(fade, Paint())
          ..drawRect(fade, paint)
          ..drawRect(
            fade,
            Paint()
              ..blendMode = BlendMode.dstIn
              ..shader = ui.Gradient.linear(
                fade.topCenter,
                fade.bottomCenter,
                const [Color(0xFFFFFFFF), Color(0x00FFFFFF)],
              ),
          )
          ..restore();
      }
    }
  }

  /// [spec]'s colours as one plain gradient rect (a solid for one colour).
  void _paintGradient(Canvas canvas, Size size) {
    final colors = _colors;
    final paint = Paint()..color = colors.first;
    if (colors.length > 1) {
      paint.shader = cache.shader(spec, size, () => _gradient(size, colors));
    }
    canvas.drawRect(Offset.zero & size, paint);
  }

  ui.Shader _gradient(Size size, List<Color> colors) {
    if (spec.kind == BackgroundKind.radialGradient) {
      final stops = [
        for (var i = 0; i < colors.length; i++) i / (colors.length - 1),
      ];
      return ui.Gradient.radial(
        Offset(size.width / 2, size.height * 0.35),
        size.longestSide * 0.75,
        colors,
        stops,
      );
    }
    return linearGradientShader(size, colors, spec.angleTenths);
  }

  /// Pattern ink opacity: [BackgroundSpec.patternOpacityPermille] when set,
  /// else the pattern colour's alpha; capped at [maxPatternOpacity].
  double get patternOpacity {
    final ink = Color(spec.patternColor);
    final o = spec.patternOpacityPermille > 0
        ? spec.patternOpacityPermille / 1000
        : ink.a;
    return o.clamp(0.0, maxPatternOpacity);
  }

  /// Pattern tiles are rasterised at this scale (sharp up to 3× screens).
  static const double tileScale = 3;

  double get _cell =>
      spec.patternScaleCdp > 0 ? spec.patternScaleCdp / 100 : 12.0;

  ui.Shader _tileShader() {
    final cell = _cell;
    final tile = spec.pattern == BackgroundPattern.checker ? cell * 2 : cell;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)..scale(tileScale);
    final ink = Paint()
      ..color = Color(spec.patternColor).withValues(alpha: patternOpacity);
    switch (spec.pattern) {
      case BackgroundPattern.dots:
        canvas.drawCircle(Offset(cell / 2, cell / 2), cell * 0.12, ink);
      case BackgroundPattern.grid:
        canvas
          ..drawRect(Rect.fromLTWH(0, 0, cell, 1), ink)
          ..drawRect(Rect.fromLTWH(0, 0, 1, cell), ink);
      case BackgroundPattern.stripes:
        ink.strokeWidth = cell * 0.25;
        for (final d in [-cell, 0.0, cell]) {
          canvas.drawLine(Offset(d, 0), Offset(d + cell, cell), ink);
        }
      case BackgroundPattern.checker:
        canvas
          ..drawRect(Rect.fromLTWH(0, 0, cell, cell), ink)
          ..drawRect(Rect.fromLTWH(cell, cell, cell, cell), ink);
      case BackgroundPattern.none ||
          BackgroundPattern.halftone ||
          BackgroundPattern.waves:
        break;
    }
    final px = (tile * tileScale).ceil().clamp(1, 1024);
    final image = recorder.endRecording().toImageSync(px, px);
    final matrix = Matrix4.diagonal3Values(tile / px, tile / px, 1).storage;
    return ui.ImageShader(image, TileMode.repeated, TileMode.repeated, matrix);
  }

  ui.Picture _pattern(Size size) {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final cell = _cell;
    final ink = Paint()
      ..color = Color(spec.patternColor).withValues(alpha: patternOpacity);
    final cols = (size.width / cell).ceil() + 1;
    final rows = (size.height / cell).ceil() + 1;
    switch (spec.pattern) {
      case BackgroundPattern.none:
        break;
      case BackgroundPattern.dots:
        for (var y = 0; y < rows; y++) {
          for (var x = 0; x < cols; x++) {
            canvas.drawCircle(
              Offset((x + 0.5) * cell, (y + 0.5) * cell),
              cell * 0.12,
              ink,
            );
          }
        }
      case BackgroundPattern.halftone:
        for (var y = 0; y < rows; y++) {
          final r = cell * (0.05 + 0.2 * y / math.max(1, rows - 1));
          for (var x = 0; x < cols; x++) {
            canvas.drawCircle(
              Offset((x + 0.5 + (y.isOdd ? 0.5 : 0)) * cell, (y + 0.5) * cell),
              r,
              ink,
            );
          }
        }
      case BackgroundPattern.grid:
        ink.strokeWidth = 1;
        for (var x = 0; x < cols; x++) {
          canvas.drawLine(
            Offset(x * cell, 0),
            Offset(x * cell, size.height),
            ink,
          );
        }
        for (var y = 0; y < rows; y++) {
          canvas.drawLine(
            Offset(0, y * cell),
            Offset(size.width, y * cell),
            ink,
          );
        }
      case BackgroundPattern.stripes:
        ink.strokeWidth = cell * 0.25;
        final span = size.width + size.height;
        for (var d = -size.height; d < span; d += cell) {
          canvas.drawLine(
            Offset(d, 0),
            Offset(d + size.height, size.height),
            ink,
          );
        }
      case BackgroundPattern.checker:
        for (var y = 0; y < rows; y++) {
          for (var x = y.isOdd ? 1 : 0; x < cols; x += 2) {
            canvas.drawRect(Rect.fromLTWH(x * cell, y * cell, cell, cell), ink);
          }
        }
      case BackgroundPattern.waves:
        ink
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5;
        final path = Path();
        for (var y = 0; y < rows; y++) {
          final base = (y + 0.5) * cell;
          path.moveTo(0, base);
          for (var x = 0.0; x <= size.width; x += 4) {
            path.lineTo(
              x,
              base + math.sin(x / cell * 2 * math.pi) * cell * 0.2,
            );
          }
        }
        canvas.drawPath(path, ink);
    }
    return recorder.endRecording();
  }

  @override
  bool shouldRepaint(BackgroundPainter oldDelegate) =>
      oldDelegate.spec != spec ||
      oldDelegate.surface != surface ||
      oldDelegate.patternFade != patternFade ||
      oldDelegate.textSafeArea != textSafeArea ||
      oldDelegate.toolbarExclusion != toolbarExclusion ||
      oldDelegate.reduceMotion != reduceMotion ||
      oldDelegate.driftSeconds != driftSeconds ||
      (spec.driftPeriodMs > 0 && !reduceMotion);
}

/// A linear gradient across [size] through evenly spaced [colors] (two or
/// more) at [angleTenths] (tenths of a degree; 0 = top → bottom, turning
/// clockwise), corner to corner along that direction: the generic
/// background gradient, for family scenes too.
ui.Shader linearGradientShader(Size size, List<Color> colors, int angleTenths) {
  final stops = [
    for (var i = 0; i < colors.length; i++) i / (colors.length - 1),
  ];
  final radians = angleTenths / 10 * math.pi / 180;
  final dir = Offset(-math.sin(radians), math.cos(radians));
  final half = (dir.dx.abs() * size.width + dir.dy.abs() * size.height) / 2;
  final c = size.center(Offset.zero);
  return ui.Gradient.linear(c - dir * half, c + dir * half, colors, stops);
}
