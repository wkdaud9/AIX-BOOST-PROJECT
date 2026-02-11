import 'dart:math' as math;
import 'package:flutter/material.dart';

/// 단일 플립 숫자 위젯 - 기계식 시계의 상하 분할 숫자판
///
/// 값이 변경되면 상반부가 뒤집히며 새 숫자가 노출되는 애니메이션을 재생합니다.
class FlipDigit extends StatefulWidget {
  final int value;
  final double width;
  final double height;
  final Color? accentColor;

  const FlipDigit({
    super.key,
    required this.value,
    this.width = 44,
    this.height = 60,
    this.accentColor,
  });

  @override
  State<FlipDigit> createState() => _FlipDigitState();
}

class _FlipDigitState extends State<FlipDigit>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  int _currentValue = 0;
  int _previousValue = 0;

  @override
  void initState() {
    super.initState();
    _currentValue = widget.value;
    _previousValue = widget.value;
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _animation = Tween<double>(begin: 0.0, end: math.pi / 2)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeIn));
  }

  @override
  void didUpdateWidget(covariant FlipDigit oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _previousValue = _currentValue;
      _currentValue = widget.value;
      _controller.reset();
      _controller.forward().then((_) {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final panelColor = isDark ? const Color(0xFF1E1E2E) : const Color(0xFF2D2D44);
    final panelLightColor = isDark ? const Color(0xFF262640) : const Color(0xFF363652);
    final textColor = Colors.white;
    final dividerColor = isDark ? Colors.black45 : Colors.black38;
    final accent = widget.accentColor;

    final textStyle = TextStyle(
      fontSize: widget.height * 0.55,
      fontWeight: FontWeight.bold,
      color: textColor,
      fontFamily: 'monospace',
      height: 1.0,
    );

    return Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        boxShadow: [
          BoxShadow(
            color: (accent ?? Colors.black).withOpacity(0.3),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Stack(
        children: [
          // 하단 반쪽 (새 숫자 - 고정)
          Positioned.fill(
            child: Column(
              children: [
                // 상단 반쪽 배경 (새 숫자)
                _buildHalf(
                  value: _currentValue,
                  isTop: true,
                  panelColor: panelLightColor,
                  textStyle: textStyle,
                ),
                // 하단 반쪽 배경 (새 숫자)
                _buildHalf(
                  value: _currentValue,
                  isTop: false,
                  panelColor: panelColor,
                  textStyle: textStyle,
                ),
              ],
            ),
          ),

          // 플립 애니메이션 - 상반부 (이전 숫자가 뒤집힘)
          AnimatedBuilder(
            animation: _animation,
            builder: (context, child) {
              final angle = _animation.value;
              if (angle >= math.pi / 2) return const SizedBox.shrink();

              return Align(
                alignment: Alignment.topCenter,
                child: Transform(
                  alignment: Alignment.bottomCenter,
                  transform: Matrix4.identity()
                    ..setEntry(3, 2, 0.006)
                    ..rotateX(-angle),
                  child: _buildHalf(
                    value: _previousValue,
                    isTop: true,
                    panelColor: panelLightColor,
                    textStyle: textStyle,
                  ),
                ),
              );
            },
          ),

          // 중앙 분할선
          Positioned(
            top: widget.height / 2 - 0.5,
            left: 0,
            right: 0,
            child: Container(
              height: 1,
              color: dividerColor,
            ),
          ),

          // 상단 하이라이트 (금속 질감)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 2,
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                gradient: LinearGradient(
                  colors: [
                    Colors.white.withOpacity(0.15),
                    Colors.white.withOpacity(0.05),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 상반부 또는 하반부 패널 빌드
  Widget _buildHalf({
    required int value,
    required bool isTop,
    required Color panelColor,
    required TextStyle textStyle,
  }) {
    return ClipRect(
      child: Align(
        alignment: isTop ? Alignment.topCenter : Alignment.bottomCenter,
        heightFactor: 0.5,
        child: Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: isTop
                  ? [panelColor, panelColor.withOpacity(0.9)]
                  : [panelColor.withOpacity(0.85), panelColor],
            ),
            borderRadius: BorderRadius.circular(6),
          ),
          alignment: Alignment.center,
          child: Text('$value', style: textStyle),
        ),
      ),
    );
  }
}

/// 플립 숫자 2자리 위젯 (예: "03", "12")
class FlipDigitPair extends StatelessWidget {
  final int value;
  final double digitWidth;
  final double digitHeight;
  final Color? accentColor;
  final String? label;

  const FlipDigitPair({
    super.key,
    required this.value,
    this.digitWidth = 36,
    this.digitHeight = 50,
    this.accentColor,
    this.label,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tens = (value ~/ 10).clamp(0, 9);
    final ones = (value % 10).clamp(0, 9);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            FlipDigit(
              value: tens,
              width: digitWidth,
              height: digitHeight,
              accentColor: accentColor,
            ),
            const SizedBox(width: 3),
            FlipDigit(
              value: ones,
              width: digitWidth,
              height: digitHeight,
              accentColor: accentColor,
            ),
          ],
        ),
        if (label != null) ...[
          const SizedBox(height: 4),
          Text(
            label!,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white54 : Colors.white70,
              letterSpacing: 1,
            ),
          ),
        ],
      ],
    );
  }
}
