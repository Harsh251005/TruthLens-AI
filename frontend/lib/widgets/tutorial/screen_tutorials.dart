// widgets/tutorial/screen_tutorials.dart
// ============================================================
// Defines the ordered CoachStep lists for every major screen.
// Import this file in each screen to get its tutorial steps.
//
// Each screen should:
//  1. Declare GlobalKeys listed here as fields.
//  2. Attach keys to the correct widgets.
//  3. Call TutorialController().maybeShowCoach(...) in initState
//     via WidgetsBinding.instance.addPostFrameCallback.
// ============================================================

import 'package:flutter/material.dart';
import '../../utils/tutorial_controller.dart';

// ── Scan Screen ───────────────────────────────────────────────

/// Keys to declare in ScanScreen's State:
///   final GlobalKey scanUploadKey   = GlobalKey();
///   final GlobalKey scanCameraKey   = GlobalKey();
///   final GlobalKey scanBatchKey    = GlobalKey();
List<CoachStep> scanScreenSteps({
  required GlobalKey uploadKey,
  required GlobalKey cameraKey,
  required GlobalKey batchKey,
}) => [
  CoachStep(
    targetKey:   uploadKey,
    title:       '📁 Upload from Gallery',
    description: 'Select any image from your phone\'s gallery to run a deepfake detection analysis.',
    position:    TooltipPosition.below,
  ),
  CoachStep(
    targetKey:   cameraKey,
    title:       '📸 Capture Live Photo',
    description: 'Take a photo in real time — great for checking images you see online.',
    position:    TooltipPosition.above,
  ),
  CoachStep(
    targetKey:   batchKey,
    title:       '⚡ Batch Scan',
    description: 'Scan multiple images at once. Perfect for auditing social media profiles.',
    position:    TooltipPosition.above,
  ),
];

// ── Result Screen ─────────────────────────────────────────────

/// Keys to declare in ResultScreen's State:
///   final GlobalKey resultVerdictKey    = GlobalKey();
///   final GlobalKey resultScoreKey      = GlobalKey();
///   final GlobalKey resultExifKey       = GlobalKey();
///   final GlobalKey resultShareKey      = GlobalKey();
List<CoachStep> resultScreenSteps({
  required GlobalKey verdictKey,
  required GlobalKey scoreKey,
  required GlobalKey exifKey,
  required GlobalKey shareKey,
}) => [
  CoachStep(
    targetKey:   verdictKey,
    title:       '✅ Verdict',
    description: 'The top card shows whether the image is REAL or FAKE with a confidence rating.',
    position:    TooltipPosition.below,
  ),
  CoachStep(
    targetKey:   scoreKey,
    title:       '📊 Confidence Score',
    description: 'A percentage score showing how certain the AI is about its verdict.',
    position:    TooltipPosition.above,
  ),
  CoachStep(
    targetKey:   exifKey,
    title:       '🔬 EXIF Metadata',
    description: 'Detailed metadata analysis — camera model, GPS, edit history, and more.',
    position:    TooltipPosition.above,
  ),
  CoachStep(
    targetKey:   shareKey,
    title:       '📤 Share Result',
    description: 'Share this result as a report to warn others about manipulated content.',
    position:    TooltipPosition.above,
  ),
];

// ── Badges Screen ─────────────────────────────────────────────

/// Keys to declare in BadgesScreen's State:
///   final GlobalKey badgesGridKey   = GlobalKey();
///   final GlobalKey xpBarKey        = GlobalKey();
List<CoachStep> badgesScreenSteps({
  required GlobalKey gridKey,
  required GlobalKey xpBarKey,
}) => [
  CoachStep(
    targetKey:   xpBarKey,
    title:       '⚡ Your XP Progress',
    description: 'This bar shows your current XP and how far you are from the next level.',
    position:    TooltipPosition.below,
  ),
  CoachStep(
    targetKey:   gridKey,
    title:       '🏅 Badge Collection',
    description: 'Locked badges are shown dimmed. Complete challenges and scans to unlock them all.',
    position:    TooltipPosition.above,
  ),
];

// ── Leaderboard Screen ────────────────────────────────────────

/// Keys to declare in LeaderboardScreen's State:
///   final GlobalKey leaderRankKey   = GlobalKey();
///   final GlobalKey leaderListKey   = GlobalKey();
List<CoachStep> leaderboardScreenSteps({
  required GlobalKey rankKey,
  required GlobalKey listKey,
}) => [
  CoachStep(
    targetKey:   rankKey,
    title:       '🎖️ Your Rank',
    description: 'This shows your current global rank based on XP earned from scans and challenges.',
    position:    TooltipPosition.below,
  ),
  CoachStep(
    targetKey:   listKey,
    title:       '🌍 Global Rankings',
    description: 'See the top detectives worldwide. Scan more and complete challenges to climb up!',
    position:    TooltipPosition.above,
  ),
];

// ── Challenge Screen ──────────────────────────────────────────

/// Keys to declare in ChallengeScreen's State:
///   final GlobalKey challengeImageKey  = GlobalKey();
///   final GlobalKey challengeTimerKey  = GlobalKey();
///   final GlobalKey challengeChoiceKey = GlobalKey();
List<CoachStep> challengeScreenSteps({
  required GlobalKey imageKey,
  required GlobalKey timerKey,
  required GlobalKey choiceKey,
}) => [
  CoachStep(
    targetKey:   imageKey,
    title:       '🖼️ The Image',
    description: 'Study the image carefully. Look for unnatural edges, lighting inconsistencies, or artifacts.',
    position:    TooltipPosition.below,
  ),
  CoachStep(
    targetKey:   timerKey,
    title:       '⏱️ Time Limit',
    description: 'You have limited seconds to make your call. Faster correct answers earn bonus XP.',
    position:    TooltipPosition.below,
  ),
  CoachStep(
    targetKey:   choiceKey,
    title:       '🤔 Real or Fake?',
    description: 'Tap REAL or FAKE. The AI will then reveal the correct answer and your reward.',
    position:    TooltipPosition.above,
  ),
];