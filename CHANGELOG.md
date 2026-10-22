## Unreleased

New widgets, so the next release is 1.1.0.

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
