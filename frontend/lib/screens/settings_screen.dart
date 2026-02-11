import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../providers/settings_provider.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';

/// 설정 화면 (토스 스타일)
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('설정'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Consumer<SettingsProvider>(
        builder: (context, settings, child) {
          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: AppSpacing.md),

                // 테마 설정 섹션
                _buildSection(
                  context,
                  title: '화면',
                  children: [
                    _buildThemeSelector(context, settings),
                  ],
                ),

                const SizedBox(height: AppSpacing.lg),

                // 알림 설정 섹션 (드롭다운 방식)
                _buildSection(
                  context,
                  title: '알림',
                  children: [
                    _buildNotificationDropdown(context, settings),
                    if (settings.notificationMode != NotificationMode.allOff &&
                        (settings.notificationMode == NotificationMode.scheduleOnly ||
                         settings.notificationMode == NotificationMode.allOn)) ...[
                      _buildDivider(context),
                      _buildReminderDaysSelector(context, settings),
                    ],
                  ],
                ),

                const SizedBox(height: AppSpacing.lg),

                // 데이터 섹션
                _buildSection(
                  context,
                  title: '데이터',
                  children: [
                    _buildActionTile(
                      context,
                      icon: Icons.cached_outlined,
                      title: '캐시 초기화',
                      subtitle: '임시 저장된 데이터 삭제',
                      onTap: () => _showClearCacheDialog(context, settings),
                    ),
                    _buildDivider(context),
                    _buildActionTile(
                      context,
                      icon: Icons.restart_alt_outlined,
                      title: '설정 초기화',
                      subtitle: '모든 설정을 기본값으로 되돌리기',
                      onTap: () => _showResetSettingsDialog(context, settings),
                    ),
                  ],
                ),

                const SizedBox(height: AppSpacing.lg),

                // 계정 섹션
                _buildSection(
                  context,
                  title: '계정',
                  children: [
                    _buildActionTile(
                      context,
                      icon: Icons.person_remove_outlined,
                      title: '회원 탈퇴',
                      subtitle: '계정 및 데이터가 영구 삭제됩니다',
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _showDeleteAccountDialog(context),
                    ),
                  ],
                ),

                const SizedBox(height: AppSpacing.xxl),
              ],
            ),
          );
        },
      ),
    );
  }

  /// 섹션 빌더
  Widget _buildSection(BuildContext context, {
    required String title,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white60
                  : AppTheme.textSecondary,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          decoration: BoxDecoration(
            color: Theme.of(context).cardTheme.color,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            boxShadow: AppShadow.soft,
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  /// 테마 선택기
  Widget _buildThemeSelector(BuildContext context, SettingsProvider settings) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.palette_outlined,
                size: 22,
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white70
                    : AppTheme.textSecondary,
              ),
              const SizedBox(width: AppSpacing.md),
              const Expanded(
                child: Text(
                  '테마',
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              _buildThemeOption(
                context,
                settings,
                mode: ThemeMode.system,
                icon: Icons.brightness_auto,
                label: '시스템',
              ),
              const SizedBox(width: AppSpacing.sm),
              _buildThemeOption(
                context,
                settings,
                mode: ThemeMode.light,
                icon: Icons.light_mode,
                label: '라이트',
              ),
              const SizedBox(width: AppSpacing.sm),
              _buildThemeOption(
                context,
                settings,
                mode: ThemeMode.dark,
                icon: Icons.dark_mode,
                label: '다크',
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 테마 옵션 버튼
  Widget _buildThemeOption(
    BuildContext context,
    SettingsProvider settings, {
    required ThemeMode mode,
    required IconData icon,
    required String label,
  }) {
    final isSelected = settings.themeMode == mode;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // 다크모드에서 primaryColor는 배경과 동일하므로 primaryLight 사용
    final accentColor = isDark ? AppTheme.primaryLight : AppTheme.primaryColor;
    return Expanded(
      child: GestureDetector(
        onTap: () => settings.setThemeMode(mode),
        child: AnimatedContainer(
          duration: AppDuration.fast,
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
          decoration: BoxDecoration(
            color: isSelected
                ? accentColor.withOpacity(0.15)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
              color: isSelected
                  ? accentColor
                  : (isDark ? Colors.white24 : Colors.grey.withOpacity(0.3)),
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                color: isSelected
                    ? accentColor
                    : Theme.of(context).iconTheme.color?.withOpacity(0.6),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  color: isSelected
                      ? accentColor
                      : Theme.of(context).textTheme.bodyMedium?.color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 알림 드롭다운
  Widget _buildNotificationDropdown(BuildContext context, SettingsProvider settings) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          Icon(
            Icons.notifications_outlined,
            size: 22,
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.white70
                : AppTheme.textSecondary,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('알림 설정', style: TextStyle(fontSize: 16)),
                Text(
                  '공지사항 및 일정 알림',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.white60
                        : AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Builder(
            builder: (context) {
              final isDarkDropdown = Theme.of(context).brightness == Brightness.dark;
              final dropdownAccent = isDarkDropdown ? AppTheme.primaryLight : AppTheme.primaryColor;
              return GestureDetector(
                onTap: () => _showNotificationModeSheet(context, settings),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: dropdownAccent.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(
                      color: dropdownAccent.withOpacity(0.4),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        settings.notificationModeDisplayText,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: isDarkDropdown ? Colors.white : AppTheme.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  /// 마감 알림 일수 선택기
  Widget _buildReminderDaysSelector(BuildContext context, SettingsProvider settings) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          Icon(
            Icons.timer_outlined,
            size: 22,
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.white70
                : AppTheme.textSecondary,
          ),
          const SizedBox(width: AppSpacing.md),
          const Expanded(
            child: Text('알림 시점', style: TextStyle(fontSize: 16)),
          ),
          GestureDetector(
            onTap: () => _showReminderDaysSheet(context, settings),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.1),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'D-${settings.deadlineReminderDays}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
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

  /// 액션 타일 (클릭 가능)
  Widget _buildActionTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    String? subtitle,
    Widget? trailing,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            Icon(
              icon,
              size: 22,
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white70
                  : AppTheme.textSecondary,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 16)),
                  if (subtitle != null)
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.white60
                            : AppTheme.textSecondary,
                      ),
                    ),
                ],
              ),
            ),
            if (trailing != null)
              IconTheme(
                data: IconThemeData(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white54
                      : AppTheme.textSecondary,
                  size: 20,
                ),
                child: trailing,
              ),
          ],
        ),
      ),
    );
  }

  /// 구분선
  Widget _buildDivider(BuildContext context) {
    return Divider(
      height: 1,
      indent: AppSpacing.md + 22 + AppSpacing.md,
      color: Theme.of(context).brightness == Brightness.dark
          ? Colors.white12
          : Colors.grey.shade200,
    );
  }

  /// 캐시 초기화 다이얼로그
  void _showClearCacheDialog(BuildContext context, SettingsProvider settings) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('캐시 초기화'),
        content: const Text('임시 저장된 데이터를 삭제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () {
              settings.clearCache();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('캐시가 초기화되었습니다')),
              );
            },
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  /// 설정 초기화 다이얼로그
  void _showResetSettingsDialog(BuildContext context, SettingsProvider settings) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('설정 초기화'),
        content: const Text('모든 설정을 기본값으로 되돌리시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () {
              settings.resetToDefaults();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('설정이 초기화되었습니다')),
              );
            },
            child: Text('확인', style: TextStyle(color: AppTheme.errorColor)),
          ),
        ],
      ),
    );
  }

  /// 알림 설정 Bottom Sheet
  void _showNotificationModeSheet(BuildContext context, SettingsProvider settings) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final options = <MapEntry<NotificationMode, String>>[
      const MapEntry(NotificationMode.allOn, '모두 켬'),
      const MapEntry(NotificationMode.noticeOnly, '공지만'),
      const MapEntry(NotificationMode.scheduleOnly, '일정만'),
      const MapEntry(NotificationMode.allOff, '모두 끔'),
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: isDark ? Theme.of(context).scaffoldBackgroundColor : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 드래그 핸들
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // 제목
              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Text(
                  '알림 설정',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : AppTheme.textPrimary,
                  ),
                ),
              ),
              Divider(height: 1, color: isDark ? Colors.white12 : Colors.grey.shade200),
              // 옵션 리스트
              ...options.map((entry) {
                final isSelected = settings.notificationMode == entry.key;
                return ListTile(
                  title: Text(
                    entry.value,
                    style: TextStyle(
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                      color: isSelected
                          ? (isDark ? AppTheme.primaryLight : AppTheme.primaryColor)
                          : (isDark ? Colors.white : AppTheme.textPrimary),
                    ),
                  ),
                  trailing: isSelected
                      ? Icon(Icons.check, color: isDark ? AppTheme.primaryLight : AppTheme.primaryColor)
                      : null,
                  onTap: () {
                    settings.setNotificationMode(entry.key);
                    Navigator.pop(context);
                  },
                );
              }),
              const SizedBox(height: AppSpacing.md),
            ],
          ),
        ),
      ),
    );
  }

  /// 알림 시점 Bottom Sheet
  void _showReminderDaysSheet(BuildContext context, SettingsProvider settings) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dayOptions = [1, 2, 3, 5, 7];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: isDark ? Theme.of(context).scaffoldBackgroundColor : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 드래그 핸들
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // 제목
              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Text(
                  '알림 시점',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : AppTheme.textPrimary,
                  ),
                ),
              ),
              Divider(height: 1, color: isDark ? Colors.white12 : Colors.grey.shade200),
              // 옵션 리스트
              ...dayOptions.map((days) {
                final isSelected = settings.deadlineReminderDays == days;
                return ListTile(
                  title: Text(
                    'D-$days',
                    style: TextStyle(
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                      color: isSelected
                          ? (isDark ? AppTheme.primaryLight : AppTheme.primaryColor)
                          : (isDark ? Colors.white : AppTheme.textPrimary),
                    ),
                  ),
                  subtitle: Text(
                    '마감 $days일 전 알림',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white38 : AppTheme.textHint,
                    ),
                  ),
                  trailing: isSelected
                      ? Icon(Icons.check, color: isDark ? AppTheme.primaryLight : AppTheme.primaryColor)
                      : null,
                  onTap: () {
                    settings.setDeadlineReminderDays(days);
                    Navigator.pop(context);
                  },
                );
              }),
              const SizedBox(height: AppSpacing.md),
            ],
          ),
        ),
      ),
    );
  }

  /// 회원 탈퇴 확인 다이얼로그
  void _showDeleteAccountDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('회원 탈퇴'),
        content: const Text(
          '탈퇴 시 계정 정보와 저장된 데이터가 모두 삭제되며, 복구할 수 없습니다.\n\n정말 탈퇴하시겠습니까?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              try {
                final userId = Supabase.instance.client.auth.currentUser?.id;
                if (userId != null) {
                  await context.read<ApiService>().deleteUser(userId);
                }
                await context.read<AuthService>().signOut();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('회원 탈퇴가 완료되었습니다')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('탈퇴 처리 중 오류가 발생했습니다: $e')),
                  );
                }
              }
            },
            child: Text(
              '탈퇴',
              style: TextStyle(
                color: AppTheme.errorColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

}
