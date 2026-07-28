// File: lib/screens/settings_screen.dart
import 'package:flutter/material.dart';

import '../models/api_profile.dart';
import '../models/api_provider.dart';
import '../services/api_profile_service.dart';
import '../services/ai_api_service.dart';
import '../services/theme_service.dart';

class SettingsScreen extends StatefulWidget {
  final ApiProfileService profileService;
  final ThemeService? themeService;
  final VoidCallback? onProfileChanged;

  const SettingsScreen({
    super.key,
    required this.profileService,
    this.themeService,
    this.onProfileChanged,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with TickerProviderStateMixin {
  late AnimationController _fabController;

  @override
  void initState() {
    super.initState();
    _fabController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    )..forward();
  }

  @override
  void dispose() {
    _fabController.dispose();
    super.dispose();
  }

  // ─── Design helpers ───
  bool get _isDark => Theme.of(context).brightness == Brightness.dark;
  Color get _bg => _isDark ? const Color(0xFF24272C) : const Color(0xFFF0F2F5);
  Color get _surface => _bg;
  Color get _primary => const Color(0xFF1A73E8);
  Color get _textPrimary =>
      _isDark ? const Color(0xFFE2E8F0) : const Color(0xFF1E293B);
  Color get _textSecondary =>
      _isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
  Color get _textTertiary =>
      _isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8);
  Color get _border =>
      _isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05);
  Color get _error => const Color(0xFFDC2626);
  Color get _success => const Color(0xFF059669);

  List<BoxShadow> get _shadowSmall => [
    BoxShadow(
      color: _isDark
          ? Colors.black.withValues(alpha: 0.4)
          : const Color(0xFFA3B1C6).withValues(alpha: 0.5),
      offset: const Offset(3, 3),
      blurRadius: 6,
    ),
    BoxShadow(
      color: _isDark ? Colors.white.withValues(alpha: 0.04) : Colors.white,
      offset: const Offset(-3, -3),
      blurRadius: 6,
    ),
  ];

