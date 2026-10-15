/// Golden inputs shared by the fixture test (VM) and the hash pins (every
/// platform, including dart2js / dart2wasm).
library;

import 'package:calsee_themes/engine/theme_spec.dart';

typedef GoldenCase = ({int seed, ThemeFamily family, bool accessible});

const List<GoldenCase> goldenCases = [
  (seed: 0, family: ThemeFamily.m3Expressive, accessible: false),
  (seed: 1, family: ThemeFamily.m3Expressive, accessible: false),
  (seed: 0xDEADBEEF, family: ThemeFamily.m3Expressive, accessible: false),
  (seed: 12345, family: ThemeFamily.m3Expressive, accessible: true),
  (seed: 0xFFFFFFFF, family: ThemeFamily.m3Expressive, accessible: false),
  (seed: 0, family: ThemeFamily.neoPop, accessible: false),
  (seed: 7, family: ThemeFamily.neoPop, accessible: false),
  (seed: 0xDEADBEEF, family: ThemeFamily.neoPop, accessible: false),
  (seed: 424242, family: ThemeFamily.neoPop, accessible: true),
  (seed: 0x80000000, family: ThemeFamily.neoPop, accessible: false),
];
