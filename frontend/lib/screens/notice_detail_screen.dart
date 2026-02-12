import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart';
import '../env_config.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/notice.dart';
import '../providers/notice_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/animated_bookmark_button.dart';

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
                final isDark = Theme.of(context).brightness == Brightness.dark;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: AnimatedBookmarkButton(
                    isBookmarked: isBookmarked,
                    onTap: () => provider.toggleBookmark(_notice!.id),
                    activeColor: isDark ? AppTheme.primaryLight : AppTheme.primaryColor,
                    inactiveColor: AppTheme.textSecondary,
                    size: 26,
                  ),
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

          const SizedBox(height: AppSpacing.sm),

          // 본문 영역
          _buildBody(),

          const SizedBox(height: AppSpacing.sm),

          // 태그 영역 (카드형 섹션)
          if (_notice!.tags.isNotEmpty)
            _buildTags(),

          // 관련 링크 (카드형 섹션)
          if (_notice!.url != null)
            _buildUrlSection(),

          const SizedBox(height: AppSpacing.lg),
        ],
      ),
    );
  }

  /// 헤더 영역 (제목, 카테고리, 날짜 등)
  Widget _buildHeader() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      color: isDark ? const Color(0xFF0F2854) : AppTheme.surfaceColor,
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
                  color: AppTheme.getCategoryColor(_notice!.category, isDark: isDark)
                      .withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  border: Border.all(
                    color: AppTheme.getCategoryColor(_notice!.category, isDark: isDark),
                    width: 1,
                  ),
                ),
                child: Text(
                  _notice!.category,
                  style: TextStyle(
                    color: AppTheme.getCategoryColor(_notice!.category, isDark: isDark),
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
                color: (isDark ? AppTheme.primaryLight : AppTheme.primaryColor).withOpacity(isDark ? 0.1 : 0.08),
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: (isDark ? AppTheme.primaryLight : AppTheme.primaryColor).withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.auto_awesome, size: 18, color: isDark ? AppTheme.primaryLight : AppTheme.primaryColor),
                      const SizedBox(width: 6),
                      Text(
                        'AI 요약',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : AppTheme.primaryDark,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    _notice!.aiSummary!,
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? Colors.white70 : AppTheme.primaryDark,
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
                color: _notice!.isDeadlineSoon
                    ? AppTheme.errorColor.withOpacity(isDark ? 0.15 : 0.08)
                    : AppTheme.successColor.withOpacity(isDark ? 0.15 : 0.08),
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(
                  color: _notice!.isDeadlineSoon
                      ? AppTheme.errorColor.withOpacity(0.3)
                      : AppTheme.successColor.withOpacity(0.3),
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
                        color: _notice!.isDeadlineSoon ? AppTheme.errorColor : AppTheme.successColor,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _notice!.hasMultipleDeadlines ? '마감일 목록' : '마감일',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : (_notice!.isDeadlineSoon ? AppTheme.errorColor : AppTheme.successColor),
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
                              color: isDark ? Colors.white70 : (_notice!.isDeadlineSoon ? AppTheme.errorColor : AppTheme.successColor),
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: dl.isSoon ? AppTheme.errorColor : AppTheme.successColor,
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
                color: _notice!.isDeadlineSoon
                    ? AppTheme.errorColor.withOpacity(isDark ? 0.15 : 0.08)
                    : AppTheme.successColor.withOpacity(isDark ? 0.15 : 0.08),
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(
                  color: _notice!.isDeadlineSoon
                      ? AppTheme.errorColor.withOpacity(0.3)
                      : AppTheme.successColor.withOpacity(0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.event,
                    size: 18,
                    color: _notice!.isDeadlineSoon ? AppTheme.errorColor : AppTheme.successColor,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '마감일: ${_notice!.deadline!.year}.${_notice!.deadline!.month.toString().padLeft(2, '0')}.${_notice!.deadline!.day.toString().padLeft(2, '0')}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : (_notice!.isDeadlineSoon ? AppTheme.errorColor : AppTheme.successColor),
                    ),
                  ),
                  const Spacer(),
                  if (_notice!.daysUntilDeadline != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _notice!.isDeadlineSoon ? AppTheme.errorColor : AppTheme.successColor,
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      child: Text(
                        _notice!.deadlineDDayText ?? '마감',
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
    final backendUrl = EnvConfig.backendUrl;
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

  /// 본문 컨텐츠를 카드로 감싸는 공통 래퍼 (양옆 가득 채움)
  Widget _buildBodyCard({required Widget child}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      color: isDark ? const Color(0xFF0F2854) : AppTheme.surfaceColor,
      child: child,
    );
  }

  /// POSTER 레이아웃: 이미지 중심 (이미지 -> 원문 접기)
  Widget _buildPosterLayout() {
    return _buildBodyCard(
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
    return _buildBodyCard(
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
    return _buildBodyCard(
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
                    ? (Theme.of(context).brightness == Brightness.dark ? AppTheme.primaryLight : AppTheme.primaryColor)
                    : (Theme.of(context).brightness == Brightness.dark ? AppTheme.primaryLight : AppTheme.primaryColor).withOpacity(0.25),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  /// 접기/펼치기 원문 (POSTER/HYBRID 모드용)
  Widget _buildCollapsibleContent() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accentColor = isDark ? AppTheme.primaryLight : AppTheme.primaryColor;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: AppSpacing.md),
        Align(
          alignment: Alignment.centerRight,
          child: InkWell(
            onTap: () {
              setState(() => _isContentExpanded = !_isContentExpanded);
            },
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm + 2,
              ),
              decoration: BoxDecoration(
                color: accentColor.withOpacity(isDark ? 0.12 : 0.06),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.description_outlined,
                    size: 16,
                    color: accentColor,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '본문 보기',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: accentColor,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    _isContentExpanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    size: 18,
                    color: accentColor,
                  ),
                ],
              ),
            ),
          ),
        ),
        if (_isContentExpanded) ...[
          const SizedBox(height: AppSpacing.md),
          _buildMarkdownContent(),
        ],
      ],
    );
  }

  /// 이미지 로딩 상태 표시
  Widget _imageLoadingBuilder(BuildContext context, Widget child, ImageChunkEvent? loadingProgress) {
    if (loadingProgress == null) return child;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      height: 200,
      decoration: BoxDecoration(
        color: isDark ? AppTheme.secondaryColor : Colors.grey.shade100,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      height: 120,
      decoration: BoxDecoration(
        color: isDark ? AppTheme.secondaryColor : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: isDark ? Colors.white12 : Colors.grey.shade300),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.broken_image, size: 36, color: isDark ? Colors.white38 : AppTheme.textHint),
          const SizedBox(height: 8),
          Text(
            '이미지를 불러올 수 없습니다',
            style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }

  /// Markdown 본문 렌더링 (표, 볼드, 리스트 등 구조 보존 + 정렬 지원)
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

    // 정렬 마커 확인 ({=center=}...{=/center=}, {=right=}...{=/right=})
    final hasAlignMarkers =
        cleaned.contains('{=center=}') || cleaned.contains('{=right=}');

    if (!hasAlignMarkers) {
      // 정렬 마커 없으면 기존 방식으로 렌더링
      cleaned = cleaned.replaceAll('\n', '  \n');
      final content = cleaned.replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();
      return _buildMarkdownBody(content);
    }

    // 정렬 마커가 있으면 섹션별 렌더링
    final sections = _parseAlignedSections(cleaned);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: sections.map((section) {
        var text = section.text
            .replaceAll('\n', '  \n')
            .replaceAll(RegExp(r'\n{3,}'), '\n\n')
            .trim();
        if (text.isEmpty) return const SizedBox.shrink();

        final align = section.align == 'center'
            ? WrapAlignment.center
            : section.align == 'right'
                ? WrapAlignment.end
                : WrapAlignment.start;
        return _buildMarkdownBody(text, textAlign: align);
      }).toList(),
    );
  }

  /// 정렬 마커를 파싱하여 섹션 리스트 반환
  List<_AlignedSection> _parseAlignedSections(String content) {
    final sections = <_AlignedSection>[];
    final regex =
        RegExp(r'\{=(center|right)=\}(.*?)\{=/\1=\}', dotAll: true);

    int lastEnd = 0;
    for (final match in regex.allMatches(content)) {
      // 마커 이전 텍스트 (정렬 없음)
      if (match.start > lastEnd) {
        final before = content.substring(lastEnd, match.start).trim();
        if (before.isNotEmpty) {
          sections.add(_AlignedSection('left', before));
        }
      }
      // 정렬된 텍스트
      final align = match.group(1)!;
      final text = match.group(2)!.trim();
      if (text.isNotEmpty) {
        sections.add(_AlignedSection(align, text));
      }
      lastEnd = match.end;
    }

    // 마지막 마커 이후 남은 텍스트
    if (lastEnd < content.length) {
      final remaining = content.substring(lastEnd).trim();
      if (remaining.isNotEmpty) {
        sections.add(_AlignedSection('left', remaining));
      }
    }

    return sections;
  }

  /// MarkdownBody 위젯 생성 헬퍼
  Widget _buildMarkdownBody(String data,
      {WrapAlignment textAlign = WrapAlignment.start}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return MarkdownBody(
      data: data,
      selectable: true,
      onTapLink: (text, href, title) {
        if (href != null) _openUrl(href);
      },
      styleSheet: MarkdownStyleSheet(
        p: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.6),
        a: TextStyle(color: isDark ? AppTheme.primaryLight : AppTheme.primaryColor, decoration: TextDecoration.underline),
        h1: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
        h2: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        h3: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        tableHead: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isDark ? Colors.white : AppTheme.textPrimary),
        tableBody: TextStyle(fontSize: 14, color: isDark ? Colors.white : AppTheme.textPrimary),
        tableBorder: TableBorder.all(color: isDark ? Colors.white24 : Colors.grey.shade300, width: 1),
        tableCellsPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        blockquoteDecoration: BoxDecoration(
          color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade50,
          border: Border(left: BorderSide(color: isDark ? Colors.white38 : Colors.grey.shade400, width: 3)),
        ),
        listBullet: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.6),
        textAlign: textAlign,
      ),
    );
  }

  /// 태그 영역 (가득 채움 + 여백)
  Widget _buildTags() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tagAccent = isDark ? AppTheme.primaryLight : AppTheme.primaryColor;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      color: isDark ? const Color(0xFF0F2854) : AppTheme.surfaceColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.tag, size: 16, color: tagAccent),
              const SizedBox(width: 6),
              Text(
                '태그',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: isDark ? Colors.white70 : AppTheme.textSecondary,
                ),
              ),
            ],
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
                  color: tagAccent.withOpacity(isDark ? 0.15 : 0.08),
                  borderRadius: BorderRadius.circular(AppRadius.round),
                ),
                child: Text(
                  '#$tag',
                  style: TextStyle(
                    color: tagAccent,
                    fontSize: 13,
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

  /// URL 섹션 (가득 채움 + 여백)
  Widget _buildUrlSection() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final urlAccent = isDark ? AppTheme.primaryLight : AppTheme.primaryColor;

    return Container(
      width: double.infinity,
      color: isDark ? const Color(0xFF0F2854) : AppTheme.surfaceColor,
      child: InkWell(
        onTap: () => _openUrl(_notice!.url!),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: urlAccent.withOpacity(isDark ? 0.15 : 0.08),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Icon(Icons.link, size: 20, color: urlAccent),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '관련 링크',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: isDark ? Colors.white70 : AppTheme.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _notice!.url!,
                      style: TextStyle(
                        color: urlAccent,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.open_in_new,
                color: urlAccent,
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 외부 URL 열기
  Future<void> _openUrl(String url) async {
    // http/https 스킴 누락 시 보정
    String targetUrl = url.trim();
    if (!targetUrl.startsWith('http://') && !targetUrl.startsWith('https://')) {
      targetUrl = 'https://$targetUrl';
    }

    final uri = Uri.tryParse(targetUrl);
    if (uri == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('올바르지 않은 링크 형식입니다.')),
        );
      }
      return;
    }

    try {
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('링크를 열 수 없습니다.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('링크 열기 실패: $e')),
        );
      }
    }
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

HeyBro 앱에서 확인하세요!
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
        return AppTheme.errorColor;
      case '중요':
        return AppTheme.warningColor;
      case '일반':
      default:
        return AppTheme.textSecondary;
    }
  }

}

/// 정렬 정보가 포함된 Markdown 섹션
class _AlignedSection {
  final String align; // 'left', 'center', 'right'
  final String text;
  const _AlignedSection(this.align, this.text);
}
