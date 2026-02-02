import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../services/auth_service.dart';

/// 마이페이지 화면 - 사용자 설정 및 정보
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 사용자 프로필
          _buildUserProfile(context),

          const SizedBox(height: AppSpacing.lg),

          // 알림 설정
          _buildSection(
            context,
            title: '알림 설정',
            items: [
              _buildSettingTile(
                context,
                icon: Icons.notifications_outlined,
                title: '푸시 알림',
                subtitle: '새로운 공지사항 알림 받기',
                trailing: Switch(
                  value: true,
                  onChanged: (value) {
                    // TODO: 알림 설정 변경
                  },
                ),
              ),
              _buildSettingTile(
                context,
                icon: Icons.event_outlined,
                title: '일정 알림',
                subtitle: '마감일 3일 전 알림',
                trailing: Switch(
                  value: true,
                  onChanged: (value) {
                    // TODO: 일정 알림 설정 변경
                  },
                ),
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.lg),

          // 관심 카테고리
          _buildSection(
            context,
            title: '관심 카테고리',
            items: [
              _buildSettingTile(
                context,
                icon: Icons.category_outlined,
                title: '관심 카테고리 설정',
                subtitle: '맞춤 공지사항을 위한 카테고리 선택',
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  _showCategoryDialog(context);
                },
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.lg),

          // 앱 정보
          _buildSection(
            context,
            title: '앱 정보',
            items: [
              _buildSettingTile(
                context,
                icon: Icons.info_outlined,
                title: '버전 정보',
                subtitle: 'v1.0.0',
                onTap: () {},
              ),
              _buildSettingTile(
                context,
                icon: Icons.privacy_tip_outlined,
                title: '개인정보 처리방침',
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  // TODO: 개인정보 처리방침 화면으로 이동
                },
              ),
              _buildSettingTile(
                context,
                icon: Icons.description_outlined,
                title: '이용약관',
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  // TODO: 이용약관 화면으로 이동
                },
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.lg),

          // 계정
          _buildSection(
            context,
            title: '계정',
            items: [
              _buildSettingTile(
                context,
                icon: Icons.logout,
                title: '로그아웃',
                titleColor: AppTheme.errorColor,
                onTap: () {
                  _showLogoutDialog(context);
                },
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }

  /// 사용자 프로필 카드
  Widget _buildUserProfile(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Row(
          children: [
            // 프로필 이미지
            CircleAvatar(
              radius: 40,
              backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
              child: const Icon(
                Icons.person,
                size: 48,
                color: AppTheme.primaryColor,
              ),
            ),

            const SizedBox(width: AppSpacing.md),

            // 사용자 정보
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '군산대학교 학생',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'student@kunsan.ac.kr',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  OutlinedButton.icon(
                    onPressed: () {
                      // TODO: 프로필 편집 화면으로 이동
                    },
                    icon: const Icon(Icons.edit, size: 16),
                    label: const Text('프로필 편집'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.xs,
                      ),
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

  /// 섹션 위젯
  Widget _buildSection(
    BuildContext context, {
    required String title,
    required List<Widget> items,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textSecondary,
                ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Card(
          child: Column(
            children: items,
          ),
        ),
      ],
    );
  }

  /// 설정 항목 타일
  Widget _buildSettingTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    String? subtitle,
    Widget? trailing,
    Color? titleColor,
    VoidCallback? onTap,
  }) {
    return ListTile(
      leading: Icon(
        icon,
        color: titleColor ?? AppTheme.textPrimary,
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w500,
          color: titleColor,
        ),
      ),
      subtitle: subtitle != null ? Text(subtitle) : null,
      trailing: trailing,
      onTap: onTap,
    );
  }

  /// 카테고리 선택 다이얼로그
  void _showCategoryDialog(BuildContext context) {
    final categories = [
      '학사공지',
      '장학',
      '취업',
      '학생활동',
      '시설',
      '기타',
    ];

    final selectedCategories = <String>{
      '학사공지',
      '장학',
    }; // TODO: 실제 사용자 선택 카테고리로 교체

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('관심 카테고리 설정'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: categories.map((category) {
                    final isSelected = selectedCategories.contains(category);
                    return CheckboxListTile(
                      title: Text(category),
                      value: isSelected,
                      activeColor: AppTheme.primaryColor,
                      onChanged: (value) {
                        setState(() {
                          if (value == true) {
                            selectedCategories.add(category);
                          } else {
                            selectedCategories.remove(category);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: const Text('취소'),
                ),
                ElevatedButton(
                  onPressed: () {
                    // TODO: 선택한 카테고리 저장
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('관심 카테고리가 저장되었습니다.'),
                      ),
                    );
                  },
                  child: const Text('저장'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// 로그아웃 확인 다이얼로그
  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Row(
            children: [
              Icon(Icons.logout, color: AppTheme.errorColor),
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
                Navigator.of(context).pop(); // 다이얼로그 닫기

                try {
                  // AuthService.signOut 호출
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
                  // AuthWrapper가 자동으로 LoginScreen으로 전환
                } catch (e) {
                  // 에러 처리
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
