import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/notice.dart';
import '../providers/notice_provider.dart';
import '../theme/app_theme.dart';

/// 공지사항 상세 화면
class NoticeDetailScreen extends StatefulWidget {
  final String noticeId;

  const NoticeDetailScreen({
    super.key,
    required this.noticeId,
  });

  @override
  State<NoticeDetailScreen> createState() => _NoticeDetailScreenState();
}

class _NoticeDetailScreenState extends State<NoticeDetailScreen> {
  Notice? _notice;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadNoticeDetail();
  }

  /// 공지사항 상세 정보 로드
  Future<void> _loadNoticeDetail() async {
    final provider = context.read<NoticeProvider>();
    final notice = await provider.getNoticeDetail(widget.noticeId);

    if (mounted) {
      setState(() {
        _notice = notice;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('공지사항'),
        actions: [
          if (_notice != null)
            Consumer<NoticeProvider>(
              builder: (context, provider, child) {
                return IconButton(
                  icon: Icon(
                    _notice!.isBookmarked
                        ? Icons.bookmark
                        : Icons.bookmark_outline,
                  ),
                  onPressed: () {
                    provider.toggleBookmark(_notice!.id);
                    setState(() {
                      _notice = _notice!.copyWith(
                        isBookmarked: !_notice!.isBookmarked,
                      );
                    });
                  },
                );
              },
            ),
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: _shareNotice,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _notice == null
              ? _buildErrorView()
              : _buildNoticeContent(),
    );
  }

  /// 공지사항 내용 표시
  Widget _buildNoticeContent() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 헤더 영역
          _buildHeader(),

          const Divider(height: 1),

          // 본문 영역
          _buildBody(),

          // 태그 영역
          if (_notice!.tags.isNotEmpty) ...[
            const Divider(height: 1),
            _buildTags(),
          ],

          // 관련 링크
          if (_notice!.url != null) ...[
            const Divider(height: 1),
            _buildUrlSection(),
          ],
        ],
      ),
    );
  }

  /// 헤더 영역 (제목, 카테고리, 날짜 등)
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      color: AppTheme.surfaceColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 카테고리와 NEW 뱃지
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.getCategoryColor(_notice!.category)
                      .withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  border: Border.all(
                    color: AppTheme.getCategoryColor(_notice!.category),
                    width: 1,
                  ),
                ),
                child: Text(
                  _notice!.category,
                  style: TextStyle(
                    color: AppTheme.getCategoryColor(_notice!.category),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (_notice!.isNew) ...[
                const SizedBox(width: AppSpacing.sm),
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
            ],
          ),

          const SizedBox(height: AppSpacing.md),

          // 제목
          Text(
            _notice!.title,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),

          const SizedBox(height: AppSpacing.md),

          // 메타 정보
          Row(
            children: [
              Icon(
                Icons.calendar_today,
                size: 16,
                color: AppTheme.textSecondary,
              ),
              const SizedBox(width: 4),
              Text(
                _notice!.formattedDate,
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 14,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Icon(
                Icons.visibility,
                size: 16,
                color: AppTheme.textSecondary,
              ),
              const SizedBox(width: 4),
              Text(
                '${_notice!.views}',
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 14,
                ),
              ),
            ],
          ),

          // 마감일 (있는 경우)
          if (_notice!.deadline != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: _notice!.isDeadlineSoon
                    ? AppTheme.errorColor.withOpacity(0.1)
                    : AppTheme.infoColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.access_time,
                    size: 16,
                    color: _notice!.isDeadlineSoon
                        ? AppTheme.errorColor
                        : AppTheme.infoColor,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '마감일: ${_notice!.deadline!.year}.${_notice!.deadline!.month.toString().padLeft(2, '0')}.${_notice!.deadline!.day.toString().padLeft(2, '0')}',
                    style: TextStyle(
                      color: _notice!.isDeadlineSoon
                          ? AppTheme.errorColor
                          : AppTheme.infoColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (_notice!.daysUntilDeadline != null) ...[
                    const SizedBox(width: 4),
                    Text(
                      '(D-${_notice!.daysUntilDeadline})',
                      style: TextStyle(
                        color: _notice!.isDeadlineSoon
                            ? AppTheme.errorColor
                            : AppTheme.infoColor,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// 본문 영역
  Widget _buildBody() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: SelectableText(
        _notice!.content,
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              height: 1.6,
            ),
      ),
    );
  }

  /// 태그 영역
  Widget _buildTags() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '태그',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: _notice!.tags.map((tag) {
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppRadius.round),
                  border: Border.all(
                    color: AppTheme.primaryColor.withOpacity(0.3),
                  ),
                ),
                child: Text(
                  '#$tag',
                  style: const TextStyle(
                    color: AppTheme.primaryColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  /// URL 섹션
  Widget _buildUrlSection() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '관련 링크',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.sm),
          InkWell(
            onTap: () {
              // TODO: URL 열기 (url_launcher 패키지 사용)
            },
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.link,
                    color: AppTheme.primaryColor,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      _notice!.url!,
                      style: const TextStyle(
                        color: AppTheme.primaryColor,
                        decoration: TextDecoration.underline,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Icon(
                    Icons.open_in_new,
                    color: AppTheme.primaryColor,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 에러 뷰
  Widget _buildErrorView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.error_outline,
            size: 64,
            color: AppTheme.textSecondary,
          ),
          const SizedBox(height: AppSpacing.md),
          const Text('공지사항을 불러올 수 없습니다.'),
          const SizedBox(height: AppSpacing.md),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('돌아가기'),
          ),
        ],
      ),
    );
  }

  /// 공지사항 공유
  void _shareNotice() {
    // TODO: 공유 기능 구현 (share_plus 패키지 사용)
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('공유 기능은 준비 중입니다.')),
    );
  }
}
