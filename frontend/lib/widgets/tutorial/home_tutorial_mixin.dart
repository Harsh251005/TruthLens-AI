// widgets/tutorial/home_tutorial_mixin.dart
// ============================================================
// Mixin for HomeScreen that registers GlobalKeys and triggers
// coach marks on first visit.
//
// FIXED: Removed XP reference in profile step — the app uses
// milestone badges and streaks only, no XP points system.
// ============================================================

import 'package:flutter/material.dart';
import '../../utils/tutorial_controller.dart';

mixin HomeTutorialMixin<T extends StatefulWidget> on State<T> {
  // ── GlobalKeys — attach these to your Home widgets ────────
  final GlobalKey scanButtonKey  = GlobalKey();
  final GlobalKey historyKey     = GlobalKey();
  final GlobalKey challengeKey   = GlobalKey();
  final GlobalKey leaderboardKey = GlobalKey();
  final GlobalKey profileKey     = GlobalKey();

  /// Call in initState after super.initState().
  void initHomeTutorial(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      TutorialController().maybeShowCoach(
        context:    context,
        screenName: 'home',
        steps:      _homeSteps,
      );
    });
  }

  List<CoachStep> get _homeSteps => [
    CoachStep(
      targetKey:   scanButtonKey,
      title:       '🔍 Scan an Image',
      description: 'Tap here to upload or capture an image. Our AI analyses it for deepfake signals instantly.',
      position:    TooltipPosition.above,
    ),
    CoachStep(
      targetKey:   challengeKey,
      title:       '🎯 Daily Challenge',
      description: 'Take on today\'s real vs fake challenge. Get it right to keep your streak alive.',
      position:    TooltipPosition.below,
    ),
    CoachStep(
      targetKey:   leaderboardKey,
      title:       '🏆 Leaderboard',
      description: 'See how you rank against other detectives globally based on scans and streaks.',
      position:    TooltipPosition.below,
    ),
    CoachStep(
      targetKey:   historyKey,
      title:       '📋 Scan History',
      description: 'Review all your past scan results and verdicts here.',
      position:    TooltipPosition.above,
    ),
    CoachStep(
      targetKey:   profileKey,
      title:       '👤 Your Profile',
      // FIXED: was "View your badges, XP, and settings"
      // App has no XP — replaced with accurate description
      description: 'View your earned badges, streak stats, and settings — or replay this tutorial anytime.',
      position:    TooltipPosition.above,
    ),
  ];
}