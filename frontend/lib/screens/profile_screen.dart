// screens/profile_screen.dart
// ============================================================
// Profile screen — professional redesign with hero header,
// stats bar, tabbed account/security sections.
// ============================================================

import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/detection_service.dart';
import '../services/storage_service.dart';
import '../utils/app_theme.dart';
import '../utils/validators.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/primary_button.dart';
import 'login_screen.dart';

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

  // ── Tab controller ────────────────────────────────────────────
  late TabController _tabController;

  // ── State ─────────────────────────────────────────────────────
  bool      _isLoadingProfile   = true;
  bool      _isUpdatingName     = false;
  bool      _isUpdatingPassword = false;
  bool      _isEditingName      = false;
  String?   _nameError;
  String?   _passwordError;
  String?   _nameSuccess;
  String?   _passwordSuccess;
  String    _userEmail          = '';
  String    _userName           = '';
  ScanStats? _stats;

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

    final profileResult = results[0] as dynamic;
    final stats         = results[1] as ScanStats?;

    setState(() {
      if (profileResult.success && profileResult.user != null) {
        _userName            = profileResult.user!.name;
        _userEmail           = profileResult.user!.email;
        _nameController.text = profileResult.user!.name;
      }
      _stats            = stats;
      _isLoadingProfile = false;
    });
  }

  // ── Update name ───────────────────────────────────────────────
  Future<void> _handleUpdateName() async {
    setState(() { _nameError = null; _nameSuccess = null; });
    if (!_nameFormKey.currentState!.validate()) return;
    setState(() => _isUpdatingName = true);

    final result = await _authService.updateProfile(
        name: _nameController.text.trim());

    if (!mounted) return;
    setState(() {
      _isUpdatingName = false;
      if (result.success) {
        _userName      = _nameController.text.trim();
        _nameSuccess   = 'Name updated successfully!';
        _isEditingName = false;
      } else {
        _nameError = result.message;
      }
    });
  }

  // ── Update password ───────────────────────────────────────────
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

  // ── Logout ────────────────────────────────────────────────────
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
          pageBuilder: (_, __, ___) => const LoginScreen(),
          transitionsBuilder: (_, animation, __, child) =>
              FadeTransition(opacity: animation, child: child),
          transitionDuration: const Duration(milliseconds: 400),
        ),
            (route) => false,
      );
    }
  }

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
        body: Column(
          children: [
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
          ],
        ),
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
          end: Alignment.bottomCenter,
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // ── App bar row ──────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 8, vertical: 4),
              child: Row(
                children: [
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
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ── Avatar with gradient ring ─────────────────────
            Container(
              width: 96, height: 96,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: AppTheme.primaryGradient,
                boxShadow: [
                  BoxShadow(color: AppTheme.primary.withOpacity(0.4),
                      blurRadius: 24, spreadRadius: 4),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(3),
                child: Container(
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppTheme.surface,
                  ),
                  child: Center(
                    child: Text(
                      _userName.isNotEmpty
                          ? _userName[0].toUpperCase() : '?',
                      style: const TextStyle(fontSize: 38,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.primary),
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 14),

            // ── Name ─────────────────────────────────────────
            Text(_userName, style: const TextStyle(fontSize: 22,
                fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),

            const SizedBox(height: 4),

            // ── Email ────────────────────────────────────────
            Text(_userEmail, style: const TextStyle(fontSize: 14,
                color: AppTheme.textSecondary)),

            const SizedBox(height: 24),

            // ── Stats bar ────────────────────────────────────
            _buildStatsBar(),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  // ── Stats Bar ─────────────────────────────────────────────────
  Widget _buildStatsBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppTheme.paddingL),
      padding: const EdgeInsets.symmetric(
          vertical: AppTheme.paddingM, horizontal: AppTheme.paddingL),
      decoration: BoxDecoration(
        color: AppTheme.surface2,
        borderRadius: BorderRadius.circular(AppTheme.radiusM),
        border: Border.all(color: AppTheme.surfaceBorder),
      ),
      child: Row(
        children: [
          _buildStatItem('Total Scans',
              '${_stats?.totalScans ?? 0}', AppTheme.primary),
          _buildStatDivider(),
          _buildStatItem('Authentic',
              '${_stats?.totalReal ?? 0}', AppTheme.success),
          _buildStatDivider(),
          _buildStatItem('Deepfakes',
              '${_stats?.totalFake ?? 0}', AppTheme.error),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(value, style: TextStyle(fontSize: 22,
              fontWeight: FontWeight.w800, color: color)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 11,
              color: AppTheme.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildStatDivider() {
    return Container(width: 1, height: 36, color: AppTheme.surfaceBorder);
  }

  // ── Tab Bar ───────────────────────────────────────────────────
  Widget _buildTabBar() {
    return Container(
      color: AppTheme.surface,
      child: TabBar(
        controller: _tabController,
        indicatorColor: AppTheme.primary,
        indicatorWeight: 2,
        labelColor: AppTheme.primary,
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

  // ── Account Tab ───────────────────────────────────────────────
  Widget _buildAccountTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppTheme.paddingL),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),

          // ── Name section ──────────────────────────────────
          _buildSectionLabel('Display Name'),
          const SizedBox(height: 12),
          _buildNameSection(),

          const SizedBox(height: 24),

          // ── Email section (read only) ─────────────────────
          _buildSectionLabel('Email Address'),
          const SizedBox(height: 12),
          _buildReadOnlyField(
            icon:  Icons.email_outlined,
            value: _userEmail,
            note:  'Email cannot be changed',
          ),

          const SizedBox(height: 32),

          // ── Logout ────────────────────────────────────────
          _buildLogoutButton(),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // ── Name Section ─────────────────────────────────────────────
  Widget _buildNameSection() {
    return Container(
      padding: const EdgeInsets.all(AppTheme.paddingL),
      decoration: AppTheme.cardDecoration(),
      child: _isEditingName
          ? Form(
        key: _nameFormKey,
        child: Column(
          children: [
            CustomTextField(
              label:      'Full Name',
              hint:       'Enter your new name',
              controller: _nameController,
              icon:       Icons.person_outline,
              validator:  Validators.name,
              textInputAction: TextInputAction.done,
            ),
            const SizedBox(height: 16),
            if (_nameError != null) ...[
              _buildBanner(_nameError!, isError: true),
              const SizedBox(height: 12),
            ],
            if (_nameSuccess != null) ...[
              _buildBanner(_nameSuccess!, isError: false),
              const SizedBox(height: 12),
            ],
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => setState(() {
                      _isEditingName      = false;
                      _nameController.text = _userName;
                      _nameError          = null;
                    }),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.textSecondary,
                      side: const BorderSide(
                          color: AppTheme.surfaceBorder),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius:
                          BorderRadius.circular(AppTheme.radiusM)),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: PrimaryButton(
                    label:     'Save',
                    onPressed: _handleUpdateName,
                    isLoading: _isUpdatingName,
                  ),
                ),
              ],
            ),
          ],
        ),
      )
          : Row(
        children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: AppTheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(AppTheme.radiusS),
            ),
            child: const Icon(Icons.person_outline,
                color: AppTheme.primary, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Full Name', style: TextStyle(
                    fontSize: 12, color: AppTheme.textSecondary)),
                const SizedBox(height: 2),
                Text(_userName, style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary)),
              ],
            ),
          ),
          // Edit button
          GestureDetector(
            onTap: () => setState(() {
              _isEditingName = true;
              _nameSuccess   = null;
              _nameError     = null;
            }),
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: AppTheme.primary.withOpacity(0.3)),
              ),
              child: const Text('Edit', style: TextStyle(
                  color: AppTheme.primary, fontSize: 13,
                  fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  // ── Read Only Field ───────────────────────────────────────────
  Widget _buildReadOnlyField({
    required IconData icon,
    required String value,
    required String note,
  }) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.paddingL),
      decoration: AppTheme.cardDecoration(),
      child: Row(
        children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: AppTheme.textSecondary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(AppTheme.radiusS),
            ),
            child: Icon(icon, color: AppTheme.textSecondary, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: const TextStyle(fontSize: 16,
                  fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
              const SizedBox(height: 2),
              Text(note, style: const TextStyle(fontSize: 12,
                  color: AppTheme.textSecondary)),
            ],
          )),
          const Icon(Icons.lock_outline,
              color: AppTheme.textSecondary, size: 18),
        ],
      ),
    );
  }

  // ── Logout Button ─────────────────────────────────────────────
  Widget _buildLogoutButton() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton.icon(
        onPressed: _handleLogout,
        icon: const Icon(Icons.logout, size: 18),
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

  // ── Security Tab ──────────────────────────────────────────────
  Widget _buildSecurityTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppTheme.paddingL),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),

          // Info banner
          Container(
            padding: const EdgeInsets.all(AppTheme.paddingM),
            decoration: BoxDecoration(
              color: AppTheme.primary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(AppTheme.radiusM),
              border: Border.all(color: AppTheme.primary.withOpacity(0.2)),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, color: AppTheme.primary, size: 18),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Use a strong password with letters, numbers and symbols.',
                    style: TextStyle(color: AppTheme.primary,
                        fontSize: 13, height: 1.4),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          _buildSectionLabel('Change Password'),
          const SizedBox(height: 12),

          Container(
            padding: const EdgeInsets.all(AppTheme.paddingL),
            decoration: AppTheme.cardDecoration(),
            child: Form(
              key: _passwordFormKey,
              child: Column(
                children: [
                  CustomTextField(
                    label:      'Current Password',
                    hint:       'Enter current password',
                    controller: _currentPasswordController,
                    icon:       Icons.lock_outline,
                    isPassword: true,
                    validator:  Validators.password,
                  ),
                  const SizedBox(height: 16),

                  // Divider with label
                  Row(children: [
                    const Expanded(child: Divider(
                        color: AppTheme.surfaceBorder)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text('New Password', style: const TextStyle(
                          fontSize: 12, color: AppTheme.textSecondary)),
                    ),
                    const Expanded(child: Divider(
                        color: AppTheme.surfaceBorder)),
                  ]),

                  const SizedBox(height: 16),

                  CustomTextField(
                    label:      'New Password',
                    hint:       'Enter new password',
                    controller: _newPasswordController,
                    icon:       Icons.lock_outline,
                    isPassword: true,
                    validator:  Validators.password,
                  ),
                  const SizedBox(height: 16),
                  CustomTextField(
                    label:      'Confirm New Password',
                    hint:       'Repeat new password',
                    controller: _confirmPasswordController,
                    icon:       Icons.lock_outline,
                    isPassword: true,
                    validator: (v) => Validators.confirmPassword(
                        v, _newPasswordController.text),
                    textInputAction: TextInputAction.done,
                  ),
                  const SizedBox(height: 20),
                  if (_passwordError != null) ...[
                    _buildBanner(_passwordError!, isError: true),
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
                ],
              ),
            ),
          ),

          const SizedBox(height: 32),
        ],
      ),
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
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppTheme.radiusS),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(children: [
        Icon(isError ? Icons.error_outline : Icons.check_circle_outline,
            color: color, size: 18),
        const SizedBox(width: 8),
        Expanded(child: Text(message,
            style: TextStyle(color: color, fontSize: 13))),
      ]),
    );
  }
}