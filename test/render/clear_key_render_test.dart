/// AC (`KeyRole.clear`) in the resolved theme and in every family renderer.
library;

import 'package:calsee_themes/calc_theme_data.dart';
import 'package:calsee_themes/engine/contrast.dart';
import 'package:calsee_themes/engine/generator.dart';
import 'package:calsee_themes/engine/theme_spec.dart';
import 'package:calsee_themes/plain_theme.dart';
import 'package:calsee_themes/render/bauhaus/bauhaus_key_face.dart';
import 'package:calsee_themes/render/claymorphism/clay_key_face.dart';
import 'package:calsee_themes/render/glass/glass_key_face.dart';
import 'package:calsee_themes/render/neopop/neopop_key_face.dart';
import 'package:calsee_themes/render/paper_ink/paper_key_art.dart';
import 'package:calsee_themes/render/paper_ink/paper_key_face.dart';
import 'package:calsee_themes/render/retro/retro_key_face.dart';
import 'package:calsee_themes/render/theme_resolver.dart';
import 'package:calsee_themes/render/y2k_aero/y2k_key_face.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

const ThemeGenerator gen = ThemeGenerator();

ThemeSpec specOf(ThemeFamily family, {int seed = 2, bool accessible = false}) =>
    gen.generate(seed, family, currentEngineVersion, accessible: accessible);

int argb(Color c) => c.toARGB32();

void main() {
  setUp(ThemeResolver.clearMemo);

  test('every family resolves AC to its own style', () {
    for (final f in ThemeFamily.values.where((f) => f.enabled)) {
      for (final accessible in [false, true]) {
        final spec = specOf(f, accessible: accessible);
        final theme = ThemeResolver.resolve(spec);
        final clear = theme.keyStyle(KeyRole.clear);
        expect(clear, theme.clearKey, reason: f.name);
        expect(clear.fill, isNot(theme.functionKey.fill), reason: f.name);
        expect(argb(clear.label), spec.clearKey.label, reason: f.name);
        if (f != ThemeFamily.liquidGlass) {
          expect(argb(clear.fill), spec.clearKey.face, reason: f.name);
        }
        expect(clear.labelWeight, theme.operatorKey.labelWeight);
        expect(
          contrastRatio(argb(clear.label), argb(clear.fill) | 0xFF000000),
          greaterThanOrEqualTo(accessible ? ratioAccessible : ratioText),
          reason: '${f.name} accessible $accessible',
        );
        // The other function keys keep the function style.
        expect(theme.keyStyle(KeyRole.backspace), theme.functionKey);
      }
    }
  });

  test('a host theme without a clear key gives AC the function style', () {
    final host = CalcThemeData(
      brightness: Brightness.light,
      background: const Color(0xFFFFFFFF),
      displayText: const Color(0xFF000000),
      previewText: const Color(0xFF333333),
      errorText: const Color(0xFFB00020),
      caret: const Color(0xFF0000FF),
      focusRing: const Color(0xFF0000FF),
      digitKey: const KeyStyle(
        fill: Color(0xFFEEEEEE),
        label: Color(0xFF000000),
      ),
      operatorKey: const KeyStyle(
        fill: Color(0xFFDDDDFF),
        label: Color(0xFF000000),
      ),
      equalsKey: const KeyStyle(
        fill: Color(0xFF2244CC),
        label: Color(0xFFFFFFFF),
      ),
      functionKey: const KeyStyle(
        fill: Color(0xFFDDDDDD),
        label: Color(0xFF000000),
      ),
    );
    expect(host.clearKey, host.functionKey);
    expect(host.keyStyle(KeyRole.clear), host.functionKey);
    final mid = CalcThemeData.lerp(host, PlainTheme.light, 0.5);
    expect(
      mid.clearKey,
      KeyStyle.lerp(host.functionKey, PlainTheme.light.clearKey, 0.5),
    );
  });

  test('the plain theme has a red AC key in every variant', () {
    for (final t in [
      PlainTheme.light,
      PlainTheme.dark,
      PlainTheme.highContrastLight,
      PlainTheme.highContrastDark,
    ]) {
      final c = t.clearKey;
      expect(c, isNot(t.functionKey));
      expect(
        contrastRatio(argb(c.label), argb(c.fill)),
        greaterThanOrEqualTo(ratioText),
      );
    }
  });

  test('family renderers colour AC on its own', () {
    final neo = keyFaceFor(specOf(ThemeFamily.neoPop)) as NeoPopKeyFace;
    expect(
      argb(neo.edgesFor(KeyRole.clear).side),
      specOf(ThemeFamily.neoPop).clearKey.edge,
    );

    final retro = keyFaceFor(specOf(ThemeFamily.retro)) as RetroKeyFace;
    expect(
      argb(retro.skirtFor(KeyRole.clear)),
      specOf(ThemeFamily.retro).clearKey.edge,
    );

    final clay = keyFaceFor(specOf(ThemeFamily.claymorphism)) as ClayKeyFace;
    expect(
      argb(clay.shadowFor(KeyRole.clear)),
      specOf(ThemeFamily.claymorphism).clearKey.edge,
    );

    final glass = keyFaceFor(specOf(ThemeFamily.liquidGlass)) as GlassKeyFace;
    expect(
      argb(glass.tintFor(KeyRole.clear).tint),
      specOf(ThemeFamily.liquidGlass).clearKey.face,
    );

    final bauhaus = keyFaceFor(specOf(ThemeFamily.bauhaus)) as BauhausKeyFace;
    expect(bauhaus.accentFor(KeyRole.clear), isFalse);

    expect(paperArtKindOf(KeyRole.clear), PaperArtKind.stamp);
    expect(y2kMetalRole(KeyRole.clear), isFalse);
    expect(y2kMetalRole(KeyRole.backspace), isTrue);
  });

  test('renderers built without AC colours fall back to the function ones', () {
    const edges = NeoPopEdges(
      side: Color(0xFF111111),
      bottom: Color(0xFF000000),
    );
    const neo = NeoPopKeyFace(
      depth: 3,
      digitEdges: edges,
      operatorEdges: edges,
      equalsEdges: edges,
      functionEdges: NeoPopEdges(
        side: Color(0xFF222222),
        bottom: Color(0xFF000000),
      ),
    );
    expect(neo.edgesFor(KeyRole.clear), neo.functionEdges);
    const retro = RetroKeyFace(
      travel: 2,
      digitSkirt: Color(0xFF111111),
      operatorSkirt: Color(0xFF111111),
      equalsSkirt: Color(0xFF111111),
      functionSkirt: Color(0xFF222222),
    );
    expect(retro.skirtFor(KeyRole.clear), retro.functionSkirt);
  });

  test('theme morphs lerp the AC renderer colours', () {
    final a = keyFaceFor(specOf(ThemeFamily.neoPop)) as NeoPopKeyFace;
    final b = keyFaceFor(specOf(ThemeFamily.neoPop, seed: 9)) as NeoPopKeyFace;
    final mid = a.lerpTo(b, 0.5) as NeoPopKeyFace;
    expect(
      mid.edgesFor(KeyRole.clear).side,
      Color.lerp(
        a.edgesFor(KeyRole.clear).side,
        b.edgesFor(KeyRole.clear).side,
        0.5,
      ),
    );
    final ta = ThemeResolver.resolve(specOf(ThemeFamily.retro));
    final tb = ThemeResolver.resolve(specOf(ThemeFamily.vaporwave));
    expect(
      CalcThemeData.lerp(ta, tb, 0.5).clearKey,
      KeyStyle.lerp(ta.clearKey, tb.clearKey, 0.5),
    );
  });
}
