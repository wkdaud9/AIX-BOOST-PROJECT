import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/notice.dart';
import '../providers/notice_provider.dart';
import '../theme/app_theme.dart';
import 'notice_detail_screen.dart';

/// mybro 추천 화면 - AI 기반 맞춤형 공지사항 추천
class RecommendScreen extends StatefulWidget {
  const RecommendScreen({super.key});

  @override
  State<RecommendScreen> createState() => _RecommendScreenState();
}

class _RecommendScreenState extends State<RecommendScreen> {
  @override
  void initState() {
    super.initState();
    _loadRecommendations();
  }

  /// AI 맞춤 추천 공지사항 로드
  void _loadRecommendations() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<NoticeProvider>().fetchRecommendedNotices();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Consumer<NoticeProvider>(
        builder: (context, provider, child) {
          return RefreshIndicator(
            onRefresh: () async {
              await Future.wait([
                provider.fetchNotices(),
                provider.fetchRecommendedNotices(),
              ]);
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 헤더
                    _buildHeader(context),
                    const SizedBox(height: 24),

                    // AI 추천 공지사항
                    _buildSection(
                      context,
                      title: 'AI 맞춤 추천',
                      icon: Icons.auto_awesome,
                      color: Colors.purple,
                      description: '당신의 관심사에 맞는 공지사항',
                    ),
                    const SizedBox(height: 16),
                    _buildAIRecommendList(context),

                    const SizedBox(height: 32),

                    // 마감 임박 공지사항
                    _buildSection(
                      context,
                      title: '마감 임박',
                      icon: Icons.alarm,
                      color: Colors.orange,
                      description: '곧 마감되는 공지사항',
                    ),
                    const SizedBox(height: 16),
                    _buildDeadlineSoonList(context),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  /// 헤더
  Widget _buildHeader(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'mybro',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'AI가 추천하는 맞춤형 공지사항',
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  /// 섹션 헤더
  Widget _buildSection(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Color color,
    required String description,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                description,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// AI 추천 공지사항 목록 (백엔드 하이브리드 검색 결과 사용)
  Widget _buildAIRecommendList(BuildContext context) {
    return Consumer<NoticeProvider>(
      builder: (context, provider, child) {
        // 로딩 중 표시
        if (provider.isRecommendedLoading) {
          return const Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final recommended = provider.recommendedNotices;

        if (recommended.isEmpty) {
          return _buildEmptyView('추천할 공지사항이 없습니다', Icons.auto_awesome);
        }

        return Column(
          children: recommended
              .map((notice) => _buildNoticeCard(context, notice))
              .toList(),
        );
      },
    );
  }

  /// 마감 임박 공지사항 목록
  Widget _buildDeadlineSoonList(BuildContext context) {
    return Consumer<NoticeProvider>(
      builder: (context, provider, child) {
        final deadlineSoon = provider.notices
            .where((n) => n.deadline != null && n.isDeadlineSoon)
            .toList();
        deadlineSoon.sort((a, b) => a.deadline!.compareTo(b.deadline!));
        final top5 = deadlineSoon.take(5).toList();

        if (top5.isEmpty) {
          return _buildEmptyView('마감 임박 공지사항이 없습니다', Icons.event_available);
        }

        return Column(
          children: top5
              .map((notice) => _buildNoticeCard(context, notice))
              .toList(),
        );
      },
    );
  }

  /// 공지사항 카드
  Widget _buildNoticeCard(BuildContext context, Notice notice) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => NoticeDetailScreen(noticeId: notice.id),
            ),
          );
        },
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 카테고리, NEW 뱃지, 북마크
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.getCategoryColor(notice.category)
                          .withOpacity(0.1),
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      border: Border.all(
                        color: AppTheme.getCategoryColor(notice.category),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      notice.category,
                      style: TextStyle(
                        color: AppTheme.getCategoryColor(notice.category),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (notice.isNew) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.errorColor,
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      child: const Text(
                        'NEW',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                  const Spacer(),
                  // 북마크 아이콘
                  Consumer<NoticeProvider>(
                    builder: (context, provider, child) {
                      return IconButton(
                        icon: Icon(
                          notice.isBookmarked
                              ? Icons.bookmark
                              : Icons.bookmark_border,
                          size: 20,
                        ),
                        color: notice.isBookmarked
                            ? Theme.of(context).colorScheme.primary
                            : Colors.grey[600],
                        onPressed: () {
                          provider.toggleBookmark(notice.id);
                        },
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        tooltip: notice.isBookmarked ? '북마크 해제' : '북마크 추가',
                      );
                    },
                  ),
                ],
              ),

              const SizedBox(height: AppSpacing.sm),

              // 제목
              Text(
                notice.title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),

              // AI 요약
              if (notice.aiSummary != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.auto_awesome, size: 14, color: Colors.blue.shade700),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          notice.aiSummary!,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.blue.shade900,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: AppSpacing.sm),

              // 메타 정보
              Row(
                children: [
                  Icon(
                    Icons.calendar_today,
                    size: 14,
                    color: AppTheme.textSecondary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    notice.formattedDate,
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Icon(
                    Icons.visibility,
                    size: 14,
                    color: AppTheme.textSecondary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${notice.views}',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  if (notice.deadline != null && notice.daysUntilDeadline != null) ...[
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: notice.isDeadlineSoon
                            ? AppTheme.errorColor
                            : AppTheme.infoColor,
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      child: Text(
                        'D-${notice.daysUntilDeadline}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 빈 뷰
  Widget _buildEmptyView(String message, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(32),
      child: Center(
        child: Column(
          children: [
            Icon(
              icon,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

}
