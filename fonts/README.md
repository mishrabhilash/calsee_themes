# Bundled fonts

All fonts are licensed under the SIL Open Font License 1.1 (see each
family's `OFL.txt`). Downloaded on 2026-10-03 from the official Google Fonts
repository (https://github.com/google/fonts, branch `main`) and renamed
(the axis list is dropped from the filename). Roboto Flex and Space Grotesk
are unmodified; Noto Sans Devanagari (added 2026-10-04, M5) is subset, see
below.

| Family (pubspec) | File | Source | SHA-256 | Size |
|---|---|---|---|---|
| `RobotoFlex` | `roboto_flex/RobotoFlex.ttf` | https://raw.githubusercontent.com/google/fonts/main/ofl/robotoflex/RobotoFlex%5BGRAD,XOPQ,XTRA,YOPQ,YTAS,YTDE,YTFI,YTLC,YTUC,opsz,slnt,wdth,wght%5D.ttf | `9b523f7d82593df0107173849ebb8c817471a1df4b4fb2c3cbf40cfd810c8281` | 1,787,292 B |
| | `roboto_flex/OFL.txt` | https://raw.githubusercontent.com/google/fonts/main/ofl/robotoflex/OFL.txt | | |
| `SpaceGrotesk` | `space_grotesk/SpaceGrotesk.ttf` | https://raw.githubusercontent.com/google/fonts/main/ofl/spacegrotesk/SpaceGrotesk%5Bwght%5D.ttf | `acad6de1fc93436f5c0f1f4137751ef04f1aea3063e7036535970ffcfbd79f72` | 136,676 B |
| | `space_grotesk/OFL.txt` | https://raw.githubusercontent.com/google/fonts/main/ofl/spacegrotesk/OFL.txt | | |
| `NotoSansDevanagari` | `NotoSansDevanagari/NotoSansDevanagari.ttf` (subset) | https://raw.githubusercontent.com/google/fonts/main/ofl/notosansdevanagari/NotoSansDevanagari%5Bwdth,wght%5D.ttf (source: 641,944 B, SHA-256 `14ec4af41f27482216d1c2229f417ff9b1425e1babb014e57d1d40d03229853e`) | `d7a1cdc7ef68aae15611a25ff3947c8d8a99a4ce5c599ff92d640b4f2224e1e7` | 323,204 B |
| | `NotoSansDevanagari/OFL.txt` | https://raw.githubusercontent.com/google/fonts/main/ofl/notosansdevanagari/OFL.txt | `a216f6f8d85c7228093e0ee5e258d9d377e6671f68acb4db1930b29583d0f331` | |

Total ≈ 2.25 MB.

## Use

- **Roboto Flex** (Copyright 2017 The Roboto Flex Project Authors): Material
  3 Expressive display and keys, and the settings/history UI. It is variable
  in `opsz` 8–144, `wght` 100–1000, `GRAD` −200–150, `wdth` 25–151 (and
  `slnt` plus parametric axes, not used). Figures are tabular by default; the
  font has `pnum` but no `tnum`. It is reused for settings and history, so no
  third UI family is bundled.
- **Space Grotesk** (Copyright 2020 The Space Grotesk Project Authors): the
  NeoPOP chunky grotesque. It is variable in `wght` 300–700. Its default
  instance is Light 300, so styles always set `wght` explicitly. It has
  `tnum`, slashed `zero` and `ss01`–`ss05`.
  - Why not Archivo Black? It is a single static weight, so it can't do the
    seeded weight variation or a lighter display weight, and it has no
    `tnum` feature.
  - Why not Familjen Grotesk? It is also variable with `tnum`/`zero`, but
    it reads as a softer editorial grotesque, not the geometric, techy chunk
    of NeoPOP. Space Grotesk's wide, squarish figures suit the extruded keys.

- **Noto Sans Devanagari** (Copyright 2022 The Noto Project Authors,
  https://github.com/notofonts/devanagari): the Devanagari fallback for
  Hindi amount words. It is never a theme font; every display, amount,
  history and settings style lists it in `fontFamilyFallback`
  (`scriptFallbackFonts` in `lib/themes/render/fonts.dart`, and
  `ThemeData.fontFamilyFallback` for the Material chrome), so Hindi takes
  the surrounding text's size and `wght` instead of the platform's lighter
  Devanagari face. Upstream it is variable in `wdth` 62.5–100 and `wght`
  100–900. To keep it small (642 KB → 323 KB) it was reduced with
  fontTools 4.60.1:

  ```sh
  fonttools varLib.instancer 'NotoSansDevanagari[wdth,wght].ttf' wdth=100 -o wght_only.ttf
  pyftsubset wght_only.ttf --layout-features='*' \
    --unicodes='U+0900-097F,U+1CD0-1CFF,U+A8E0-A8FF,U+200C-200D,U+25CC' \
    --output-file=NotoSansDevanagari.ttf
  ```

  That pins the width axis at its default (100) and keeps only Devanagari,
  Devanagari Extended, Vedic Extensions, ZWNJ/ZWJ and the dotted circle,
  with every OpenType layout feature (conjuncts, nukta, matras). Latin,
  digits and punctuation come from the theme font. The `wght` axis stays
  variable (100–900).

## Theme family fonts (added 2026-10-11)

Six more OFL 1.1 families for the Claymorphism, Y2K / Frutiger Aero,
Paper & ink, Cyberpunk, Vaporwave and Bauhaus theme families. Downloaded on
2026-10-11 from https://github.com/google/fonts (branch `main`,
`https://raw.githubusercontent.com/google/fonts/main/ofl/<dir>/<file>`,
with `[` `]` encoded as `%5B` `%5D`). None of the six licences declares a
Reserved Font Name, so the reduced files keep their names.

| Family (pubspec) | File | Source file | Source SHA-256 | Source size | Bundled SHA-256 | Bundled size |
|---|---|---|---|---|---|---|
| `Nunito` | `nunito/Nunito.ttf` | `ofl/nunito/Nunito[wght].ttf` | `bb55a5ca5c2042335b3991af27c4d0705d0ef41cac6164ac737fd8f2a1e85207` | 276,932 B | `5070739e9576cb6dee9e537659bdfa4bef1e2e59286acca2e14b6b2b78e4dbf4` | 81,928 B |
| `OpenSans` | `open_sans/OpenSans.ttf` | `ofl/opensans/OpenSans[wdth,wght].ttf` | `36643644f318a812aab2d2ed3bb98f8cf0872527f835fe9398d95fe6b9adb878` | 532,636 B | `55f0266700788f70d7c1c49b96daf334e04d02f5520588178665a18cdeb48041` | 87,112 B |
| `Newsreader` | `newsreader/Newsreader.ttf` | `ofl/newsreader/Newsreader[opsz,wght].ttf` | `8a08d13f8a6c0d51be379a60af84f945f65369a67e509ee3c3bdcc421254d7c1` | 451,664 B | `e5c9ac85e5d35e56769837535026f7802b749f474e87e95bc94a06def14cb4ea` | 230,572 B |
| `Oxanium` | `oxanium/Oxanium.ttf` | `ofl/oxanium/Oxanium[wght].ttf` | `2ce01d946e1e1ffc8d7eecfffbda8623bedd63eaf811a20488c4b69af45babb0` | 43,536 B | `75d800b22f50e5ac69338a03aec6179831aa4d80b218e0942339b31d8d5c6950` | 28,296 B |
| `Anybody` | `anybody/Anybody.ttf` | `ofl/anybody/Anybody[wdth,wght].ttf` | `b184bd7e6ca8348bbaecec98951565729d7e89b7872d4898a1f9981342b5b64c` | 201,352 B | `50682343dc0f13713b4616abc8269950102f81e263fdde30f9dd27638d668bcb` | 97,972 B |
| `Jost` | `jost/Jost.ttf` | `ofl/jost/Jost[wght].ttf` | `6343b70971000b04c5d401c96ae08ce371086135e999d5e1e1413039c0213076` | 134,996 B | `a1a74a012f7a14968d6910e43692319ba962a05c393ae206aaff0dafd7144b16` | 59,628 B |

Total ≈ 586 KB. Each `OFL.txt` is the upstream file from the same
directory.

Built with fontTools 4.66.1 (`SOURCE_DATE_EPOCH=1791676800` for
reproducible timestamps):

```sh
UNI='U+0020-007E,U+00A0-00FF,U+2212,U+00D7,U+00F7,U+00B1,U+20B9,U+2030,U+2248,U+2026,U+03C0,U+221A,U+221B,U+02B8,U+02E3,U+2093,U+207A,U+207B,U+207F,U+2070,U+2074-2079,U+202F,U+2060,U+2009,U+200A,U+2010-2014,U+2018-201D,U+20AC,U+221E,U+2044'
# Open Sans: pin the width axis at its default first (wght 300–800 stays).
fonttools varLib.instancer 'OpenSans[wdth,wght].ttf' wdth=100 -o OpenSans-wght.ttf
# Every font: Basic Latin, Latin-1 and the calculator symbols, all layout
# features kept (Nunito, Newsreader, Oxanium, Anybody and Jost keep every
# axis).
pyftsubset <in>.ttf --layout-features='*' --notdef-outline --unicodes="$UNI" --output-file=<name>.sub.ttf
# Metrics only (no glyph changes): centre the figures in a 1.2 em line box.
python center_figures.py <name>.sub.ttf <name>.ttf
```

`center_figures.py` sets the hhea and OS/2 typo ascender to
`(1.2·upm + h8) / 2`, the descender to `−(1.2·upm − h8) / 2` and the line
gap to 0, where `h8` is the top of the `8` glyph. Digits then sit centred in
key labels and in the display's line box (Newsreader's sat 0.1 em high
before):

```python
import sys
from fontTools.ttLib import TTFont
src, dst = sys.argv[1], sys.argv[2]
f = TTFont(src, recalcTimestamp=False)
upm = f['head'].unitsPerEm
fig = f['glyf'][f.getBestCmap()[ord('8')]].yMax
asc, dsc = round((1.2 * upm + fig) / 2), -round((1.2 * upm - fig) / 2)
f['hhea'].ascent, f['hhea'].descent, f['hhea'].lineGap = asc, dsc, 0
o = f['OS/2']; o.sTypoAscender, o.sTypoDescender, o.sTypoLineGap = asc, dsc, 0
f.save(dst)
```

| Font | Axes | Figures | Use |
|---|---|---|---|
| Nunito | `wght` 200–1000 (default 200) | tabular by default | Claymorphism: rounded, puffy heavy weights |
| Open Sans | `wght` 300–800 | tabular by default, `tnum`, `zero` | Y2K / Frutiger Aero: humanist, a sibling of Segoe UI |
| Newsreader | `wght` 200–800, `opsz` 6–72 | tabular by default | Paper & ink: editorial serif; `opsz` follows the font size |
| Oxanium | `wght` 200–800 (default 200) | tabular by default, `zero` | Cyberpunk: squared techno |
| Anybody | `wdth` 50–150, `wght` 100–900 (default 100) | `tnum`, `zero` | Vaporwave: extended 90s grotesque |
| Jost | `wght` 100–900 | `tnum` | Bauhaus: Futura-model geometric |

None of the six has `∛` or U+202F, and Newsreader and Anybody also lack `π`
and `√`; missing glyphs fall back to the platform font.

Weights, widths, grade and optical size go through `FontVariation` helpers
in `lib/themes/render/fonts.dart` (`BundledFont.style` / `.variations`).
Tests load these files with `test/helpers/load_fonts.dart`.

## Chrome font (added 2026-10-13)

**Patrick Hand** (Copyright 2010-2012 Patrick Wagesreiter): Paper & ink's
handwritten screen and dialog titles in settings, history and dialogs
(`ChromeStyle.handFont`, lib/themes/chrome_style.dart). Never used for
numbers or by the theme generator: it is a static Regular with proportional
figures. Downloaded on 2026-10-13 from
`https://raw.githubusercontent.com/google/fonts/main/ofl/patrickhand/PatrickHand-Regular.ttf`
(`OFL.txt` from the same directory) and subset with the same `pyftsubset`
command and Unicode set as the theme family fonts above (fontTools 4.66.1,
same `SOURCE_DATE_EPOCH`; the unsupported `FFTM` table is dropped). No
figure centring.

| Family (pubspec) | File | Source SHA-256 | Source size | Bundled SHA-256 | Bundled size |
|---|---|---|---|---|---|
| `PatrickHand` | `patrick_hand/PatrickHand.ttf` | `0f173b3e6cb6d1af25babf7f0057c5ac4ee11f9992b0469bb817e967ef4ad0fc` | 214,772 B | `f1ce3bacd3a11abfa75ecc656df82d677240b44b6c7e53d7b61617b6916ba95c` | 76,364 B |
| | `patrick_hand/OFL.txt` | `377f4f9c19e935228552478eb68cc2ed82910988a60ba60e2ac73b09f32d02d1` | | | |

## Symbols fallback: CalseeSymbols (added 2026-10-16, M7)

**Calsee Symbols** (`CalseeSymbols`, m7-design D14 and §6) holds the
scientific key glyphs that no theme font has (ʸ ˣ ⁻ ₓ ∛ everywhere; √ in
Roboto Flex, Newsreader and Anybody; π in Newsreader and Anybody) and the
currency signs the converter needs. It is never a theme font: every text
style lists it in `fontFamilyFallback` after Noto Sans Devanagari
(`scriptFallbackFonts`), and key labels draw their super- and subscript
runs in it (`KeyLabel`, `symbolRunStyle`), so `sin⁻¹` never mixes a
fallback ⁻ with the family's own ¹. It is variable in `wght` 100–900, so a
fallback glyph takes the label's weight.

It is built by `tool/build_calsee_symbols.py` (fontTools 4.67.0; it
downloads the sources, checks their SHA-256, checks the result's cmap and
writes a byte-identical file on every run) from google/fonts at commit
`1d0e46c7933245c8180fe83e47917961c913bbdb`, each source pinned at `wdth`
100:

| Source (`ofl/…`) | SHA-256 | Size | Used for |
|---|---|---|---|
| `notosans/NotoSans[wdth,wght].ttf` | `bfb7bb691513f12e734dc346c03a03f784912432d7e3fa8e56efcf906fe86b3d` | 2,049,096 B | ¹ ² ³, U+2070–209F (super- and subscripts), ʸ ˣ, π µ μ, U+20A0–20C0 (₹ ₨ ₩ ₽ ₺ ₫ ₦ ₱ ₪ …) |
| `notosansmono/NotoSansMono[wdth,wght].ttf` | `2cb2adb378a8f574213e23df697050b83c54c27df465a2015552740b2769a081` | 1,708,408 B | √ ∞ (Noto Sans has neither) |
| `notosansthai/NotoSansThai[wdth,wght].ttf` | `5a1c559bb539583c8a1fd99d1c5b9491e5e14478c9cd2bd0970d5c3096cc9ef8` | 218,652 B | ฿ |
| `notosansmath/NotoSansMath-Regular.ttf` | `3f495fe933c06786e4d5f6d86b8ee70b6753a68ee3b9d87528726de0f6e2c47d` | 1,015,396 B | measured only: where its ∛ puts the index |

∛ is a composite of the √ above and Noto Sans's ³ (× 0.649), placed
against the radical's short stroke as Noto Sans Math places its index, so
it follows `wght` with √ (Noto Sans Math is a static Regular). Advance
deltas are rebuilt from the glyph deltas (`HVAR`); `MVAR` is dropped.
Vertical metrics follow `center_figures.py` above, with h8 = 724 (Noto
Sans's `8`): ascender 962, descender −238, line gap 0. The name table says
"Calsee Symbols"; the notices of the sources are kept.

| Family (pubspec) | File | SHA-256 | Size |
|---|---|---|---|
| `CalseeSymbols` | `calsee_symbols/CalseeSymbols.ttf` | `a2efc3b0d39e18749e1d79213277d7b987d10596818edb8e45aa79d321679632` | 27,584 B (87 code points) |
| | `calsee_symbols/OFL.txt` | `d3e31d15a1cb4c262b482b58995ef129dd32c3899c3a82e657d88701ef2638e9` | Noto Sans's OFL text with the Noto Sans and Noto Sans Thai notices |

Every app that uses `calsee_themes` must bundle it under the same family
name (Game Night too).

## Licence obligations (OFL 1.1)

Each font ships with its `OFL.txt` in the source tree. Roboto Flex and
Space Grotesk are unmodified. A font whose licence declares a Reserved Font
Name must be renamed if it is ever subset or modified. Noto Sans
Devanagari, Nunito, Open Sans, Newsreader, Oxanium, Anybody, Jost and
Patrick Hand declare none, so their reduced files keep their names. The
Noto sources of Calsee Symbols declare none either; it is renamed only
because it combines several fonts. The app's licence
page lists every bundled font (`AppInfo.fontLicences`, registered with
`LicenseRegistry`).
