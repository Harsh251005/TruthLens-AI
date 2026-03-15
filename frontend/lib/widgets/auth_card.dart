// widgets/auth_card.dart
// ============================================================
// Dark themed card container for auth forms.
// ============================================================

import 'package:flutter/material.dart';
import '../utils/app_theme.dart';

class AuthCard extends StatelessWidget {
  final Widget child;

  const AuthCard({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppTheme.paddingL),
      decoration: AppTheme.cardDecoration(),
      child: child,
    );
  }
}