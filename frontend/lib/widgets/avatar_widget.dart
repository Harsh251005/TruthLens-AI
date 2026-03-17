// widgets/avatar_widget.dart
// ============================================================
// AvatarWidget — reusable widget that renders the correct
// avatar based on the user's avatarType + avatarData.
//
// Three rendering modes:
//   'initial'    → coloured circle with first letter of name
//   'predefined' → emoji on a colour-matched background circle
//   'custom'     → circular cropped photo decoded from base64
//
// Props:
//   avatarType   — 'initial' | 'predefined' | 'custom'
//   avatarData   — avatar ID (predefined) or base64 JPEG (custom)
//   name         — used for the initial fallback letter
//   size         — diameter of the circle in logical pixels
//   showRing     — wraps circle in a glowing gradient ring (profile hero)
//   ringWidth    — thickness of the gradient ring (default 3)
// ============================================================

import 'dart:convert';
import 'package:flutter/material.dart';
import '../utils/avatar_constants.dart';
import '../utils/app_theme.dart';

class AvatarWidget extends StatelessWidget {
  final String  avatarType;
  final String? avatarData;
  final String  name;
  final double  size;
  final bool    showRing;
  final double  ringWidth;

  const AvatarWidget({
    super.key,
    required this.avatarType,
    required this.name,
    this.avatarData,
    this.size      = 48,
    this.showRing  = false,
    this.ringWidth = 3,
  });

  @override
  Widget build(BuildContext context) {
    final Widget circle = _buildCircle();

    // Wrap in glowing gradient ring when requested (profile hero header)
    if (showRing) {
      return Container(
        width:  size + ringWidth * 2,
        height: size + ringWidth * 2,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: AppTheme.primaryGradient,
          boxShadow: [
            BoxShadow(
              color:       AppTheme.primary.withValues(alpha: 0.4),
              blurRadius:  24,
              spreadRadius: 4,
            ),
          ],
        ),
        child: Padding(
          padding: EdgeInsets.all(ringWidth),
          child: circle,
        ),
      );
    }

    return circle;
  }

  // ── Choose which avatar style to render ───────────────────────
  Widget _buildCircle() {
    switch (avatarType) {
      case 'predefined':
        return _buildPredefinedAvatar();
      case 'custom':
        return _buildCustomAvatar();
      default:
        return _buildInitialAvatar();   // 'initial' or unknown
    }
  }

  // ── Initial: coloured circle with first letter ────────────────
  Widget _buildInitialAvatar() {
    final letter = name.isNotEmpty ? name[0].toUpperCase() : '?';
    return Container(
      width:  size,
      height: size,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: AppTheme.surface,
      ),
      child: Center(
        child: Text(
          letter,
          style: TextStyle(
            fontSize:   size * 0.42,   // scales with circle size
            fontWeight: FontWeight.w800,
            color:      AppTheme.primary,
          ),
        ),
      ),
    );
  }

  // ── Predefined: emoji on coloured background ──────────────────
  Widget _buildPredefinedAvatar() {
    // Look up the avatar entry; fall back to initial if ID unknown
    final avatar = AvatarConstants.findById(avatarData ?? '');
    if (avatar == null) return _buildInitialAvatar();

    return Container(
      width:  size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: avatar.color.withValues(alpha: 0.25),
        border: Border.all(color: avatar.color.withValues(alpha: 0.5), width: 1.5),
      ),
      child: Center(
        child: Text(
          avatar.emoji,
          style: TextStyle(fontSize: size * 0.48),
        ),
      ),
    );
  }

  // ── Custom: photo decoded from base64 ─────────────────────────
  Widget _buildCustomAvatar() {
    if (avatarData == null || avatarData!.isEmpty) {
      return _buildInitialAvatar();
    }

    try {
      final bytes = base64Decode(avatarData!);
      return Container(
        width:  size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: AppTheme.primary.withValues(alpha: 0.4),
            width: 1.5,
          ),
        ),
        child: ClipOval(
          child: Image.memory(
            bytes,
            width:  size,
            height: size,
            fit:    BoxFit.cover,
            // If bytes are corrupted fall back to a letter
            errorBuilder: (_, _, _) => _buildInitialAvatar(),
          ),
        ),
      );
    } catch (_) {
      // base64Decode threw — fall back gracefully
      return _buildInitialAvatar();
    }
  }
}