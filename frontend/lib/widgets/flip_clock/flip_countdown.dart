import 'dart:async';
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import 'flip_digit.dart';

/// 마감 카운트다운 위젯 - FlipDigitPair를 조합하여 DD일 HH시간 MM분 표시
///
/// [deadline]까지 남은 시간을 1분 간격으로 갱신하며 플립 애니메이션을 재생합니다.
/// 3일 이내 마감 시 errorColor 하이라이트, 당일이면 "D-Day" 특수 표시.
class FlipCountdown extends StatefulWidget {
  final DateTime deadline;
  final double digitWidth;
  final double digitHeight;

  const FlipCountdown({
    super.key,
    required this.deadline,
    this.digitWidth = 36,
    this.digitHeight = 50,
  });

  @override
  State<FlipCountdown> createState() => _FlipCountdownState();
}

class _FlipCountdownState extends State<FlipCountdown> {
  Timer? _timer;
  late int _days;
  late int _hours;
  late int _minutes;

  @override
  void initState() {
    super.initState();
    _calculateRemaining();
    // 1분마다 갱신
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) {
        setState(() => _calculateRemaining());
      }
    });
  }

  @override
  void didUpdateWidget(covariant FlipCountdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.deadline != widget.deadline) {
      _calculateRemaining();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  /// 남은 시간 계산
  void _calculateRemaining() {
    final now = DateTime.now();
    final diff = widget.deadline.difference(now);

    if (diff.isNegative) {
      _days = 0;
      _hours = 0;
      _minutes = 0;
    } else {
      _days = diff.inDays;
      _hours = diff.inHours % 24;
      _minutes = diff.inMinutes % 60;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isUrgent = _days <= 3;
    final isExpired = _days == 0 && _hours == 0 && _minutes == 0;
    final accent = isUrgent ? AppTheme.errorColor : AppTheme.infoColor;

    // D-Day 또는 마감 시 특수 표시
    if (isExpired || (widget.deadline.isBefore(DateTime.now()))) {
      return _buildDDayBadge(isDark);
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // 일
        FlipDigitPair(
          value: _days.clamp(0, 99),
          digitWidth: widget.digitWidth,
          digitHeight: widget.digitHeight,
          accentColor: accent,
          label: 'DAYS',
        ),
        _buildSeparator(isDark, accent),
        // 시간
        FlipDigitPair(
          value: _hours,
          digitWidth: widget.digitWidth,
          digitHeight: widget.digitHeight,
          accentColor: accent,
          label: 'HRS',
        ),
        _buildSeparator(isDark, accent),
        // 분
        FlipDigitPair(
          value: _minutes,
          digitWidth: widget.digitWidth,
          digitHeight: widget.digitHeight,
          accentColor: accent,
          label: 'MIN',
        ),
      ],
    );
  }

  /// 콜론 세퍼레이터 (작은 원 2개)
  Widget _buildSeparator(bool isDark, Color accent) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 0, 6, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _dot(accent),
          const SizedBox(height: 8),
          _dot(accent),
        ],
      ),
    );
  }

  Widget _dot(Color color) {
    return Container(
      width: 5,
      height: 5,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }

  /// D-Day 특수 뱃지
  Widget _buildDDayBadge(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.errorColor.withOpacity(isDark ? 0.2 : 0.15),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: AppTheme.errorColor.withOpacity(0.5),
          width: 1.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.alarm_on_rounded, color: AppTheme.errorColor, size: 24),
          const SizedBox(width: 8),
          Text(
            'D-Day',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: AppTheme.errorColor,
              letterSpacing: 2,
            ),
          ),
        ],
      ),
    );
  }
}
