import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/notice.dart';
import '../providers/notice_provider.dart';
import '../theme/app_theme.dart';
import 'notice_detail_screen.dart';

enum BookmarkSortMode { recent, deadline, views }

/// 북마크 화면 - 저장된 공지사항 목록
class BookmarkScreen extends StatefulWidget {
  const BookmarkScreen({super.key});

  @override
  State<BookmarkScreen> createState() => _BookmarkScreenState();
}

class _BookmarkScreenState extends State<BookmarkScreen> {
  BookmarkSortMode _sortMode = BookmarkSortMode.recent;

  @override
  Widget build(BuildContext context) {
    return Consumer<NoticeProvider>(
      builder: (context, provider, child) {
        var bookmarkedNotices = List<Notice>.from(provider.bookmarkedNotices);

        // 정렬
        switch (_sortMode) {
          case BookmarkSortMode.recent:
            bookmarkedNotices.sort((a, b) => b.date.compareTo(a.date));
            break;
          case BookmarkSortMode.deadline:
            bookmarkedNotices.sort((a, b) {
              if (a.deadline == null && b.deadline == null) return 0;
              if (a.deadline == null) return 1;
              if (b.deadline == null) return -1;
              return a.deadline!.compareTo(b.deadline!);
            });
            break;
          case BookmarkSortMode.views:
            bookmarkedNotices.sort((a, b) => b.views.compareTo(a.views));
            break;
        }

        if (provider.isLoading) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        if (bookmarkedNotices.isEmpty) {
          return _buildEmptyView();
        }

        return Column(
          children: [
            // 정렬 옵션
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                children: [
                  const Text(
                    '정렬',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: SegmentedButton<BookmarkSortMode>(
                      segments: const [
                        ButtonSegment<BookmarkSortMode>(
                          value: BookmarkSortMode.recent,
                          label: Text('최신순', style: TextStyle(fontSize: 12)),
                          icon: Icon(Icons.schedule, size: 16),
                        ),
                        ButtonSegment<BookmarkSortMode>(
                          value: BookmarkSortMode.deadline,
                          label: Text('마감순', style: TextStyle(fontSize: 12)),
                          icon: Icon(Icons.alarm, size: 16),
                        ),
                        ButtonSegment<BookmarkSortMode>(
                          value: BookmarkSortMode.views,
                          label: Text('조회순', style: TextStyle(fontSize: 12)),
                          icon: Icon(Icons.trending_up, size: 16),
                        ),
                      ],
                      selected: {_sortMode},
                      onSelectionChanged: (Set<BookmarkSortMode> newSelection) {
                        setState(() {
                          _sortMode = newSelection.first;
                        });
                      },
                      style: ButtonStyle(
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // 북마크 리스트
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  await provider.fetchNotices();
                },
                child: ListView.builder(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  itemCount: bookmarkedNotices.length,
                  itemBuilder: (context, index) {
                    final notice = bookmarkedNotices[index];
                    return _buildBookmarkCard(context, notice, provider);
                  },
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  /// 북마크 카드
  Widget _buildBookmarkCard(
    BuildContext context,
    Notice notice,
    NoticeProvider provider,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Dismissible(
      key: Key(notice.id),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.md),
        decoration: BoxDecoration(
          color: AppTheme.errorColor,
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: AppSpacing.lg),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.bookmark_remove,
              color: Colors.white,
              size: 32,
            ),
            SizedBox(height: 4),
            Text(
              '삭제',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
      onDismissed: (direction) {
        provider.toggleBookmark(notice.id);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('북마크가 삭제되었습니다.'),
            action: SnackBarAction(
              label: '취소',
              onPressed: () {
                provider.toggleBookmark(notice.id);
              },
            ),
          ),
        );
      },
      child: Card(
        margin: const EdgeInsets.only(bottom: AppSpacing.md),
        child: InkWell(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => NoticeDetailScreen(
                  noticeId: notice.id,
                ),
              ),
            );
          },
          borderRadius: BorderRadius.circular(AppRadius.lg),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 카테고리와 북마크 아이콘
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.getCategoryColor(notice.category, isDark: isDark)
                            .withOpacity(0.1),
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                        border: Border.all(
                          color: AppTheme.getCategoryColor(notice.category, isDark: isDark),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        notice.category,
                        style: TextStyle(
                          color: AppTheme.getCategoryColor(notice.category, isDark: isDark),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: Icon(
                        Icons.bookmark,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? AppTheme.primaryLight
                            : AppTheme.primaryColor,
                      ),
                      onPressed: () {
                        provider.toggleBookmark(notice.id);
                      },
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
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

                const SizedBox(height: AppSpacing.sm),

                // 내용 미리보기
                Text(
                  notice.content,
                  style: Theme.of(context).textTheme.bodySmall,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),

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
                    if (notice.deadline != null) ...[
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
                          notice.daysUntilDeadline != null
                              ? 'D-${notice.daysUntilDeadline}'
                              : '마감',
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

                // 태그
                if (notice.tags.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Wrap(
                    spacing: AppSpacing.xs,
                    runSpacing: AppSpacing.xs,
                    children: notice.tags.take(3).map((tag) {
                      final tagIsDark = Theme.of(context).brightness == Brightness.dark;
                      final tagColor = tagIsDark ? AppTheme.primaryLight : AppTheme.primaryColor;
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: tagColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                        ),
                        child: Text(
                          '#$tag',
                          style: TextStyle(
                            color: tagColor,
                            fontSize: 10,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 빈 북마크 뷰
  Widget _buildEmptyView() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.xl),
            decoration: BoxDecoration(
              color: isDark ? Colors.white12 : AppTheme.textHint.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.bookmark_outline,
              size: 48,
              color: isDark ? Colors.white38 : AppTheme.textHint,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            '저장된 북마크가 없습니다',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white70 : AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '관심있는 공지사항을 북마크에 저장해보세요',
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.white54 : AppTheme.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
