# calsee_themes: context for AI agents and contributors

Endless, seeded, generated themes for Flutter, published on pub.dev as
`calsee_themes` (MIT). It started as the theme engine of the Calsee
calculator (https://calsee.tech). This repo is the package's only home:
https://github.com/mishrabhilash/calsee_themes

Read this before changing anything. The hard rules are in "Rules".

## What it is

- **Engine** (`lib/engine/`): pure Dart. It turns (seed, family,
  engineVersion, accessible[, intent]) into a `ThemeSpec`, bit-exact on
  every platform. It also holds the feed (`ThemeFeed`: endless history,
  back and forward, heroes every 8–12 steps, family filter, steering),
  share codes, names and the contrast guardrails.
- **Renderers** (`lib/render/`, one folder per family): key faces, display
  faces and ambient backdrops. `ThemeResolver.resolve(spec)` turns a spec
  into `CalcThemeData`.
- **Theme plumbing** (`lib/*.dart`): `CalcTheme` / `AnimatedCalcTheme`
  (an InheritedModel, with per-frame morphs), `CalcThemeData`, `KeyRole`,
  key and press motion, and the live painters.
- **Drop-in widgets** (`lib/widgets/`): `CalseeScope` +
  `CalseeThemeController`, `CalseeKey`, `CalseeSurface`, `CalseeBackdrop`,
  `CalseeDisplayPanel`, `CalseeReadout`, `CalseeSwipeArea`.
- **Public API:** `lib/calsee_themes.dart`. It exports the widgets and the
  few types users need. Deeper libraries are importable but less stable.
- **Fonts** (`fonts/`): 11 bundled OFL fonts. Sources and checksums are in
  `fonts/README.md`.
- **Example** (`example/`): a kids' maths game. Keep payment examples
  out of the package, its docs and its gallery. `example/screenshots/`
  renders the README and pub.dev images into `doc/`.

Families (`ThemeFamily`, `lib/engine/families.dart`): m3Expressive,
liquidGlass, neoPop, neumorphism, retro, neoBrutalism, claymorphism,
y2kChrome, paperInk, cyberpunk, vaporwave and bauhaus are enabled. plain,
pixel, aurora and terminal are disabled. Family ids are stable: they are
stored in share codes and JSON.

## Who depends on it

- **Calsee**, the calculator: `~/calculator`, private repo
  `mishrabhilash/calsee`. It still uses an older in-repo copy at
  `packages/calsee_themes`. Moving it onto this package is pending; it
  will then drop its own font declarations. Its Material chrome
  (`materialThemeFor`, `ChromeTheme`) lives in
  `calculator/packages/calsee_themes_material` (Flutter 3.47+), which is
  not part of this package.
- **Game Night (Clatter)**: `~/game_night`. Also on the in-repo copy, for
  now.
- **Outside apps on Flutter 3.35.** The first was a UPI payment app on
  3.35.7 that themes only its amount and keypad screen. That's why the
  minimum is Flutter 3.35 / Dart 3.9.

## Toolchains

- **Flutter 3.47.6** (Dart 3.13) at `~/flutter-3.47.6/bin`: the primary
  toolchain and the lint gate.
- **Flutter 3.35.7** (Dart 3.9) at `~/flutter-3.35.7/bin`: the minimum
  supported version. Every change must compile and pass tests here too.
- The global `flutter` on PATH (3.44.8) is not used for this repo.

Prefix commands with `export PATH=~/flutter-3.47.6/bin:$PATH && ...`
(or the 3.35.7 path).

## Commands

```bash
flutter test                                    # 653 tests, run on both toolchains
flutter analyze                                 # must be "No issues found" on 3.47.6
dart format --output=none --set-exit-if-changed lib test example/lib example/screenshots
(cd example && flutter analyze)
dart pub publish --dry-run                      # 0 warnings
pana --no-warning --flutter-sdk ~/flutter-3.47.6 .   # pub.dev score, expect 160/160
```

- **Switching toolchains rewrites `pubspec.lock`** (it isn't committed).
  Running `pub get` on 3.35.7 pins `very_good_analysis` 10 and
  `dynamic_color` 1.x. Back on 3.47.6, run `flutter pub upgrade` before
  `flutter analyze`. Otherwise you get stale lints such as
  `one_member_abstracts` and `unreachable_from_main`.
- **Illustrations:** from `example/`, with
  `FLUTTER_ROOT=~/flutter-3.47.6`, run
  `flutter test screenshots/screenshots_test.dart --update-goldens`, then
  `python3 screenshots/compose.py`. Commit `doc/`. `screenshots/out/` is
  git-ignored.

## Rules

### Dart 3.9 / Flutter 3.35 compatibility (everything in `lib/` and `example/`)
- Use classic constructors: `ClassName(...)` and `ClassName.named(...)`.
  Never `new(...)`, `factory name(...)`, primary constructors, or private
  named parameters (`{required this._x}`). Write `{required T x}` with
  `: _x = x` instead.
- Enum constructors must say `const` explicitly.
- No dot shorthands (`.foo` for `Type.foo`); they need Dart 3.10.
- No `FontWeight(int)`; it doesn't exist before Flutter 3.38. Use
  `cssFontWeight(css)` from `render/fonts.dart`: exact on new Flutter, the
  nearest hundred on 3.35.
- No `material_ui` / `cupertino_ui` (they need Flutter 3.44+), and no
  `package:flutter/material.dart` or `cupertino.dart`. `lib/` uses
  `package:flutter/widgets.dart` and lower layers only. The backspace icon
  is a raw `IconData(0xeeb5, fontFamily: 'MaterialIcons')`.
- Dependency ranges must resolve on both toolchains: `meta ^1.16.0`,
  `dynamic_color >=1.9.0 <3.0.0`, `test >=1.26.2`,
  `very_good_analysis >=9.0.0 <12.0.0`.
- `analysis_options.yaml` pins `formatter: trailing_commas: preserve`.
  very_good_analysis 11 dropped it, and pub.dev formats with 11. Keep it,
  or pana's format check fails.

### Bit-exact engine (`lib/engine/**`)
- Pure Dart: no Flutter, no `dart:ui`, no `dart:math` (use
  `bitexact_math.dart`). The one exception is `theme_feed.dart`, which may
  `import 'dart:math' show Random;` for `Random.secure()`, and only to
  pick a feed's start seed.
- Use seeded PRNG only (`rng.dart`). Never an unseeded or `dart:math`
  `Random(seed)` in generation, and never `sin`/`cos`/`atan2`/`pow` from
  `dart:math` in generator outputs.
- `ThemeSpec` is a pure function of (seed, family, engineVersion,
  accessible, intent, centred): identical `toJson` and `hashCode` on
  every run and platform.
- **Any change to generator output needs an engine version bump**
  (`currentEngineVersion` in `generator.dart`, now 4) and a golden JSON
  fixture (`test/engine/fixtures/`) proving older versions still reproduce
  exactly. Saved feeds, favourites and share codes in shipped apps depend
  on this.
- Guardrails (`guardrails.dart`) are non-negotiable:
  - digit, operator and `=` labels ≥ 4.5:1 on their faces;
  - display text ≥ 3:1 (target 4.5:1); preview text ≥ 3:1;
  - operator and `=` faces differ from digit faces by ΔEOK ≥ 0.08 under
    normal, protan, deutan and tritan vision **and** ≥ 1.5:1 face contrast,
    or the family records a non-colour cue;
  - the accessible lock needs labels ≥ 7:1.

  Repairs use OKLCH lightness bisection. A failing theme never ships: the
  generator retries the next sub-seed and finally falls back to a hero.
- Stable ids (family ids, font ids, hero ids, `IntentColor.code`, the
  `steeredHarmonies` order) are stored data. Never renumber them.

### Steering (`theme_intent.dart`, `steering.dart`)
- A host turns words into a `ThemeIntent`. The package never sees text
  and takes no AI dependency.
- Steering narrows existing draws; it never removes one. Brightness and
  the harmony scheme are drawn and then overridden, chroma ranges are
  narrowed before sampling, and steered hues come from the
  `palette…/intent` sub-stream. Without an intent, output is unchanged.
- Steering exists from engine v4 on. Changing how an intent is applied
  changes steered output: bump the engine version and keep
  `fixtures/steered_v4.json` reproducing.
- `ThemeIntent.vocabulary` is append-only, and a test pins it: hosts
  generate prompts and schemas from it. `steerableFamilies` lists the
  families that honour steering. To add one, steer its builder, add it to
  the set, and teach `reportFor` what it can't honour.
- `ThemeVariant` values are only ever added, and each addition breaks
  hosts with exhaustive switches (2.0.0 added `steered`): it's a major
  version.

### Rendering
- Fonts are declared in this package's pubspec. Every family name carries
  `fontPackagePrefix` (`packages/calsee_themes/`). Apps declare no fonts.
  To add a font: put the file and its `OFL.txt` in `fonts/`, add the
  pubspec entry, a `BundledFont` value, and entries in `bundledFontAssets`
  and `bundledFontLicenses`, then update `fonts/README.md`.
- A theme change must never touch app state. Keys repaint without relayout
  (60 fps budget), there's no `Morph` construction in commit frames, and
  every frame of a transition keeps labels ≥ 4.5:1.
- Reduce Motion, Bold Text and High Contrast must keep working (see
  `KeyPressMotion`, `labelWeightFor` and `ThemeResolver.resolve`).

## Gotchas

- **Material 3 Expressive and Bauhaus reshape keys by role** (blobs,
  pentagons, triangles). The README tells screens where a button must
  look plain to filter them out. The default feed (`FeedFilter.surpriseMe`) includes every
  enabled family, Bauhaus too. Calsee makes Bauhaus opt-in in its own
  settings.
- In the package's own widget tests, fonts register without the
  `packages/calsee_themes/` prefix, so text falls back. Real renders are
  checked through `example/` (a dependent app).
- This repo has no import checker. In Calsee these rules were enforced by
  `calculator/tool/check_imports.dart`. Here they are kept by review and by
  compiling on 3.35.7.

## Releasing

1. Bump `version` in `pubspec.yaml` (semver; a public API break means a
   major bump) and add a `CHANGELOG.md` entry.
2. Run tests on both toolchains, analyze, the format check, the publish
   dry-run, and pana (160/160).
3. If visuals changed, regenerate the illustrations.
4. Commit, tag `vX.Y.Z`, and push.
5. The owner runs `dart pub publish` from this directory. It needs their
   pub.dev sign-in through Google, so an agent must not try it.

## Git

- Commits use the repo-local email
  `8214632+mishrabhilash@users.noreply.github.com`. That's GitHub's
  no-reply address for mishrabhilash: commits are credited to the account
  and the personal email stays private. Don't change `user.email` here.
- Push as GitHub account `mishrabhilash`. `pathaknikita15` is also logged
  in on the owner's Mac, so check with `gh auth status`.
