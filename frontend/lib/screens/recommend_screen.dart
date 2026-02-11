import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/notice.dart';
import '../providers/notice_provider.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../widgets/flip_card/flip_card_section.dart';

/// MyBro 추천 화면 - 좌우 카테고리 전환 + 상하 공지 넘김
///
/// 좌우 스와이프로 4개 카테고리(AI 맞춤 추천, 오늘 필수, 학과 인기, 마감 임박) 전환.
/// 각 카테고리 내에서는 상하 스와이프로 공지사항 카드를 넘김.
/// 쇼츠 스타일 세로 카드가 화면 중앙에 배치됨.
class RecommendScreen extends StatefulWidget {
  const RecommendScreen({super.key});

  @override
  State<RecommendScreen> createState() => _RecommendScreenState();
}

class _RecommendScreenState extends State<RecommendScreen> {
  late PageController _categoryPageController;
  int _currentCategoryIndex = 0;

  /// 카테고리 정보 (제목, 아이콘, 악센트 색상)
  static const List<_CategoryInfo> _categories = [
    _CategoryInfo('AI 맞춤 추천', Icons.auto_awesome_rounded, AppTheme.primaryColor),
    _CategoryInfo('오늘 필수', Icons.push_pin_rounded, AppTheme.errorColor),
    _CategoryInfo('학과 인기', Icons.star_rounded, AppTheme.infoColor),
    _CategoryInfo('마감 임박', Icons.alarm_rounded, AppTheme.warningColor),
  ];

  @override
  void initState() {
    super.initState();
    _categoryPageController = PageController();
    _loadData();
  }

  @override
  void dispose() {
    _categoryPageController.dispose();
    super.dispose();
  }

  /// 데이터 로드
  void _loadData() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<NoticeProvider>();
      provider.fetchRecommendedNotices();
      provider.fetchDepartmentPopularNotices();
    });
  }

  /// 새로고침
  Future<void> _onRefresh() async {
    final provider = context.read<NoticeProvider>();
    await Future.wait([
      provider.fetchNotices(),
      provider.fetchRecommendedNotices(),
      provider.fetchDepartmentPopularNotices(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: Consumer<NoticeProvider>(
        builder: (context, provider, child) {
          // 마감 임박 공지 필터
          final deadlineSoon = provider.notices
              .where((n) => n.deadline != null && n.isDeadlineSoon)
              .toList()
            ..sort((a, b) => a.deadline!.compareTo(b.deadline!));

          // 학과 인기 (API 결과 없으면 로컬 폴백)
          List<Notice> deptPopular = provider.departmentPopularNotices;
          if (deptPopular.isEmpty) {
            final authService = context.watch<AuthService>();
            deptPopular = provider.getDepartmentPopularNotices(
                authService.department, authService.grade);
          }

          // 카테고리별 데이터 매핑
          final categoryData = <int, _CategoryData>{
            0: _CategoryData(provider.recommendedNotices, provider.isRecommendedLoading, '추천 공지가 없습니다'),
            1: _CategoryData(provider.todayMustSeeNotices, false, '오늘 필수 공지가 없습니다'),
            2: _CategoryData(deptPopular, provider.isDepartmentPopularLoading, '학과 인기 공지가 없습니다'),
            3: _CategoryData(deadlineSoon, false, '마감 임박 공지가 없습니다'),
          };

          return Column(
            children: [
              // 헤더
              _buildHeader(colorScheme),

              // 카테고리 탭 인디케이터
              _buildCategoryTabs(colorScheme),

              // 카드 영역 (좌우=카테고리 전환, 상하=공지 넘김)
              Expanded(
                child: PageView.builder(
                  controller: _categoryPageController,
                  itemCount: _categories.length,
                  onPageChanged: (index) {
                    setState(() => _currentCategoryIndex = index);
                  },
                  itemBuilder: (context, index) {
                    final cat = _categories[index];
                    final data = categoryData[index]!;
                    return FlipCardSection(
                      title: cat.title,
                      icon: cat.icon,
                      accentColor: cat.color,
                      notices: data.notices,
                      isLoading: data.isLoading,
                      emptyMessage: data.emptyMessage,
                      showHeader: false,
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// 다크모드에서 보이는 카테고리 색상 반환
  Color _categoryDisplayColor(_CategoryInfo cat, bool isDark) {
    // primaryColor(0xFF0F2854)는 다크모드 배경과 동일하므로 primaryLight 사용
    if (isDark && cat.color == AppTheme.primaryColor) {
      return AppTheme.primaryLight;
    }
    return cat.color;
  }

  /// 카테고리 탭 인디케이터
  Widget _buildCategoryTabs(ColorScheme colorScheme) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      color: colorScheme.surface,
      child: Row(
        children: List.generate(_categories.length, (index) {
          final cat = _categories[index];
          final isSelected = _currentCategoryIndex == index;
          final displayColor = _categoryDisplayColor(cat, isDark);

          return Expanded(
            child: GestureDetector(
              onTap: () {
                _categoryPageController.animateToPage(
                  index,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                );
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: EdgeInsets.only(
                  left: index == 0 ? 0 : 3,
                  right: index == _categories.length - 1 ? 0 : 3,
                ),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? displayColor.withOpacity(isDark ? 0.15 : 0.1)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  border: Border.all(
                    color: isSelected
                        ? displayColor.withOpacity(0.3)
                        : colorScheme.onSurface.withOpacity(isDark ? 0.12 : 0.06),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      cat.icon,
                      size: 16,
                      color: isSelected
                          ? displayColor
                          : colorScheme.onSurface.withOpacity(isDark ? 0.5 : 0.3),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      cat.title,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight:
                            isSelected ? FontWeight.w700 : FontWeight.w500,
                        color: isSelected
                            ? displayColor
                            : colorScheme.onSurface.withOpacity(isDark ? 0.6 : 0.4),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  /// 헤더 (모던 클린 스타일, 다크모드 대비 보장)
  Widget _buildHeader(ColorScheme colorScheme) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accentColor = isDark ? AppTheme.primaryLight : AppTheme.primaryColor;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
          20, MediaQuery.of(context).padding.top + 16, 20, 12),
      decoration: BoxDecoration(
        color: colorScheme.surface,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'MyBro',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: accentColor,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'AI가 추천하는 맞춤형 공지사항',
                  style: TextStyle(
                    fontSize: 13,
                    color: colorScheme.onSurface.withOpacity(0.5),
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
          // 새로고침 버튼
          GestureDetector(
            onTap: _onRefresh,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: accentColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Icon(
                Icons.refresh_rounded,
                color: accentColor,
                size: 22,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 카테고리 정보 (제목, 아이콘, 색상)
class _CategoryInfo {
  final String title;
  final IconData icon;
  final Color color;

  const _CategoryInfo(this.title, this.icon, this.color);
}

/// 카테고리별 데이터 (공지 목록, 로딩 상태, 빈 메시지)
class _CategoryData {
  final List<Notice> notices;
  final bool isLoading;
  final String emptyMessage;

  const _CategoryData(this.notices, this.isLoading, this.emptyMessage);
}
