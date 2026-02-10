import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/notice.dart';
import '../providers/notice_provider.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import 'notice_detail_screen.dart';

/// 전체 공지사항 검색 화면
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ApiService _apiService = ApiService();

  List<Notice> _searchResults = [];
  bool _isLoading = false;
  bool _hasSearched = false;
  String? _errorMessage;
  Timer? _debounceTimer;

  @override
  void dispose() {
    _searchController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  /// 검색어 변경 시 디바운스 처리 (500ms 지연 후 검색 실행)
  void _onSearchChanged(String query) {
    _debounceTimer?.cancel();

    if (query.trim().length < 2) {
      setState(() {
        _searchResults = [];
        _hasSearched = false;
        _errorMessage = null;
      });
      return;
    }

    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      _performSearch(query.trim());
    });
  }

  /// 검색 실행 (API 호출)
  Future<void> _performSearch(String query) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final results = await _apiService.searchNotices(query: query);
      if (mounted) {
        setState(() {
          _searchResults =
              results.map((json) => Notice.fromJson(json)).toList();
          _hasSearched = true;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
          _isLoading = false;
          _hasSearched = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? Theme.of(context).scaffoldBackgroundColor : AppTheme.backgroundColor,
      appBar: _buildAppBar(isDark),
      body: _buildBody(isDark),
    );
  }

  /// 검색 AppBar (TextField 포함)
  PreferredSizeWidget _buildAppBar(bool isDark) {
    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios),
        onPressed: () => Navigator.pop(context),
      ),
      title: TextField(
        controller: _searchController,
        autofocus: true,
        onChanged: _onSearchChanged,
        decoration: InputDecoration(
          hintText: '공지사항 검색...',
          hintStyle: TextStyle(
            color: isDark ? Colors.white38 : AppTheme.textHint,
            fontSize: 16,
          ),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: EdgeInsets.zero,
          isDense: true,
          filled: false,
        ),
        style: TextStyle(
          fontSize: 16,
          color: isDark ? Colors.white : AppTheme.textPrimary,
        ),
      ),
      actions: [
        if (_searchController.text.isNotEmpty)
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () {
              _searchController.clear();
              _onSearchChanged('');
            },
          ),
      ],
      elevation: 0,
      backgroundColor:
          isDark ? Theme.of(context).scaffoldBackgroundColor : AppTheme.surfaceColor,
    );
  }

  /// 본문 상태 분기
  Widget _buildBody(bool isDark) {
    if (_errorMessage != null) {
      return _buildErrorView(isDark);
    }
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }
    if (!_hasSearched) {
      return _buildInitialView(isDark);
    }
    if (_searchResults.isEmpty) {
      return _buildEmptyView(isDark);
    }
    return _buildResultsList(isDark);
  }

  /// 초기 화면 (검색 전)
  Widget _buildInitialView(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withOpacity(0.05)
                  : AppTheme.primaryColor.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.search,
              size: 44,
              color: isDark
                  ? Colors.white24
                  : AppTheme.primaryColor.withOpacity(0.4),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            '검색어를 입력해주세요',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white54 : AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '2자 이상 입력하면 자동으로 검색됩니다',
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.white38 : AppTheme.textHint,
            ),
          ),
        ],
      ),
    );
  }

  /// 검색 결과 없음 화면
  Widget _buildEmptyView(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withOpacity(0.05)
                  : AppTheme.textHint.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.search_off,
              size: 44,
              color: isDark ? Colors.white24 : AppTheme.textHint,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            '검색 결과가 없습니다',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white54 : AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '다른 키워드로 검색해보세요',
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.white38 : AppTheme.textHint,
            ),
          ),
        ],
      ),
    );
  }

  /// 에러 화면
  Widget _buildErrorView(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 48,
            color: isDark ? Colors.white38 : AppTheme.errorColor.withOpacity(0.6),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            _errorMessage ?? '검색 중 오류가 발생했습니다',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.white54 : AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          TextButton(
            onPressed: () {
              if (_searchController.text.trim().length >= 2) {
                _performSearch(_searchController.text.trim());
              }
            },
            child: const Text('다시 시도'),
          ),
        ],
      ),
    );
  }

  /// 검색 결과 목록
  Widget _buildResultsList(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.sm,
          ),
          child: Text(
            '검색 결과 ${_searchResults.length}건',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white54 : AppTheme.textSecondary,
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            itemCount: _searchResults.length,
            itemBuilder: (context, index) {
              return _buildNoticeCard(_searchResults[index], isDark);
            },
          ),
        ),
      ],
    );
  }

  /// 공지사항 카드 (CategoryNoticeScreen 패턴 재사용)
  Widget _buildNoticeCard(Notice notice, bool isDark) {
    final categoryColor = AppTheme.getCategoryColor(notice.category);
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
        color: isDark ? const Color(0xFF25253D) : Colors.white,
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
                      // 뱃지 행 (카테고리 + 우선순위 + NEW + D-day)
                      _buildBadgeRow(
                          notice, categoryColor, showDDay, dDayColor, isDark),
                      const SizedBox(height: AppSpacing.sm),
                      // 제목
                      Text(
                        notice.title,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : AppTheme.textPrimary,
                          height: 1.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      // AI 요약
                      if (notice.aiSummary != null &&
                          notice.aiSummary!.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          notice.aiSummary!,
                          style: TextStyle(
                            fontSize: 12,
                            color:
                                isDark ? Colors.white54 : AppTheme.textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const SizedBox(height: AppSpacing.sm),
                      // 메타 행
                      _buildMetaRow(notice, isDark),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                // 우측: 썸네일 + 북마크
                Column(
                  children: [
                    _buildThumbnail(notice, categoryColor, isDark),
                    const SizedBox(height: AppSpacing.sm),
                    _buildBookmarkButton(notice, isDark),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 뱃지 행 (카테고리 + 우선순위 + NEW + D-day)
  Widget _buildBadgeRow(
    Notice notice,
    Color categoryColor,
    bool showDDay,
    Color dDayColor,
    bool isDark,
  ) {
    return Wrap(
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      children: [
        // 카테고리 뱃지
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 3),
          decoration: BoxDecoration(
            color: categoryColor.withOpacity(isDark ? 0.2 : 0.12),
            borderRadius: BorderRadius.circular(AppRadius.xs),
          ),
          child: Text(
            notice.category,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: categoryColor,
            ),
          ),
        ),
        // 우선순위 뱃지
        if (notice.priority != null && notice.priority != '일반')
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm, vertical: 3),
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
                horizontal: AppSpacing.sm, vertical: 3),
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
                horizontal: AppSpacing.sm, vertical: 3),
            decoration: BoxDecoration(
              color: dDayColor.withOpacity(isDark ? 0.2 : 0.1),
              borderRadius: BorderRadius.circular(AppRadius.xs),
              border: Border.all(color: dDayColor.withOpacity(0.4)),
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
    );
  }

  /// 메타 정보 행 (조회수 + 북마크 수 + 날짜)
  Widget _buildMetaRow(Notice notice, bool isDark) {
    final metaColor = isDark ? Colors.white38 : AppTheme.textSecondary;
    final hintColor = isDark ? Colors.white24 : AppTheme.textHint;

    return Row(
      children: [
        Icon(Icons.visibility_outlined, size: 14, color: metaColor),
        const SizedBox(width: 4),
        Text(
          '${notice.views}',
          style: TextStyle(fontSize: 12, color: metaColor, fontWeight: FontWeight.w500),
        ),
        const SizedBox(width: AppSpacing.md),
        Icon(Icons.bookmark_outlined, size: 14, color: metaColor),
        const SizedBox(width: 4),
        Text(
          '${notice.bookmarkCount}',
          style: TextStyle(fontSize: 12, color: metaColor, fontWeight: FontWeight.w500),
        ),
        const Spacer(),
        Text(
          notice.formattedDate,
          style: TextStyle(fontSize: 12, color: hintColor),
        ),
      ],
    );
  }

  /// 카테고리별 아이콘 매핑
  IconData _getCategoryIcon(String category) {
    switch (category) {
      case '학사':
      case '학사공지':
        return Icons.school_rounded;
      case '장학':
        return Icons.attach_money_rounded;
      case '취업':
        return Icons.work_rounded;
      case '행사':
      case '학생활동':
        return Icons.event_rounded;
      case '교육':
        return Icons.menu_book_rounded;
      case '공모전':
        return Icons.emoji_events_rounded;
      case '시설':
        return Icons.apartment_rounded;
      default:
        return Icons.article_outlined;
    }
  }

  /// 카테고리 아이콘 썸네일
  Widget _buildThumbnail(Notice notice, Color categoryColor, bool isDark) {
    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        color: isDark
            ? categoryColor.withOpacity(0.15)
            : categoryColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Icon(
        _getCategoryIcon(notice.category),
        size: 32,
        color: categoryColor.withOpacity(isDark ? 0.7 : 0.5),
      ),
    );
  }

  /// 북마크 토글 버튼
  Widget _buildBookmarkButton(Notice notice, bool isDark) {
    return Consumer<NoticeProvider>(
      builder: (context, provider, child) {
        return InkWell(
          borderRadius: BorderRadius.circular(AppRadius.round),
          onTap: () => provider.toggleBookmark(notice.id),
          child: Container(
            width: 44,
            height: 36,
            alignment: Alignment.center,
            child: Icon(
              notice.isBookmarked
                  ? Icons.bookmark_rounded
                  : Icons.bookmark_border_rounded,
              size: 22,
              color: notice.isBookmarked
                  ? AppTheme.primaryColor
                  : (isDark ? Colors.white38 : AppTheme.textSecondary),
            ),
          ),
        );
      },
    );
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
