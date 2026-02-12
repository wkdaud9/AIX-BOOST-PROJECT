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

  /// 카테고리 정보 (제목, 아이콘)
  static const List<_CategoryInfo> _categories = [
    _CategoryInfo('AI 맞춤 추천', Icons.auto_awesome_rounded),
    _CategoryInfo('오늘 필수', Icons.push_pin_rounded),
    _CategoryInfo('학과 인기', Icons.star_rounded),
    _CategoryInfo('마감 임박', Icons.alarm_rounded),
  ];

  @override
  void initState() {
    super.initState();
    _categoryPageController = PageController();
  }

  /// 탭 전환 시 해당 탭 데이터를 개별 로드 (캐시 유효하면 스킵)
  void _fetchForTab(int index) {
    final provider = context.read<NoticeProvider>();
    switch (index) {
      case 0:
        provider.fetchRecommendedNotices();
        break;
      case 1:
        provider.fetchEssentialNotices();
        break;
      case 2:
        provider.fetchDepartmentPopularNotices();
        break;
      case 3:
        provider.fetchDeadlineSoonNotices();
        break;
    }
  }

  @override
  void dispose() {
    _categoryPageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: Consumer<NoticeProvider>(
        builder: (context, provider, child) {
          // 학과 인기 (API 결과 없으면 로컬 폴백)
          List<Notice> deptPopular = provider.departmentPopularNotices;
          if (deptPopular.isEmpty) {
            final authService = context.watch<AuthService>();
            deptPopular = provider.getDepartmentPopularNotices(
                authService.department, authService.grade);
          }

          // 카테고리별 데이터 매핑 (탭별 독립 API 결과)
          final categoryData = <int, _CategoryData>{
            0: _CategoryData(provider.recommendedNotices, provider.isRecommendedLoading, '추천 공지가 없습니다'),
            1: _CategoryData(provider.essentialNotices, provider.isEssentialLoading, '오늘 필수 공지가 없습니다'),
            2: _CategoryData(deptPopular, provider.isDepartmentPopularLoading, '학과 인기 공지가 없습니다'),
            3: _CategoryData(provider.deadlineSoonNotices, provider.isDeadlineSoonLoading, '마감 임박 공지가 없습니다'),
          };

          return Column(
            children: [
              // 헤더 + 탭
              _buildHeaderWithTabs(colorScheme),

              // 카드 영역 (좌우=카테고리 전환, 상하=공지 넘김)
              Expanded(
                child: PageView.builder(
                  controller: _categoryPageController,
                  itemCount: _categories.length,
                  onPageChanged: (index) {
                    setState(() => _currentCategoryIndex = index);
                    _fetchForTab(index);
                  },
                  itemBuilder: (context, index) {
                    final cat = _categories[index];
                    final data = categoryData[index]!;
                    final isDark = Theme.of(context).brightness == Brightness.dark;
                    final accentColor = AppTheme.getMyBroColor(cat.title, isDark: isDark);
                    return FlipCardSection(
                      title: cat.title,
                      icon: cat.icon,
                      accentColor: accentColor,
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

  /// 헤더 + 언더라인 탭 (통합)
  Widget _buildHeaderWithTabs(ColorScheme colorScheme) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accentColor = isDark ? AppTheme.primaryLight : AppTheme.primaryColor;

    return Container(
      width: double.infinity,
      color: colorScheme.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 타이틀
          Padding(
            padding: EdgeInsets.fromLTRB(
                20, MediaQuery.of(context).padding.top + 16, 20, 0),
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
          const SizedBox(height: 16),

          // 언더라인 탭
          Stack(
            children: [
              // 하단 베이스 라인
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  height: 1,
                  color: colorScheme.onSurface.withOpacity(isDark ? 0.08 : 0.06),
                ),
              ),
              // 탭 아이템
              Row(
                children: List.generate(_categories.length, (index) {
                  final cat = _categories[index];
                  final isSelected = _currentCategoryIndex == index;

                  return Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        _categoryPageController.animateToPage(
                          index,
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      },
                      child: Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  cat.icon,
                                  size: 14,
                                  color: isSelected
                                      ? accentColor
                                      : colorScheme.onSurface.withOpacity(isDark ? 0.3 : 0.25),
                                ),
                                const SizedBox(width: 5),
                                Flexible(
                                  child: Text(
                                    cat.title,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                      color: isSelected
                                          ? (isDark ? Colors.white : colorScheme.onSurface)
                                          : colorScheme.onSurface.withOpacity(isDark ? 0.35 : 0.3),
                                      letterSpacing: -0.2,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // 인디케이터 바
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            curve: Curves.easeOutCubic,
                            height: 2.5,
                            margin: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? accentColor
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 카테고리 정보 (제목, 아이콘)
class _CategoryInfo {
  final String title;
  final IconData icon;

  const _CategoryInfo(this.title, this.icon);
}

/// 카테고리별 데이터 (공지 목록, 로딩 상태, 빈 메시지)
class _CategoryData {
  final List<Notice> notices;
  final bool isLoading;
  final String emptyMessage;

  const _CategoryData(this.notices, this.isLoading, this.emptyMessage);
}
