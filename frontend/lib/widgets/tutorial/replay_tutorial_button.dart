// widgets/tutorial/replay_tutorial_button.dart
// ============================================================
// A reusable "Replay Tutorial" button for the Profile/Settings
// screen. Resets all tutorial state and navigates the user
// back to the TutorialScreen to replay from the beginning.
// ============================================================

import 'package:flutter/material.dart';
import '../../services/tutorial_service.dart';
import '../../utils/app_theme.dart';

class ReplayTutorialButton extends StatelessWidget {
  const ReplayTutorialButton({super.key});

  Future<void> _onReplay(BuildContext context) async {
    // Reset all seen flags so every screen shows coach marks again
    await TutorialService().resetAll();

    if (!context.mounted) return;

    // Navigate to the tutorial intro screen
    Navigator.of(context).pushNamed('/tutorial');
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _onReplay(context),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.paddingM,
          vertical:   AppTheme.paddingM,
        ),
        decoration: AppTheme.cardDecoration(
          borderColor: AppTheme.primary.withOpacity(0.25),
        ),
        child: Row(
          children: [
            // Icon container
            Container(
              width: 42, height: 42,
              decoration: BoxDecoration(
                color:        AppTheme.primary.withOpacity(0.12),
                borderRadius: BorderRadius.circular(AppTheme.radiusS),
              ),
              child: const Icon(
                Icons.play_circle_outline_rounded,
                color: AppTheme.primary,
                size:  22,
              ),
            ),
            const SizedBox(width: 14),

            // Label + subtitle
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Replay Tutorial',
                    style: TextStyle(
                      color:      AppTheme.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize:   14,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Walk through the app guide again',
                    style: TextStyle(
                      color:    AppTheme.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),

            // Chevron
            const Icon(
              Icons.chevron_right_rounded,
              color: AppTheme.textHint,
              size:  20,
            ),
          ],
        ),
      ),
    );
  }
}