import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/notice.dart';
import '../../providers/notice_provider.dart';
import '../../theme/app_theme.dart';
import '../../screens/notice_detail_screen.dart';

/// 플립 가능한 공지 카드 위젯
///
/// 탭하면 Y축 기준 180° 회전하여 앞면(요약)↔뒷면(AI 요약+상세) 전환.
/// 카테고리별 색상 포인트, 적층 효과를 지원합니다.
class FlipNoticeCard extends StatefulWidget {
  final Notice notice;
  final double? height;
  final bool showStackEffect;
  final int stackIndex;

  const FlipNoticeCard({
    super.key,
    required this.notice,
    this.height,
    this.showStackEffect = false,
    this.stackIndex = 0,
  });

  @override
  State<FlipNoticeCard> createState() => _FlipNoticeCardState();
}

class _FlipNoticeCardState extends State<FlipNoticeCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  bool _isFront = true;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _animation = Tween<double>(begin: 0, end: math.pi)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final categoryColor = AppTheme.getCategoryColor(widget.notice.category, isDark: isDark);

    // 적층 효과: 아래 카드일수록 살짝 줄이고 오프셋
    final stackScale = widget.showStackEffect
        ? 1.0 - (widget.stackIndex * 0.02).clamp(0.0, 0.06)
        : 1.0;
    final stackOffset = widget.showStackEffect
        ? widget.stackIndex * -4.0
        : 0.0;

    return Transform.translate(
      offset: Offset(0, stackOffset),
      child: Transform.scale(
        scale: stackScale,
        child: AnimatedBuilder(
          animation: _animation,
          builder: (context, child) {
            final angle = _animation.value;
            final showFront = angle < math.pi / 2;

            return Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.002)
                ..rotateY(angle),
              child: showFront
                  ? _buildFront(isDark, categoryColor)
                  : Transform(
                      alignment: Alignment.center,
                      transform: Matrix4.identity()..rotateY(math.pi),
                      child: _buildBack(isDark, categoryColor),
                    ),
            );
          },
        ),
      ),
    );
  }

  /// 앞면: 공지 요약 카드
  Widget _buildFront(bool isDark, Color categoryColor) {
    final notice = widget.notice;
    final showDDay = notice.deadline != null &&
        notice.daysUntilDeadline != null &&
        notice.daysUntilDeadline! >= 0;
    final dDayColor =
        (notice.daysUntilDeadline != null && notice.daysUntilDeadline! <= 3)
            ? AppTheme.errorColor
            : AppTheme.infoColor;

    return GestureDetector(
      onTap: _toggleFlip,
      child: Container(
        height: widget.height,
        decoration: _cardDecoration(isDark, categoryColor),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 상단 카테고리 바 (금속 질감)
            _buildCategoryBar(isDark, categoryColor),
            // 콘텐츠
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 뱃지 행
                    _buildBadgeRow(notice, categoryColor, isDark),
                    const SizedBox(height: 8),
                    // 제목
                    Text(
                      notice.title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : AppTheme.textPrimary,
                        height: 1.35,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Spacer(),
                    // 하단: D-day + 메타
                    Row(
                      children: [
                        // D-day 플립 뱃지
                        if (showDDay) _buildDDayChip(notice, dDayColor, isDark),
                        if (showDDay) const SizedBox(width: 8),
                        const Spacer(),
                        // 메타 (조회수 + 날짜)
                        _buildCompactMeta(notice, isDark),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 뒷면: AI 요약 + 상세보기 버튼
  Widget _buildBack(bool isDark, Color categoryColor) {
    final notice = widget.notice;

    return GestureDetector(
      onTap: _toggleFlip,
      child: Container(
        height: widget.height,
        decoration: _cardDecoration(isDark, categoryColor),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 상단 바
            _buildCategoryBar(isDark, categoryColor),
            // AI 요약 콘텐츠
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // AI 아이콘 + 라벨
                    Row(
                      children: [
                        Icon(
                          Icons.auto_awesome,
                          size: 16,
                          color: categoryColor,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'AI 요약',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: categoryColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    // AI 요약 본문
                    Expanded(
                      child: Text(
                        notice.aiSummary ?? '요약 정보가 없습니다.',
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? Colors.white70 : AppTheme.textPrimary,
                          height: 1.5,
                        ),
                        overflow: TextOverflow.fade,
                      ),
                    ),
                    const SizedBox(height: 8),
                    // 상세보기 버튼
                    SizedBox(
                      width: double.infinity,
                      child: TextButton(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) =>
                                  NoticeDetailScreen(noticeId: notice.id),
                            ),
                          );
                        },
                        style: TextButton.styleFrom(
                          backgroundColor:
                              categoryColor.withOpacity(isDark ? 0.15 : 0.1),
                          foregroundColor: categoryColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppRadius.sm),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('상세보기',
                                style: TextStyle(
                                    fontWeight: FontWeight.w600, fontSize: 13)),
                            SizedBox(width: 4),
                            Icon(Icons.arrow_forward_ios, size: 12),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 카드 데코레이션 (금속 질감)
  BoxDecoration _cardDecoration(bool isDark, Color categoryColor) {
    return BoxDecoration(
      color: isDark ? const Color(0xFF1E1E30) : Colors.white,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      border: Border.all(
        color: isDark
            ? categoryColor.withOpacity(0.2)
            : Colors.grey.withOpacity(0.15),
        width: 1,
      ),
      boxShadow: [
        BoxShadow(
          color: isDark
              ? Colors.black.withOpacity(0.4)
              : Colors.black.withOpacity(0.08),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }

  /// 상단 카테고리 바 (얇은 금속 스트라이프)
  Widget _buildCategoryBar(bool isDark, Color categoryColor) {
    return Container(
      height: 4,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            categoryColor.withOpacity(0.7),
            categoryColor,
            categoryColor.withOpacity(0.7),
          ],
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
    );
  }

  /// 뱃지 행 (카테고리 + 우선순위 + NEW)
  Widget _buildBadgeRow(Notice notice, Color categoryColor, bool isDark) {
    return Row(
      children: [
        // 카테고리
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: categoryColor.withOpacity(isDark ? 0.2 : 0.1),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            notice.category,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: categoryColor,
            ),
          ),
        ),
        if (notice.priority != null && notice.priority != '일반') ...[
          const SizedBox(width: 4),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              color: _getPriorityColor(notice.priority!),
              borderRadius: BorderRadius.circular(4),
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
        if (notice.isNew) ...[
          const SizedBox(width: 4),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              color: AppTheme.errorColor,
              borderRadius: BorderRadius.circular(4),
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
        // 북마크
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
                    : (isDark ? Colors.white38 : AppTheme.textHint),
              ),
            );
          },
        ),
      ],
    );
  }

  /// D-day 칩 (플립 숫자 스타일)
  Widget _buildDDayChip(Notice notice, Color dDayColor, bool isDark) {
    final days = notice.daysUntilDeadline!;
    final text = days == 0 ? 'D-Day' : 'D-$days';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: dDayColor.withOpacity(isDark ? 0.15 : 0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: dDayColor.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.alarm_rounded, size: 12, color: dDayColor),
          const SizedBox(width: 3),
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: dDayColor,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }

  /// 컴팩트 메타 정보 (조회수 + 날짜)
  Widget _buildCompactMeta(Notice notice, bool isDark) {
    final metaColor = isDark ? Colors.white38 : AppTheme.textSecondary;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.visibility_outlined, size: 12, color: metaColor),
        const SizedBox(width: 3),
        Text(
          '${notice.views}',
          style: TextStyle(fontSize: 11, color: metaColor),
        ),
        const SizedBox(width: 8),
        Text(
          notice.formattedDate,
          style: TextStyle(
            fontSize: 11,
            color: isDark ? Colors.white24 : AppTheme.textHint,
          ),
        ),
      ],
    );
  }

  /// 우선순위 색상
  Color _getPriorityColor(String priority) {
    switch (priority) {
      case '긴급':
        return AppTheme.errorColor;
      case '중요':
        return AppTheme.warningColor;
      default:
        return AppTheme.textSecondary;
    }
  }
}
