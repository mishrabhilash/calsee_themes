# calsee_themes example

A kids' maths game themed by `calsee_themes`. Swipe the sum for a new
theme; the number pad and the OK button keep working the same in every
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
