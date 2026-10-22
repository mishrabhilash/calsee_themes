# calsee_themes example

A payment keypad themed by `calsee_themes`. Swipe the amount for a new
theme; the keypad and the Pay button keep working the same in every
theme.

```bash
flutter run
```

`screenshots/` regenerates the illustrations in the package's `doc/`
folder:

```bash
flutter test screenshots/screenshots_test.dart --update-goldens
python3 screenshots/compose.py
```
