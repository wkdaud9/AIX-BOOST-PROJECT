import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart';
import '../providers/notice_provider.dart';

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

          // 관심 카테고리 (강조된 박스 디자인)
          Container(
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppTheme.primaryColor.withValues(alpha: 0.3),
                width: 2,
              ),
            ),
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 헤더 섹션
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.star_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '관심 카테고리',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.primaryColor,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '맞춤 공지사항을 위한 카테고리 선택',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                  color: AppTheme.textSecondary,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: AppSpacing.lg),

                // 현재 선택된 카테고리 표시
                if (_userProfile?['preferences']?['categories'] != null) ...[
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: (_userProfile!['preferences']['categories']
                            as List<dynamic>)
                        .map((category) => category as String)
                        .map((category) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          category,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],

                // 카테고리 변경 버튼
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      _showCategoryDialog(context);
                    },
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('카테고리 변경하기'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg,
                        vertical: AppSpacing.md,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
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
    final user = _userProfile?['user'];
    final name = user?['name'] ?? '이름 없음';
    final department = user?['department'] ?? '학과 정보 없음';
    final email = user?['email'] ?? '';

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
                    '$department $name',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    email,
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
    // 백엔드 카테고리와 일치하는 목록
    final categories = [
      '학사',
      '장학',
      '취업',
      '행사',
      '교육',
      '공모전',
    ];

    // 현재 사용자의 선택된 카테고리로 초기화
    final currentCategories = _userProfile?['preferences']?['categories'];
    final selectedCategories = currentCategories != null
        ? Set<String>.from(currentCategories as List<dynamic>)
        : <String>{};

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
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
                        setDialogState(() {
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
                    Navigator.of(dialogContext).pop();
                  },
                  child: const Text('취소'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    // 최소 1개 이상 선택 확인
                    if (selectedCategories.isEmpty) {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('최소 1개 이상의 카테고리를 선택해주세요.'),
                          backgroundColor: AppTheme.errorColor,
                          behavior: SnackBarBehavior.floating,
                          margin: EdgeInsets.all(16),
                        ),
                      );
                      return;
                    }

                    if (!context.mounted) return;
                    final authService = context.read<AuthService>();
                    final apiService = context.read<ApiService>();
                    final userId = authService.currentUser!.id;

                    if (!dialogContext.mounted) return;
                    Navigator.of(dialogContext).pop();

                    // API 호출하여 카테고리 저장
                    try {
                      await apiService.updateUserPreferences(
                        userId: userId,
                        categories: selectedCategories.toList(),
                      );

                      // UI 갱신을 위해 프로필 다시 로드
                      await _loadUserProfile();

                      // MYBRO 추천 목록도 갱신 (변경된 카테고리 반영)
                      if (context.mounted) {
                        context.read<NoticeProvider>().fetchRecommendedNotices();
                      }

                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('관심 카테고리가 저장되었습니다.'),
                          backgroundColor: AppTheme.primaryColor,
                          behavior: SnackBarBehavior.floating,
                          margin: EdgeInsets.all(16),
                        ),
                      );
                    } catch (e) {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('저장 중 오류가 발생했습니다: ${e.toString().replaceFirst('Exception: ', '')}'),
                          backgroundColor: AppTheme.errorColor,
                          behavior: SnackBarBehavior.floating,
                          margin: const EdgeInsets.all(16),
                        ),
                      );
                    }
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
