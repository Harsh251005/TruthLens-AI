// utils/avatar_constants.dart
// ============================================================
// AvatarConstants — single source of truth for all predefined
// emoji avatars available to users.
//
// Each entry has:
//   id     → stored in DB / SharedPreferences (used as avatar_data)
//   emoji  → displayed as the avatar face
//   label  → accessible name shown below the avatar in the picker
//   color  → background colour for the avatar circle
//
// To add more avatars: just append to the list below.
// The picker grid auto-adapts to any list length.
// ============================================================

import 'package:flutter/material.dart';

class PredefinedAvatar {
  final String id;
  final String emoji;
  final String label;
  final Color  color;

  const PredefinedAvatar({
    required this.id,
    required this.emoji,
    required this.label,
    required this.color,
  });
}

class AvatarConstants {

  // ── Predefined avatar catalogue ───────────────────────────────
  static const List<PredefinedAvatar> predefined = [
    PredefinedAvatar(id: 'fox',       emoji: '🦊', label: 'Fox',       color: Color(0xFFE65100)),
    PredefinedAvatar(id: 'panda',     emoji: '🐼', label: 'Panda',     color: Color(0xFF546E7A)),
    PredefinedAvatar(id: 'lion',      emoji: '🦁', label: 'Lion',      color: Color(0xFFF57F17)),
    PredefinedAvatar(id: 'tiger',     emoji: '🐯', label: 'Tiger',     color: Color(0xFFE64A19)),
    PredefinedAvatar(id: 'butterfly', emoji: '🦋', label: 'Butterfly', color: Color(0xFF6A1B9A)),
    PredefinedAvatar(id: 'octopus',   emoji: '🐙', label: 'Octopus',   color: Color(0xFFC62828)),
    PredefinedAvatar(id: 'unicorn',   emoji: '🦄', label: 'Unicorn',   color: Color(0xFFAD1457)),
    PredefinedAvatar(id: 'frog',      emoji: '🐸', label: 'Frog',      color: Color(0xFF2E7D32)),
    PredefinedAvatar(id: 'robot',     emoji: '🤖', label: 'Robot',     color: Color(0xFF1565C0)),
    PredefinedAvatar(id: 'alien',     emoji: '👾', label: 'Alien',     color: Color(0xFF00838F)),
    PredefinedAvatar(id: 'dragon',    emoji: '🐉', label: 'Dragon',    color: Color(0xFFB71C1C)),
    PredefinedAvatar(id: 'eagle',     emoji: '🦅', label: 'Eagle',     color: Color(0xFF4E342E)),
    PredefinedAvatar(id: 'crystal',   emoji: '💎', label: 'Crystal',   color: Color(0xFF00796B)),
    PredefinedAvatar(id: 'fire',      emoji: '🔥', label: 'Fire',      color: Color(0xFFBF360C)),
    PredefinedAvatar(id: 'star',      emoji: '⭐', label: 'Star',      color: Color(0xFFF9A825)),
    PredefinedAvatar(id: 'ninja',     emoji: '🥷', label: 'Ninja',     color: Color(0xFF37474F)),
  ];


  // ── Lookup helpers ────────────────────────────────────────────

  /// Returns the PredefinedAvatar for a given ID, or null if not found.
  static PredefinedAvatar? findById(String id) {
    try {
      return predefined.firstWhere((a) => a.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Returns just the emoji for a given ID (convenience shorthand).
  static String emojiFor(String id) => findById(id)?.emoji ?? '😊';

  /// Returns the background colour for a given predefined avatar ID.
  static Color colorFor(String id) =>
      findById(id)?.color ?? const Color(0xFF4F8EF7);
}