## 2.2.0

The all-clear key gets a colour of its own, so users can find it.

- `KeyRole.clear` (AC) now wears its own colours in every family instead
  of the function keys'. It's a warm alert key (red first, then
  vermilion, crimson, amber or rose; Bauhaus uses a spare primary) that
  stays apart from the digit, function, operator and `=` keys, including
  for colour-blind users. It keeps each family's look: a NeoPOP slab
  with its own sides, a Retro cap and skirt, a clay candy with its own
  shadow, a glass tint, a Y2K gel, a Paper & ink stamp, a Cyberpunk neon
  slab. Labels meet 4.5:1, and 7:1 under the Accessible lock.
- `CalcThemeData.clearKey` is the new style, and `keyStyle(KeyRole.clear)`
  returns it. A `CalcThemeData` built without one gives AC the function
  style, as before. The plain theme has a red AC key in all four variants.
- `ThemeSpec.clearKey` gives the colours as `KeyColors`. They're derived
  from the finished theme, so every saved theme and share code gets them,
  and `toJson`, `stableHash` and engine output are unchanged (engine
  version stays 5). `test/engine/fixtures/clear_keys.json` pins them.
- Family renderers take optional AC colours: `NeoPopKeyFace.clearEdges`,
  `RetroKeyFace.clearSkirt`, `ClayKeyFace.clearShadow` and
  `GlassKeyFace.clear`. Without them, AC uses the function key's.
- Bauhaus no longer draws the function accent on AC; its AC block is the
  accent.

If your app puts `KeyRole.clear` on a key that shouldn't stand out, give
it `KeyRole.function`.

## 2.1.0

Every family now follows a `ThemeIntent`'s colours.

- Liquid Glass, Neumorphism, Retro, Neo-brutalism, Y2K Aero, Paper & ink,
  Cyberpunk, Vaporwave and Bauhaus follow colours, brightness and chroma,
  and keep their own look: "red" Cyberpunk is red neon.
- The first colour goes on the operators (Claymorphism: on its body),
  and the rest of the palette turns with it. The second colour sets `=`,
  the third the function keys.
- Claymorphism follows the colour fully, body included.
- A key a colour is named for always shows it, even where the family
  left it white, grey or black, and muted colours stay visible.
- A colour's brightness and chroma lean (navy leans dark) now comes from
  the first colour only. `effectiveBrightness` and `effectiveChroma`
  follow suit; `v4Brightness` and `v4Chroma` keep the 2.0.0 reading.
- `steerableFamilies` lists every family; `familySteerableAt` tells which
  followed colours at an older engine version.
- Engine version 5. Unsteered themes are unchanged, and themes steered
  with 2.0.0 (engine v4) reproduce exactly.

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
