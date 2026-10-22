# Drawing themed UI

How to build a screen from `calsee_themes`, one element at a time. Every
section has a short snippet, a live example you can play with, and the
example's full source.

**[Open the live gallery](https://mishrabhilash.github.io/calsee_themes/)**.
It runs every example below in your browser. Press **Next** at the top to
see each element in every family.

All snippets use one import:

```dart
import 'package:calsee_themes/calsee_themes.dart';
```

- [Theme feed](#theme-feed): `CalseeScope`, `CalseeThemeController`
- [Backdrop and text](#backdrop-and-text): `CalseeBackdrop`, `CalseeTextColors`
- [Keys](#keys): `CalseeKey.text`, `KeyRole`
- [Icon keys](#icon-keys): `CalseeKey.icon`
- [Custom key content](#custom-key-content): `CalseeKey`, `CalseeKeyLabel`
- [Display and readout](#display-and-readout): `CalseeDisplayPanel`, `CalseeReadout`
- [Surfaces](#surfaces): `CalseeSurface`, `calseeFaceInset`
- [Form controls](#form-controls): `CalseeCheckbox`, `CalseeRadio`,
  `CalseeSwitch`, `CalseeSegmented`, `CalseeSlider`, `CalseeDropdown`,
  `CalseeExpandable`, `CalseeTextField`
- [Swipe for a theme](#swipe-for-a-theme): `CalseeSwipeArea`
- [Your own widgets](#your-own-widgets): `CalcTheme.of`, `calseeDisplayStyle`
- [Share codes](#share-codes): `encodeShareCode`, `themeOfTheDay`
- [A whole screen](#a-whole-screen)

## Theme feed

`CalseeScope` themes everything below it, and nothing outside it, so you
can theme one screen of an existing app. Its controller is an endless,
seeded feed: `next()` makes a new theme, `previous()` returns to the exact
previous one.

```dart
final themes = CalseeThemeController(
  families: const [ThemeFamily.claymorphism, ThemeFamily.liquidGlass],
);

CalseeScope(
  controller: themes,
  onChanged: (state) => prefs.setString('theme', jsonEncode(state)),
  child: const PayScreen(),
);

themes.next();
themes.previous();
themes.accessible = true; // only themes with stricter contrast
themes.spec.name;         // e.g. "Tide Gumdrop"
```

Without a `controller`, the scope makes its own from `families`, `seed` and
`savedState`. Read it anywhere below with `CalseeScope.of(context)`.

The gallery runs on exactly this: one `CalseeThemeController` above every
page, and its **‹** and **Next theme ›** buttons call `previous()` and
`next()`.

[▶ Try it](https://mishrabhilash.github.io/calsee_themes/) ·
[Source](../example/lib/gallery/app.dart)

## Backdrop and text

`CalseeBackdrop` paints the theme's background and its family's ambient
artwork: Liquid Glass blobs, Cyberpunk scanlines, Vaporwave sunsets. Put
it behind the whole screen. `CalseeTextColors` gives text colours that stay
readable on it.

```dart
CalseeBackdrop(
  child: Builder(
    builder: (context) {
      final colors = CalseeTextColors.of(context);
      return Column(
        children: [
          Text('Good evening', style: TextStyle(color: colors.primary)),
          Text('Captions', style: TextStyle(color: colors.secondary)),
        ],
      );
    },
  ),
);
```

`CalseeTextColors.of` needs a context below the backdrop, hence the
`Builder`. Text with no colour of its own takes the backdrop's.

[▶ Try it](https://mishrabhilash.github.io/calsee_themes/#/backdrop) ·
[Source](../example/lib/gallery/examples/backdrop_example.dart)

## Keys

`CalseeKey.text` is a button drawn by the theme's key renderer, with the
family's spring press: Claymorphism squishes, NeoPOP extrudes, Liquid Glass
inflates. A key fills its box, so size it with `SizedBox`, `Expanded` or a
grid.

```dart
SizedBox(
  height: 64,
  child: CalseeKey.text('Pay', role: KeyRole.equals, onPressed: pay),
);
```

The `role` picks which of the theme's faces the key wears:

| Role | Use it for |
|---|---|
| `KeyRole.equals` | The one primary action (Pay, Send). It wears the theme's accent. |
| `KeyRole.operator` | Secondary actions. |
| `KeyRole.function` | Tertiary actions and toggles. |
| `KeyRole.digit` | Everything else. |
| `decimal`, `clear`, `backspace`, `sign`, `percent`, `constant`, `paren`, `memory`, `mode` | Calculator keys. They take the colours of `digit` (`decimal`, `sign`) or `function` (the rest). Material 3 Expressive and Bauhaus also give some roles their own shapes. |

- No `onPressed` and no `onLongPress`: the key is disabled and dimmed.
- With `onLongPress`, a hold fills the face, then fires.
- `sizeFactor` sets the label size as a fraction of the key's shorter side.

[▶ Try it](https://mishrabhilash.github.io/calsee_themes/#/keys) ·
[Source](../example/lib/gallery/examples/keys_example.dart)

## Icon keys

`CalseeKey.icon` draws an icon in the key's label colour, with an optional
label under it. Icon-only keys need a `semanticLabel` for screen readers.

```dart
CalseeKey.icon(
  sendIcon,
  role: KeyRole.equals,
  semanticLabel: 'Send money',
  label: 'Send',
  onPressed: send,
);
```

Any `IconData` works. The examples use Material Icons, which needs
`uses-material-design: true` in your app's pubspec.

[▶ Try it](https://mishrabhilash.github.io/calsee_themes/#/icon-keys) ·
[Source](../example/lib/gallery/examples/icon_keys_example.dart)

## Custom key content

The plain `CalseeKey` constructor takes a builder, so a themed key can hold
any widget. The builder gets the face's `KeyStyle` (label colour and
weight) and the key's shorter side, for sizing. `CalseeKeyLabel` draws text
in the theme's key font.

```dart
CalseeKey(
  role: KeyRole.digit,
  semanticLabel: '15 percent tip',
  onPressed: () => setTip(15),
  builder: (context, style, shortSide) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      CalseeKeyLabel('15%', style: style, size: shortSide * 0.32),
      Text('₹187', style: TextStyle(color: style.label)),
    ],
  ),
);
```

[▶ Try it](https://mishrabhilash.github.io/calsee_themes/#/custom-keys) ·
[Source](../example/lib/gallery/examples/custom_key_example.dart)

## Display and readout

`CalseeDisplayPanel` draws the family's display: Retro's LCD, Clay's inset
well, Y2K's glass. Families without a display draw nothing. `CalseeReadout`
is one line in the theme's display font that shrinks to fit. Use them for
an amount, a score or a timer.

```dart
CalseeDisplayPanel(
  child: CalseeReadout('₹1,250', size: 64),
);
```

Inside the panel, `CalseeTextColors.of(context)` switches to colours solved
against the panel, so captions under the readout stay readable.

[▶ Try it](https://mishrabhilash.github.io/calsee_themes/#/display) ·
[Source](../example/lib/gallery/examples/display_example.dart)

## Surfaces

`CalseeSurface` wears a key face at rest, with no press motion: cards,
tiles and badges that aren't buttons. `calseeFaceInset` keeps content clear
of the face's rounded corners.

```dart
CalseeSurface(
  role: KeyRole.digit,
  builder: (context, style, shortSide) => Padding(
    padding: calseeFaceInset(context, shortSide),
    child: Text('Alex Morgan', style: TextStyle(color: style.label)),
  ),
);
```

[▶ Try it](https://mishrabhilash.github.io/calsee_themes/#/surfaces) ·
[Source](../example/lib/gallery/examples/surface_example.dart)

## Form controls

Checkboxes, radios, switches, segmented buttons, sliders, dropdowns,
expandable sections and text fields, drawn by the theme. They follow one
rule, so they stay readable in every family: a selected control wears the
theme's accent face (the `equals` key's), an unselected one the plain face
(the `digit` key's), and every mark on it (tick, dot, thumb, chevron) is
drawn in that face's own label colour, which the guardrails keep at 4.5:1
or more against the face. The marks are painted, so your app needs no icon
font. Pass `null` as `onChanged` to disable a control; it dims.

Each control has screen-reader semantics (checked, toggled, selected, a
slider's value) and follows Reduce Motion and Bold Text.

### Checkboxes and radios

```dart
CalseeCheckbox(
  value: saveCard,
  label: 'Save this card',
  onChanged: (value) => setState(() => saveCard = value),
);

CalseeRadio<Method>(
  value: Method.upi,
  groupValue: method,
  label: 'UPI',
  onChanged: (value) => setState(() => method = value),
);
```

Tapping the label toggles or chooses too. `size` sets the box's side.

[▶ Try it](https://mishrabhilash.github.io/calsee_themes/#/checkbox-radio) ·
[Source](../example/lib/gallery/examples/checkbox_radio_example.dart)

### Switches

```dart
CalseeSwitch(
  value: alerts,
  label: 'Payment alerts',
  onChanged: (value) => setState(() => alerts = value),
);
```

[▶ Try it](https://mishrabhilash.github.io/calsee_themes/#/switch) ·
[Source](../example/lib/gallery/examples/switch_example.dart)

### Segmented buttons and sliders

```dart
CalseeSegmented<int>(
  options: const [(2, '2'), (3, '3'), (4, '4')],
  selected: people,
  onChanged: (value) => setState(() => people = value),
);

CalseeSlider(
  value: tip,
  max: 25,
  divisions: 5, // snaps to 0, 5, 10, 15, 20, 25
  semanticLabel: 'Tip',
  onChanged: (value) => setState(() => tip = value),
);
```

Each segment is a key, with the family's press. The slider fills its
width; drag it or tap along it.

[▶ Try it](https://mishrabhilash.github.io/calsee_themes/#/segmented-slider) ·
[Source](../example/lib/gallery/examples/segmented_slider_example.dart)

### Dropdowns and expandable sections

```dart
CalseeDropdown<String>(
  items: const [('savings', 'Savings ••4821'), ('salary', 'Salary ••1290')],
  value: account,
  hint: 'Choose an account',
  onChanged: (value) => setState(() => account = value),
);

CalseeExpandable(
  title: 'Fees and limits',
  child: Text('No fee for UPI payments.'),
);
```

The dropdown's list opens in the app's `Overlay` (`WidgetsApp` and
`MaterialApp` provide one) with the theme of where the dropdown sits, and
closes on a choice or a tap outside.

[▶ Try it](https://mishrabhilash.github.io/calsee_themes/#/dropdown-expandable) ·
[Source](../example/lib/gallery/examples/dropdown_expandable_example.dart)

### Text fields

```dart
CalseeTextField(
  hint: 'Name or UPI ID',
  onChanged: (value) => setState(() => payee = value),
);
```

The text is in the theme's key font and the face's label colour, and the
theme's focus ring shows while the field has focus. It takes the usual
`EditableText` options: `controller`, `focusNode`, `keyboardType`,
`textInputAction`, `obscureText` and `inputFormatters`.

[▶ Try it](https://mishrabhilash.github.io/calsee_themes/#/text-field) ·
[Source](../example/lib/gallery/examples/text_field_example.dart)

## Swipe for a theme

`CalseeSwipeArea` changes the theme when the user swipes across it: left
for the next theme, right for the exact previous one. Taps and vertical
scrolls pass through to the child.

```dart
CalseeSwipeArea(
  child: CalseeDisplayPanel(child: CalseeReadout(amount, size: 64)),
);
```

[▶ Try it](https://mishrabhilash.github.io/calsee_themes/#/swipe) ·
[Source](../example/lib/gallery/examples/swipe_example.dart)

## Your own widgets

For anything the drop-in widgets don't cover, read the theme directly.
`CalcTheme.of(context)` returns the colours, fonts, key styles and springs
behind every widget above. Widgets that read it rebuild when the theme
changes and morph with it. `calseeDisplayStyle` gives the display font,
tabular figures and the family's text treatment.

```dart
final theme = CalcTheme.of(context);

CustomPaint(
  painter: RingPainter(
    track: theme.digitKey.fill,
    fill: theme.equalsKey.fill,
  ),
  child: Text('60%', style: calseeDisplayStyle(context, 40)),
);
```

Useful fields: `background`, `displayText`, `digitKey`, `operatorKey`,
`functionKey` and `equalsKey` (each with `fill` and `label`),
`keyFontFamily`, `displayFontFamily` and `keyCornerFraction`.

[▶ Try it](https://mishrabhilash.github.io/calsee_themes/#/theme-data) ·
[Source](../example/lib/gallery/examples/theme_data_example.dart)

## Share codes

Every theme can be written as a short code (`XXXXX-XXXXX`) that shows the
exact same theme on any device. `themeOfTheDay` gives every user the same
theme on a given date. Show either with `jumpTo`. `previous()` then
returns to where the user was.

```dart
final themes = CalseeScope.of(context);
final entry = themes.entry;
final code = encodeShareCode(
  entry.family!.id,
  entry.engineVersion,
  entry.seed!,
);

themes.jumpTo(themeOfTheDay(DateTime.now()));
```

Hand-crafted hero themes have no family or seed: encode them with
`shareFamilyHero` and `entry.heroId`. The example shows both, and how to
turn a code back into a `FeedEntry` with `decodeShareCode`.

[▶ Try it](https://mishrabhilash.github.io/calsee_themes/#/share) ·
[Source](../example/lib/gallery/examples/share_example.dart)

## A whole screen

The [example app](../example/lib/main.dart) puts it all together: a
payment keypad with a themed amount, keypad and Pay button. The payment
logic is ordinary app code that knows nothing about themes.

[▶ Try it](https://mishrabhilash.github.io/calsee_themes/#/payment) ·
[Source](../example/lib/main.dart)

## Running the gallery locally

From `example/`:

```sh
flutter run -d chrome -t lib/gallery.dart
```

It runs on Android, iOS and desktop too. The examples are plain widgets
under `example/lib/gallery/examples/`, so you can copy one into your app.
