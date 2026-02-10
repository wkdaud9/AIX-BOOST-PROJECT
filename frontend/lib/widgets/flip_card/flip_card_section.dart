import 'package:flutter/material.dart';
import '../../models/notice.dart';
import '../../theme/app_theme.dart';
import 'modern_flip_card.dart';

/// 카테고리 내 수직 카드 플립 섹션
///
/// 수직 스와이프로 공지사항 카드를 넘기는 위젯.
/// 카드는 정사각형으로 화면 중앙에 배치.
/// [showHeader]가 false이면 헤더 없이 카드 영역만 렌더링.
class FlipCardSection extends StatefulWidget {
  final String title;
  final IconData icon;
  final Color accentColor;
  final List<Notice> notices;
  final bool isLoading;
  final String emptyMessage;
  final bool showHeader;

  const FlipCardSection({
    super.key,
    required this.title,
    required this.icon,
    required this.accentColor,
    required this.notices,
    this.isLoading = false,
    this.emptyMessage = '공지사항이 없습니다',
    this.showHeader = true,
  });

  @override
  State<FlipCardSection> createState() => _FlipCardSectionState();
}

class _FlipCardSectionState extends State<FlipCardSection> {
  late PageController _pageController;
  double _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.82);
    _pageController.addListener(() {
      if (mounted) {
        setState(() {
          _currentPage = _pageController.page ?? 0;
        });
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (widget.isLoading) return _buildLoading(colorScheme);
    if (widget.notices.isEmpty) return _buildEmpty(colorScheme);

    return Column(
      children: [
        // 선택적 헤더
        if (widget.showHeader)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: widget.accentColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(widget.icon,
                      size: 16, color: widget.accentColor),
                ),
                const SizedBox(width: 8),
                Text(
                  widget.title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
        // 카드 영역
        Expanded(
          child: _buildVerticalCards(colorScheme),
        ),
      ],
    );
  }

  /// 수직 PageView - 쇼츠 스타일 세로 카드 중앙 배치
  Widget _buildVerticalCards(ColorScheme colorScheme) {
    final items = widget.notices.take(10).toList();
    final screenWidth = MediaQuery.of(context).size.width;
    final cardWidth = screenWidth - 32; // 좌우 여백 16씩

    return LayoutBuilder(
      builder: (context, constraints) {
        // 사용 가능한 높이의 88%를 카드 높이로 사용 (쇼츠 느낌)
        final cardHeight = constraints.maxHeight * 0.88;

        return Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            // 수직 PageView
            PageView.builder(
              controller: _pageController,
              scrollDirection: Axis.vertical,
              itemCount: items.length,
              physics: const BouncingScrollPhysics(),
              itemBuilder: (context, index) {
                return AnimatedBuilder(
                  animation: _pageController,
                  builder: (context, child) {
                    double value = 0;
                    if (_pageController.position.haveDimensions) {
                      value = index - (_pageController.page ?? 0);
                    }

                    // 3D 틸트 + 스케일 + 투명도
                    final rotateAngle = value * 0.1;
                    final scale =
                        1.0 - (value.abs() * 0.05).clamp(0.0, 0.1);
                    final opacity =
                        1.0 - (value.abs() * 0.4).clamp(0.0, 0.7);
                    final translateY = value.abs() > 0.01
                        ? value.sign * 10.0
                        : 0.0;

                    return Center(
                      child: Opacity(
                        opacity: opacity,
                        child: Transform(
                          alignment: Alignment.center,
                          transform: Matrix4.identity()
                            ..setEntry(3, 2, 0.002)
                            ..rotateX(rotateAngle)
                            ..translate(0.0, translateY),
                          child: Transform.scale(
                            scale: scale,
                            child: SizedBox(
                              width: cardWidth,
                              height: cardHeight,
                              child: ModernFlipCard(
                                notice: items[index],
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
            // 페이지 인디케이터 (우측 하단)
            if (items.length > 1)
              Positioned(
                right: 24,
                bottom: constraints.maxHeight * 0.04,
                child: _buildIndicator(colorScheme, items.length),
              ),
          ],
        );
      },
    );
  }

  /// 페이지 인디케이터 (1/5 형태)
  Widget _buildIndicator(ColorScheme colorScheme, int count) {
    final currentIdx = _currentPage.round();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: colorScheme.surface.withOpacity(0.9),
        borderRadius: BorderRadius.circular(AppRadius.round),
        border: Border.all(
          color: colorScheme.onSurface.withOpacity(0.08),
        ),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.swap_vert_rounded,
              size: 12, color: colorScheme.onSurface.withOpacity(0.3)),
          const SizedBox(width: 4),
          Text(
            '${currentIdx + 1}',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: widget.accentColor,
            ),
          ),
          Text(
            ' / $count',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: colorScheme.onSurface.withOpacity(0.4),
            ),
          ),
        ],
      ),
    );
  }

  /// 로딩 상태
  Widget _buildLoading(ColorScheme colorScheme) {
    return Center(
      child: CircularProgressIndicator(
        strokeWidth: 2,
        color: widget.accentColor,
      ),
    );
  }

  /// 빈 상태
  Widget _buildEmpty(ColorScheme colorScheme) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            widget.icon,
            size: 40,
            color: colorScheme.onSurface.withOpacity(0.1),
          ),
          const SizedBox(height: 12),
          Text(
            widget.emptyMessage,
            style: TextStyle(
              fontSize: 14,
              color: colorScheme.onSurface.withOpacity(0.35),
            ),
          ),
        ],
      ),
    );
  }
}
