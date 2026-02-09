import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart';
import '../providers/settings_provider.dart';
import '../widgets/modals/version_info_modal.dart';
import '../widgets/modals/privacy_policy_modal.dart';
import '../widgets/modals/terms_of_service_modal.dart';
import '../widgets/modals/profile_edit_modal.dart';

/// 마이페이지 화면 - 사용자 설정 및 정보
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? _userProfile;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  /// 사용자 프로필 로드
  Future<void> _loadUserProfile() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final authService = context.read<AuthService>();
      final apiService = context.read<ApiService>();

      if (authService.currentUser == null) {
        throw Exception('로그인이 필요합니다.');
      }

      final userId = authService.currentUser!.id;
      final profileData = await apiService.getUserProfile(userId);

      setState(() {
        _userProfile = profileData;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 64,
              color: AppTheme.errorColor,
            ),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              style: const TextStyle(color: AppTheme.errorColor),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadUserProfile,
              icon: const Icon(Icons.refresh),
              label: const Text('다시 시도'),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Column(
        children: [
          const SizedBox(height: AppSpacing.md),

          // 프로필 헤더 카드
          _buildProfileHeader(context, isDark),

          const SizedBox(height: AppSpacing.lg),

          // 빠른 액션 버튼 그리드
          _buildQuickActions(context, isDark),

          const SizedBox(height: AppSpacing.lg),

          // 알림 설정 섹션
          Consumer<SettingsProvider>(
            builder: (context, settings, child) {
              return _buildModernSection(
                context,
                isDark: isDark,
                title: '알림',
                icon: Icons.notifications_none_rounded,
                children: [
                  _buildModernTile(
                    context,
                    isDark: isDark,
                    icon: Icons.campaign_rounded,
                    iconColor: AppTheme.infoColor,
                    title: '푸시 알림',
                    subtitle: '새로운 공지사항 알림',
                    trailing: Switch(
                      value: settings.pushNotificationEnabled,
                      onChanged: (value) {
                        settings.setPushNotificationEnabled(value);
                      },
                      activeColor: AppTheme.primaryColor,
                    ),
                  ),
                  Divider(
                    height: 1,
                    indent: 56,
                    color: isDark ? Colors.white10 : Colors.grey.shade100,
                  ),
                  _buildModernTile(
                    context,
                    isDark: isDark,
                    icon: Icons.event_available_rounded,
                    iconColor: AppTheme.successColor,
                    title: '일정 알림',
                    subtitle: '마감 ${settings.deadlineReminderDays}일 전 알림',
                    trailing: Switch(
                      value: settings.scheduleNotificationEnabled,
                      onChanged: (value) {
                        settings.setScheduleNotificationEnabled(value);
                      },
                      activeColor: AppTheme.primaryColor,
                    ),
                  ),
                ],
              );
            },
          ),

          const SizedBox(height: AppSpacing.md),

          // 앱 정보 섹션
          _buildModernSection(
            context,
            isDark: isDark,
            title: '앱 정보',
            icon: Icons.info_outline_rounded,
            children: [
              _buildModernTile(
                context,
                isDark: isDark,
                icon: Icons.new_releases_outlined,
                iconColor: AppTheme.primaryColor,
                title: '버전 정보',
                subtitle: 'v1.0.0',
                trailing: Icon(
                  Icons.chevron_right_rounded,
                  color: isDark ? Colors.white30 : Colors.grey.shade400,
                ),
                onTap: () => VersionInfoModal.show(context),
              ),
              Divider(
                height: 1,
                indent: 56,
                color: isDark ? Colors.white10 : Colors.grey.shade100,
              ),
              _buildModernTile(
                context,
                isDark: isDark,
                icon: Icons.shield_outlined,
                iconColor: AppTheme.secondaryColor,
                title: '개인정보 처리방침',
                trailing: Icon(
                  Icons.chevron_right_rounded,
                  color: isDark ? Colors.white30 : Colors.grey.shade400,
                ),
                onTap: () => PrivacyPolicyModal.show(context),
              ),
              Divider(
                height: 1,
                indent: 56,
                color: isDark ? Colors.white10 : Colors.grey.shade100,
              ),
              _buildModernTile(
                context,
                isDark: isDark,
                icon: Icons.article_outlined,
                iconColor: AppTheme.warningColor,
                title: '이용약관',
                trailing: Icon(
                  Icons.chevron_right_rounded,
                  color: isDark ? Colors.white30 : Colors.grey.shade400,
                ),
                onTap: () => TermsOfServiceModal.show(context),
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.lg),

          // 로그아웃 버튼
          _buildLogoutButton(context, isDark),

          const SizedBox(height: AppSpacing.xxl),
        ],
      ),
    );
  }

  /// 프로필 헤더 카드 - 그라데이션 배경 + 아바타 + 정보
  Widget _buildProfileHeader(BuildContext context, bool isDark) {
    final user = _userProfile?['user'];
    final name = user?['name'] ?? '이름 없음';
    final department = user?['department'] ?? '학과 정보 없음';
    final email = user?['email'] ?? '';

    // 이름에서 이니셜 추출
    final initials = name.isNotEmpty ? name[0] : '?';

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.xl),
        boxShadow: AppShadow.medium,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.xl),
        child: Stack(
          children: [
            // 그라데이션 배경
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 28),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isDark
                      ? [
                          const Color(0xFF3D3577),
                          const Color(0xFF2D2B55),
                        ]
                      : [
                          AppTheme.primaryColor,
                          AppTheme.primaryDark,
                        ],
                ),
              ),
              child: Column(
                children: [
                  // 아바타
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.2),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.4),
                        width: 3,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        initials,
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // 이름
                  Text(
                    '$name님',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: -0.5,
                    ),
                  ),

                  const SizedBox(height: 6),

                  // 학과
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(AppRadius.round),
                    ),
                    child: Text(
                      department,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white.withOpacity(0.9),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),

                  const SizedBox(height: 8),

                  // 이메일
                  Text(
                    email,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withOpacity(0.6),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 빠른 액션 버튼 그리드
  Widget _buildQuickActions(BuildContext context, bool isDark) {
    return Row(
      children: [
        // 프로필 편집 버튼
        Expanded(
          child: _buildActionButton(
            context,
            isDark: isDark,
            icon: Icons.edit_rounded,
            label: '프로필 편집',
            color: AppTheme.primaryColor,
            onTap: () {
              ProfileEditModal.show(
                context,
                initialProfile: _userProfile,
                onSaved: _loadUserProfile,
              );
            },
          ),
        ),
        const SizedBox(width: 12),
        // 고객센터 버튼
        Expanded(
          child: _buildActionButton(
            context,
            isDark: isDark,
            icon: Icons.headset_mic_rounded,
            label: '고객센터',
            color: AppTheme.secondaryColor,
            onTap: () => _showContactDialog(context),
          ),
        ),
      ],
    );
  }

  /// 빠른 액션 버튼 위젯
  Widget _buildActionButton(
    BuildContext context, {
    required bool isDark,
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: isDark ? const Color(0xFF2D2D44) : Colors.white,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            boxShadow: isDark ? null : AppShadow.soft,
          ),
          child: Column(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(height: 10),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : AppTheme.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 모던 섹션 카드
  Widget _buildModernSection(
    BuildContext context, {
    required bool isDark,
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 섹션 타이틀
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 10),
          child: Row(
            children: [
              Icon(
                icon,
                size: 18,
                color: isDark ? Colors.white54 : AppTheme.textSecondary,
              ),
              const SizedBox(width: 6),
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white54 : AppTheme.textSecondary,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
        // 섹션 콘텐츠 카드
        Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF2D2D44) : Colors.white,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            boxShadow: isDark ? null : AppShadow.soft,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            child: Column(children: children),
          ),
        ),
      ],
    );
  }

  /// 모던 설정 타일
  Widget _buildModernTile(
    BuildContext context, {
    required bool isDark,
    required IconData icon,
    required Color iconColor,
    required String title,
    String? subtitle,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: 14,
          ),
          child: Row(
            children: [
              // 아이콘 배경
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Icon(icon, size: 20, color: iconColor),
              ),
              const SizedBox(width: AppSpacing.md),
              // 텍스트
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: isDark ? Colors.white : AppTheme.textPrimary,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark
                              ? Colors.white38
                              : AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              // 트레일링 위젯
              if (trailing != null) trailing,
            ],
          ),
        ),
      ),
    );
  }

  /// 로그아웃 버튼
  Widget _buildLogoutButton(BuildContext context, bool isDark) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () => _showLogoutDialog(context),
        icon: const Icon(Icons.logout_rounded, size: 18),
        label: const Text('로그아웃'),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppTheme.textSecondary,
          side: BorderSide(
            color: isDark ? Colors.white12 : Colors.grey.shade200,
          ),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
        ),
      ),
    );
  }

  /// 고객센터 다이얼로그
  void _showContactDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl),
        ),
        title: const Row(
          children: [
            Icon(Icons.headset_mic_rounded, color: AppTheme.primaryColor),
            SizedBox(width: 12),
            Text('고객센터'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '문의사항이 있으시면 아래 이메일로 연락해주세요.',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: AppSpacing.md),
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: const Row(
                children: [
                  Icon(Icons.email_outlined, size: 20, color: AppTheme.primaryColor),
                  SizedBox(width: AppSpacing.sm),
                  Text(
                    'aix.boost@kunsan.ac.kr',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            const Text(
              '운영시간: 평일 09:00 ~ 18:00',
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  /// 로그아웃 확인 다이얼로그
  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.xl),
          ),
          title: const Row(
            children: [
              Icon(Icons.logout_rounded, color: AppTheme.errorColor),
              SizedBox(width: 12),
              Text('로그아웃'),
            ],
          ),
          content: const Text(
            '정말 로그아웃 하시겠습니까?',
            style: TextStyle(fontSize: 16),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
              ),
              child: const Text('취소'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop();

                try {
                  await context.read<AuthService>().signOut();

                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('로그아웃 되었습니다.'),
                        behavior: SnackBarBehavior.floating,
                        margin: EdgeInsets.all(16),
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('로그아웃 중 오류가 발생했습니다.'),
                        backgroundColor: AppTheme.errorColor,
                        behavior: SnackBarBehavior.floating,
                        margin: const EdgeInsets.all(16),
                      ),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.errorColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
              ),
              child: const Text('로그아웃'),
            ),
          ],
        );
      },
    );
  }
}
