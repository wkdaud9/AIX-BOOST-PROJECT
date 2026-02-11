import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/notice.dart';
import '../../providers/notice_provider.dart';
import '../../theme/app_theme.dart';
import '../../screens/notice_detail_screen.dart';

/// 모던 공지 카드 위젯
///
/// 미니멀 디지털 카드 스타일. 탭하면 상세 페이지로 이동.
/// Theme.of(context).colorScheme 기반으로 라이트/다크 모드 자동 대응.
class ModernFlipCard extends StatelessWidget {
  final Notice notice;
  final double? height;

  const ModernFlipCard({
    super.key,
    required this.notice,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final categoryColor = AppTheme.getCategoryColor(notice.category, isDark: isDark);
    final showDDay = notice.deadline != null &&
        notice.daysUntilDeadline != null &&
        notice.daysUntilDeadline! >= 0;

    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => NoticeDetailScreen(noticeId: notice.id),
          ),
        );
      },
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0D1F3C) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark
                ? Colors.white.withOpacity(0.06)
                : Colors.black.withOpacity(0.04),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.3 : 0.06),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.15 : 0.02),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 상단: 카테고리 + 뱃지 + 북마크
              _buildTopRow(colorScheme, categoryColor, isDark),
              const SizedBox(height: 20),
              // 제목
              Text(
                notice.title,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : AppTheme.textPrimary,
                  height: 1.35,
                  letterSpacing: -0.3,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 16),
              // AI 요약
              if (notice.aiSummary != null && notice.aiSummary!.isNotEmpty)
                Expanded(child: _buildAiSummary(isDark)),
              if (notice.aiSummary == null || notice.aiSummary!.isEmpty)
                const Spacer(),
              const SizedBox(height: 16),
              // 구분선
              Container(
                height: 1,
                color: isDark
                    ? Colors.white.withOpacity(0.06)
                    : Colors.black.withOpacity(0.04),
              ),
              const SizedBox(height: 14),
              // 하단: D-day + 메타 정보
              Row(
                children: [
                  if (showDDay) ...[
                    _buildDDayBadge(isDark),
                    const SizedBox(width: 10),
                  ],
                  const Spacer(),
                  _buildMeta(isDark),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 상단 행: 카테고리 칩 + 뱃지 + 북마크
  Widget _buildTopRow(
      ColorScheme colorScheme, Color categoryColor, bool isDark) {
    return Row(
      children: [
        // 카테고리 칩
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: categoryColor.withOpacity(isDark ? 0.15 : 0.08),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            notice.category,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: categoryColor,
            ),
          ),
        ),
        // 우선순위 뱃지
        if (notice.priority != null && notice.priority != '일반') ...[
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
              color: notice.priority == '긴급'
                  ? AppTheme.errorColor
                  : AppTheme.warningColor,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              notice.priority!,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
        // NEW 뱃지
        if (notice.isNew) ...[
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
              color: AppTheme.errorColor,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              'NEW',
              style: TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.3,
              ),
            ),
          ),
        ],
        const Spacer(),
        // 북마크 버튼
        Consumer<NoticeProvider>(
          builder: (context, provider, child) {
            final isBookmarked = notice.isBookmarked;
            return GestureDetector(
              onTap: () => provider.toggleBookmark(notice.id),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: isBookmarked
                      ? categoryColor.withOpacity(isDark ? 0.15 : 0.08)
                      : (isDark
                          ? Colors.white.withOpacity(0.05)
                          : Colors.grey.withOpacity(0.06)),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Icon(
                  isBookmarked
                      ? Icons.bookmark_rounded
                      : Icons.bookmark_border_rounded,
                  size: 20,
                  color: isBookmarked
                      ? categoryColor
                      : (isDark ? Colors.white30 : AppTheme.textHint),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  /// AI 요약 영역
  Widget _buildAiSummary(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withOpacity(0.04)
            : const Color(0xFFF6F8FB),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.auto_awesome_rounded,
                size: 14,
                color: isDark ? AppTheme.primaryLight : AppTheme.primaryColor,
              ),
              const SizedBox(width: 5),
              Text(
                'AI 요약',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color:
                      isDark ? AppTheme.primaryLight : AppTheme.primaryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Expanded(
            child: Text(
              notice.aiSummary!,
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.white70 : AppTheme.textSecondary,
                height: 1.6,
              ),
              overflow: TextOverflow.fade,
            ),
          ),
        ],
      ),
    );
  }

  /// D-day 뱃지
  Widget _buildDDayBadge(bool isDark) {
    final days = notice.daysUntilDeadline!;
    final isUrgent = days <= 3;
    final color = isUrgent ? AppTheme.errorColor : AppTheme.infoColor;
    final text = days == 0 ? 'D-Day' : 'D-$days';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(isDark ? 0.12 : 0.07),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.alarm_rounded, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  /// 메타 정보 (조회수 + 날짜)
  Widget _buildMeta(bool isDark) {
    final metaColor = isDark ? Colors.white30 : AppTheme.textHint;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.visibility_outlined, size: 13, color: metaColor),
        const SizedBox(width: 4),
        Text(
          '${notice.views}',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: metaColor,
          ),
        ),
        const SizedBox(width: 12),
        Icon(Icons.schedule_rounded, size: 13, color: metaColor),
        const SizedBox(width: 4),
        Text(
          notice.formattedDate,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: metaColor,
          ),
        ),
      ],
    );
  }
}
