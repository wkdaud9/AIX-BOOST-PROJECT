import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/notice.dart';
import '../providers/notice_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/animated_bookmark_button.dart';
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

  /// 공지사항 카드 - 모던 디자인
  Widget _buildNoticeCard(Notice notice, bool isDark) {
    final categoryColor = isDark
        ? AppTheme.getCategoryColor(widget.categoryName, isDark: true)
        : widget.categoryColor;

    // D-day 표시 로직: 미만료 건만 표시
    final showDDay = notice.deadline != null &&
        notice.daysUntilDeadline != null &&
        notice.daysUntilDeadline! >= 0;
    // 마감 표시 로직: 마감일이 지난 건
    final showExpired = notice.deadline != null &&
        notice.daysUntilDeadline != null &&
        notice.daysUntilDeadline! < 0;
    final dDayColor =
        (notice.daysUntilDeadline != null && notice.daysUntilDeadline! <= 3)
            ? AppTheme.errorColor
            : AppTheme.infoColor;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0D1F3C) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark
              ? categoryColor.withOpacity(0.08)
              : Colors.grey.withOpacity(0.06),
        ),
        boxShadow: isDark
            ? [
                BoxShadow(
                  color: Colors.black.withOpacity(0.25),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ]
            : [
                BoxShadow(
                  color: categoryColor.withOpacity(0.06),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                ),
                BoxShadow(
                  color: Colors.black.withOpacity(0.02),
                  blurRadius: 6,
                  offset: const Offset(0, 1),
                ),
              ],
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
          borderRadius: BorderRadius.circular(18),
          child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 상단: 카테고리 + 뱃지 + 북마크
                      Row(
                        children: [
                          // 카테고리 필 뱃지 (이모지 + 이름)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: categoryColor
                                  .withOpacity(isDark ? 0.15 : 0.07),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _getCategoryEmoji(notice.category),
                                  style: const TextStyle(fontSize: 11),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  notice.category,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: categoryColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 6),
                          // 우선순위 뱃지
                          if (notice.priority != null &&
                              notice.priority != '일반') ...[
                            _buildPriorityBadge(notice.priority!, isDark),
                            const SizedBox(width: 6),
                          ],
                          // NEW 뱃지
                          if (notice.isNew) ...[
                            _buildNewBadge(),
                            const SizedBox(width: 6),
                          ],
                          // D-day 뱃지
                          if (showDDay)
                            _buildDDayBadge(notice, dDayColor, isDark),
                          // 마감 뱃지
                          if (showExpired) _buildExpiredBadge(isDark),
                          const Spacer(),
                          // 북마크 버튼
                          _buildBookmarkButton(notice, categoryColor, isDark),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // 제목 (2줄)
                      Text(
                        notice.title,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : AppTheme.textPrimary,
                          height: 1.45,
                          letterSpacing: -0.2,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 12),
                      // 하단: 날짜 + 조회수 + 북마크 수
                      Row(
                        children: [
                          // 날짜
                          Icon(
                            Icons.schedule_rounded,
                            size: 13,
                            color:
                                isDark ? Colors.white24 : AppTheme.textHint,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            notice.formattedDate,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: isDark
                                  ? Colors.white30
                                  : AppTheme.textHint,
                            ),
                          ),
                          const Spacer(),
                          // 조회수
                          _buildMetaChip(
                            Icons.visibility_outlined,
                            '${notice.views}',
                            isDark,
                          ),
                          const SizedBox(width: 14),
                          // 북마크 수
                          _buildMetaChip(
                            Icons.bookmark_outline_rounded,
                            '${notice.bookmarkCount}',
                            isDark,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
  }

  /// 우선순위 뱃지 (긴급/중요)
  Widget _buildPriorityBadge(String priority, bool isDark) {
    final color = _getPriorityColor(priority, isDark);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        priority,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        ),
      ),
    );
  }

  /// NEW 뱃지
  Widget _buildNewBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.errorColor,
            AppTheme.errorColor.withOpacity(0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Text(
        'NEW',
        style: TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  /// D-day 뱃지
  Widget _buildDDayBadge(Notice notice, Color dDayColor, bool isDark) {
    final days = notice.daysUntilDeadline!;
    final text = days == 0 ? 'D-Day' : 'D-$days';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: dDayColor.withOpacity(isDark ? 0.15 : 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: dDayColor.withOpacity(isDark ? 0.3 : 0.2),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.alarm_rounded, size: 11, color: dDayColor),
          const SizedBox(width: 3),
          Text(
            text,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: dDayColor,
            ),
          ),
        ],
      ),
    );
  }

  /// 마감 뱃지
  Widget _buildExpiredBadge(bool isDark) {
    final color = isDark ? Colors.white30 : const Color(0xFFB0B8C4);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(isDark ? 0.12 : 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: color.withOpacity(0.25),
          width: 1,
        ),
      ),
      child: Text(
        '마감',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  /// 메타 정보 칩 (아이콘 + 텍스트)
  Widget _buildMetaChip(IconData icon, String text, bool isDark) {
    final color = isDark ? Colors.white38 : AppTheme.textSecondary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 3),
        Text(
          text,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: color,
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

  /// 북마크 토글 버튼
  Widget _buildBookmarkButton(
      Notice notice, Color categoryColor, bool isDark) {
    return Consumer<NoticeProvider>(
      builder: (context, provider, child) {
        final isBookmarked = notice.isBookmarked;
        return AnimatedBookmarkButton(
          isBookmarked: isBookmarked,
          onTap: () => provider.toggleBookmark(notice.id),
          activeColor: categoryColor,
          inactiveColor: isDark ? Colors.white38 : AppTheme.textHint,
          size: 18,
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
