// models/tutorial_slide_model.dart
// ============================================================
// Data model for intro slides.
// FIXED: Removed XP/points references — the app uses a
// milestone + streak badge system only (no XP points).
// ============================================================

import 'package:flutter/material.dart';

class TutorialSlideModel {
  final IconData icon;
  final String   headline;
  final String   subtitle;
  final Color    accentColor;
  final String   tag;

  const TutorialSlideModel({
    required this.icon,
    required this.headline,
    required this.subtitle,
    required this.accentColor,
    required this.tag,
  });
}

// ── Slide Content ──────────────────────────────────────────────

const List<TutorialSlideModel> kTutorialSlides = [
  TutorialSlideModel(
    icon:        Icons.shield_rounded,
    headline:    'Welcome to TruthLens',
    subtitle:    'Your AI-powered shield against deepfakes and manipulated media. Let\'s show you how it works.',
    accentColor: Color(0xFF4F8EF7),
    tag:         'WELCOME',
  ),
  TutorialSlideModel(
    icon:        Icons.document_scanner_rounded,
    headline:    'Scan Any Image',
    subtitle:    'Upload a photo or capture one live. Our model analyses it in seconds and returns a Real or Fake verdict.',
    accentColor: Color(0xFF10B981),
    tag:         'SCAN',
  ),
  TutorialSlideModel(
    icon:        Icons.bar_chart_rounded,
    headline:    'Detailed Results',
    subtitle:    'Get a confidence score, EXIF metadata analysis, and an AI-written breakdown of what was found.',
    accentColor: Color(0xFFF5A623),
    tag:         'RESULTS',
  ),
  TutorialSlideModel(
    icon:        Icons.emoji_events_rounded,
    headline:    'Earn Badges',
    // FIXED: Removed "XP" — badges are earned via scan milestones & streaks only
    subtitle:    'Every scan and daily streak unlocks badges. Complete milestones to build your collection.',
    accentColor: Color(0xFFA855F7),
    tag:         'BADGES',
  ),
  TutorialSlideModel(
    icon:        Icons.quiz_rounded,
    headline:    'Daily Challenges',
    subtitle:    'Test your detective skills with daily real vs fake image challenges. Can you outsmart the AI?',
    accentColor: Color(0xFFEF4444),
    tag:         'CHALLENGE',
  ),
  TutorialSlideModel(
    icon:        Icons.newspaper_rounded,
    headline:    'Stay Informed',
    // NEW slide: highlights the news tracker feature
    subtitle:    'Browse the latest deepfake, cybersecurity, and AI ethics news — all in one curated feed.',
    accentColor: Color(0xFF06B6D4),
    tag:         'NEWS',
  ),
];