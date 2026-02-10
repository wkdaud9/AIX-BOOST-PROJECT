import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/notice.dart';
import '../providers/notice_provider.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../widgets/modals/full_list_modal.dart';
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 히어로 헤더
                    _buildHeroHeader(context, isDark),
                    const SizedBox(height: AppSpacing.lg),

                    // 1. AI 추천 섹션 (최상단)
                    _buildSectionHeader(
                      context,
                      isDark: isDark,
                      title: 'AI 맞춤 추천',
                      icon: Icons.auto_awesome_rounded,
                      color: AppTheme.primaryColor,
                      description: '당신의 관심사에 맞는 공지사항',
                      count: provider.recommendedNotices.length,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _buildAIRecommendList(context, isDark),

                    const SizedBox(height: AppSpacing.xl),

                    // 2. 오늘 꼭 봐야 할 공지 섹션
                    Builder(
                      builder: (context) {
                        final todayMustSee = provider.todayMustSeeNotices;
                        if (todayMustSee.isEmpty) return const SizedBox.shrink();
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildSectionHeader(
                              context,
                              isDark: isDark,
                              title: '오늘 꼭 봐야 할 공지',
                              icon: Icons.push_pin_rounded,
                              color: AppTheme.errorColor,
                              description: '긴급/마감임박/최신 종합 추천',
                              count: todayMustSee.length,
                            ),
                            const SizedBox(height: AppSpacing.md),
                            _buildTodayMustSeeList(context, isDark, todayMustSee),
                            const SizedBox(height: AppSpacing.xl),
                          ],
                        );
                      },
                    ),

                    // 3. 학과/학년 인기 공지 섹션
                    _buildDepartmentPopularSection(context, isDark, provider),

                    // 4. 마감 임박 섹션
                    Builder(
                      builder: (context) {
                        final deadlineSoon = provider.notices
                            .where((n) =>
                                n.deadline != null && n.isDeadlineSoon)
                            .toList();
                        return _buildSectionHeader(
                          context,
                          isDark: isDark,
                          title: '마감 임박',
                          icon: Icons.alarm_rounded,
                          color: AppTheme.warningColor,
                          description: '곧 마감되는 공지사항',
                          count: deadlineSoon.length,
                        );
                      },
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _buildDeadlineSoonList(context, isDark),

                    const SizedBox(height: AppSpacing.xxl),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  /// 히어로 헤더 카드 - 그라데이션 배경
  Widget _buildHeroHeader(BuildContext context, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.xl),
        boxShadow: AppShadow.medium,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.xl),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? [const Color(0xFF3D3577), const Color(0xFF2D2B55)]
                  : [AppTheme.primaryColor, AppTheme.primaryDark],
            ),
          ),
          child: Row(
            children: [
              // 텍스트 영역
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'mybro',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'AI가 추천하는 맞춤형 공지사항',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withOpacity(0.8),
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
              // AI 아이콘
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 섹션 헤더 (아이콘 + 타이틀 + 건수)
  Widget _buildSectionHeader(
    BuildContext context, {
    required bool isDark,
    required String title,
    required IconData icon,
    required Color color,
    required String description,
    int count = 0,
  }) {
    return Row(
      children: [
        // 아이콘 배경
        Container(
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
            color: color.withOpacity(isDark ? 0.2 : 0.1),
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        const SizedBox(width: AppSpacing.md),
        // 타이틀 + 설명
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : AppTheme.textPrimary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (count > 0) ...[
                    const SizedBox(width: AppSpacing.sm),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.15),
                        borderRadius:
                            BorderRadius.circular(AppRadius.round),
                      ),
                      child: Text(
                        '$count건',
                        style: TextStyle(
                          color: color,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.white54 : AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// AI 추천 공지사항 목록 (최대 5개 미리보기 + 전체보기)
  Widget _buildAIRecommendList(BuildContext context, bool isDark) {
    return Consumer<NoticeProvider>(
      builder: (context, provider, child) {
        if (provider.isRecommendedLoading) {
          return _buildLoadingSkeleton(isDark);
        }

        final recommended = provider.recommendedNotices;

        if (recommended.isEmpty) {
          return _buildEmptyView(
            '추천할 공지사항이 없습니다',
            Icons.auto_awesome_rounded,
            isDark,
          );
        }

        // 최대 5개만 미리보기
        const previewCount = 5;
        final previewItems = recommended.take(previewCount).toList();
        final hasMore = recommended.length > previewCount;

        return Column(
          children: [
            ...previewItems
                .map((notice) => _buildNoticeCard(context, notice, isDark)),
            // 전체보기 버튼 (5개 초과 시)
            if (hasMore)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.sm),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => FullListModal.showAIRecommend(context),
                    icon: const Icon(Icons.list_alt_rounded, size: 18),
                    label: Text('전체보기 (${recommended.length}건)'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.primaryColor,
                      side: BorderSide(
                        color: AppTheme.primaryColor.withOpacity(0.4),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  /// 오늘 꼭 봐야 할 공지 목록 (최대 5개 + 전체보기)
  Widget _buildTodayMustSeeList(BuildContext context, bool isDark, List<Notice> notices) {
    return Column(
      children: [
        ...notices.map((notice) => _buildNoticeCard(context, notice, isDark)),
        if (notices.length >= 5)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.sm),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => FullListModal.showTodayMustSee(context),
                icon: const Icon(Icons.list_alt_rounded, size: 18),
                label: Text('전체보기 (${notices.length}건)'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.errorColor,
                  side: BorderSide(
                    color: AppTheme.errorColor.withOpacity(0.4),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  /// 학과/학년 인기 공지 섹션
  Widget _buildDepartmentPopularSection(BuildContext context, bool isDark, NoticeProvider provider) {
    final authService = context.watch<AuthService>();
    final department = authService.department;
    final grade = authService.grade;

    final notices = provider.getDepartmentPopularNotices(department, grade);
    if (notices.isEmpty) return const SizedBox.shrink();

    final deptLabel = department ?? '전체';
    final gradeLabel = grade != null ? ' $grade학년' : '';
    final sectionTitle = '$deptLabel$gradeLabel 학생들이 많이 본 공지';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          context,
          isDark: isDark,
          title: sectionTitle,
          icon: Icons.star_rounded,
          color: AppTheme.infoColor,
          description: '조회수 + 관련도 기준 인기 공지',
          count: notices.length,
        ),
        const SizedBox(height: AppSpacing.md),
        ...notices.map((notice) => _buildNoticeCard(context, notice, isDark)),
        if (notices.length >= 5)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.sm),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => FullListModal.showDepartmentPopular(context, department, grade),
                icon: const Icon(Icons.list_alt_rounded, size: 18),
                label: Text('전체보기 (${notices.length}건)'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.infoColor,
                  side: BorderSide(
                    color: AppTheme.infoColor.withOpacity(0.4),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                  ),
                ),
              ),
            ),
          ),
        const SizedBox(height: AppSpacing.xl),
      ],
    );
  }

  /// 마감 임박 공지사항 목록 (최대 5개 + 전체보기)
  Widget _buildDeadlineSoonList(BuildContext context, bool isDark) {
    return Consumer<NoticeProvider>(
      builder: (context, provider, child) {
        final deadlineSoon = provider.notices
            .where((n) => n.deadline != null && n.isDeadlineSoon)
            .toList();
        deadlineSoon.sort((a, b) => a.deadline!.compareTo(b.deadline!));
        final top5 = deadlineSoon.take(5).toList();

        if (top5.isEmpty) {
          return _buildEmptyView(
            '마감 임박 공지사항이 없습니다',
            Icons.event_available_rounded,
            isDark,
          );
        }

        return Column(
          children: [
            ...top5.map((notice) => _buildNoticeCard(context, notice, isDark)),
            // 전체보기 버튼 (5개 초과 시)
            if (deadlineSoon.length > 5)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.sm),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => FullListModal.showDeadlineSoon(context),
                    icon: const Icon(Icons.list_alt_rounded, size: 18),
                    label: Text('전체보기 (${deadlineSoon.length}건)'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.warningColor,
                      side: BorderSide(
                        color: AppTheme.warningColor.withOpacity(0.4),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  /// 공지사항 카드 - 좌측 액센트 바 + 우측 D-day 영역
  Widget _buildNoticeCard(
      BuildContext context, Notice notice, bool isDark) {
    final categoryColor = AppTheme.getCategoryColor(notice.category);
    final showDDay = notice.deadline != null &&
        notice.daysUntilDeadline != null &&
        notice.daysUntilDeadline! >= 0;
    final dDayColor =
        (notice.daysUntilDeadline != null && notice.daysUntilDeadline! <= 3)
            ? AppTheme.errorColor
            : AppTheme.infoColor;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF25253D) : Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.md),
        boxShadow: isDark ? null : AppShadow.soft,
        border: Border(
          left: BorderSide(
            color: categoryColor,
            width: 3,
          ),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) =>
                    NoticeDetailScreen(noticeId: notice.id),
              ),
            );
          },
          borderRadius: const BorderRadius.only(
            topRight: Radius.circular(AppRadius.md),
            bottomRight: Radius.circular(AppRadius.md),
          ),
          child: IntrinsicHeight(
            child: Row(
              children: [
                // 메인 콘텐츠
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 뱃지 행: 카테고리 + 우선순위 + NEW
                        _buildBadgeRow(notice, categoryColor, isDark),
                        const SizedBox(height: 4),

                        // 제목
                        Text(
                          notice.title,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color:
                                isDark ? Colors.white : AppTheme.textPrimary,
                            height: 1.3,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),

                        // AI 요약 (1줄로 축소)
                        if (notice.aiSummary != null) ...[
                          const SizedBox(height: 3),
                          _buildAISummary(notice.aiSummary!, isDark),
                        ],

                        const SizedBox(height: 4),

                        // 메타 정보
                        _buildMetaRow(notice, isDark),
                      ],
                    ),
                  ),
                ),

                // D-day 우측 영역
                if (showDDay)
                  _buildDDayPanel(notice, dDayColor, isDark),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 뱃지 행 (카테고리 + 우선순위 + NEW + 북마크)
  Widget _buildBadgeRow(
      Notice notice, Color categoryColor, bool isDark) {
    return Row(
      children: [
        // 카테고리 뱃지
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: 3,
          ),
          decoration: BoxDecoration(
            color: categoryColor.withOpacity(isDark ? 0.2 : 0.1),
            borderRadius: BorderRadius.circular(AppRadius.xs),
            border: Border.all(
              color: categoryColor.withOpacity(0.4),
              width: 1,
            ),
          ),
          child: Text(
            notice.category,
            style: TextStyle(
              color: categoryColor,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),

        // 우선순위 뱃지
        if (notice.priority != null && notice.priority != '일반') ...[
          const SizedBox(width: AppSpacing.xs),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: 3,
            ),
            decoration: BoxDecoration(
              color: _getPriorityColor(notice.priority!),
              borderRadius: BorderRadius.circular(AppRadius.xs),
            ),
            child: Text(
              notice.priority!,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],

        // NEW 뱃지
        if (notice.isNew) ...[
          const SizedBox(width: AppSpacing.xs),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: 3,
            ),
            decoration: BoxDecoration(
              color: AppTheme.errorColor,
              borderRadius: BorderRadius.circular(AppRadius.xs),
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
            return GestureDetector(
              onTap: () => provider.toggleBookmark(notice.id),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xs),
                child: Icon(
                  notice.isBookmarked
                      ? Icons.bookmark_rounded
                      : Icons.bookmark_border_rounded,
                  size: 20,
                  color: notice.isBookmarked
                      ? AppTheme.primaryColor
                      : (isDark ? Colors.white38 : AppTheme.textHint),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  /// AI 요약 박스 (컴팩트)
  Widget _buildAISummary(String summary, bool isDark) {
    return Row(
      children: [
        Icon(
          Icons.auto_awesome,
          size: 12,
          color: AppTheme.primaryColor.withOpacity(isDark ? 0.7 : 0.8),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            summary,
            style: TextStyle(
              fontSize: 11,
              color: isDark ? Colors.white54 : AppTheme.textSecondary,
              height: 1.2,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  /// 메타 정보 행 (날짜 + 조회수 + 북마크 수)
  Widget _buildMetaRow(Notice notice, bool isDark) {
    final metaColor = isDark ? Colors.white38 : AppTheme.textSecondary;

    return Row(
      children: [
        Icon(Icons.calendar_today_rounded, size: 11, color: metaColor),
        const SizedBox(width: 3),
        Text(
          notice.formattedDate,
          style: TextStyle(color: metaColor, fontSize: 11),
        ),
        const SizedBox(width: AppSpacing.sm),
        Icon(Icons.visibility_outlined, size: 11, color: metaColor),
        const SizedBox(width: 3),
        Text(
          '${notice.views}',
          style: TextStyle(color: metaColor, fontSize: 11),
        ),
        const SizedBox(width: AppSpacing.sm),
        Icon(Icons.bookmark_outlined, size: 11, color: metaColor),
        const SizedBox(width: 3),
        Text(
          '${notice.bookmarkCount}',
          style: TextStyle(color: metaColor, fontSize: 11),
        ),
      ],
    );
  }

  /// D-day 우측 패널
  Widget _buildDDayPanel(Notice notice, Color dDayColor, bool isDark) {
    final days = notice.daysUntilDeadline!;
    final text = days == 0 ? 'D-Day' : 'D-$days';

    return Container(
      width: 46,
      decoration: BoxDecoration(
        color: dDayColor.withOpacity(isDark ? 0.15 : 0.06),
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(AppRadius.md),
          bottomRight: Radius.circular(AppRadius.md),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.alarm_rounded,
            size: 14,
            color: dDayColor,
          ),
          const SizedBox(height: 2),
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: dDayColor,
            ),
          ),
        ],
      ),
    );
  }

  /// 로딩 스켈레톤
  Widget _buildLoadingSkeleton(bool isDark) {
    return Column(
      children: List.generate(
        3,
        (index) => Container(
          height: 110,
          margin: const EdgeInsets.only(bottom: AppSpacing.md),
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFF25253D).withOpacity(0.5)
                : AppTheme.surfaceLight,
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 뱃지 스켈레톤
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 20,
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withOpacity(0.05)
                            : Colors.grey.shade200,
                        borderRadius:
                            BorderRadius.circular(AppRadius.xs),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Container(
                      width: 36,
                      height: 20,
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withOpacity(0.05)
                            : Colors.grey.shade200,
                        borderRadius:
                            BorderRadius.circular(AppRadius.xs),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                // 제목 스켈레톤
                Container(
                  width: double.infinity,
                  height: 16,
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withOpacity(0.05)
                        : Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(AppRadius.xs),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Container(
                  width: 200,
                  height: 16,
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withOpacity(0.05)
                        : Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(AppRadius.xs),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 빈 상태 뷰
  Widget _buildEmptyView(String message, IconData icon, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(
        vertical: AppSpacing.xxl,
        horizontal: AppSpacing.lg,
      ),
      child: Center(
        child: Column(
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withOpacity(0.05)
                    : AppTheme.backgroundColor,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 40,
                color: isDark ? Colors.white24 : AppTheme.textHint,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              message,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white38 : AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              '아래로 당겨서 새로고침해 보세요',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white24 : AppTheme.textHint,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 우선순위 색상 반환
  Color _getPriorityColor(String priority) {
    switch (priority) {
      case '긴급':
        return AppTheme.errorColor;
      case '중요':
        return AppTheme.warningColor;
      case '일반':
      default:
        return AppTheme.textSecondary;
    }
  }
}
