import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/notice.dart';
import '../providers/notice_provider.dart';
import '../theme/app_theme.dart';
import 'notice_detail_screen.dart';

/// 정렬 타입
enum SortType {
  popularity, // 인기순 (북마크 수)
  latest, // 최신순
  deadline, // 마감순
  views, // 조회순
}

/// 카테고리별 공지사항 화면
class CategoryNoticeScreen extends StatefulWidget {
  final String categoryName;
  final Color categoryColor;

  const CategoryNoticeScreen({
    super.key,
    required this.categoryName,
    required this.categoryColor,
  });

  @override
  State<CategoryNoticeScreen> createState() => _CategoryNoticeScreenState();
}

class _CategoryNoticeScreenState extends State<CategoryNoticeScreen> {
  SortType _sortType = SortType.latest;

  @override
  void initState() {
    super.initState();
    // 카테고리별 공지사항을 백엔드 API로 조회
    final provider = context.read<NoticeProvider>();
    Future.microtask(() {
      provider.fetchNoticesByCategory(widget.categoryName);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Consumer<NoticeProvider>(
      builder: (context, provider, child) {
        // API에서 가져온 카테고리별 공지사항 사용
        var categoryNotices = List<Notice>.from(provider.categoryNotices);

        // 정렬 적용
        _sortNotices(categoryNotices);

        return Scaffold(
          appBar: _buildAppBar(categoryNotices.length, isDark),
          body: provider.isLoading
              ? const Center(child: CircularProgressIndicator())
              : categoryNotices.isEmpty
              ? _buildEmptyView(isDark)
              : RefreshIndicator(
                  onRefresh: () async {
                    await provider.fetchNoticesByCategory(widget.categoryName);
                  },
                  child: ListView.builder(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    itemCount: categoryNotices.length,
                    itemBuilder: (context, index) {
                      return _buildNoticeCard(
                          categoryNotices[index], isDark);
                    },
                  ),
                ),
        );
      },
    );
  }

  /// AppBar 구성 (카테고리명 + 건수 + 정렬)
  PreferredSizeWidget _buildAppBar(int resultCount, bool isDark) {
    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => Navigator.pop(context),
      ),
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            widget.categoryName,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : AppTheme.textPrimary,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          // 결과 건수 뱃지
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: 2,
            ),
            decoration: BoxDecoration(
              color: widget.categoryColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(AppRadius.round),
            ),
            child: Text(
              '$resultCount건',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: widget.categoryColor,
              ),
            ),
          ),
        ],
      ),
      centerTitle: true,
      elevation: 0,
      backgroundColor:
          isDark ? Theme.of(context).scaffoldBackgroundColor : AppTheme.surfaceColor,
      actions: [
        _buildSortDropdown(isDark),
      ],
    );
  }

  /// 정렬 드롭다운
  Widget _buildSortDropdown(bool isDark) {
    return PopupMenuButton<SortType>(
      icon: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _getSortLabel(_sortType),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: widget.categoryColor,
            ),
          ),
          const SizedBox(width: 4),
          Icon(
            Icons.arrow_drop_down,
            color: widget.categoryColor,
            size: 20,
          ),
        ],
      ),
      color: isDark ? AppTheme.secondaryColor : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      position: PopupMenuPosition.under,
      onSelected: (SortType type) {
        setState(() {
          _sortType = type;
        });
      },
      itemBuilder: (BuildContext context) => <PopupMenuEntry<SortType>>[
        _buildSortMenuItem(
            SortType.popularity, '인기순', Icons.trending_up, isDark),
        _buildSortMenuItem(
            SortType.latest, '최신순', Icons.schedule, isDark),
        _buildSortMenuItem(
            SortType.deadline, '마감순', Icons.alarm, isDark),
        _buildSortMenuItem(
            SortType.views, '조회순', Icons.visibility, isDark),
      ],
    );
  }

  /// 정렬 메뉴 아이템
  PopupMenuItem<SortType> _buildSortMenuItem(
    SortType type,
    String label,
    IconData icon,
    bool isDark,
  ) {
    final isSelected = _sortType == type;
    return PopupMenuItem<SortType>(
      value: type,
      child: Row(
        children: [
          Icon(
            icon,
            size: 18,
            color: isSelected
                ? widget.categoryColor
                : (isDark ? Colors.white54 : AppTheme.textSecondary),
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected
                  ? widget.categoryColor
                  : (isDark ? Colors.white : AppTheme.textPrimary),
            ),
          ),
          if (isSelected) ...[
            const Spacer(),
            Icon(
              Icons.check,
              size: 18,
              color: widget.categoryColor,
            ),
          ],
        ],
      ),
    );
  }

  /// 공지사항 카드 - Row 기반 레이아웃 (Stack/Positioned 제거)
  Widget _buildNoticeCard(Notice notice, bool isDark) {
    // D-day 표시 로직: 미만료 건만 표시
    final showDDay = notice.deadline != null &&
        notice.daysUntilDeadline != null &&
        notice.daysUntilDeadline! >= 0;
    final dDayColor =
        (notice.daysUntilDeadline != null && notice.daysUntilDeadline! <= 3)
            ? AppTheme.errorColor
            : AppTheme.infoColor;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F2854) : Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: isDark ? null : AppShadow.soft,
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
          borderRadius: BorderRadius.circular(AppRadius.lg),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 좌측: 콘텐츠 영역
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 인라인 뱃지 행 (고정 높이 - 뱃지 유무와 무관)
                      SizedBox(
                        height: 22,
                        child: _buildInlineBadges(
                            notice, showDDay, dDayColor, isDark),
                      ),

                      const SizedBox(height: AppSpacing.sm),

                      // 제목 (고정 높이 영역 - 2줄 기준)
                      SizedBox(
                        height: 40,
                        child: Text(
                          notice.title,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? Colors.white
                                : AppTheme.textPrimary,
                            height: 1.3,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),

                      const SizedBox(height: AppSpacing.sm),

                      // 메타 정보 행
                      _buildMetaRow(notice, isDark),
                    ],
                  ),
                ),

                const SizedBox(width: AppSpacing.md),

                // 우측: 썸네일 + 북마크 오버레이
                SizedBox(
                  width: 72,
                  height: 72,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      _buildThumbnail(notice, isDark),
                      Positioned(
                        top: -4,
                        right: -4,
                        child: _buildBookmarkButton(notice, isDark),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 인라인 뱃지 행 (우선순위 + NEW + D-day)
  Widget _buildInlineBadges(
    Notice notice,
    bool showDDay,
    Color dDayColor,
    bool isDark,
  ) {
    final hasBadges = (notice.priority != null && notice.priority != '일반') ||
        notice.isNew ||
        showDDay;

    if (!hasBadges) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Wrap(
        spacing: AppSpacing.xs,
        runSpacing: AppSpacing.xs,
        children: [
          // 우선순위 뱃지
          if (notice.priority != null && notice.priority != '일반')
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: 3,
              ),
              decoration: BoxDecoration(
                color: _getPriorityColor(notice.priority!, isDark),
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

          // NEW 뱃지
          if (notice.isNew)
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

          // D-day 뱃지
          if (showDDay)
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: 3,
              ),
              decoration: BoxDecoration(
                color: dDayColor.withOpacity(isDark ? 0.2 : 0.1),
                borderRadius: BorderRadius.circular(AppRadius.xs),
                border: Border.all(
                  color: dDayColor.withOpacity(0.4),
                ),
              ),
              child: Text(
                notice.daysUntilDeadline == 0
                    ? 'D-Day'
                    : 'D-${notice.daysUntilDeadline}',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: dDayColor,
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// 메타 정보 행 (조회수 + 북마크 수 + 날짜)
  Widget _buildMetaRow(Notice notice, bool isDark) {
    final metaColor = isDark ? Colors.white38 : AppTheme.textSecondary;
    final hintColor = isDark ? Colors.white24 : AppTheme.textHint;

    return Row(
      children: [
        // 조회수
        Icon(Icons.visibility_outlined, size: 14, color: metaColor),
        const SizedBox(width: 4),
        Text(
          '${notice.views}',
          style: TextStyle(
            fontSize: 12,
            color: metaColor,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(width: AppSpacing.md),

        // 북마크 수
        Icon(Icons.bookmark_outlined, size: 14, color: metaColor),
        const SizedBox(width: 4),
        Text(
          '${notice.bookmarkCount}',
          style: TextStyle(
            fontSize: 12,
            color: metaColor,
            fontWeight: FontWeight.w500,
          ),
        ),

        const Spacer(),

        // 날짜
        Text(
          notice.formattedDate,
          style: TextStyle(
            fontSize: 12,
            color: hintColor,
          ),
        ),
      ],
    );
  }

  /// 카테고리별 이모지 매핑
  String _getCategoryEmoji(String category) {
    switch (category) {
      case '학사':
      case '학사공지':
        return '🎓';
      case '장학':
        return '💰';
      case '취업':
        return '💼';
      case '행사':
      case '학생활동':
        return '🎉';
      case '교육':
        return '📚';
      case '공모전':
        return '🏆';
      case '시설':
        return '🏢';
      default:
        return '📋';
    }
  }

  /// 썸네일 (카테고리 이모지)
  Widget _buildThumbnail(Notice notice, bool isDark) {
    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        color: isDark
            ? widget.categoryColor.withOpacity(0.15)
            : widget.categoryColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Center(
        child: Text(
          _getCategoryEmoji(notice.category),
          style: const TextStyle(fontSize: 30),
        ),
      ),
    );
  }

  /// 북마크 토글 버튼 (썸네일 오버레이용)
  Widget _buildBookmarkButton(Notice notice, bool isDark) {
    return Consumer<NoticeProvider>(
      builder: (context, provider, child) {
        return GestureDetector(
          onTap: () => provider.toggleBookmark(notice.id),
          child: Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: (isDark ? Colors.white.withOpacity(0.1) : Colors.white.withOpacity(0.85)),
              borderRadius: BorderRadius.circular(AppRadius.xs),
            ),
            alignment: Alignment.center,
            child: Icon(
              notice.isBookmarked
                  ? Icons.bookmark_rounded
                  : Icons.bookmark_border_rounded,
              size: 18,
              color: notice.isBookmarked
                  ? widget.categoryColor
                  : (isDark ? Colors.white54 : AppTheme.textSecondary),
            ),
          ),
        );
      },
    );
  }

  /// 빈 화면
  Widget _buildEmptyView(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 카테고리별 아이콘 + 원형 배경
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withOpacity(0.05)
                  : widget.categoryColor.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: Text(
              _getCategoryEmoji(widget.categoryName),
              style: TextStyle(
                fontSize: 40,
                color: isDark ? Colors.white24 : null,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            '해당 카테고리의\n공지사항이 없습니다',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white54 : AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  /// 정렬 적용
  void _sortNotices(List<Notice> notices) {
    switch (_sortType) {
      case SortType.popularity:
        // 인기순: 북마크 수 기준 (동일하면 조회수로 2차 정렬)
        notices.sort((a, b) {
          final cmp = b.bookmarkCount.compareTo(a.bookmarkCount);
          return cmp != 0 ? cmp : b.views.compareTo(a.views);
        });
        break;
      case SortType.views:
        notices.sort((a, b) => b.views.compareTo(a.views));
        break;
      case SortType.latest:
        notices.sort((a, b) => b.date.compareTo(a.date));
        break;
      case SortType.deadline:
        // 마감 임박 순: 지난 마감일은 뒤로, 임박한 순서대로 표시
        final now = DateTime.now();
        notices.sort((a, b) {
          if (a.deadline == null && b.deadline == null) return 0;
          if (a.deadline == null) return 1;
          if (b.deadline == null) return -1;
          final aExpired = a.deadline!.isBefore(now);
          final bExpired = b.deadline!.isBefore(now);
          if (aExpired && !bExpired) return 1;
          if (!aExpired && bExpired) return -1;
          if (aExpired && bExpired) {
            return b.deadline!.compareTo(a.deadline!);
          }
          return a.deadline!.compareTo(b.deadline!);
        });
        break;
    }
  }

  /// 정렬 라벨
  String _getSortLabel(SortType type) {
    switch (type) {
      case SortType.popularity:
        return '인기순';
      case SortType.latest:
        return '최신순';
      case SortType.deadline:
        return '마감순';
      case SortType.views:
        return '조회순';
    }
  }

  /// 우선순위 색상
  Color _getPriorityColor(String priority, bool isDark) {
    switch (priority) {
      case '긴급':
        return AppTheme.errorColor;
      case '중요':
        return AppTheme.warningColor;
      case '일반':
      default:
        return isDark ? Colors.white38 : AppTheme.textSecondary;
    }
  }
}