  BorderRadius get _radiusSm => BorderRadius.circular(10);
  BorderRadius get _radiusMd => BorderRadius.circular(16);
  BorderRadius get _radiusLg => BorderRadius.circular(24);

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.profileService,
      builder: (context, _) {
        final profiles = widget.profileService.profiles;
        final activeId = widget.profileService.activeProfile?.id;

        return Scaffold(
          backgroundColor: _bg,
          appBar: AppBar(
            backgroundColor: _bg,
            elevation: 0,
            leading: IconButton(
              icon: Icon(Icons.arrow_back_rounded, color: _textPrimary),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(
              'Settings',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: _textPrimary,
                letterSpacing: -0.5,
              ),
            ),
            centerTitle: false,
          ),
          body: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            children: [
              // ═══ API Profiles Section ═══
              _sectionHeader('API Profiles', Icons.key_rounded),
              const SizedBox(height: 12),

              if (profiles.isEmpty) _buildNoProfilesCard(),

              ...profiles.map(
                (p) => _buildProfileCard(p, isActive: p.id == activeId),
              ),

              const SizedBox(height: 12),
              _buildAddProfileButton(),

              const SizedBox(height: 28),

              // ═══ Appearance Section ═══
              _sectionHeader('Appearance', Icons.palette_rounded),
              const SizedBox(height: 12),
              _buildThemeCard(),

              const SizedBox(height: 28),

              // ═══ About Section ═══
              _sectionHeader('About', Icons.info_outline_rounded),
              const SizedBox(height: 12),
              _buildAboutCard(),

              const SizedBox(height: 40),
            ],
          ),
        );
      },
    );
  }

  Widget _sectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _primary.withValues(alpha: 0.1),
            borderRadius: _radiusSm,
          ),
          child: Icon(icon, color: _primary, size: 18),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: _textPrimary,
            letterSpacing: -0.3,
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════
  // NO PROFILES CARD
  // ═══════════════════════════════════════
  Widget _buildNoProfilesCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: _radiusMd,
        boxShadow: _shadowSmall,
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _primary.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.vpn_key_rounded, color: _primary, size: 32),
          ),
          const SizedBox(height: 16),
          Text(
            'No API Profiles Yet',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: _textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Add an API profile to start chatting with AI models.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: _textSecondary, height: 1.4),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════
  // PROFILE CARD
  // ═══════════════════════════════════════
  Widget _buildProfileCard(ApiProfile profile, {bool isActive = false}) {
    final provider = ApiProviderRegistry.getProvider(profile.provider);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: _radiusMd,
          onTap: () => _onProfileTap(profile),
          onLongPress: () => _showProfileActions(profile),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: _radiusMd,
              boxShadow: isActive ? _shadowSmall : null,
              border: isActive
                  ? Border.all(
                      color: _primary.withValues(alpha: 0.3),
                      width: 1.5,
                    )
                  : Border.all(color: _border),
            ),
            child: Row(
              children: [
                // Provider Icon
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: isActive
                        ? provider.color
                        : provider.color.withValues(alpha: 0.12),
                    borderRadius: _radiusSm,
                    boxShadow: isActive
                        ? [
                            BoxShadow(
                              color: provider.color.withValues(alpha: 0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: Icon(
                    provider.icon,
                    color: isActive ? Colors.white : provider.color,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 14),
                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              profile.name,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: isActive
                                    ? FontWeight.w800
                                    : FontWeight.w600,
                                color: isActive ? _primary : _textPrimary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isActive) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: _primary,
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: const Text(
                                'ACTIVE',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: provider.color.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              provider.displayName,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: provider.color,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            profile.maskedKey,
                            style: TextStyle(
                              fontSize: 11,
                              color: _textTertiary,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ],
                      ),
                      if (profile.selectedModel != null) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.smart_toy_rounded,
                              size: 11,
                              color: _textTertiary,
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                profile.selectedModel!.split('/').last,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: _textTertiary,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                // Actions
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _miniIconBtn(
                      Icons.edit_outlined,
                      Colors.blue,
                      () => _showEditProfileSheet(profile),
                    ),
                    const SizedBox(width: 4),
                    _miniIconBtn(
                      Icons.delete_outline_rounded,
                      Colors.red,
                      () => _confirmDelete(profile),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _miniIconBtn(IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: _radiusSm,
        ),
        child: Icon(icon, size: 15, color: color.withValues(alpha: 0.7)),
      ),
    );
  }

  // ═══════════════════════════════════════
  // ADD PROFILE BUTTON
  // ═══════════════════════════════════════
  Widget _buildAddProfileButton() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: _radiusMd,
        onTap: () => _showAddProfileSheet(),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: _primary.withValues(alpha: 0.06),
            borderRadius: _radiusMd,
            border: Border.all(
              color: _primary.withValues(alpha: 0.2),
              width: 1.5,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add_rounded, color: _primary, size: 20),
              const SizedBox(width: 8),
              Text(
                'Add New Profile',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: _primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════
  // THEME CARD
  // ═══════════════════════════════════════
  Widget _buildThemeCard() {
    final isDark = widget.themeService?.themeMode == ThemeMode.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: _radiusMd,
        boxShadow: _shadowSmall,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: (isDark ? _primary : Colors.orange).withValues(
                alpha: 0.12,
              ),
              borderRadius: _radiusSm,
            ),
            child: Icon(
              isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
              color: isDark ? _primary : Colors.orange,
              size: 20,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Theme',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: _textPrimary,
                  ),
                ),
                Text(
                  isDark ? 'Dark Mode' : 'Light Mode',
                  style: TextStyle(fontSize: 12, color: _textSecondary),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => widget.themeService?.toggleTheme(),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 52,
              height: 28,
              decoration: BoxDecoration(
                color: _bg,
                borderRadius: BorderRadius.circular(14),
                boxShadow: _shadowSmall,
              ),
              child: Stack(
                children: [
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOutBack,
                    left: isDark ? 26 : 2,
                    top: 2,
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: isDark ? _primary : Colors.orange,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: (isDark ? _primary : Colors.orange)
                                .withValues(alpha: 0.3),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Icon(
                        isDark
                            ? Icons.dark_mode_rounded
                            : Icons.light_mode_rounded,
                        color: Colors.white,
                        size: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════
  // ABOUT CARD
  // ═══════════════════════════════════════
  Widget _buildAboutCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: _radiusMd,
        boxShadow: _shadowSmall,
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.smart_toy_rounded, color: _primary, size: 22),
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'JagadAI',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: _textPrimary,
                    ),
                  ),
                  Text(
                    'Multi-Provider AI Assistant',
                    style: TextStyle(fontSize: 12, color: _textSecondary),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Divider(color: _border, height: 1),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.verified_rounded, size: 14, color: _textTertiary),
              const SizedBox(width: 8),
              Text(
                'Version 3.0.1 — Multi-Provider Edition',
                style: TextStyle(fontSize: 12, color: _textTertiary),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════
  // PROFILE ACTIONS
  // ═══════════════════════════════════════
  void _onProfileTap(ApiProfile profile) async {
    if (widget.profileService.activeProfile?.id == profile.id) return;
    await widget.profileService.setActiveProfile(profile.id);
    widget.onProfileChanged?.call();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white, size: 16),
              const SizedBox(width: 8),
              Text('Switched to "${profile.name}"'),
            ],
          ),
          backgroundColor: _primary,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _showProfileActions(ApiProfile profile) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: _border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Text(
              profile.name,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: _textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            _actionTile(
              Icons.check_circle_outline,
              'Set as Active',
              _primary,
              () {
                Navigator.pop(ctx);
                _onProfileTap(profile);
              },
            ),
            _actionTile(Icons.edit_outlined, 'Edit Profile', Colors.blue, () {
              Navigator.pop(ctx);
              _showEditProfileSheet(profile);
            }),
            _actionTile(Icons.delete_outline, 'Delete Profile', Colors.red, () {
              Navigator.pop(ctx);
              _confirmDelete(profile);
            }),
            SizedBox(height: MediaQuery.of(ctx).padding.bottom + 8),
          ],
        ),
      ),
    );
  }

  Widget _actionTile(
    IconData icon,
    String label,
    Color color,
    VoidCallback onTap,
  ) {
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(
        label,
        style: TextStyle(fontWeight: FontWeight.w600, color: _textPrimary),
      ),
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: _radiusSm),
    );
  }

  void _confirmDelete(ApiProfile profile) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _surface,
        shape: RoundedRectangleBorder(borderRadius: _radiusLg),
        title: Text(
          'Delete Profile?',
          style: TextStyle(fontWeight: FontWeight.w800, color: _textPrimary),
        ),
        content: Text(
          'Are you sure you want to delete "${profile.name}"? This cannot be undone.',
          style: TextStyle(color: _textSecondary, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: _textSecondary)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await widget.profileService.deleteProfile(profile.id);
              widget.onProfileChanged?.call();
            },
            style: TextButton.styleFrom(foregroundColor: _error),
            child: const Text(
              'Delete',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════
  // ADD / EDIT PROFILE SHEET
  // ═══════════════════════════════════════
  void _showAddProfileSheet() {
    _showProfileFormSheet(null);
  }

  void _showEditProfileSheet(ApiProfile profile) {
    _showProfileFormSheet(profile);
  }

  void _showProfileFormSheet(ApiProfile? existing) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ProfileFormSheet(
        existing: existing,
        isDark: _isDark,
        onSave: (profile) async {
          if (existing != null) {
            await widget.profileService.updateProfile(profile);
          } else {
            await widget.profileService.addProfile(profile);
          }
          widget.onProfileChanged?.call();
        },
      ),
    );
  }
}

