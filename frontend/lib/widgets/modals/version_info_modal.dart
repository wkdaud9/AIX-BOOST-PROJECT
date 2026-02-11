import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// 버전 정보 모달 (토스 스타일)
class VersionInfoModal extends StatelessWidget {
  const VersionInfoModal({super.key});

  /// 모달 표시
  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const VersionInfoModal(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.9,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: isDark ? Theme.of(context).scaffoldBackgroundColor : Colors.white,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppRadius.xl),
            ),
          ),
          child: Column(
            children: [
              // 핸들바
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // 헤더
              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        '버전 정보',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),

              const Divider(height: 1),

              // 내용
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 앱 로고 및 버전
                      Center(
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(AppSpacing.lg),
                              decoration: BoxDecoration(
                                color: (isDark ? AppTheme.primaryLight : AppTheme.primaryColor).withOpacity(0.15),
                                borderRadius: BorderRadius.circular(AppRadius.xl),
                              ),
                              child: Icon(
                                Icons.school,
                                size: 48,
                                color: isDark ? AppTheme.primaryLight : AppTheme.primaryColor,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.md),
                            const Text(
                              'HeyBro',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              '버전 1.0.0 (빌드 1)',
                              style: TextStyle(
                                fontSize: 14,
                                color: isDark ? Colors.white60 : AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: AppSpacing.xl),

                      // 업데이트 로그
                      _buildSectionTitle(context, '업데이트 내역'),
                      const SizedBox(height: AppSpacing.md),

                      _buildUpdateItem(
                        context,
                        version: '1.0.0',
                        date: '2025.02.09',
                        changes: [
                          '초기 버전 출시',
                          '공지사항 자동 크롤링 기능',
                          'AI 기반 공지사항 요약 및 추천',
                          '북마크 기반 캘린더 연동',
                          '마감일 알림 기능',
                        ],
                        isLatest: true,
                      ),

                      const SizedBox(height: AppSpacing.xl),

                      // 개발 정보
                      _buildSectionTitle(context, '개발 정보'),
                      const SizedBox(height: AppSpacing.md),

                      _buildInfoRow(context, '개발팀', 'HeyBro Team'),
                      _buildInfoRow(context, '기술 스택', 'Flutter, Flask, Supabase'),
                      _buildInfoRow(context, 'AI 엔진', 'Google Gemini 2.0'),
                      _buildInfoRow(context, '문의', 'mullabproject2026@gmail.com'),

                      const SizedBox(height: AppSpacing.xl),

                      // 저작권
                      Center(
                        child: Text(
                          '© 2025 HeyBro. All rights reserved.',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.white38 : AppTheme.textSecondary,
                          ),
                        ),
                      ),

                      const SizedBox(height: AppSpacing.lg),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildUpdateItem(
    BuildContext context, {
    required String version,
    required String date,
    required List<String> changes,
    bool isLatest = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final accentColor = isDark ? AppTheme.primaryLight : AppTheme.primaryColor;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: isLatest
            ? accentColor.withOpacity(0.15)
            : (isDark ? Colors.white12 : Colors.grey.shade100),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: isLatest
            ? Border.all(color: accentColor.withOpacity(0.3))
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'v$version',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: isLatest ? accentColor : null,
                ),
              ),
              if (isLatest) ...[
                const SizedBox(width: AppSpacing.sm),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: accentColor,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    '최신',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
              const Spacer(),
              Text(
                date,
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.white54 : AppTheme.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          ...changes.map((change) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '• ',
                  style: TextStyle(
                    color: isDark ? Colors.white70 : AppTheme.textSecondary,
                  ),
                ),
                Expanded(
                  child: Text(
                    change,
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? Colors.white70 : AppTheme.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildInfoRow(BuildContext context, String label, String value) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.white60 : AppTheme.textSecondary,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
