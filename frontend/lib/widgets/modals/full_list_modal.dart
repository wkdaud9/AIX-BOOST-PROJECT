import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/notice.dart';
import '../../providers/notice_provider.dart';
import '../../screens/notice_detail_screen.dart';
import '../../theme/app_theme.dart';
import '../animated_bookmark_button.dart';

/// 전체보기 모달 (추천정보 카드에서 사용)
/// 인기 게시물, 저장한 일정, AI 추천, 이번 주 일정 전체 목록을 표시
class FullListModal extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<Notice> notices;
  final Color themeColor;
  final IconData icon;
  final FullListType listType;

  const FullListModal({
    super.key,
    required this.title,
    required this.subtitle,
    required this.notices,
    required this.themeColor,
    required this.icon,
    required this.listType,
  });

  /// HOT 게시물 전체보기 모달
  static void showPopular(BuildContext context) {
    final provider = context.read<NoticeProvider>();
    final sorted = List<Notice>.from(provider.notices);
    sorted.sort((a, b) => b.views.compareTo(a.views));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => FullListModal(
        title: 'HOT 게시물',
        subtitle: '조회수 TOP',
        notices: sorted,
        themeColor: const Color(0xFFFF6B6B),
        icon: Icons.local_fire_department_rounded,
        listType: FullListType.popular,
      ),
    );
  }

  /// 저장한 일정 전체보기 모달
  static void showSavedEvents(BuildContext context) {
    final provider = context.read<NoticeProvider>();
    final bookmarked = List<Notice>.from(provider.bookmarkedNotices);
    final now = DateTime.now();

    // 마감일 있는 것 우선, 임박한 순 정렬
    bookmarked.sort((a, b) {
      if (a.deadline == null && b.deadline == null) return 0;
      if (a.deadline == null) return 1;
      if (b.deadline == null) return -1;
      final aExpired = a.deadline!.isBefore(now);
      final bExpired = b.deadline!.isBefore(now);
      if (aExpired && !bExpired) return 1;
      if (!aExpired && bExpired) return -1;
      if (aExpired && bExpired) return b.deadline!.compareTo(a.deadline!);
      return a.deadline!.compareTo(b.deadline!);
    });

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => FullListModal(
        title: '저장한 일정',
        subtitle: '마감 임박 순 정렬',
        notices: bookmarked,
        themeColor: const Color(0xFF7C8CF8),
        icon: Icons.bookmark_rounded,
        listType: FullListType.savedEvents,
      ),
    );
  }

  /// AI 추천 전체보기 모달
  static void showAIRecommend(BuildContext context) {
    final provider = context.read<NoticeProvider>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => FullListModal(
        title: 'AI 추천',
        subtitle: '맞춤 공지사항',
        notices: provider.recommendedNotices,
        themeColor: const Color(0xFFA855F7),
        icon: Icons.auto_awesome,
        listType: FullListType.aiRecommend,
      ),
    );
  }

  /// 학과/학년 인기 공지 전체보기 모달
  static void showDepartmentPopular(BuildContext context, String? department, int? grade) {
    final provider = context.read<NoticeProvider>();
    final notices = provider.getDepartmentPopularNotices(department, grade);

    final deptLabel = department ?? '전체';
    final gradeLabel = grade != null ? ' $grade학년' : '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => FullListModal(
        title: '$deptLabel$gradeLabel 인기 공지',
        subtitle: '조회수 + 관련도 기준',
        notices: notices,
        themeColor: AppTheme.infoColor,
        icon: Icons.star_rounded,
        listType: FullListType.departmentPopular,
      ),
    );
  }

  /// 오늘 꼭 봐야 할 공지 전체보기 모달
  static void showTodayMustSee(BuildContext context) {
    final provider = context.read<NoticeProvider>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => FullListModal(
        title: '오늘 꼭 봐야 할 공지',
        subtitle: '긴급/마감임박/최신 종합',
        notices: provider.todayMustSeeNotices,
        themeColor: AppTheme.errorColor,
        icon: Icons.push_pin_rounded,
        listType: FullListType.todayMustSee,
      ),
    );
  }

  /// 마감 임박 전체보기 모달
  static void showDeadlineSoon(BuildContext context) {
    final provider = context.read<NoticeProvider>();

    final deadlineSoonNotices = provider.notices
        .where((n) => n.isDeadlineSoon)
        .toList();

    // 마감일 임박한 순 정렬
    deadlineSoonNotices.sort((a, b) {
      if (a.deadline == null && b.deadline == null) return 0;
      if (a.deadline == null) return 1;
      if (b.deadline == null) return -1;
      return a.deadline!.compareTo(b.deadline!);
    });

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => FullListModal(
        title: '마감 임박 공지',
        subtitle: '마감일 순 정렬',
        notices: deadlineSoonNotices,
        themeColor: AppTheme.warningColor,
        icon: Icons.timer,
        listType: FullListType.deadlineSoon,
      ),
    );
  }

  /// 이번 주 일정 전체보기 모달
  static void showWeeklySchedule(BuildContext context) {
    final provider = context.read<NoticeProvider>();
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final weekEnd = weekStart.add(const Duration(days: 6, hours: 23, minutes: 59));

    final weeklyNotices = provider.notices
        .where((n) =>
            n.deadline != null &&
            n.deadline!.isAfter(weekStart.subtract(const Duration(days: 1))) &&
            n.deadline!.isBefore(weekEnd))
        .toList();

    // 마감일 순 정렬
    weeklyNotices.sort((a, b) => a.deadline!.compareTo(b.deadline!));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => FullListModal(
        title: '이번 주 일정',
        subtitle: '마감 예정 공지사항',
        notices: weeklyNotices,
        themeColor: const Color(0xFF38BDF8),
        icon: Icons.date_range_rounded,
        listType: FullListType.weekly,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
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

              // 헤더 (아이콘 배경 없이 깔끔하게)
              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Row(
                  children: [
                    Icon(
                      icon,
                      color: themeColor,
                      size: 28,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '$subtitle (${notices.length}개)',
                            style: TextStyle(
                              fontSize: 13,
                              color: isDark ? Colors.white54 : AppTheme.textSecondary,
                            ),
                          ),
                        ],
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

              // 목록 영역 (배경 tint + 카드 화이트)
              Expanded(
                child: Container(
                  color: isDark
                      ? Colors.white.withOpacity(0.03)
                      : Colors.grey.shade100,
                  child: listType == FullListType.savedEvents
                      ? Consumer<NoticeProvider>(
                          builder: (context, provider, child) {
                            final liveBookmarked = List<Notice>.from(provider.bookmarkedNotices);
                            final now = DateTime.now();
                            liveBookmarked.sort((a, b) {
                              if (a.deadline == null && b.deadline == null) return 0;
                              if (a.deadline == null) return 1;
                              if (b.deadline == null) return -1;
                              final aExpired = a.deadline!.isBefore(now);
                              final bExpired = b.deadline!.isBefore(now);
                              if (aExpired && !bExpired) return 1;
                              if (!aExpired && bExpired) return -1;
                              if (aExpired && bExpired) return b.deadline!.compareTo(a.deadline!);
                              return a.deadline!.compareTo(b.deadline!);
                            });
                            return liveBookmarked.isEmpty
                                ? _buildEmptyState(isDark)
                                : ListView.separated(
                                    controller: scrollController,
                                    padding: const EdgeInsets.all(AppSpacing.md),
                                    itemCount: liveBookmarked.length,
                                    separatorBuilder: (context, index) =>
                                        const SizedBox(height: AppSpacing.sm),
                                    itemBuilder: (context, index) {
                                      final notice = liveBookmarked[index];
                                      return _buildNoticeItem(context, notice, index, isDark);
                                    },
                                  );
                          },
                        )
                      : notices.isEmpty
                          ? _buildEmptyState(isDark)
                          : ListView.separated(
                              controller: scrollController,
                              padding: const EdgeInsets.all(AppSpacing.md),
                              itemCount: notices.length,
                              separatorBuilder: (context, index) =>
                                  const SizedBox(height: AppSpacing.sm),
                              itemBuilder: (context, index) {
                                final notice = notices[index];
                                return _buildNoticeItem(context, notice, index, isDark);
                              },
                            ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// 빈 상태 위젯
  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 64,
            color: isDark ? Colors.white24 : Colors.grey.shade300,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            _getEmptyMessage(),
            style: TextStyle(
              fontSize: 16,
              color: isDark ? Colors.white54 : AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  String _getEmptyMessage() {
    switch (listType) {
      case FullListType.popular:
        return 'HOT 게시물이 없습니다';
      case FullListType.savedEvents:
        return '저장된 일정이 없습니다';
      case FullListType.aiRecommend:
        return '추천 공지사항이 없습니다';
      case FullListType.weekly:
        return '이번 주 일정이 없습니다';
      case FullListType.departmentPopular:
        return '관련 인기 공지가 없습니다';
      case FullListType.todayMustSee:
        return '오늘 꼭 봐야 할 공지가 없습니다';
      case FullListType.deadlineSoon:
        return '마감 임박 공지가 없습니다';
    }
  }

  /// 공지사항 아이템 위젯 (통일된 크기)
  Widget _buildNoticeItem(
    BuildContext context,
    Notice notice,
    int index,
    bool isDark,
  ) {
    return InkWell(
      onTap: () {
        Navigator.pop(context); // 모달 닫기
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => NoticeDetailScreen(noticeId: notice.id),
          ),
        );
      },
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        constraints: const BoxConstraints(minHeight: 72),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 14),
        decoration: BoxDecoration(
          color: isDark
              ? const Color(0xFF0D1F3C)
              : Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: isDark
                ? Colors.white.withOpacity(0.08)
                : Colors.grey.shade200,
          ),
        ),
        child: Row(
          children: [
            // 순위 표시 (인기 게시물일 경우)
            if (listType == FullListType.popular) ...[
              SizedBox(
                width: 28,
                child: Text(
                  '${index + 1}',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: index < 3
                        ? themeColor
                        : (isDark ? Colors.white38 : AppTheme.textHint),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
            ],

            // 공지사항 정보
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    notice.title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.white : AppTheme.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      // 카테고리 태그
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.getCategoryColor(notice.category, isDark: isDark)
                              .withOpacity(0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          notice.category,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: AppTheme.getCategoryColor(notice.category, isDark: isDark),
                          ),
                        ),
                      ),
                      const Spacer(),

                      // 추가 정보 (리스트 타입에 따라 다름)
                      _buildExtraInfo(notice, isDark),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(width: 4),

            // 우측 북마크 버튼
            _buildTrailingWidget(context, notice, isDark),
          ],
        ),
      ),
    );
  }

  /// 추가 정보 (조회수, 마감일 등)
  Widget _buildExtraInfo(Notice notice, bool isDark) {
    switch (listType) {
      case FullListType.popular:
        return Row(
          children: [
            Icon(
              Icons.visibility,
              size: 12,
              color: isDark ? Colors.white38 : AppTheme.textHint,
            ),
            const SizedBox(width: 4),
            Text(
              '${notice.views}',
              style: TextStyle(
                fontSize: 11,
                color: isDark ? Colors.white38 : AppTheme.textHint,
              ),
            ),
          ],
        );

      case FullListType.savedEvents:
      case FullListType.weekly:
        if (notice.daysUntilDeadline != null) {
          final daysLeft = notice.daysUntilDeadline!;
          final isExpired = daysLeft < 0;
          return Text(
            isExpired ? '마감됨' : (daysLeft == 0 ? 'D-Day' : 'D-$daysLeft'),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isExpired
                  ? Colors.grey
                  : (daysLeft <= 3 ? AppTheme.errorColor : themeColor),
            ),
          );
        }
        return const SizedBox.shrink();

      case FullListType.aiRecommend:
        if (notice.aiSummary != null && notice.aiSummary!.isNotEmpty) {
          return Flexible(
            child: Text(
              notice.aiSummary!,
              style: TextStyle(
                fontSize: 11,
                color: isDark ? Colors.white38 : AppTheme.textHint,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          );
        }
        return const SizedBox.shrink();

      case FullListType.departmentPopular:
        return Row(
          children: [
            Icon(
              Icons.visibility,
              size: 12,
              color: isDark ? Colors.white38 : AppTheme.textHint,
            ),
            const SizedBox(width: 4),
            Text(
              '${notice.views}',
              style: TextStyle(
                fontSize: 11,
                color: isDark ? Colors.white38 : AppTheme.textHint,
              ),
            ),
            if (notice.bookmarkCount > 0) ...[
              const SizedBox(width: 8),
              Icon(
                Icons.bookmark,
                size: 12,
                color: isDark ? Colors.white38 : AppTheme.textHint,
              ),
              const SizedBox(width: 2),
              Text(
                '${notice.bookmarkCount}',
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? Colors.white38 : AppTheme.textHint,
                ),
              ),
            ],
          ],
        );

      case FullListType.todayMustSee:
        return Row(
          children: [
            if (notice.priority != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: notice.priority == '긴급'
                      ? AppTheme.errorColor.withOpacity(0.15)
                      : AppTheme.warningColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Text(
                  notice.priority!,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: notice.priority == '긴급'
                        ? AppTheme.errorColor
                        : AppTheme.warningColor,
                  ),
                ),
              ),
              const SizedBox(width: 6),
            ],
            if (notice.isDeadlineSoon) ...[
              Text(
                'D-${notice.daysUntilDeadline}',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.errorColor,
                ),
              ),
            ],
          ],
        );

      case FullListType.deadlineSoon:
        if (notice.daysUntilDeadline != null) {
          final daysLeft = notice.daysUntilDeadline!;
          return Text(
            daysLeft == 0 ? 'D-Day' : 'D-$daysLeft',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: daysLeft <= 3 ? AppTheme.errorColor : themeColor,
            ),
          );
        }
        return const SizedBox.shrink();
    }
  }

  /// 우측 위젯 (북마크 버튼 - 애니메이션)
  /// Provider가 copyWith()로 새 객체를 생성하므로, 정적 리스트의 옛 참조 대신
  /// Provider의 모든 리스트에서 실시간 상태를 조회
  Widget _buildTrailingWidget(BuildContext context, Notice notice, bool isDark) {
    return Consumer<NoticeProvider>(
      builder: (context, provider, child) {
        // notices, recommendedNotices, categoryNotices 모두에서 검색
        bool isBookmarked = false;
        for (final n in provider.notices) {
          if (n.id == notice.id) { isBookmarked = n.isBookmarked; break; }
        }
        if (!isBookmarked) {
          for (final n in provider.recommendedNotices) {
            if (n.id == notice.id) { isBookmarked = n.isBookmarked; break; }
          }
        }
        if (!isBookmarked) {
          for (final n in provider.categoryNotices) {
            if (n.id == notice.id) { isBookmarked = n.isBookmarked; break; }
          }
        }
        return AnimatedBookmarkButton(
          isBookmarked: isBookmarked,
          onTap: () => provider.toggleBookmark(notice.id),
          activeColor: themeColor,
          inactiveColor: isDark ? Colors.white38 : AppTheme.textHint,
          size: 22,
        );
      },
    );
  }
}

/// 전체보기 리스트 타입
enum FullListType {
  popular,            // 인기 게시물
  savedEvents,        // 저장한 일정
  aiRecommend,        // AI 추천
  weekly,             // 이번 주 일정
  departmentPopular,  // 학과/학년 인기
  todayMustSee,       // 오늘 꼭 봐야 할 공지
  deadlineSoon,       // 마감 임박
}
