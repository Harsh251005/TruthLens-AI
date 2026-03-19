// screens/profile_screen.dart
// ============================================================
// Profile screen — redesigned for a professional look.
// All business logic unchanged — only UI rebuilt.
// ============================================================

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/auth_service.dart';
import '../services/detection_service.dart';
import '../services/storage_service.dart';
import '../utils/app_theme.dart';
import '../utils/avatar_constants.dart';
import '../utils/validators.dart';
import '../widgets/avatar_widget.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/primary_button.dart';
import 'login_screen.dart';
import 'dart:typed_data';
import 'package:custom_image_crop/custom_image_crop.dart';
import 'badges_screen.dart';
import '../services/notification_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {

  // ── Controllers ───────────────────────────────────────────────
  final _nameController            = TextEditingController();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController     = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _nameFormKey               = GlobalKey<FormState>();
  final _passwordFormKey           = GlobalKey<FormState>();

  // ── Services ──────────────────────────────────────────────────
  final _authService      = AuthService();
  final _detectionService = DetectionService();
  final _imagePicker      = ImagePicker();

  // ── Tab controller ────────────────────────────────────────────
  late TabController _tabController;

  // ── User/profile state ────────────────────────────────────────
  bool      _isLoadingProfile   = true;
  bool      _isUpdatingName     = false;
  bool      _isUpdatingPassword = false;
  bool      _isUpdatingAvatar   = false;
  bool      _isEditingName      = false;
  bool      _isDeletingAccount  = false;
  bool      _isResettingAccount = false;
  bool      _streakNotifEnabled = true;
  bool      _badgeNotifEnabled  = true;
  String?   _nameError;
  String?   _passwordError;
  String?   _nameSuccess;
  String?   _passwordSuccess;
  String    _userEmail          = '';
  String    _userName           = '';
  ScanStats? _stats;

  // ── Avatar state ──────────────────────────────────────────────
  String  _avatarType = 'initial';
  String? _avatarData;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nameController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // ── Load profile + stats in parallel ─────────────────────────
  Future<void> _loadData() async {
    final results = await Future.wait([
      _authService.getProfile(),
      _detectionService.getStats(),
    ]);

    if (!mounted) return;

    final profileResult = results[0] as AuthResult;
    final stats         = results[1] as ScanStats?;

    setState(() {
      if (profileResult.success && profileResult.user != null) {
        final user           = profileResult.user!;
        _userName            = user.name;
        _userEmail           = user.email;
        _nameController.text = user.name;
        _avatarType          = user.avatarType;
        _avatarData          = user.avatarData;
      }
      _stats            = stats;
      _isLoadingProfile = false;
    });

    final streakEnabled = await NotificationService().isStreakNotifEnabled();
    final badgeEnabled  = await NotificationService().isBadgeNotifEnabled();
    setState(() {
      _streakNotifEnabled = streakEnabled;
      _badgeNotifEnabled  = badgeEnabled;
    });
  }


  // ═══════════════════════════════════════════════════════════════
  //  AVATAR — all logic unchanged
  // ═══════════════════════════════════════════════════════════════

  void _showAvatarPicker() {
    showModalBottomSheet(
      context:            context,
      isScrollControlled: true,
      backgroundColor:    Colors.transparent,
      builder:            (_) => _buildAvatarPickerSheet(),
    );
  }

  Widget _buildAvatarPickerSheet() {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: const BoxDecoration(
        color:        AppTheme.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(
              color:        AppTheme.surfaceBorder,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          const Text('Choose Your Avatar',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary)),
          const SizedBox(height: 4),
          const Text('Pick an emoji or upload a photo',
              style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
          const SizedBox(height: 20),
          Flexible(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: GridView.builder(
                shrinkWrap: true,
                physics: const BouncingScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount:   4,
                  crossAxisSpacing: 12,
                  mainAxisSpacing:  12,
                  childAspectRatio: 0.85,
                ),
                itemCount: AvatarConstants.predefined.length,
                itemBuilder: (_, i) {
                  final avatar     = AvatarConstants.predefined[i];
                  final isSelected = _avatarType == 'predefined' &&
                      _avatarData == avatar.id;
                  return GestureDetector(
                    onTap: () => _selectPredefined(avatar),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      decoration: BoxDecoration(
                        color: avatar.color.withValues(
                            alpha: isSelected ? 0.3 : 0.12),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected
                              ? avatar.color : Colors.transparent,
                          width: 2.5,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(avatar.emoji,
                              style: const TextStyle(fontSize: 32)),
                          const SizedBox(height: 4),
                          Text(avatar.label,
                              style: const TextStyle(fontSize: 11,
                                  color: AppTheme.textSecondary)),
                          if (isSelected) ...[
                            const SizedBox(height: 2),
                            Icon(Icons.check_circle,
                                color: avatar.color, size: 14),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Column(children: [
              const Divider(color: AppTheme.surfaceBorder),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity, height: 48,
                child: ElevatedButton.icon(
                  onPressed: _pickFromGallery,
                  icon:  const Icon(Icons.photo_library_outlined, size: 20),
                  label: const Text('Browse from Device',
                      style: TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius:
                        BorderRadius.circular(AppTheme.radiusM)),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity, height: 44,
                child: OutlinedButton.icon(
                  onPressed: _avatarType == 'initial' ? null : _resetToInitial,
                  icon:  const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Reset to Default',
                      style: TextStyle(fontSize: 14)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.textSecondary,
                    side: const BorderSide(color: AppTheme.surfaceBorder),
                    shape: RoundedRectangleBorder(
                        borderRadius:
                        BorderRadius.circular(AppTheme.radiusM)),
                  ),
                ),
              ),
              SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
            ]),
          ),
        ],
      ),
    );
  }

  Future<void> _selectPredefined(PredefinedAvatar avatar) async {
    Navigator.of(context).pop();
    await _saveAvatar(avatarType: 'predefined', avatarData: avatar.id);
  }

  Future<void> _pickFromGallery() async {
    Navigator.of(context).pop();
    final picked = await _imagePicker.pickImage(
      source: ImageSource.gallery, imageQuality: 90,
    );
    if (picked == null || !mounted) return;
    final bytes = await picked.readAsBytes();
    if (!mounted) return;
    final croppedBytes = await Navigator.of(context).push<Uint8List>(
      MaterialPageRoute(builder: (_) => _CropPage(imageBytes: bytes)),
    );
    if (croppedBytes == null || !mounted) return;
    final base64Str = base64Encode(croppedBytes);
    await _saveAvatar(avatarType: 'custom', avatarData: base64Str);
  }

  Future<void> _resetToInitial() async {
    Navigator.of(context).pop();
    await _saveAvatar(avatarType: 'initial', avatarData: null);
  }

  Future<void> _saveAvatar({
    required String avatarType,
    String?         avatarData,
  }) async {
    setState(() => _isUpdatingAvatar = true);
    final result = await _authService.updateAvatar(
      avatarType: avatarType, avatarData: avatarData,
    );
    if (!mounted) return;
    if (result.success) {
      setState(() {
        _avatarType       = avatarType;
        _avatarData       = avatarData;
        _isUpdatingAvatar = false;
      });
    } else {
      setState(() => _isUpdatingAvatar = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message),
            backgroundColor: AppTheme.error),
      );
    }
  }


  // ═══════════════════════════════════════════════════════════════
  //  NAME UPDATE — logic unchanged
  // ═══════════════════════════════════════════════════════════════

  Future<void> _handleUpdateName() async {
    setState(() { _nameError = null; _nameSuccess = null; });
    if (!_nameFormKey.currentState!.validate()) return;
    setState(() => _isUpdatingName = true);
    final result = await _authService.updateProfile(
        name: _nameController.text.trim());
    if (!mounted) return;
    if (result.success) {
      await StorageService.updateName(_nameController.text.trim());
      setState(() {
        _isUpdatingName = false;
        _userName       = _nameController.text.trim();
        _nameSuccess    = 'Name updated successfully!';
        _isEditingName  = false;
      });
    } else {
      setState(() { _isUpdatingName = false; _nameError = result.message; });
    }
  }


  // ═══════════════════════════════════════════════════════════════
  //  PASSWORD UPDATE — logic unchanged
  // ═══════════════════════════════════════════════════════════════

  Future<void> _handleUpdatePassword() async {
    setState(() { _passwordError = null; _passwordSuccess = null; });
    if (!_passwordFormKey.currentState!.validate()) return;
    setState(() => _isUpdatingPassword = true);
    final result = await _authService.updateProfile(
      currentPassword: _currentPasswordController.text,
      newPassword:     _newPasswordController.text,
    );
    if (!mounted) return;
    setState(() {
      _isUpdatingPassword = false;
      if (result.success) {
        _currentPasswordController.clear();
        _newPasswordController.clear();
        _confirmPasswordController.clear();
        _passwordSuccess = 'Password updated successfully!';
      } else {
        _passwordError = result.message;
      }
    });
  }


  // ═══════════════════════════════════════════════════════════════
  //  LOGOUT — logic unchanged
  // ═══════════════════════════════════════════════════════════════

  Future<void> _handleLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusL)),
        title: const Text('Sign Out',
            style: TextStyle(color: AppTheme.textPrimary,
                fontWeight: FontWeight.w700)),
        content: const Text('Are you sure you want to sign out?',
            style: TextStyle(color: AppTheme.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel',
                style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusS)),
            ),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await StorageService.clearUser();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        PageRouteBuilder(
          pageBuilder:        (_, _, _) => const LoginScreen(),
          transitionsBuilder: (_, animation, _, child) =>
              FadeTransition(opacity: animation, child: child),
          transitionDuration: const Duration(milliseconds: 400),
        ),
            (route) => false,
      );
    }
  }


  // ═══════════════════════════════════════════════════════════════
  //  DELETE ACCOUNT — logic unchanged
  // ═══════════════════════════════════════════════════════════════

  Future<void> _handleDeleteAccount() async {
    final passwordController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusL)),
        title: const Text('Delete Account',
            style: TextStyle(color: AppTheme.error,
                fontWeight: FontWeight.w700)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'This will permanently delete your account and ALL data including scans, badges and streak. This cannot be undone.',
              style: TextStyle(color: AppTheme.textSecondary,
                  height: 1.5, fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller:  passwordController,
              obscureText: true,
              style: const TextStyle(color: AppTheme.textPrimary),
              decoration: InputDecoration(
                hintText:  'Enter your password to confirm',
                hintStyle: const TextStyle(
                    color: AppTheme.textSecondary, fontSize: 13),
                filled:    true,
                fillColor: AppTheme.background,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusS),
                  borderSide:
                  const BorderSide(color: AppTheme.surfaceBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusS),
                  borderSide:
                  const BorderSide(color: AppTheme.surfaceBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusS),
                  borderSide: const BorderSide(color: AppTheme.error),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel',
                style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusS)),
            ),
            child: const Text('Delete Forever'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!mounted) return;
    if (passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your password'),
            backgroundColor: AppTheme.error),
      );
      return;
    }
    setState(() => _isDeletingAccount = true);
    final result =
    await _authService.deleteAccount(password: passwordController.text);
    if (!mounted) return;
    if (result.success) {
      Navigator.of(context).pushAndRemoveUntil(
        PageRouteBuilder(
          pageBuilder:        (_, _, _) => const LoginScreen(),
          transitionsBuilder: (_, animation, _, child) =>
              FadeTransition(opacity: animation, child: child),
          transitionDuration: const Duration(milliseconds: 400),
        ),
            (route) => false,
      );
    } else {
      setState(() => _isDeletingAccount = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message),
            backgroundColor: AppTheme.error),
      );
    }
  }


  // ═══════════════════════════════════════════════════════════════
  //  RESET ACCOUNT — logic unchanged
  // ═══════════════════════════════════════════════════════════════

  Future<void> _handleResetAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusL)),
        title: const Text('Reset Account',
            style: TextStyle(color: AppTheme.accent,
                fontWeight: FontWeight.w700)),
        content: const Text(
          'This will reset all your data — scans, streak, badges, avatar and challenge scores. Your account and login details will be kept.',
          style: TextStyle(color: AppTheme.textSecondary,
              height: 1.5, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel',
                style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusS)),
            ),
            child: const Text('Reset Everything'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _isResettingAccount = true);
    final result = await _authService.resetAccount();
    if (!mounted) return;
    setState(() => _isResettingAccount = false);
    if (result.success) {
      setState(() {
        _avatarType = 'initial';
        _avatarData = null;
        _stats      = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message),
            backgroundColor: AppTheme.success),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message),
            backgroundColor: AppTheme.error),
      );
    }
  }


  // ═══════════════════════════════════════════════════════════════
  //  BUILD — completely redesigned
  // ═══════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    if (_isLoadingProfile) {
      return const Scaffold(
        backgroundColor: AppTheme.background,
        body: Center(
            child: CircularProgressIndicator(color: AppTheme.primary)),
      );
    }

    return PopScope(
      // Intercept every pop (system back gesture + AppBar back button)
      // and return the current _userName so HomeScreen can update its
      // greeting without depending on SharedPreferences.
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (didPop) return;
          Navigator.of(context).pop(_userName);
        },
        child: Scaffold(
          backgroundColor: AppTheme.background,
          body: NestedScrollView(
            headerSliverBuilder: (_, innerScrolled) => [
              _buildSliverHeader(innerScrolled),
            ],
            body: Column(children: [
              _buildTabBar(),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildAccountTab(),
                    _buildSecurityTab(),
                  ],
                ),
              ),
            ]),
          ),
        ));
  }


  // ── Sliver collapsible header ─────────────────────────────────
  Widget _buildSliverHeader(bool innerScrolled) {
    return SliverAppBar(
      expandedHeight:  360,
      collapsedHeight: 60,
      pinned:          true,
      backgroundColor: AppTheme.surface,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new,
            color: AppTheme.textPrimary, size: 20),
        // Return current _userName so HomeScreen greeting updates instantly
        onPressed: () => Navigator.of(context).pop(_userName),
      ),
      title: AnimatedOpacity(
        opacity:  innerScrolled ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 200),
        child: Row(children: [
          AvatarWidget(
            avatarType: _avatarType,
            avatarData: _avatarData,
            name:       _userName,
            size:       28,
            showRing:   false,
          ),
          const SizedBox(width: 10),
          Text(_userName,
              style: const TextStyle(fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary)),
        ]),
      ),
      flexibleSpace: FlexibleSpaceBar(
        collapseMode: CollapseMode.pin,
        background:   _buildHeroContent(),
      ),
    );
  }


  // ── Hero content inside the flexible space ────────────────────
  Widget _buildHeroContent() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0F1629), Color(0xFF0A0E1A)],
          begin:  Alignment.topCenter,
          end:    Alignment.bottomCenter,
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 56),  // space for back button

            // ── Avatar ─────────────────────────────────────────
            GestureDetector(
              onTap: _isUpdatingAvatar ? null : _showAvatarPicker,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // Outer glow ring
                  Container(
                    width: 100, height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppTheme.primary.withValues(alpha: 0.3),
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color:      AppTheme.primary.withValues(alpha: 0.15),
                          blurRadius: 20,
                          spreadRadius: 4,
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(3),
                      child: AvatarWidget(
                        avatarType: _avatarType,
                        avatarData: _avatarData,
                        name:       _userName,
                        size:       94,
                        showRing:   false,
                      ),
                    ),
                  ),
                  // Loading overlay
                  if (_isUpdatingAvatar)
                    Positioned.fill(
                      child: Container(
                        decoration: const BoxDecoration(
                          color: Colors.black45,
                          shape: BoxShape.circle,
                        ),
                        child: const Center(
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2),
                        ),
                      ),
                    ),
                  // Edit badge
                  Positioned(
                    bottom: 0, right: 0,
                    child: Container(
                      width: 30, height: 30,
                      decoration: BoxDecoration(
                        color:  AppTheme.primary,
                        shape:  BoxShape.circle,
                        border: Border.all(
                            color: const Color(0xFF0A0E1A), width: 2),
                        boxShadow: [
                          BoxShadow(
                            color:      AppTheme.primary.withValues(alpha: 0.5),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: const Icon(Icons.edit_rounded,
                          color: Colors.white, size: 14),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // ── Name ─────────────────────────────────────────────
            Text(_userName,
                style: const TextStyle(fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary,
                    letterSpacing: -0.3)),

            const SizedBox(height: 4),

            // ── Email with icon ───────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.email_outlined,
                    color: AppTheme.textSecondary, size: 13),
                const SizedBox(width: 5),
                Text(_userEmail,
                    style: const TextStyle(fontSize: 13,
                        color: AppTheme.textSecondary)),
              ],
            ),

            const SizedBox(height: 16),

            // ── Stats row ─────────────────────────────────────────
            _buildStatsRow(),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }


  // ── Stats row — 3 chips ───────────────────────────────────────
  Widget _buildStatsRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.paddingL),
      child: Row(children: [
        _buildStatChip(
          icon:  Icons.document_scanner_rounded,
          label: 'Total Scans',
          value: '${_stats?.totalScans ?? 0}',
          color: AppTheme.primary,
        ),
        const SizedBox(width: 8),
        _buildStatChip(
          icon:  Icons.verified_rounded,
          label: 'Authentic',
          value: '${_stats?.totalReal ?? 0}',
          color: AppTheme.success,
        ),
        const SizedBox(width: 8),
        _buildStatChip(
          icon:  Icons.dangerous_rounded,
          label: 'Deepfakes',
          value: '${_stats?.totalFake ?? 0}',
          color: AppTheme.error,
        ),
      ]),
    );
  }

  Widget _buildStatChip({
    required IconData icon,
    required String   label,
    required String   value,
    required Color    color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color:        color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppTheme.radiusM),
          border:       Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 4),
          Text(value,
              style: TextStyle(fontSize: 18,
                  fontWeight: FontWeight.w800, color: color)),
          const SizedBox(height: 2),
          Text(label,
              style: const TextStyle(fontSize: 10,
                  color: AppTheme.textSecondary),
              textAlign: TextAlign.center),
        ]),
      ),
    );
  }


  // ── Tab bar ───────────────────────────────────────────────────
  Widget _buildTabBar() {
    return Container(
      color: AppTheme.surface,
      child: TabBar(
        controller:           _tabController,
        indicatorColor:       AppTheme.primary,
        indicatorWeight:      2,
        labelColor:           AppTheme.primary,
        unselectedLabelColor: AppTheme.textSecondary,
        labelStyle: const TextStyle(
            fontSize: 14, fontWeight: FontWeight.w600),
        tabs: const [
          Tab(text: 'Account'),
          Tab(text: 'Security'),
        ],
      ),
    );
  }


  // ═══════════════════════════════════════════════════════════════
  //  ACCOUNT TAB
  // ═══════════════════════════════════════════════════════════════

  Widget _buildAccountTab() {
    return SingleChildScrollView(
      // AFTER:
      padding: EdgeInsets.only(
        top:    20,
        bottom: MediaQuery.of(context).padding.bottom + 20,
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // ── Profile section ──────────────────────────────────────
        _buildSectionHeader('Profile'),
        _buildSettingsCard(children: [
          _buildNameRow(),
          _buildDivider(),
          _buildReadOnlyRow(
            icon:  Icons.email_outlined,
            label: 'Email',
            value: _userEmail,
            note:  'Cannot be changed',
          ),
        ]),

        const SizedBox(height: 20),

        // ── Achievements section ─────────────────────────────────
        _buildSectionHeader('Achievements'),
        _buildBadgesCard(),

        const SizedBox(height: 20),

        // ── Session section ──────────────────────────────────────
        _buildSectionHeader('Session'),
        _buildSettingsCard(children: [
          _buildActionRow(
            icon:       Icons.logout_rounded,
            iconColor:  AppTheme.error,
            label:      'Sign Out',
            labelColor: AppTheme.error,
            onTap:      _handleLogout,
          ),
        ]),

        const SizedBox(height: 32),
      ]),
    );
  }


  // ── Name row — shows name or inline edit form ─────────────────
  Widget _buildNameRow() {
    if (_isEditingName) {
      return Padding(
        padding: const EdgeInsets.all(4),
        child: Form(
          key: _nameFormKey,
          child: Column(children: [
            CustomTextField(
              label:           'Full Name',
              hint:            'Enter your new name',
              controller:      _nameController,
              icon:            Icons.person_outline,
              validator:       Validators.name,
              textInputAction: TextInputAction.done,
            ),
            const SizedBox(height: 12),
            if (_nameError   != null) ...[
              _buildBanner(_nameError!,   isError: true),
              const SizedBox(height: 10),
            ],
            if (_nameSuccess != null) ...[
              _buildBanner(_nameSuccess!, isError: false),
              const SizedBox(height: 10),
            ],
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => setState(() {
                    _isEditingName       = false;
                    _nameController.text = _userName;
                    _nameError           = null;
                  }),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.textSecondary,
                    side: const BorderSide(color: AppTheme.surfaceBorder),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                        borderRadius:
                        BorderRadius.circular(AppTheme.radiusM)),
                  ),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: PrimaryButton(
                  label:     'Save',
                  onPressed: _handleUpdateName,
                  isLoading: _isUpdatingName,
                ),
              ),
            ]),
          ]),
        ),
      );
    }

    // ── Display mode ──────────────────────────────────────────────
    return _buildInfoRow(
      icon:       Icons.person_outline,
      iconColor:  AppTheme.primary,
      label:      'Full Name',
      value:      _userName,
      trailing: GestureDetector(
        onTap: () => setState(() {
          _isEditingName = true;
          _nameSuccess   = null;
          _nameError     = null;
        }),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color:        AppTheme.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: AppTheme.primary.withValues(alpha: 0.25)),
          ),
          child: const Text('Edit',
              style: TextStyle(fontSize: 12,
                  color: AppTheme.primary,
                  fontWeight: FontWeight.w600)),
        ),
      ),
    );
  }


  // ── Badges card ───────────────────────────────────────────────
  Widget _buildBadgesCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.paddingL),
      child: GestureDetector(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const BadgesScreen()),
        ),
        child: Container(
          padding: const EdgeInsets.all(AppTheme.paddingL),
          decoration: BoxDecoration(
            color:        AppTheme.surface,
            borderRadius: BorderRadius.circular(AppTheme.radiusL),
            border: Border.all(
                color: AppTheme.accent.withValues(alpha: 0.25)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              Row(children: [
                Container(
                  width: 38, height: 38,
                  decoration: BoxDecoration(
                    color:        AppTheme.accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.emoji_events_rounded,
                      color: AppTheme.accent, size: 20),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Badges & Streaks',
                          style: TextStyle(fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textPrimary)),
                      Text('Tap to view all achievements',
                          style: TextStyle(fontSize: 12,
                              color: AppTheme.textSecondary)),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right,
                    color: AppTheme.textSecondary, size: 20),
              ]),

              // ── Earned badges preview strip ──────────────────
              _buildBadgesStrip(),
            ],
          ),
        ),
      ),
    );
  }


  // ── Earned badges horizontal strip ───────────────────────────
  Widget _buildBadgesStrip() {
    return FutureBuilder<BadgesData?>(
      future: _detectionService.getBadges(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data == null) {
          return const SizedBox.shrink();
        }
        final earned = snapshot.data!.badges
            .where((b) => b.earned)
            .toList();

        if (earned.isEmpty) {
          return Padding(
            padding: const EdgeInsets.only(top: 14),
            child: Row(children: [
              const Icon(Icons.lock_outline,
                  color: AppTheme.textSecondary, size: 14),
              const SizedBox(width: 6),
              Text('No badges yet — start scanning!',
                  style: TextStyle(fontSize: 12,
                      color: AppTheme.textSecondary
                          .withValues(alpha: 0.7))),
            ]),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            const Divider(color: AppTheme.surfaceBorder, height: 1),
            const SizedBox(height: 14),
            Row(children: [
              Text('${earned.length} earned',
                  style: const TextStyle(fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textSecondary,
                      letterSpacing: 0.5)),
              const Spacer(),
            ]),
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: earned.map((b) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Tooltip(
                    message: b.name,
                    child: Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(
                        color:        AppTheme.surface2,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: AppTheme.accent
                                .withValues(alpha: 0.2)),
                      ),
                      child: Center(
                        child: Text(b.emoji,
                            style: const TextStyle(fontSize: 22)),
                      ),
                    ),
                  ),
                )).toList(),
              ),
            ),
          ],
        );
      },
    );
  }


  // ═══════════════════════════════════════════════════════════════
  //  SECURITY TAB
  // ═══════════════════════════════════════════════════════════════

  Widget _buildSecurityTab() {
    return SingleChildScrollView(
      // AFTER:
      padding: EdgeInsets.only(
        top:    20,
        bottom: MediaQuery.of(context).padding.bottom + 20,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          // ── Notifications ────────────────────────────────────
          _buildSectionHeader('Notifications'),
          _buildSettingsCard(children: [
            _buildToggleRow(
              icon:      Icons.local_fire_department_rounded,
              iconColor: AppTheme.accent,
              label:     'Daily Streak Reminder',
              subtitle:  'Reminds you to scan at 8:00 PM',
              value:     _streakNotifEnabled,
              onChanged: (val) async {
                setState(() => _streakNotifEnabled = val);
                await NotificationService().setStreakNotifEnabled(val);
              },
            ),
            _buildDivider(),
            _buildToggleRow(
              icon:      Icons.emoji_events_rounded,
              iconColor: AppTheme.primary,
              label:     'Badge Progress Alerts',
              subtitle:  'Notifies when close to a new badge',
              value:     _badgeNotifEnabled,
              onChanged: (val) async {
                setState(() => _badgeNotifEnabled = val);
                await NotificationService().setBadgeNotifEnabled(val);
              },
            ),
          ]),

          const SizedBox(height: 20),

          // ── Password ─────────────────────────────────────────
          _buildSectionHeader('Change Password'),
          Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.paddingL),
            child: Container(
              padding: const EdgeInsets.all(AppTheme.paddingL),
              decoration: BoxDecoration(
                color:        AppTheme.surface,
                borderRadius: BorderRadius.circular(AppTheme.radiusL),
                border: Border.all(color: AppTheme.surfaceBorder),
              ),
              child: Form(
                key: _passwordFormKey,
                child: Column(children: [
                  // Security tip
                  Container(
                    padding: const EdgeInsets.all(AppTheme.paddingM),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.07),
                      borderRadius:
                      BorderRadius.circular(AppTheme.radiusS),
                      border: Border.all(
                          color: AppTheme.primary
                              .withValues(alpha: 0.15)),
                    ),
                    child: const Row(children: [
                      Icon(Icons.shield_outlined,
                          color: AppTheme.primary, size: 16),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Use letters, numbers and symbols for a strong password.',
                          style: TextStyle(color: AppTheme.primary,
                              fontSize: 12, height: 1.4),
                        ),
                      ),
                    ]),
                  ),

                  const SizedBox(height: 16),

                  CustomTextField(
                    label:      'Current Password',
                    hint:       'Enter current password',
                    controller: _currentPasswordController,
                    icon:       Icons.lock_outline,
                    isPassword: true,
                    validator:  Validators.password,
                  ),

                  const SizedBox(height: 14),

                  // Divider with label
                  Row(children: [
                    const Expanded(
                        child: Divider(
                            color: AppTheme.surfaceBorder)),
                    Padding(
                      padding:
                      const EdgeInsets.symmetric(horizontal: 10),
                      child: Text('New Password',
                          style: TextStyle(fontSize: 11,
                              color: AppTheme.textSecondary
                                  .withValues(alpha: 0.7),
                              fontWeight: FontWeight.w600)),
                    ),
                    const Expanded(
                        child: Divider(
                            color: AppTheme.surfaceBorder)),
                  ]),

                  const SizedBox(height: 14),

                  CustomTextField(
                    label:      'New Password',
                    hint:       'Enter new password',
                    controller: _newPasswordController,
                    icon:       Icons.lock_outline,
                    isPassword: true,
                    validator:  Validators.password,
                  ),

                  const SizedBox(height: 14),

                  CustomTextField(
                    label:      'Confirm New Password',
                    hint:       'Repeat new password',
                    controller: _confirmPasswordController,
                    icon:       Icons.lock_outline,
                    isPassword: true,
                    validator:  (v) => Validators.confirmPassword(
                        v, _newPasswordController.text),
                    textInputAction: TextInputAction.done,
                  ),

                  const SizedBox(height: 20),

                  if (_passwordError   != null) ...[
                    _buildBanner(_passwordError!,   isError: true),
                    const SizedBox(height: 12),
                  ],
                  if (_passwordSuccess != null) ...[
                    _buildBanner(_passwordSuccess!, isError: false),
                    const SizedBox(height: 12),
                  ],

                  PrimaryButton(
                    label:     'Update Password',
                    onPressed: _handleUpdatePassword,
                    isLoading: _isUpdatingPassword,
                  ),
                ]),
              ),
            ),
          ),

          const SizedBox(height: 20),

          // ── Danger zone ──────────────────────────────────────
          _buildSectionHeader('Danger Zone'),
          Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.paddingL),
            child: Container(
              decoration: BoxDecoration(
                color:        AppTheme.surface,
                borderRadius: BorderRadius.circular(AppTheme.radiusL),
                border: Border.all(
                    color: AppTheme.error.withValues(alpha: 0.2)),
              ),
              child: Column(children: [
                _buildDangerRow(
                  icon:      Icons.restart_alt_rounded,
                  iconColor: AppTheme.accent,
                  label:     'Reset Account',
                  subtitle:  'Clears all scans, badges and streak',
                  isLoading: _isResettingAccount,
                  onTap:     _handleResetAccount,
                ),
                _buildDivider(),
                _buildDangerRow(
                  icon:      Icons.delete_forever_rounded,
                  iconColor: AppTheme.error,
                  label:     'Delete Account',
                  subtitle:  'Permanently removes your account',
                  isLoading: _isDeletingAccount,
                  onTap:     _handleDeleteAccount,
                ),
              ]),
            ),
          ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }


  // ═══════════════════════════════════════════════════════════════
  //  REUSABLE ROW COMPONENTS
  // ═══════════════════════════════════════════════════════════════

  // ── Section header label ──────────────────────────────────────
  Widget _buildSectionHeader(String label) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppTheme.paddingL, 0, AppTheme.paddingL, 10),
      child: Text(label.toUpperCase(),
          style: const TextStyle(fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppTheme.textSecondary,
              letterSpacing: 1.1)),
    );
  }

  // ── Settings card wrapper ─────────────────────────────────────
  Widget _buildSettingsCard({required List<Widget> children}) {
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.paddingL),
      child: Container(
        decoration: BoxDecoration(
          color:        AppTheme.surface,
          borderRadius: BorderRadius.circular(AppTheme.radiusL),
          border: Border.all(color: AppTheme.surfaceBorder),
        ),
        child: Column(children: children),
      ),
    );
  }

  // ── Info display row (icon + label + value + optional trailing) ─
  Widget _buildInfoRow({
    required IconData icon,
    required Color    iconColor,
    required String   label,
    required String   value,
    Widget?           trailing,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: 16, vertical: 14),
      child: Row(children: [
        Container(
          width: 38, height: 38,
          decoration: BoxDecoration(
            color:        iconColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: iconColor, size: 19),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(fontSize: 11,
                      color: AppTheme.textSecondary,
                      fontWeight: FontWeight.w500)),
              const SizedBox(height: 2),
              Text(value,
                  style: const TextStyle(fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary)),
            ],
          ),
        ),
        if (trailing != null) trailing,
      ]),
    );
  }

  // ── Read-only row with lock icon ──────────────────────────────
  Widget _buildReadOnlyRow({
    required IconData icon,
    required String   label,
    required String   value,
    required String   note,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: 16, vertical: 14),
      child: Row(children: [
        Container(
          width: 38, height: 38,
          decoration: BoxDecoration(
            color: AppTheme.textSecondary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon,
              color: AppTheme.textSecondary, size: 19),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(fontSize: 11,
                      color: AppTheme.textSecondary,
                      fontWeight: FontWeight.w500)),
              const SizedBox(height: 2),
              Text(value,
                  style: const TextStyle(fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary)),
              const SizedBox(height: 1),
              Text(note,
                  style: const TextStyle(fontSize: 11,
                      color: AppTheme.textSecondary)),
            ],
          ),
        ),
        const Icon(Icons.lock_outline,
            color: AppTheme.textSecondary, size: 16),
      ]),
    );
  }

  // ── Action row (for sign out etc) ─────────────────────────────
  Widget _buildActionRow({
    required IconData icon,
    required Color    iconColor,
    required String   label,
    required Color    labelColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap:        onTap,
      borderRadius: BorderRadius.circular(AppTheme.radiusL),
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 14),
        child: Row(children: [
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
              color:        iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 19),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label,
                style: TextStyle(fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: labelColor)),
          ),
          Icon(Icons.chevron_right,
              color: labelColor.withValues(alpha: 0.5), size: 20),
        ]),
      ),
    );
  }

  // ── Toggle row (for notifications) ───────────────────────────
  Widget _buildToggleRow({
    required IconData  icon,
    required Color     iconColor,
    required String    label,
    required String    subtitle,
    required bool      value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: 16, vertical: 12),
      child: Row(children: [
        Container(
          width: 38, height: 38,
          decoration: BoxDecoration(
            color:        iconColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: iconColor, size: 19),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary)),
              Text(subtitle,
                  style: const TextStyle(fontSize: 11,
                      color: AppTheme.textSecondary)),
            ],
          ),
        ),
        Switch(
          value:            value,
          activeThumbColor: iconColor,
          onChanged:        onChanged,
        ),
      ]),
    );
  }

  // ── Danger zone row ───────────────────────────────────────────
  Widget _buildDangerRow({
    required IconData      icon,
    required Color         iconColor,
    required String        label,
    required String        subtitle,
    required bool          isLoading,
    required VoidCallback  onTap,
  }) {
    return InkWell(
      onTap:        isLoading ? null : onTap,
      borderRadius: BorderRadius.circular(AppTheme.radiusL),
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 14),
        child: Row(children: [
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
              color:        iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: isLoading
                ? Center(
              child: SizedBox(
                width: 18, height: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: iconColor),
              ),
            )
                : Icon(icon, color: iconColor, size: 19),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: iconColor)),
                Text(subtitle,
                    style: const TextStyle(fontSize: 11,
                        color: AppTheme.textSecondary)),
              ],
            ),
          ),
          Icon(Icons.chevron_right,
              color: iconColor.withValues(alpha: 0.4), size: 20),
        ]),
      ),
    );
  }

  // ── Thin divider between rows ─────────────────────────────────
  Widget _buildDivider() => const Padding(
    padding: EdgeInsets.symmetric(horizontal: 16),
    child: Divider(color: AppTheme.surfaceBorder, height: 1),
  );

  // ── Success / error banner ────────────────────────────────────
  Widget _buildBanner(String message, {required bool isError}) {
    final color = isError ? AppTheme.error : AppTheme.success;
    return Container(
      width:   double.infinity,
      padding: const EdgeInsets.all(AppTheme.paddingM),
      decoration: BoxDecoration(
        color:        color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppTheme.radiusS),
        border:       Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(children: [
        Icon(isError
            ? Icons.error_outline : Icons.check_circle_outline,
            color: color, size: 18),
        const SizedBox(width: 8),
        Expanded(child: Text(message,
            style: TextStyle(color: color, fontSize: 13))),
      ]),
    );
  }
}


