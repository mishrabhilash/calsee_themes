// CalseeBackdrop and CalseeTextColors: the screen behind everything.
//
// The backdrop paints the theme's background and its family's ambient
// artwork (Liquid Glass blobs, Cyberpunk scanlines, Vaporwave sunsets).
// CalseeTextColors gives text colours that stay readable on it.
import 'package:calsee_themes/calsee_themes.dart';
import 'package:flutter/widgets.dart';

class BackdropExample extends StatelessWidget {
  const BackdropExample({super.key});

  @override
  Widget build(BuildContext context) => CalseeBackdrop(
    child: Builder(
      // CalseeTextColors.of needs a context below the backdrop.
      builder: (context) {
        final colors = CalseeTextColors.of(context);
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Good evening, Alex',
                style: TextStyle(
                  color: colors.primary,
                  fontSize: 28,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Primary text for headings, secondary for captions.',
                style: TextStyle(color: colors.secondary, fontSize: 15),
              ),
              const Spacer(),
              // Text with no colour of its own takes the backdrop's.
              const Text('Default text on the backdrop'),
            ],
          ),
        );
      },
    ),
  );
}
