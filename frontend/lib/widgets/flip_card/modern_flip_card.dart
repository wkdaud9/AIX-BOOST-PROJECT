import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/notice.dart';
import '../../providers/notice_provider.dart';
import '../../theme/app_theme.dart';
import '../../screens/notice_detail_screen.dart';

/// 모던 플립 카드 위젯
///
/// 깔끔한 디지털 카드 스타일. 탭하면 Y축 180° 회전하여
/// 앞면(요약)↔뒷면(AI 요약+상세보기) 전환.
/// Theme.of(context).colorScheme 기반으로 라이트/다크 모드 자동 대응.
class ModernFlipCard extends StatefulWidget {
  final Notice notice;
  final double? height;

  const ModernFlipCard({
    super.key,
    required this.notice,
    this.height,
  });

  @override
  State<ModernFlipCard> createState() => _ModernFlipCardState();
}

class _ModernFlipCardState extends State<ModernFlipCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  bool _isFront = true;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _animation = Tween<double>(begin: 0, end: math.pi).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// 카드 플립 토글
  void _toggleFlip() {
    if (_isFront) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
    _isFront = !_isFront;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final categoryColor = AppTheme.getCategoryColor(widget.notice.category);

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        final angle = _animation.value;
        final showFront = angle < math.pi / 2;

        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.0015)
            ..rotateY(angle),
          child: showFront
              ? _buildFront(colorScheme, categoryColor)
              : Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.identity()..rotateY(math.pi),
                  child: _buildBack(colorScheme, categoryColor),
                ),
        );
      },
    );
  }

  /// 앞면: 공지 요약 카드 (쇼츠 스타일 세로 레이아웃)
  Widget _buildFront(ColorScheme colorScheme, Color categoryColor) {
    final notice = widget.notice;
    final showDDay = notice.deadline != null &&
        notice.daysUntilDeadline != null &&
        notice.daysUntilDeadline! >= 0;

    return GestureDetector(
      onTap: _toggleFlip,
      child: Container(
        height: widget.height,
        decoration: _cardDecoration(colorScheme, categoryColor),
        child: Stack(
          children: [
            // 좌측 카테고리 악센트 바
            Positioned(
              left: 0,
              top: 16,
              bottom: 16,
              child: Container(
                width: 3.5,
                decoration: BoxDecoration(
                  color: categoryColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // 중앙 크리스 라인 (미세한 접힘 표시)
            Positioned(
              left: 28,
              right: 28,
              top: 0,
              bottom: 0,
              child: Center(
                child: Container(
                  height: 1,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        colorScheme.onSurface.withOpacity(0.04),
                        colorScheme.onSurface.withOpacity(0.06),
                        colorScheme.onSurface.withOpacity(0.04),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),
            // 콘텐츠
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 20, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 상단: 카테고리 칩 + 우선순위 + 북마크
                  _buildTopRow(colorScheme, categoryColor, notice),
                  const SizedBox(height: 16),
                  // 제목
                  Text(
                    notice.title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: colorScheme.onSurface,
                      height: 1.4,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 12),
                  // AI 요약 (아이콘 + 배경 강조, 다크모드 대비 보장)
                  if (notice.aiSummary != null &&
                      notice.aiSummary!.isNotEmpty)
                    Expanded(
                      child: Builder(builder: (context) {
                        final isDark = Theme.of(context).brightness == Brightness.dark;
                        final aiAccent = isDark ? AppTheme.primaryLight : colorScheme.primary;
                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: aiAccent.withOpacity(isDark ? 0.12 : 0.04),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: aiAccent.withOpacity(isDark ? 0.25 : 0.08),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.auto_awesome,
                                    size: 14,
                                    color: aiAccent,
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    'AI 요약',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: aiAccent,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Expanded(
                                child: Text(
                                  notice.aiSummary!,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: colorScheme.onSurface
                                        .withOpacity(isDark ? 0.8 : 0.6),
                                    height: 1.5,
                                  ),
                                  overflow: TextOverflow.fade,
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ),
                  if (notice.aiSummary == null || notice.aiSummary!.isEmpty)
                    const Spacer(),
                  const SizedBox(height: 12),
                  // 하단: D-day + 메타 정보
                  Row(
                    children: [
                      if (showDDay) _buildDDayBadge(notice, colorScheme),
                      if (showDDay) const SizedBox(width: 8),
                      const Spacer(),
                      _buildMeta(notice, colorScheme),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 뒷면: AI 요약 + 상세보기 (쇼츠 스타일 세로 레이아웃)
  Widget _buildBack(ColorScheme colorScheme, Color categoryColor) {
    final notice = widget.notice;

    return GestureDetector(
      onTap: _toggleFlip,
      child: Container(
        height: widget.height,
        decoration: _cardDecoration(colorScheme, categoryColor),
        child: Stack(
          children: [
            // 좌측 악센트 바
            Positioned(
              left: 0,
              top: 16,
              bottom: 16,
              child: Container(
                width: 3.5,
                decoration: BoxDecoration(
                  color: categoryColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // 콘텐츠
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 20, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // AI 라벨 + 제목
                  Row(
                    children: [
                      Icon(Icons.auto_awesome, size: 16, color: categoryColor),
                      const SizedBox(width: 6),
                      Text(
                        'AI 요약',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: categoryColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // 공지 제목 (뒷면에서도 확인 가능)
                  Text(
                    notice.title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurface.withOpacity(0.5),
                      height: 1.35,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 14),
                  // 구분선
                  Container(
                    height: 1,
                    color: colorScheme.onSurface.withOpacity(0.06),
                  ),
                  const SizedBox(height: 14),
                  // AI 요약 전문
                  Expanded(
                    child: Text(
                      notice.aiSummary ?? '요약 정보가 없습니다.',
                      style: TextStyle(
                        fontSize: 14,
                        color: colorScheme.onSurface.withOpacity(0.7),
                        height: 1.6,
                      ),
                      overflow: TextOverflow.fade,
                    ),
                  ),
                  const SizedBox(height: 12),
                  // 상세보기 버튼
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: TextButton(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                NoticeDetailScreen(noticeId: notice.id),
                          ),
                        );
                      },
                      style: TextButton.styleFrom(
                        backgroundColor: categoryColor.withOpacity(
                            Theme.of(context).brightness == Brightness.dark ? 0.2 : 0.08),
                        foregroundColor: categoryColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                        ),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('상세보기',
                              style: TextStyle(
                                  fontWeight: FontWeight.w600, fontSize: 14)),
                          SizedBox(width: 4),
                          Icon(Icons.arrow_forward_ios, size: 13),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 카드 데코레이션 (colorScheme 기반)
  BoxDecoration _cardDecoration(ColorScheme colorScheme, Color categoryColor) {
    return BoxDecoration(
      color: colorScheme.surface,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      border: Border.all(
        color: colorScheme.onSurface.withOpacity(0.06),
      ),
      boxShadow: [
        BoxShadow(
          color: colorScheme.shadow.withOpacity(0.08),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
        BoxShadow(
          color: colorScheme.shadow.withOpacity(0.03),
          blurRadius: 4,
          offset: const Offset(0, 1),
        ),
      ],
    );
  }

  /// 상단 행: 카테고리 칩 + 우선순위 + 북마크
  Widget _buildTopRow(
      ColorScheme colorScheme, Color categoryColor, Notice notice) {
    return Row(
      children: [
        // 카테고리 칩
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: categoryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            notice.category,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: categoryColor,
            ),
          ),
        ),
        // 우선순위 뱃지
        if (notice.priority != null && notice.priority != '일반') ...[
          const SizedBox(width: 5),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              color: notice.priority == '긴급'
                  ? colorScheme.error
                  : AppTheme.warningColor,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              notice.priority!,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold),
            ),
          ),
        ],
        // NEW 뱃지
        if (notice.isNew) ...[
          const SizedBox(width: 5),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              color: colorScheme.error,
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Text(
              'NEW',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold),
            ),
          ),
        ],
        const Spacer(),
        // 북마크 아이콘
        Consumer<NoticeProvider>(
          builder: (context, provider, child) {
            return GestureDetector(
              onTap: () => provider.toggleBookmark(notice.id),
              child: Icon(
                notice.isBookmarked
                    ? Icons.bookmark_rounded
                    : Icons.bookmark_border_rounded,
                size: 20,
                color: notice.isBookmarked
                    ? categoryColor
                    : colorScheme.onSurface.withOpacity(0.25),
              ),
            );
          },
        ),
      ],
    );
  }

  /// D-day 뱃지
  Widget _buildDDayBadge(Notice notice, ColorScheme colorScheme) {
    final days = notice.daysUntilDeadline!;
    final isUrgent = days <= 3;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = isUrgent ? colorScheme.error : (isDark ? AppTheme.primaryLight : colorScheme.primary);
    final text = days == 0 ? 'D-Day' : 'D-$days';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.alarm_rounded, size: 12, color: color),
          const SizedBox(width: 3),
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  /// 메타 정보 (조회수 + 날짜)
  Widget _buildMeta(Notice notice, ColorScheme colorScheme) {
    final metaColor = colorScheme.onSurface.withOpacity(0.35);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.visibility_outlined, size: 12, color: metaColor),
        const SizedBox(width: 3),
        Text('${notice.views}',
            style: TextStyle(fontSize: 11, color: metaColor)),
        const SizedBox(width: 8),
        Text(notice.formattedDate,
            style: TextStyle(fontSize: 11, color: metaColor)),
      ],
    );
  }
}