// ═══════════════════════════════════════════════════════════════
//  CROP PAGE — completely unchanged
// ═══════════════════════════════════════════════════════════════

class _CropPage extends StatefulWidget {
  final Uint8List imageBytes;
  const _CropPage({required this.imageBytes});

  @override
  State<_CropPage> createState() => _CropPageState();
}

class _CropPageState extends State<_CropPage> {
  final _cropController = CustomImageCropController();
  bool _isProcessing    = false;

  @override
  void dispose() {
    _cropController.dispose();
    super.dispose();
  }

  Future<void> _confirmCrop() async {
    setState(() => _isProcessing = true);
    final result = await _cropController.onCropImage();
    if (!mounted) return;
    if (result != null) {
      Navigator.of(context).pop(result.bytes);
    } else {
      setState(() => _isProcessing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Could not crop image. Please try again.'),
            backgroundColor: AppTheme.error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor:         AppTheme.surface,
        elevation:               0,
        automaticallyImplyLeading: false,
        leading: IconButton(
          icon: const Icon(Icons.close, color: AppTheme.textPrimary),
          onPressed: () => Navigator.of(context).pop(null),
        ),
        title: const Text('Adjust Your Avatar',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary)),
        centerTitle: true,
        actions: [
          _isProcessing
              ? const Padding(
            padding: EdgeInsets.all(14),
            child: SizedBox(
              width: 20, height: 20,
              child: CircularProgressIndicator(
                  color: AppTheme.primary, strokeWidth: 2),
            ),
          )
              : IconButton(
            icon:     const Icon(Icons.check, color: AppTheme.primary),
            onPressed: _confirmCrop,
          ),
        ],
      ),
      body: Column(children: [
        Container(
          width:   double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 10),
          color:   AppTheme.surface,
          child: const Text('Pinch to zoom  •  Drag to reposition',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12,
                  color: AppTheme.textSecondary)),
        ),
        Expanded(
          child: CustomImageCrop(
            cropController:  _cropController,
            image:           MemoryImage(widget.imageBytes),
            shape:           CustomCropShape.Circle,
            ratio:           Ratio(width: 1, height: 1),
            overlayColor:    Colors.black.withValues(alpha: 0.55),
            backgroundColor: AppTheme.background,
            imageFit:        CustomImageFit.fillCropSpace,
          ),
        ),
        Container(
          width:   double.infinity,
          padding: const EdgeInsets.all(16),
          color:   AppTheme.surface,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildBottomAction(
                icon:  Icons.rotate_left,
                label: 'Rotate Left',
                onTap: () => _cropController.addTransition(
                    CropImageData(angle: -90 * (3.141592 / 180))),
              ),
              _buildBottomAction(
                icon:  Icons.center_focus_strong_outlined,
                label: 'Reset',
                onTap: () => _cropController.reset(),
              ),
              _buildBottomAction(
                icon:  Icons.rotate_right,
                label: 'Rotate Right',
                onTap: () => _cropController.addTransition(
                    CropImageData(angle: 90 * (3.141592 / 180))),
              ),
            ],
          ),
        ),
        SizedBox(height: MediaQuery.of(context).padding.bottom),
      ]),
    );
  }

  Widget _buildBottomAction({
    required IconData      icon,
    required String        label,
    required VoidCallback  onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            color:  AppTheme.primary.withValues(alpha: 0.12),
            shape:  BoxShape.circle,
            border: Border.all(
                color: AppTheme.primary.withValues(alpha: 0.3)),
          ),
          child: Icon(icon, color: AppTheme.primary, size: 22),
        ),
        const SizedBox(height: 4),
        Text(label,
            style: const TextStyle(fontSize: 11,
                color: AppTheme.textSecondary)),
      ]),
    );
  }
}