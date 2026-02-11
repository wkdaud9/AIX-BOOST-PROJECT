import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 애니메이션 북마크 버튼 - 탭 시 바운스 + 컬러 전환 + 햅틱 피드백
class AnimatedBookmarkButton extends StatefulWidget {
  final bool isBookmarked;
  final VoidCallback onTap;
  final Color activeColor;
  final Color inactiveColor;
  final double size;
  final bool showBackground;
  final double backgroundSize;

  const AnimatedBookmarkButton({
    super.key,
    required this.isBookmarked,
    required this.onTap,
    required this.activeColor,
    this.inactiveColor = Colors.grey,
    this.size = 20,
    this.showBackground = false,
    this.backgroundSize = 36,
  });

  @override
  State<AnimatedBookmarkButton> createState() => _AnimatedBookmarkButtonState();
}

class _AnimatedBookmarkButtonState extends State<AnimatedBookmarkButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 350),
      vsync: this,
    );
    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.35), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 1.35, end: 0.85), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 0.85, end: 1.0), weight: 30),
    ]).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// 탭 핸들러: 바운스 애니메이션 + 햅틱 피드백 실행 후 콜백
  void _handleTap() {
    _controller.forward(from: 0);
    if (!widget.isBookmarked) {
      HapticFeedback.lightImpact();
    }
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: _handleTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: child,
          );
        },
        child: widget.showBackground
            ? Container(
                width: widget.backgroundSize,
                height: widget.backgroundSize,
                decoration: BoxDecoration(
                  color: widget.isBookmarked
                      ? widget.activeColor.withOpacity(isDark ? 0.15 : 0.08)
                      : (isDark
                          ? Colors.white.withOpacity(0.05)
                          : Colors.grey.withOpacity(0.06)),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: _buildIcon(isDark),
              )
            : _buildIcon(isDark),
      ),
    );
  }

  /// 북마크 아이콘 (컬러 전환 애니메이션 포함)
  Widget _buildIcon(bool isDark) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      transitionBuilder: (child, animation) {
        return FadeTransition(opacity: animation, child: child);
      },
      child: Icon(
        widget.isBookmarked
            ? Icons.bookmark_rounded
            : Icons.bookmark_border_rounded,
        key: ValueKey(widget.isBookmarked),
        size: widget.size,
        color: widget.isBookmarked
            ? widget.activeColor
            : (isDark ? Colors.white30 : widget.inactiveColor),
      ),
    );
  }
}
