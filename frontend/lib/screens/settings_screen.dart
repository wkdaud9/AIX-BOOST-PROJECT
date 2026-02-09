import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';
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

                // 알림 설정 섹션
                _buildSection(
                  context,
                  title: '알림',
                  children: [
                    _buildSwitchTile(
                      context,
                      icon: Icons.notifications_outlined,
                      title: '푸시 알림',
                      subtitle: '새로운 공지사항 알림 받기',
                      value: settings.pushNotificationEnabled,
                      onChanged: (value) => settings.setPushNotificationEnabled(value),
                    ),
                    _buildDivider(context),
                    _buildSwitchTile(
                      context,
                      icon: Icons.event_outlined,
                      title: '일정 알림',
                      subtitle: '마감일 ${settings.deadlineReminderDays}일 전 알림',
                      value: settings.scheduleNotificationEnabled,
                      onChanged: (value) => settings.setScheduleNotificationEnabled(value),
                    ),
                    if (settings.scheduleNotificationEnabled) ...[
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

                // 지원 섹션
                _buildSection(
                  context,
                  title: '지원',
                  children: [
                    _buildActionTile(
                      context,
                      icon: Icons.help_outline,
                      title: '고객센터',
                      subtitle: 'aix.boost@kunsan.ac.kr',
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _showContactDialog(context),
                    ),
                    _buildDivider(context),
                    _buildActionTile(
                      context,
                      icon: Icons.description_outlined,
                      title: '오픈소스 라이선스',
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _showLicensesDialog(context),
                    ),
                  ],
                ),

                const SizedBox(height: AppSpacing.lg),

                // 앱 정보 섹션
                _buildSection(
                  context,
                  title: '정보',
                  children: [
                    _buildInfoTile(
                      context,
                      icon: Icons.info_outline,
                      title: '앱 버전',
                      value: 'v1.0.0 (Build 1)',
                    ),
                    _buildDivider(context),
                    _buildInfoTile(
                      context,
                      icon: Icons.code_outlined,
                      title: '개발',
                      value: 'AIX-Boost Team',
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
    return Expanded(
      child: GestureDetector(
        onTap: () => settings.setThemeMode(mode),
        child: AnimatedContainer(
          duration: AppDuration.fast,
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
          decoration: BoxDecoration(
            color: isSelected
                ? AppTheme.primaryColor.withOpacity(0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
              color: isSelected
                  ? AppTheme.primaryColor
                  : Colors.grey.withOpacity(0.3),
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                color: isSelected
                    ? AppTheme.primaryColor
                    : Theme.of(context).iconTheme.color?.withOpacity(0.6),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  color: isSelected
                      ? AppTheme.primaryColor
                      : Theme.of(context).textTheme.bodyMedium?.color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 스위치 타일
  Widget _buildSwitchTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    String? subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
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
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: AppTheme.primaryColor,
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
          DropdownButton<int>(
            value: settings.deadlineReminderDays,
            underline: const SizedBox(),
            items: [1, 2, 3, 5, 7].map((days) {
              return DropdownMenuItem(
                value: days,
                child: Text('D-$days'),
              );
            }).toList(),
            onChanged: (value) {
              if (value != null) {
                settings.setDeadlineReminderDays(value);
              }
            },
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

  /// 정보 타일 (읽기 전용)
  Widget _buildInfoTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Padding(
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
            child: Text(title, style: const TextStyle(fontSize: 16)),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white60
                  : AppTheme.textSecondary,
            ),
          ),
        ],
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

  /// 고객센터 다이얼로그
  void _showContactDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('고객센터'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('문의사항이 있으시면 아래 이메일로 연락해주세요.'),
            const SizedBox(height: AppSpacing.md),
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: const Row(
                children: [
                  Icon(Icons.email_outlined, size: 20),
                  SizedBox(width: AppSpacing.sm),
                  Text(
                    'aix.boost@kunsan.ac.kr',
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                ],
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

  /// 오픈소스 라이선스 다이얼로그
  void _showLicensesDialog(BuildContext context) {
    showLicensePage(
      context: context,
      applicationName: 'AIX-Boost',
      applicationVersion: 'v1.0.0',
      applicationLegalese: '© 2025 AIX-Boost Team. All rights reserved.',
    );
  }
}
