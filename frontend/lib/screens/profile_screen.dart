// screens/profile_screen.dart
// ============================================================
// Profile screen — hero header, stats bar, tabbed account/security.
//
// AVATAR CHANGES (Step 9):
//   • Hero avatar is now an AvatarWidget (renders emoji/photo/initial)
//   • Tapping the avatar opens _showAvatarPicker() bottom sheet
//   • Bottom sheet has:
//       - Grid of 16 predefined emoji avatars
//       - "Browse from Device" button (image_picker)
//       - "Reset to Initial" option (grey out if already initial)
//   • On selection: calls AuthService.updateAvatar() → saves to DB
//     and calls StorageService.updateAvatar() → updates SharedPrefs
// ============================================================

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/user_model.dart';
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
  bool      _isUpdatingAvatar   = false;   // NEW: avatar upload in progress
  bool      _isEditingName      = false;
  String?   _nameError;
  String?   _passwordError;
  String?   _nameSuccess;
  String?   _passwordSuccess;
  String    _userEmail          = '';
  String    _userName           = '';
  ScanStats? _stats;

  // ── Avatar state ──────────────────────────────────────────────
  String  _avatarType = 'initial';    // 'initial' | 'predefined' | 'custom'
  String? _avatarData;               // avatar ID or base64 JPEG

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
  }


  // ═══════════════════════════════════════════════════════════════
  //  AVATAR — bottom-sheet picker
  // ═══════════════════════════════════════════════════════════════

  /// Opens the avatar selection bottom sheet.
  void _showAvatarPicker() {
    showModalBottomSheet(
      context:           context,
      isScrollControlled: true,
      backgroundColor:   Colors.transparent,
      builder:           (_) => _buildAvatarPickerSheet(),
    );
  }

  Widget _buildAvatarPickerSheet() {
    return Container(
      // Takes up to 85% of screen height
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
          // ── Drag handle ──────────────────────────────────────
          const SizedBox(height: 12),
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(
              color:        AppTheme.surfaceBorder,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),

          // ── Title ─────────────────────────────────────────────
          const Text('Choose Your Avatar',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary)),
          const SizedBox(height: 4),
          const Text('Pick an emoji or upload a photo',
              style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
          const SizedBox(height: 20),

          // ── Predefined emoji grid ──────────────────────────────
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
                  final avatar  = AvatarConstants.predefined[i];
                  final isSelected = _avatarType == 'predefined' &&
                      _avatarData == avatar.id;

                  return GestureDetector(
                    onTap: () => _selectPredefined(avatar),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      decoration: BoxDecoration(
                        color:  avatar.color.withOpacity(isSelected ? 0.3 : 0.12),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected
                              ? avatar.color
                              : Colors.transparent,
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
                          ]
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          // ── Action buttons ────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Column(children: [
              const Divider(color: AppTheme.surfaceBorder),
              const SizedBox(height: 8),

              // Browse from device
              SizedBox(
                width: double.infinity, height: 48,
                child: ElevatedButton.icon(
                  onPressed: _pickFromGallery,
                  icon:  const Icon(Icons.photo_library_outlined, size: 20),
                  label: const Text('Browse from Device',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radiusM)),
                  ),
                ),
              ),

              const SizedBox(height: 10),

              // Reset to initial (disabled if already initial)
              SizedBox(
                width: double.infinity, height: 44,
                child: OutlinedButton.icon(
                  onPressed: _avatarType == 'initial'
                      ? null
                      : _resetToInitial,
                  icon:  const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Reset to Default',
                      style: TextStyle(fontSize: 14)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.textSecondary,
                    side: BorderSide(color: AppTheme.surfaceBorder),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radiusM)),
                  ),
                ),
              ),

              // Safe-area bottom padding
              SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
            ]),
          ),
        ],
      ),
    );
  }


  // ── Select predefined emoji avatar ────────────────────────────
  Future<void> _selectPredefined(PredefinedAvatar avatar) async {
    Navigator.of(context).pop();  // Close bottom sheet first
    await _saveAvatar(avatarType: 'predefined', avatarData: avatar.id);
  }


  // ── Pick image from device gallery ────────────────────────────
  Future<void> _pickFromGallery() async {
    Navigator.of(context).pop(); // Close avatar picker bottom sheet

    // Step 1: Pick image from gallery
    final picked = await _imagePicker.pickImage(
      source:       ImageSource.gallery,
      imageQuality: 90,
    );
    if (picked == null || !mounted) return;

    final bytes = await picked.readAsBytes();

    // Step 2: Open our custom Flutter crop page
    // This is a full-screen page we control entirely — no native toolbar
    final croppedBytes = await Navigator.of(context).push<Uint8List>(
      MaterialPageRoute(
        builder: (_) => _CropPage(imageBytes: bytes),
      ),
    );

    if (croppedBytes == null || !mounted) return;

    // Step 3: Convert to base64 and save
    final base64Str = base64Encode(croppedBytes);
    await _saveAvatar(avatarType: 'custom', avatarData: base64Str);
  }

  // ── Reset to letter initial ───────────────────────────────────
  Future<void> _resetToInitial() async {
    Navigator.of(context).pop();
    await _saveAvatar(avatarType: 'initial', avatarData: null);
  }


  // ── Call API + update local state ─────────────────────────────
  Future<void> _saveAvatar({
    required String avatarType,
    String?         avatarData,
  }) async {
    setState(() => _isUpdatingAvatar = true);

    final result = await _authService.updateAvatar(
      avatarType: avatarType,
      avatarData: avatarData,
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
        SnackBar(
          content:         Text(result.message),
          backgroundColor: AppTheme.error,
        ),
      );
    }
  }


  // ═══════════════════════════════════════════════════════════════
  //  NAME UPDATE
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
      setState(() {
        _isUpdatingName = false;
        _nameError      = result.message;
      });
    }
  }


  // ═══════════════════════════════════════════════════════════════
  //  PASSWORD UPDATE
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
  //  LOGOUT
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
          pageBuilder:      (_, __, ___) => const LoginScreen(),
          transitionsBuilder: (_, animation, __, child) =>
              FadeTransition(opacity: animation, child: child),
          transitionDuration: const Duration(milliseconds: 400),
        ),
            (route) => false,
      );
    }
  }


  // ═══════════════════════════════════════════════════════════════
  //  BUILD
  // ═══════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: _isLoadingProfile
          ? const Center(
          child: CircularProgressIndicator(color: AppTheme.primary))
          : NestedScrollView(
        headerSliverBuilder: (_, __) => [
          SliverToBoxAdapter(child: _buildHeroHeader()),
        ],
        body: Column(children: [
          _buildTabBar(),
          Expanded(child: TabBarView(
            controller: _tabController,
            children: [
              _buildAccountTab(),
              _buildSecurityTab(),
            ],
          )),
        ]),
      ),
    );
  }


  // ── Hero Header ───────────────────────────────────────────────
  Widget _buildHeroHeader() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF111827), Color(0xFF0A0E1A)],
          begin: Alignment.topCenter,
          end:   Alignment.bottomCenter,
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(children: [

          // ── Back button row ──────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_new,
                    color: AppTheme.textPrimary, size: 20),
                onPressed: () => Navigator.of(context).pop(),
              ),
              const Expanded(
                child: Text('My Profile',
                    style: TextStyle(fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary)),
              ),
            ]),
          ),

          const SizedBox(height: 16),

          // ── Avatar with edit overlay ──────────────────────────
          GestureDetector(
            onTap: _isUpdatingAvatar ? null : _showAvatarPicker,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // The avatar circle (with glowing ring)
                AvatarWidget(
                  avatarType: _avatarType,
                  avatarData: _avatarData,
                  name:       _userName,
                  size:       90,
                  showRing:   true,
                ),

                // Loading indicator overlay
                if (_isUpdatingAvatar)
                  Positioned.fill(
                    child: Container(
                      decoration: const BoxDecoration(
                        color:  Colors.black45,
                        shape:  BoxShape.circle,
                      ),
                      child: const Center(
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      ),
                    ),
                  ),

                // Edit pencil badge (bottom-right)
                Positioned(
                  bottom: 0,
                  right:  0,
                  child: Container(
                    width: 28, height: 28,
                    decoration: BoxDecoration(
                      color:  AppTheme.primary,
                      shape:  BoxShape.circle,
                      border: Border.all(color: AppTheme.background, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color:      AppTheme.primary.withOpacity(0.4),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: const Icon(Icons.edit, color: Colors.white, size: 14),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 4),

          // Subtle hint below avatar
          const Text('Tap to change',
              style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),

          const SizedBox(height: 10),

          // ── Name ─────────────────────────────────────────────
          Text(_userName, style: const TextStyle(fontSize: 22,
              fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),

          const SizedBox(height: 4),

          // ── Email ────────────────────────────────────────────
          Text(_userEmail, style: const TextStyle(fontSize: 14,
              color: AppTheme.textSecondary)),

          const SizedBox(height: 24),

          // ── Stats bar ────────────────────────────────────────
          _buildStatsBar(),

          const SizedBox(height: 24),
        ]),
      ),
    );
  }


  // ── Stats Bar ─────────────────────────────────────────────────
  Widget _buildStatsBar() {
    return Container(
      margin:  const EdgeInsets.symmetric(horizontal: AppTheme.paddingL),
      padding: const EdgeInsets.symmetric(
          vertical: AppTheme.paddingM, horizontal: AppTheme.paddingL),
      decoration: BoxDecoration(
        color:        AppTheme.surface2,
        borderRadius: BorderRadius.circular(AppTheme.radiusM),
        border:       Border.all(color: AppTheme.surfaceBorder),
      ),
      child: Row(children: [
        _buildStatItem('Total Scans', '${_stats?.totalScans ?? 0}', AppTheme.primary),
        _buildStatDivider(),
        _buildStatItem('Authentic',   '${_stats?.totalReal  ?? 0}', AppTheme.success),
        _buildStatDivider(),
        _buildStatItem('Deepfakes',   '${_stats?.totalFake  ?? 0}', AppTheme.error),
      ]),
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Expanded(
      child: Column(children: [
        Text(value, style: TextStyle(fontSize: 22,
            fontWeight: FontWeight.w800, color: color)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 11,
            color: AppTheme.textSecondary)),
      ]),
    );
  }

  Widget _buildStatDivider() =>
      Container(width: 1, height: 36, color: AppTheme.surfaceBorder);


  // ── Tab Bar ───────────────────────────────────────────────────
  Widget _buildTabBar() {
    return Container(
      color: AppTheme.surface,
      child: TabBar(
        controller:            _tabController,
        indicatorColor:        AppTheme.primary,
        indicatorWeight:       2,
        labelColor:            AppTheme.primary,
        unselectedLabelColor:  AppTheme.textSecondary,
        labelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        tabs: const [Tab(text: 'Account'), Tab(text: 'Security')],
      ),
    );
  }


  // ── Account Tab ───────────────────────────────────────────────
  Widget _buildAccountTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppTheme.paddingL),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SizedBox(height: 8),
        _buildSectionLabel('Display Name'),
        const SizedBox(height: 12),
        _buildNameSection(),
        const SizedBox(height: 16),
        _buildBadgesRow(),
        const SizedBox(height: 24),
        _buildSectionLabel('Email Address'),
        const SizedBox(height: 24),
        _buildSectionLabel('Email Address'),
        const SizedBox(height: 12),
        _buildReadOnlyField(
          icon:  Icons.email_outlined,
          value: _userEmail,
          note:  'Email cannot be changed',
        ),
        const SizedBox(height: 32),
        _buildLogoutButton(),
        const SizedBox(height: 32),
      ]),
    );
  }

  Widget _buildNameSection() {
    return Container(
      padding: const EdgeInsets.all(AppTheme.paddingL),
      decoration: AppTheme.cardDecoration(),
      child: _isEditingName
          ? Form(
        key: _nameFormKey,
        child: Column(children: [
          CustomTextField(
            label: 'Full Name', hint: 'Enter your new name',
            controller: _nameController, icon: Icons.person_outline,
            validator: Validators.name,
            textInputAction: TextInputAction.done,
          ),
          const SizedBox(height: 16),
          if (_nameError   != null) ...[_buildBanner(_nameError!,   isError: true),  const SizedBox(height: 12)],
          if (_nameSuccess != null) ...[_buildBanner(_nameSuccess!, isError: false), const SizedBox(height: 12)],
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
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusM)),
                ),
                child: const Text('Cancel'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: PrimaryButton(
                label: 'Save', onPressed: _handleUpdateName,
                isLoading: _isUpdatingName,
              ),
            ),
          ]),
        ]),
      )
          : Row(children: [
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            color:        AppTheme.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(AppTheme.radiusS),
          ),
          child: const Icon(Icons.person_outline, color: AppTheme.primary, size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Full Name', style: TextStyle(
                fontSize: 12, color: AppTheme.textSecondary)),
            const SizedBox(height: 2),
            Text(_userName, style: const TextStyle(fontSize: 16,
                fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
          ]),
        ),
        GestureDetector(
          onTap: () => setState(() {
            _isEditingName = true;
            _nameSuccess   = null;
            _nameError     = null;
          }),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color:  AppTheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppTheme.primary.withOpacity(0.3)),
            ),
            child: const Text('Edit', style: TextStyle(
                color: AppTheme.primary, fontSize: 13, fontWeight: FontWeight.w600)),
          ),
        ),
      ]),
    );
  }

  Widget _buildReadOnlyField({
    required IconData icon, required String value, required String note,
  }) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.paddingL),
      decoration: AppTheme.cardDecoration(),
      child: Row(children: [
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            color:        AppTheme.textSecondary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(AppTheme.radiusS),
          ),
          child: Icon(icon, color: AppTheme.textSecondary, size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(value, style: const TextStyle(fontSize: 16,
              fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
          const SizedBox(height: 2),
          Text(note, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
        ])),
        const Icon(Icons.lock_outline, color: AppTheme.textSecondary, size: 18),
      ]),
    );
  }

  Widget _buildLogoutButton() {
    return SizedBox(
      width: double.infinity, height: 52,
      child: OutlinedButton.icon(
        onPressed: _handleLogout,
        icon:  const Icon(Icons.logout, size: 18),
        label: const Text('Sign Out',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppTheme.error,
          side: BorderSide(color: AppTheme.error.withOpacity(0.5)),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusM)),
        ),
      ),
    );
  }

  Widget _buildBadgesRow() {
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const BadgesScreen()),
      ),
      child: Container(
        padding: const EdgeInsets.all(AppTheme.paddingL),
        decoration: AppTheme.cardDecoration(
            borderColor: AppTheme.accent.withOpacity(0.3)),
        child: Row(children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color:        AppTheme.accent.withOpacity(0.1),
              borderRadius: BorderRadius.circular(AppTheme.radiusS),
            ),
            child: const Icon(Icons.emoji_events_rounded,
                color: AppTheme.accent, size: 22),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Badges & Streaks',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary)),
              Text('View your achievements',
                  style: TextStyle(fontSize: 12,
                      color: AppTheme.textSecondary)),
            ]),
          ),
          const Icon(Icons.chevron_right,
              color: AppTheme.textSecondary, size: 20),
        ]),
      ),
    );
  }


  // ── Security Tab ──────────────────────────────────────────────
  Widget _buildSecurityTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppTheme.paddingL),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(AppTheme.paddingM),
          decoration: BoxDecoration(
            color:        AppTheme.primary.withOpacity(0.08),
            borderRadius: BorderRadius.circular(AppTheme.radiusM),
            border:       Border.all(color: AppTheme.primary.withOpacity(0.2)),
          ),
          child: const Row(children: [
            Icon(Icons.info_outline, color: AppTheme.primary, size: 18),
            SizedBox(width: 10),
            Expanded(
              child: Text('Use a strong password with letters, numbers and symbols.',
                  style: TextStyle(color: AppTheme.primary, fontSize: 13, height: 1.4)),
            ),
          ]),
        ),
        const SizedBox(height: 20),
        _buildSectionLabel('Change Password'),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(AppTheme.paddingL),
          decoration: AppTheme.cardDecoration(),
          child: Form(
            key: _passwordFormKey,
            child: Column(children: [
              CustomTextField(
                label: 'Current Password', hint: 'Enter current password',
                controller: _currentPasswordController,
                icon: Icons.lock_outline, isPassword: true,
                validator: Validators.password,
              ),
              const SizedBox(height: 16),
              Row(children: [
                const Expanded(child: Divider(color: AppTheme.surfaceBorder)),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Text('New Password', style: TextStyle(
                      fontSize: 12, color: AppTheme.textSecondary)),
                ),
                const Expanded(child: Divider(color: AppTheme.surfaceBorder)),
              ]),
              const SizedBox(height: 16),
              CustomTextField(
                label: 'New Password', hint: 'Enter new password',
                controller: _newPasswordController,
                icon: Icons.lock_outline, isPassword: true,
                validator: Validators.password,
              ),
              const SizedBox(height: 16),
              CustomTextField(
                label: 'Confirm New Password', hint: 'Repeat new password',
                controller: _confirmPasswordController,
                icon: Icons.lock_outline, isPassword: true,
                validator: (v) =>
                    Validators.confirmPassword(v, _newPasswordController.text),
                textInputAction: TextInputAction.done,
              ),
              const SizedBox(height: 20),
              if (_passwordError   != null) ...[_buildBanner(_passwordError!,   isError: true),  const SizedBox(height: 12)],
              if (_passwordSuccess != null) ...[_buildBanner(_passwordSuccess!, isError: false), const SizedBox(height: 12)],
              PrimaryButton(
                label: 'Update Password', onPressed: _handleUpdatePassword,
                isLoading: _isUpdatingPassword,
              ),
            ]),
          ),
        ),
        const SizedBox(height: 32),
      ]),
    );
  }


  // ── Helpers ───────────────────────────────────────────────────
  Widget _buildSectionLabel(String label) {
    return Text(label.toUpperCase(),
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
            color: AppTheme.textSecondary, letterSpacing: 1.0));
  }

  Widget _buildBanner(String message, {required bool isError}) {
    final color = isError ? AppTheme.error : AppTheme.success;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppTheme.paddingM),
      decoration: BoxDecoration(
        color:        color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppTheme.radiusS),
        border:       Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(children: [
        Icon(isError ? Icons.error_outline : Icons.check_circle_outline,
            color: color, size: 18),
        const SizedBox(width: 8),
        Expanded(child: Text(message, style: TextStyle(color: color, fontSize: 13))),
      ]),
    );
  }
}

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
        const SnackBar(content: Text('Could not crop image. Please try again.'),
            backgroundColor: AppTheme.error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        elevation: 0,
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
              ? const Padding(padding: EdgeInsets.all(14),
              child: SizedBox(width: 20, height: 20,
                  child: CircularProgressIndicator(
                      color: AppTheme.primary, strokeWidth: 2)))
              : IconButton(
            icon: const Icon(Icons.check, color: AppTheme.primary),
            onPressed: _confirmCrop,
          ),
        ],
      ),
      body: Column(children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 10),
          color: AppTheme.surface,
          child: const Text('Pinch to zoom  •  Drag to reposition',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
        ),
        Expanded(
          child: CustomImageCrop(
            cropController:  _cropController,
            image:           MemoryImage(widget.imageBytes),
            shape:           CustomCropShape.Circle,
            ratio:           Ratio(width: 1, height: 1),
            overlayColor:    Colors.black.withOpacity(0.55),
            backgroundColor: AppTheme.background,
            imageFit:        CustomImageFit.fillCropSpace,
          ),
        ),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          color: AppTheme.surface,
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
            _buildBottomAction(icon: Icons.rotate_left, label: 'Rotate Left',
                onTap: () => _cropController.addTransition(
                    CropImageData(angle: -90 * (3.141592 / 180)))),
            _buildBottomAction(icon: Icons.center_focus_strong_outlined, label: 'Reset',
                onTap: () => _cropController.reset()),
            _buildBottomAction(icon: Icons.rotate_right, label: 'Rotate Right',
                onTap: () => _cropController.addTransition(
                    CropImageData(angle: 90 * (3.141592 / 180)))),
          ]),
        ),
        SizedBox(height: MediaQuery.of(context).padding.bottom),
      ]),
    );
  }

  Widget _buildBottomAction({
    required IconData icon, required String label, required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            color:  AppTheme.primary.withOpacity(0.12),
            shape:  BoxShape.circle,
            border: Border.all(color: AppTheme.primary.withOpacity(0.3)),
          ),
          child: Icon(icon, color: AppTheme.primary, size: 22),
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 11,
            color: AppTheme.textSecondary)),
      ]),
    );
  }
}

