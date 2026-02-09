import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
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
  int _currentImageIndex = 0;
  bool _isContentExpanded = false;

  @override
  void initState() {
    super.initState();
    _loadNoticeDetail();
  }

  /// 공지사항 상세 정보 로드
  Future<void> _loadNoticeDetail() async {
    final provider = context.read<NoticeProvider>();

    // getNoticeDetail 내부에서 북마크 상태를 처리하므로 별도 호출 불필요
    final notice = await provider.getNoticeDetail(widget.noticeId);

    if (kDebugMode) {
      debugPrint('[NoticeDetail] contentImages: ${notice?.contentImages}');
    }

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
                // Provider의 북마크 상태를 기준으로 표시 (캘린더/목록과 동기화)
                final isBookmarked = provider.bookmarkedNotices
                    .any((n) => n.id == _notice!.id);
                return IconButton(
                  icon: Icon(
                    isBookmarked
                        ? Icons.bookmark
                        : Icons.bookmark_outline,
                  ),
                  onPressed: () {
                    provider.toggleBookmark(_notice!.id);
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
          // 카테고리, 중요도, NEW 뱃지
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
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
              if (_notice!.priority != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _getPriorityColor(_notice!.priority!),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Text(
                    _notice!.priority!,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              if (_notice!.isNew)
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

          // AI 요약 (있는 경우)
          if (_notice!.aiSummary != null) ...[
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.auto_awesome, size: 18, color: Colors.blue.shade700),
                      const SizedBox(width: 6),
                      Text(
                        'AI 요약',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade900,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    _notice!.aiSummary!,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.blue.shade900,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
          ],

          // 마감일 표시 — 복수 마감일 지원
          if (_notice!.deadlines.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: _notice!.isDeadlineSoon ? Colors.red.shade50 : Colors.green.shade50,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(
                  color: _notice!.isDeadlineSoon ? Colors.red.shade200 : Colors.green.shade200,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 헤더
                  Row(
                    children: [
                      Icon(
                        Icons.event,
                        size: 18,
                        color: _notice!.isDeadlineSoon ? Colors.red.shade700 : Colors.green.shade700,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _notice!.hasMultipleDeadlines ? '마감일 목록' : '마감일',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: _notice!.isDeadlineSoon ? Colors.red.shade900 : Colors.green.shade900,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // 각 마감일 항목
                  ..._notice!.deadlines.map((dl) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${dl.label}: ~ ${dl.date.month.toString().padLeft(2, '0')}.${dl.date.day.toString().padLeft(2, '0')}',
                            style: TextStyle(
                              fontSize: 13,
                              color: _notice!.isDeadlineSoon ? Colors.red.shade800 : Colors.green.shade800,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: dl.isSoon ? Colors.red : Colors.green,
                            borderRadius: BorderRadius.circular(AppRadius.sm),
                          ),
                          child: Text(
                            dl.dDayText,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
          ] else if (_notice!.deadline != null) ...[
            // 기존 단일 마감일 호환 (deadlines 배열이 비어있는 경우)
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: _notice!.isDeadlineSoon ? Colors.red.shade50 : Colors.green.shade50,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(
                  color: _notice!.isDeadlineSoon ? Colors.red.shade200 : Colors.green.shade200,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.event,
                    size: 18,
                    color: _notice!.isDeadlineSoon ? Colors.red.shade700 : Colors.green.shade700,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '마감일: ${_notice!.deadline!.year}.${_notice!.deadline!.month.toString().padLeft(2, '0')}.${_notice!.deadline!.day.toString().padLeft(2, '0')}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: _notice!.isDeadlineSoon ? Colors.red.shade900 : Colors.green.shade900,
                    ),
                  ),
                  const Spacer(),
                  if (_notice!.daysUntilDeadline != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _notice!.isDeadlineSoon ? Colors.red : Colors.green,
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      child: Text(
                        _notice!.daysUntilDeadline! > 0
                            ? 'D-${_notice!.daysUntilDeadline}'
                            : _notice!.daysUntilDeadline == 0
                                ? 'D-Day'
                                : '마감',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
          ],

          // 메타 정보
          Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.sm,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
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
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
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
              if (_notice!.author != null)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.person_outline,
                      size: 16,
                      color: AppTheme.textSecondary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _notice!.author!,
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
            ],
          ),

          // 마감일은 상단 섹션(line 244)에서 이미 표시됨
        ],
      ),
    );
  }

  /// 학교 서버 이미지를 백엔드 프록시를 통해 로드하기 위한 URL 변환
  String _getProxyImageUrl(String originalUrl) {
    final backendUrl = dotenv.env['BACKEND_URL'] ?? 'http://localhost:5000';
    return '$backendUrl/api/notices/image-proxy?url=${Uri.encodeComponent(originalUrl)}';
  }

  /// 본문 영역 (AI가 판단한 display_mode에 따라 레이아웃 분기)
  /// - POSTER: 이미지 캐러셀 -> 원문 접기
  /// - DOCUMENT: Markdown 본문 -> 이미지(하단)
  /// - HYBRID: 이미지 캐러셀 -> 원문 접기
  Widget _buildBody() {
    switch (_notice!.displayMode) {
      case 'POSTER':
        return _buildPosterLayout();
      case 'HYBRID':
        return _buildHybridLayout();
      case 'DOCUMENT':
      default:
        return _buildDocumentLayout();
    }
  }

  /// POSTER 레이아웃: 이미지 중심 (이미지 -> 원문 접기)
  Widget _buildPosterLayout() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_notice!.hasImages)
            _buildImageCarousel(),
          // 원문이 제목과 다른 경우에만 접기 표시
          if (_notice!.content.isNotEmpty && _notice!.content != _notice!.title)
            _buildCollapsibleContent(),
        ],
      ),
    );
  }

  /// DOCUMENT 레이아웃: 텍스트 중심 (Markdown 본문 -> 이미지 하단)
  Widget _buildDocumentLayout() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_notice!.content.isNotEmpty)
            _buildMarkdownContent(),
          if (_notice!.hasImages) ...[
            const SizedBox(height: AppSpacing.md),
            _buildImageCarousel(),
          ],
        ],
      ),
    );
  }

  /// HYBRID 레이아웃: 이미지+텍스트 모두 중요 (이미지 -> 원문 접기)
  Widget _buildHybridLayout() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_notice!.hasImages)
            _buildImageCarousel(),
          if (_notice!.content.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            _buildCollapsibleContent(),
          ],
        ],
      ),
    );
  }

  /// 이미지 캐러셀 (1장: 단일 이미지, 2장+: 스와이프 캐러셀)
  Widget _buildImageCarousel() {
    final images = _notice!.contentImages;

    if (images.length == 1) {
      // 이미지 1장: 전체 너비 단일 이미지
      return ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Image.network(
          _getProxyImageUrl(images.first),
          width: double.infinity,
          fit: BoxFit.fitWidth,
          loadingBuilder: _imageLoadingBuilder,
          errorBuilder: _imageErrorBuilder,
        ),
      );
    }

    // 이미지 2장+: 캐러셀 슬라이더
    return Column(
      children: [
        CarouselSlider.builder(
          itemCount: images.length,
          options: CarouselOptions(
            height: 300.0,
            enlargeCenterPage: true,
            enlargeFactor: 0.2,
            viewportFraction: 0.92,
            enableInfiniteScroll: images.length > 2,
            onPageChanged: (index, reason) {
              setState(() => _currentImageIndex = index);
            },
          ),
          itemBuilder: (context, index, realIndex) {
            return ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.md),
              child: Image.network(
                _getProxyImageUrl(images[index]),
                width: double.infinity,
                fit: BoxFit.contain,
                loadingBuilder: _imageLoadingBuilder,
                errorBuilder: _imageErrorBuilder,
              ),
            );
          },
        ),
        const SizedBox(height: 12),
        // 하단 dot indicator
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: images.asMap().entries.map((entry) {
            final isActive = _currentImageIndex == entry.key;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: isActive ? 28.0 : 8.0,
              height: 8.0,
              margin: const EdgeInsets.symmetric(horizontal: 4.0),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.sm),
                color: isActive
                    ? AppTheme.primaryColor
                    : AppTheme.primaryColor.withOpacity(0.2),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  /// 접기/펼치기 원문 (POSTER/HYBRID 모드용)
  Widget _buildCollapsibleContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(),
        InkWell(
          onTap: () {
            setState(() => _isContentExpanded = !_isContentExpanded);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: Row(
              children: [
                Text(
                  '원문 보기',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primaryColor,
                  ),
                ),
                const Spacer(),
                Icon(
                  _isContentExpanded
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                  color: AppTheme.primaryColor,
                ),
              ],
            ),
          ),
        ),
        if (_isContentExpanded)
          _buildMarkdownContent(),
      ],
    );
  }

  /// 이미지 로딩 상태 표시
  Widget _imageLoadingBuilder(BuildContext context, Widget child, ImageChunkEvent? loadingProgress) {
    if (loadingProgress == null) return child;
    return Container(
      height: 200,
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: const Center(
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
    );
  }

  /// 이미지 로드 에러 표시
  Widget _imageErrorBuilder(BuildContext context, Object error, StackTrace? stackTrace) {
    if (kDebugMode) {
      debugPrint('[NoticeDetail] 이미지 로드 에러: $error');
    }
    return Container(
      height: 120,
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.broken_image, size: 36, color: Colors.grey.shade400),
          const SizedBox(height: 8),
          Text(
            '이미지를 불러올 수 없습니다',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  /// Markdown 본문 렌더링 (표, 볼드, 리스트 등 구조 보존)
  Widget _buildMarkdownContent() {
    // Markdown 내 이미지 문법(![](url))을 제거하여 텍스트만 표시
    var cleaned = _notice!.content
        .replaceAll(RegExp(r'!\[.*?\]\(.*?\)'), '');
    // 짝이 맞지 않는 ** 마커 제거 (줄 단위로 ** 개수가 홀수면 제거)
    cleaned = cleaned.split('\n').map((line) {
      if ('**'.allMatches(line).length % 2 != 0) {
        return line.replaceAll('**', '');
      }
      return line;
    }).join('\n');
    // 줄바꿈 보존: Markdown에서 단일 \n은 공백으로 처리되므로
    // trailing 2 spaces를 추가하여 hard line break로 변환
    cleaned = cleaned.replaceAll('\n', '  \n');
    final contentWithoutImages = cleaned
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();

    return MarkdownBody(
      data: contentWithoutImages,
      selectable: true,
      styleSheet: MarkdownStyleSheet(
        p: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.6),
        h1: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
        h2: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        h3: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        tableHead: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        tableBody: const TextStyle(fontSize: 14),
        tableBorder: TableBorder.all(color: Colors.grey.shade300, width: 1),
        tableCellsPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        blockquoteDecoration: BoxDecoration(
          color: Colors.grey.shade50,
          border: Border(left: BorderSide(color: Colors.grey.shade400, width: 3)),
        ),
        listBullet: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.6),
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

  /// 공지사항 공유 (시스템 공유 시트 사용)
  Future<void> _shareNotice() async {
    if (_notice == null) return;

    final title = _notice!.title;
    final url = _notice!.url ?? '';
    final category = _notice!.category;
    final deadline = _notice!.deadline != null
        ? '마감: ${_notice!.deadline!.month}/${_notice!.deadline!.day}'
        : '';

    // 공유 텍스트 구성
    final shareText = '''
[$category] $title
${deadline.isNotEmpty ? '\n$deadline' : ''}
${url.isNotEmpty ? '\n$url' : ''}

AIX-Boost 앱에서 확인하세요!
''';

    try {
      await Share.share(
        shareText.trim(),
        subject: title,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('공유 실패: $e')),
        );
      }
    }
  }

  /// 중요도에 따른 색상 반환
  Color _getPriorityColor(String priority) {
    switch (priority) {
      case '긴급':
        return Colors.red.shade700;
      case '중요':
        return Colors.orange.shade700;
      case '일반':
      default:
        return Colors.grey.shade600;
    }
  }
}
