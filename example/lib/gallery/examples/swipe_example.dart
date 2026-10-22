// CalseeSwipeArea: swipe for a new theme.
//
// Swiping left shows the next theme, right the exact previous one. Taps
// and vertical scrolls pass through to the child.
import 'package:calsee_themes/calsee_themes.dart';
import 'package:flutter/widgets.dart';

class SwipeExample extends StatelessWidget {
  const SwipeExample({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = CalseeScope.of(context).spec;
    return CalseeSwipeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: CalseeDisplayPanel(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 32,
              ),
              child: Builder(
                builder: (context) => Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CalseeReadout(theme.name, size: 40),
                    const SizedBox(height: 8),
                    Text(
                      '← Swipe here (or drag with the mouse) →',
                      style: TextStyle(
                        color: CalseeTextColors.of(context).secondary,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
