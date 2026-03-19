// utils/tutorial_controller.dart
// ============================================================
// Coordinates coach-mark step sequences for each screen.
// Uses GlobalKeys attached to real UI widgets to calculate
// spotlight positions. Each screen registers its own keys
// and calls TutorialController to start its sequence.
// ============================================================

import 'package:flutter/material.dart';
import '../services/tutorial_service.dart';
import '../widgets/tutorial/tutorial_coach_overlay.dart';

/// Describes a single coach-mark step: which widget to spotlight,
/// what title & body to show, and where the tooltip appears.
class CoachStep {
  final GlobalKey  targetKey;   // Key attached to the widget being highlighted
  final String     title;       // Short label shown in the tooltip
  final String     description; // Explanation text
  final TooltipPosition position; // Above or below the spotlight

  const CoachStep({
    required this.targetKey,
    required this.title,
    required this.description,
    this.position = TooltipPosition.below,
  });
}

/// Where the tooltip card is drawn relative to the spotlight circle.
enum TooltipPosition { above, below }

class TutorialController {
  // ── Singleton ─────────────────────────────────────────────
  static final TutorialController _instance = TutorialController._internal();
  factory TutorialController() => _instance;
  TutorialController._internal();

  final TutorialService _service = TutorialService();

  // ── Public API ────────────────────────────────────────────

  /// Call this from a screen's initState (after first frame) to auto-show
  /// coach marks if the user hasn't seen them yet for [screenName].
  ///
  /// [steps]      — ordered list of CoachStep for this screen.
  /// [screenName] — unique identifier stored in SharedPreferences.
  Future<void> maybeShowCoach({
    required BuildContext context,
    required String screenName,
    required List<CoachStep> steps,
  }) async {
    // Skip if user has already seen coach marks for this screen
    final seen = await _service.hasSeenCoach(screenName);
    if (seen) return;

    // Wait one frame so all GlobalKeys are mounted and have RenderBox
    await Future.delayed(const Duration(milliseconds: 400));

    if (!context.mounted) return;

    // Show the overlay and await until user dismisses it
    await showTutorialCoachOverlay(
      context: context,
      steps: steps,
    );

    // Persist completion
    await _service.markCoachSeen(screenName);
  }

  /// Force-show coach marks regardless of seen state (e.g., "Replay Tutorial").
  Future<void> forceShowCoach({
    required BuildContext context,
    required String screenName,
    required List<CoachStep> steps,
  }) async {
    await Future.delayed(const Duration(milliseconds: 200));
    if (!context.mounted) return;

    await showTutorialCoachOverlay(
      context: context,
      steps: steps,
    );

    await _service.markCoachSeen(screenName);
  }
}