// ═══════════════════════════════════════════════════
// PROFILE FORM BOTTOM SHEET (Stateful)
// ═══════════════════════════════════════════════════
class _ProfileFormSheet extends StatefulWidget {
  final ApiProfile? existing;
  final bool isDark;
  final Future<void> Function(ApiProfile profile) onSave;

  const _ProfileFormSheet({
    this.existing,
    required this.isDark,
    required this.onSave,
  });

  @override
  State<_ProfileFormSheet> createState() => _ProfileFormSheetState();
}

class _ProfileFormSheetState extends State<_ProfileFormSheet> {
  late String _selectedProvider;
  late TextEditingController _nameCtrl;
  late TextEditingController _keyCtrl;
  late TextEditingController _baseUrlCtrl;
  late TextEditingController _maxTokensCtrl;
  late double _maxTokens;
  bool _obscureKey = true;
  bool _isTesting = false;
  bool? _testResult;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _selectedProvider = widget.existing?.provider ?? 'openrouter';
    _nameCtrl = TextEditingController(text: widget.existing?.name ?? '');
    _keyCtrl = TextEditingController(text: widget.existing?.apiKey ?? '');
    _baseUrlCtrl = TextEditingController(text: widget.existing?.baseUrl ?? '');
    _maxTokens = (widget.existing?.maxTokens ?? 16000).toDouble();
    _maxTokensCtrl = TextEditingController(text: _maxTokens.toInt().toString());
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _keyCtrl.dispose();
    _baseUrlCtrl.dispose();
    _maxTokensCtrl.dispose();
    super.dispose();
  }

  bool get _isDark => widget.isDark;
  Color get _bg => _isDark ? const Color(0xFF24272C) : const Color(0xFFF0F2F5);
  Color get _surface => _bg;
  Color get _primary => const Color(0xFF1A73E8);
  Color get _textPrimary =>
      _isDark ? const Color(0xFFE2E8F0) : const Color(0xFF1E293B);
  Color get _textSecondary =>
      _isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
  Color get _textTertiary =>
      _isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8);
  Color get _border =>
      _isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05);
  Color get _error => const Color(0xFFDC2626);
  Color get _success => const Color(0xFF059669);

  List<BoxShadow> get _shadowSmall => [
    BoxShadow(
      color: _isDark
          ? Colors.black.withValues(alpha: 0.4)
          : const Color(0xFFA3B1C6).withValues(alpha: 0.5),
      offset: const Offset(3, 3),
      blurRadius: 6,
    ),
    BoxShadow(
      color: _isDark ? Colors.white.withValues(alpha: 0.04) : Colors.white,
      offset: const Offset(-3, -3),
      blurRadius: 6,
    ),
  ];

  BorderRadius get _radiusSm => BorderRadius.circular(10);
  BorderRadius get _radiusMd => BorderRadius.circular(16);

  @override
  Widget build(BuildContext context) {
    final provider = ApiProviderRegistry.getProvider(_selectedProvider);
    final isEdit = widget.existing != null;
    final bottomPad = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 10, bottom: 4),
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: _border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Title
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _primary,
                    borderRadius: _radiusSm,
                    boxShadow: [
                      BoxShadow(
                        color: _primary.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(
                    isEdit ? Icons.edit_rounded : Icons.add_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isEdit ? 'Edit Profile' : 'New API Profile',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: _textPrimary,
                        letterSpacing: -0.5,
                      ),
                    ),
                    Text(
                      isEdit
                          ? 'Update your API configuration'
                          : 'Connect to an AI provider',
                      style: TextStyle(fontSize: 12, color: _textTertiary),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Form
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(20, 0, 20, bottomPad + 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ─── Provider Selector ───
                  _label('Provider'),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 80,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: ApiProviderRegistry.providerIds.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 10),
                      itemBuilder: (_, i) {
                        final pid = ApiProviderRegistry.providerIds[i];
                        final prov = ApiProviderRegistry.getProvider(pid);
                        final selected = pid == _selectedProvider;
                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedProvider = pid;
                              _testResult = null;
                              if (_nameCtrl.text.isEmpty ||
                                  ApiProviderRegistry.allProviders.any(
                                    (p) => p.displayName == _nameCtrl.text,
                                  )) {
                                _nameCtrl.text = prov.displayName;
                              }
                            });
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: 90,
                            padding: const EdgeInsets.symmetric(
                              vertical: 10,
                              horizontal: 8,
                            ),
                            decoration: BoxDecoration(
                              color: selected
                                  ? prov.color.withValues(alpha: 0.12)
                                  : _bg,
                              borderRadius: _radiusMd,
                              border: Border.all(
                                color: selected ? prov.color : _border,
                                width: selected ? 2 : 1,
                              ),
                              boxShadow: selected ? _shadowSmall : null,
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  prov.icon,
                                  color: selected ? prov.color : _textTertiary,
                                  size: 22,
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  pid == 'custom' ? 'Custom' : prov.displayName,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: selected
                                        ? FontWeight.w800
                                        : FontWeight.w600,
                                    color: selected
                                        ? prov.color
                                        : _textSecondary,
                                  ),
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: provider.color.withValues(alpha: 0.06),
                      borderRadius: _radiusSm,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 14,
                          color: provider.color,
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            provider.description,
                            style: TextStyle(
                              fontSize: 11,
                              color: provider.color,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ─── Profile Name ───
                  _label('Profile Name'),
                  const SizedBox(height: 8),
                  _inputField(
                    controller: _nameCtrl,
                    hint: 'e.g., My OpenAI, Work Account',
                    icon: Icons.badge_outlined,
                  ),

                  const SizedBox(height: 20),

                  // ─── API Key ───
                  _label('API Key'),
                  const SizedBox(height: 8),
                  _inputField(
                    controller: _keyCtrl,
                    hint: 'Enter your API key...',
                    icon: Icons.vpn_key_outlined,
                    obscure: _obscureKey,
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureKey
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        color: _textTertiary,
                        size: 20,
                      ),
                      onPressed: () =>
                          setState(() => _obscureKey = !_obscureKey),
                    ),
                  ),

                  // ─── Base URL (Custom only) ───
                  if (provider.requiresBaseUrl) ...[
                    const SizedBox(height: 20),
                    _label('Base URL'),
                    const SizedBox(height: 8),
                    _inputField(
                      controller: _baseUrlCtrl,
                      hint: 'e.g., http://localhost:11434/v1',
                      icon: Icons.link_rounded,
                    ),
                  ],

                  const SizedBox(height: 20),

                  // ─── Max Tokens ───
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _label('Max Tokens'),
                      Text(
                        _maxTokens.toInt().toString(),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: _primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: _bg,
                      borderRadius: _radiusMd,
                      boxShadow: _shadowSmall,
                    ),
                    padding: const EdgeInsets.symmetric(
                      vertical: 8,
                      horizontal: 16,
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.token_outlined,
                              color: _textTertiary,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextField(
                                controller: _maxTokensCtrl,
                                keyboardType: TextInputType.number,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: _textPrimary,
                                ),
                                decoration: InputDecoration(
                                  hintText: 'e.g., 16000',
                                  hintStyle: TextStyle(
                                    color: _textTertiary,
                                    fontSize: 13,
                                  ),
                                  border: InputBorder.none,
                                  isDense: true,
                                ),
                                onChanged: (val) {
                                  final parsed = double.tryParse(val);
                                  if (parsed != null &&
                                      parsed >= 100 &&
                                      parsed <= 128000) {
                                    setState(() {
                                      _maxTokens = parsed;
                                    });
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                        SliderTheme(
                          data: SliderThemeData(
                            trackHeight: 4,
                            activeTrackColor: _primary,
                            inactiveTrackColor: _border,
                            thumbColor: _primary,
                            overlayColor: _primary.withValues(alpha: 0.1),
                            thumbShape: const RoundSliderThumbShape(
                              enabledThumbRadius: 6,
                            ),
                            overlayShape: const RoundSliderOverlayShape(
                              overlayRadius: 16,
                            ),
                          ),
                          child: Slider(
                            value: _maxTokens,
                            min: 100,
                            max: 128000,
                            divisions: 1279,
                            onChanged: (val) {
                              setState(() {
                                _maxTokens = val;
                                _maxTokensCtrl.text = val.toInt().toString();
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ─── Test Connection ───
                  Row(
                    children: [
                      Expanded(
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: _radiusMd,
                            onTap: _isTesting ? null : _testConnection,
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              decoration: BoxDecoration(
                                color: _bg,
                                borderRadius: _radiusMd,
                                boxShadow: _shadowSmall,
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  if (_isTesting)
                                    SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: _primary,
                                      ),
                                    )
                                  else if (_testResult == true)
                                    Icon(
                                      Icons.check_circle,
                                      color: _success,
                                      size: 18,
                                    )
                                  else if (_testResult == false)
                                    Icon(
                                      Icons.error_outline,
                                      color: _error,
                                      size: 18,
                                    )
                                  else
                                    Icon(
                                      Icons.wifi_find,
                                      color: _primary,
                                      size: 18,
                                    ),
                                  const SizedBox(width: 8),
                                  Text(
                                    _isTesting
                                        ? 'Testing...'
                                        : _testResult == true
                                        ? 'Connected!'
                                        : _testResult == false
                                        ? 'Failed'
                                        : 'Test Connection',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: _isTesting
                                          ? _textSecondary
                                          : _testResult == true
                                          ? _success
                                          : _testResult == false
                                          ? _error
                                          : _primary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // ─── Save Button ───
                  SizedBox(
                    width: double.infinity,
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: _radiusMd,
                        onTap: _isSaving ? null : _saveProfile,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          decoration: BoxDecoration(
                            color: _primary,
                            borderRadius: _radiusMd,
                            boxShadow: [
                              BoxShadow(
                                color: _primary.withValues(alpha: 0.3),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (_isSaving)
                                const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              else
                                const Icon(
                                  Icons.save_rounded,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              const SizedBox(width: 10),
                              Text(
                                _isSaving
                                    ? 'Saving...'
                                    : isEdit
                                    ? 'Update Profile'
                                    : 'Save Profile',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  letterSpacing: -0.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool get isEdit => widget.existing != null;

  Widget _label(String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: _textSecondary,
        letterSpacing: 0.2,
      ),
    );
  }

  Widget _inputField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool obscure = false,
    Widget? suffixIcon,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: _bg,
        borderRadius: _radiusMd,
        boxShadow: _shadowSmall,
      ),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        style: TextStyle(fontSize: 14, color: _textPrimary),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: _textTertiary, fontSize: 13),
          prefixIcon: Icon(icon, color: _textTertiary, size: 20),
          suffixIcon: suffixIcon,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
        ),
      ),
    );
  }

  Future<void> _testConnection() async {
    final key = _keyCtrl.text.trim();
    if (key.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please enter an API key first'),
          backgroundColor: _error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
      return;
    }

    setState(() {
      _isTesting = true;
      _testResult = null;
    });

    final tempProfile = ApiProfile.create(
      name: 'test',
      provider: _selectedProvider,
      apiKey: key,
      baseUrl: _selectedProvider == 'custom' ? _baseUrlCtrl.text.trim() : null,
      maxTokens: _maxTokens.toInt(),
    );

    try {
      final service = AiApiService(profile: tempProfile);
      final result = await service.testConnection();
      if (mounted) setState(() => _testResult = result);
    } catch (e) {
      if (mounted) setState(() => _testResult = false);
    } finally {
      if (mounted) setState(() => _isTesting = false);
    }
  }

  Future<void> _saveProfile() async {
    final name = _nameCtrl.text.trim();
    final key = _keyCtrl.text.trim();
    final baseUrl = _baseUrlCtrl.text.trim();

    if (name.isEmpty || key.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please fill in name and API key'),
          backgroundColor: _error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
      return;
    }

    if (_selectedProvider == 'custom' && baseUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please enter a base URL for custom provider'),
          backgroundColor: _error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final profile = widget.existing != null
          ? widget.existing!.copyWith(
              name: name,
              provider: _selectedProvider,
              apiKey: key,
              baseUrl: _selectedProvider == 'custom' ? baseUrl : null,
              maxTokens: _maxTokens.toInt(),
            )
          : ApiProfile.create(
              name: name,
              provider: _selectedProvider,
              apiKey: key,
              baseUrl: _selectedProvider == 'custom' ? baseUrl : null,
              maxTokens: _maxTokens.toInt(),
            );

      await widget.onSave(profile);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 16),
                const SizedBox(width: 8),
                Text(isEdit ? 'Profile updated!' : 'Profile saved!'),
              ],
            ),
            backgroundColor: _success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: _error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}
