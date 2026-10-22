// Share codes and the theme of the day.
//
// Every theme can be written as a short code (XXXXX-XXXXX) that shows the
// exact same theme on any device. themeOfTheDay gives every user the same
// theme on a given date. Show either with CalseeThemeController.jumpTo.
import 'package:calsee_themes/calsee_themes.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

class ShareExample extends StatefulWidget {
  const ShareExample({super.key});

  @override
  State<ShareExample> createState() => _ShareExampleState();
}

class _ShareExampleState extends State<ShareExample> {
  String? _copied;

  /// The share code of [entry].
  static String codeOf(FeedEntry entry) => entry.heroId != null
      ? encodeShareCode(shareFamilyHero, entry.engineVersion, entry.heroId!)
      : encodeShareCode(entry.family!.id, entry.engineVersion, entry.seed!);

  /// The theme a share code stands for; null for a mistyped code.
  static FeedEntry? entryOf(String code) {
    final payload = decodeShareCode(code);
    if (payload == null) return null;
    final family = ThemeFamily.fromId(payload.familyId);
    if (payload.familyId == shareFamilyHero) {
      return FeedEntry.hero(payload.seed);
    }
    if (family == null) return null;
    return FeedEntry.generated(
      seed: payload.seed,
      family: family,
      engineVersion: payload.engineVersion,
    );
  }

  @override
  Widget build(BuildContext context) {
    final themes = CalseeScope.of(context);
    final code = codeOf(themes.entry);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          CalseeDisplayPanel(
            child: Builder(
              builder: (context) => Column(
                children: [
                  CalseeReadout(code, size: 36),
                  Text(
                    themes.spec.name,
                    style: TextStyle(
                      color: CalseeTextColors.of(context).secondary,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 56,
            child: Row(
              children: [
                Expanded(
                  child: CalseeKey.text(
                    _copied == code ? 'Copied' : 'Copy code',
                    role: KeyRole.function,
                    sizeFactor: 0.3,
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: code));
                      setState(() => _copied = code);
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: CalseeKey.text(
                    'Next theme',
                    role: KeyRole.operator,
                    sizeFactor: 0.3,
                    onPressed: themes.next,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 56,
            child: Row(
              children: [
                Expanded(
                  child: CalseeKey.text(
                    "Today's theme",
                    role: KeyRole.equals,
                    sizeFactor: 0.3,
                    onPressed: () =>
                        themes.jumpTo(themeOfTheDay(DateTime.now())),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  // A code someone sent you: a Claymorphism theme.
                  child: CalseeKey.text(
                    'Open 71G00-0GJA4',
                    role: KeyRole.digit,
                    sizeFactor: 0.24,
                    onPressed: () {
                      final entry = entryOf('71G00-0GJA4');
                      if (entry != null) themes.jumpTo(entry);
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
