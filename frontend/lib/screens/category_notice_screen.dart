import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/notice.dart';
import '../providers/notice_provider.dart';
import '../theme/app_theme.dart';
import 'notice_detail_screen.dart';

/// 정렬 타입
enum SortType {
  popularity, // 인기순 (조회수)
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
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      body: Consumer<NoticeProvider>(
        builder: (context, provider, child) {
          // 카테고리 필터링
          var categoryNotices = provider.notices
              .where((n) => n.category == widget.categoryName)
              .toList();

          // 정렬 적용
          _sortNotices(categoryNotices);

          if (categoryNotices.isEmpty) {
            return _buildEmptyView();
          }

          return RefreshIndicator(
            onRefresh: () async {
              await provider.fetchNotices();
            },
            child: ListView.builder(
              padding: const EdgeInsets.all(AppSpacing.md),
              itemCount: categoryNotices.length,
              itemBuilder: (context, index) {
                return _buildNoticeCard(categoryNotices[index]);
              },
            ),
          );
        },
      ),
    );
  }

  /// AppBar 구성
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => Navigator.pop(context),
      ),
      title: Text(
        widget.categoryName,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          color: AppTheme.textPrimary,
        ),
      ),
      centerTitle: true,
      elevation: 0,
      backgroundColor: AppTheme.surfaceColor,
      actions: [
        _buildSortDropdown(),
      ],
    );
  }

  /// 정렬 드롭다운
  Widget _buildSortDropdown() {
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
      onSelected: (SortType type) {
        setState(() {
          _sortType = type;
        });
      },
      itemBuilder: (BuildContext context) => <PopupMenuEntry<SortType>>[
        _buildSortMenuItem(SortType.popularity, '인기순', Icons.trending_up),
        _buildSortMenuItem(SortType.latest, '최신순', Icons.schedule),
        _buildSortMenuItem(SortType.deadline, '마감순', Icons.alarm),
        _buildSortMenuItem(SortType.views, '조회순', Icons.visibility),
      ],
    );
  }

  /// 정렬 메뉴 아이템
  PopupMenuItem<SortType> _buildSortMenuItem(
    SortType type,
    String label,
    IconData icon,
  ) {
    final isSelected = _sortType == type;
    return PopupMenuItem<SortType>(
      value: type,
      child: Row(
        children: [
          Icon(
            icon,
            size: 18,
            color: isSelected ? widget.categoryColor : AppTheme.textSecondary,
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected ? widget.categoryColor : AppTheme.textPrimary,
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

  /// 공지사항 카드
  Widget _buildNoticeCard(Notice notice) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
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
          child: Stack(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 왼쪽 영역 (제목, 메타 정보)
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // D-day 표시 (빨간색 텍스트만)
                        if (notice.deadline != null &&
                            notice.daysUntilDeadline != null) ...[
                          Text(
                            'D-${notice.daysUntilDeadline}',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Colors.red.shade600,
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],

                        // 제목
                        Padding(
                          padding: const EdgeInsets.only(right: 60), // 우선순위 뱃지 공간 확보
                          child: Text(
                            notice.title,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textPrimary,
                                ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(height: 8),

                        // 메타 정보 (조회수, 저장 횟수)
                        Row(
                          children: [
                            // 조회수
                            Icon(
                              Icons.visibility_outlined,
                              size: 16,
                              color: AppTheme.textSecondary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${notice.views}',
                              style: TextStyle(
                                fontSize: 13,
                                color: AppTheme.textSecondary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(width: 16),

                            // 캘린더 저장 횟수
                            Icon(
                              Icons.bookmark_border,
                              size: 16,
                              color: AppTheme.textSecondary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${(notice.views * 0.1).toInt()}',
                              style: TextStyle(
                                fontSize: 13,
                                color: AppTheme.textSecondary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const Spacer(),

                            // 날짜 정보
                            Text(
                              notice.formattedDate,
                              style: TextStyle(
                                fontSize: 12,
                                color: AppTheme.textHint,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),

                  // 오른쪽 영역 (썸네일)
                  _buildThumbnail(notice),
                ],
              ),
              // 우선순위 + NEW 뱃지 (오른쪽 상단)
              Positioned(
                top: 0,
                right: 90,
                child: Row(
                  children: [
                    if (notice.priority != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: _getPriorityColor(notice.priority!),
                          borderRadius: BorderRadius.circular(AppRadius.sm),
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
                      const SizedBox(width: 4),
                    ],
                    if (notice.isNew)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
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
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 썸네일 이미지
  Widget _buildThumbnail(Notice notice) {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        color: widget.categoryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: widget.categoryColor.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // 기본 아이콘 (플레이스홀더)
            Icon(
              Icons.article_outlined,
              size: 36,
              color: widget.categoryColor.withOpacity(0.4),
            ),
            // 향후 이미지 URL이 있으면 표시
            // notice.imageUrl != null
            //   ? Image.network(notice.imageUrl!, fit: BoxFit.cover)
            //   : SizedBox.shrink(),
          ],
        ),
      ),
    );
  }

  /// 빈 화면
  Widget _buildEmptyView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inbox_outlined,
            size: 80,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            '해당 카테고리의\n공지사항이 없습니다',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
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
      case SortType.views:
        notices.sort((a, b) => b.views.compareTo(a.views));
        break;
      case SortType.latest:
        notices.sort((a, b) => b.date.compareTo(a.date));
        break;
      case SortType.deadline:
        notices.sort((a, b) {
          if (a.deadline == null && b.deadline == null) return 0;
          if (a.deadline == null) return 1;
          if (b.deadline == null) return -1;
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
  Color _getPriorityColor(String priority) {
    switch (priority) {
      case '중요':
        return Colors.orange.shade700;
      case '일반':
      default:
        return Colors.grey.shade600;
    }
  }
}
