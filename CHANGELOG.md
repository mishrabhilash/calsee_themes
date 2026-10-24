## 2.0.0

Steering: generate themes that match a description.

### Breaking

- `ThemeVariant` has a new value, `steered`. Add it to exhaustive
  switches. A steered spec rebuilds like a generated one:

  ```dart
  case ThemeVariant.generated || ThemeVariant.steered:
    return FeedEntry.ofSpec(spec).resolve(accessible: accessible);
  ```

### New

- `ThemeIntent`: colours (26 named), light or dark, chroma, harmony and
  a name. Pass it to `CalseeThemeController(intent:)`,
  `CalseeScope(intent:)`, `ThemeFeed.steer` or
  `ThemeGenerator.generate(intent:)`. The feed shows endless variations,
  starting at the intent's centre, and every guardrail still runs.
- Material 3 Expressive, NeoPOP and Claymorphism honour steering
  (`steerableFamilies`); other families take only the name.
  `intent.reportFor(family)` lists what a family can't follow.
- For on-device models: `ThemeIntent.parse` (lenient, never throws),
  `ThemeIntent.vocabulary`, `ThemeIntent.jsonSchema()` and
  `ThemeIntent.promptFragment()`.
- Steered themes share as 25-symbol codes. Use `entry.shareCode` and
  `FeedEntry.fromSharePayload` instead of encoding codes by hand;
  `shareCodeStatus` tells an invalid code from one made by a newer app.
- Includes the 1.1.1 Vaporwave font fix.

### Compatibility

- New themes use engine version 4. Unsteered themes look the same as in
  1.x, and saved or shared 1.x themes reproduce exactly.
- Apps on 1.x can't open share codes or saved feeds made by 2.0.0: they
  report an unsupported engine version or an invalid code, never a
  different theme.
- `decodeShareCode` also accepts 25-symbol codes (29 characters with
  hyphens).

## 1.1.1

- Vaporwave's π and its maths operator glyphs (+ − × ÷ = ±) now draw in
  the bundled Roboto Flex as intended. Its fallback font list named
  Roboto Flex without the package prefix, so every app drew them in the
  platform font. A test now checks that every font name the package uses
  carries the prefix.

## 1.1.0

- Form controls drawn by the theme: `CalseeCheckbox`, `CalseeRadio`,
  `CalseeSwitch`, `CalseeSegmented`, `CalseeSlider`, `CalseeDropdown`,
  `CalseeExpandable` and `CalseeTextField`. Selected states wear the
  accent face, unselected ones the plain face, and their marks use the
  face's label colour (≥ 4.5:1). They have screen-reader semantics and
  follow Reduce Motion and Bold Text.
- `CalseeScope` prepares the next themes between changes (key art, shape
  morphs and transitions for the key sizes on screen), so the frame that
  shows a new theme no longer builds them. On the web, a theme change on
  a busy screen went from up to 119 ms of build work to under 35 ms.
- `CalseeKey.icon` with a `label` no longer overflows its key on faces
  that leave less room for content (some Material 3 Expressive shapes);
  the icon and label shrink to fit, as text labels do.
- The example app is now a kids' maths game, and the README images,
  pub.dev screenshots, guide and live gallery show it.

## 1.0.0

First public release.

- An endless, seeded feed of generated themes in twelve families:
  Claymorphism, Liquid Glass, NeoPOP, Retro, Cyberpunk, Paper & Ink,
  Neumorphism, Y2K Aero, Vaporwave, Neo-brutalism, Material 3 Expressive
  and Bauhaus. Themes are bit-exact: a seed shows the same theme on every
  device.
- Drop-in widgets: `CalseeScope`, `CalseeKey`, `CalseeSurface`,
  `CalseeBackdrop`, `CalseeDisplayPanel`, `CalseeReadout` and
  `CalseeSwipeArea`.
- Contrast guardrails on every theme, an accessible mode with stricter
  contrast, and support for High Contrast, Reduce Motion and Bold Text.
- Bundled OFL fonts: apps declare none.
- Supports Flutter 3.35 and newer.
