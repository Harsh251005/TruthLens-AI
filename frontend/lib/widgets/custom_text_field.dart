// widgets/custom_text_field.dart
// ============================================================
// Reusable text field styled for the dark theme.
// ============================================================

import 'package:flutter/material.dart';
import '../utils/app_theme.dart';

class CustomTextField extends StatefulWidget {
  final String label;
  final String hint;
  final TextEditingController controller;
  final IconData icon;
  final bool isPassword;
  final String? Function(String?)? validator;
  final TextInputType keyboardType;
  final TextInputAction textInputAction;

  const CustomTextField({
    super.key,
    required this.label,
    required this.hint,
    required this.controller,
    required this.icon,
    this.isPassword        = false,
    this.validator,
    this.keyboardType      = TextInputType.text,
    this.textInputAction   = TextInputAction.next,
  });

  @override
  State<CustomTextField> createState() => _CustomTextFieldState();
}

class _CustomTextFieldState extends State<CustomTextField> {
  bool _obscureText = true;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller:      widget.controller,
      obscureText:     widget.isPassword && _obscureText,
      keyboardType:    widget.keyboardType,
      textInputAction: widget.textInputAction,
      validator:       widget.validator,
      style: const TextStyle(color: AppTheme.textPrimary, fontSize: 15),
      decoration: InputDecoration(
        labelText:     widget.label,
        hintText:      widget.hint,
        labelStyle:    const TextStyle(color: AppTheme.textSecondary),
        hintStyle:     const TextStyle(color: AppTheme.textHint),
        prefixIcon:    Icon(widget.icon, color: AppTheme.textSecondary, size: 20),
        // Password visibility toggle
        suffixIcon: widget.isPassword
            ? IconButton(
          icon: Icon(
            _obscureText ? Icons.visibility_outlined : Icons.visibility_off_outlined,
            color: AppTheme.textSecondary,
            size: 20,
          ),
          onPressed: () => setState(() => _obscureText = !_obscureText),
        )
            : null,
      ),
    );
  }
}