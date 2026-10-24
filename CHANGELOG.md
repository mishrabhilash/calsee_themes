## 2.0.0

Steering: generate themes that match a description.

- `ThemeIntent` describes the look a host wants: colours (26 named, such
  as green, navy or lavender), light or dark, how colourful, colour
  harmony and an optional name. A host builds one from the user's words
  however it likes (an on-device model, mood chips) and passes it to
  `CalseeThemeController(intent: …)`, `CalseeScope(intent: …)`,
  `ThemeFeed.steer` or `ThemeGenerator.generate(intent: …)`. The package
  never sees the words.
- Steered themes are endless variations on the intent, and the first one
  sits at its centre. Every contrast guardrail still runs.
- Material 3 Expressive, NeoPOP and Claymorphism honour steering
  (`steerableFamilies`). Other families take only the name. Use
  `ThemeIntent.reportFor(family)` to see which hints a family can't
  follow.
- For model output: `ThemeIntent.parse` reads loose JSON and never throws.
  `ThemeIntent.vocabulary` gives every field and value with a one-line
  description, and `ThemeIntent.jsonSchema()` and
  `ThemeIntent.promptFragment()` are generated from it.
- Engine version 4. Unsteered themes are the same as version 3 apart
  from the version number, and versions 1 to 3 still reproduce exactly.
- Steered themes have a longer, 25-symbol share code that carries the
  intent. `shareCodeStatus` tells an invalid code apart from one made by
  a newer app. Links can carry a theme name (`?name=`). Builds before
  2.0.0 reject steered codes as invalid.
- `FeedEntry.shareCode` and `FeedEntry.fromSharePayload` turn feed
  entries into share codes and back.

**Breaking:** `ThemeVariant` has a new value, `steered`. A `switch` over
`ThemeVariant` without a default needs a `case ThemeVariant.steered`.

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
