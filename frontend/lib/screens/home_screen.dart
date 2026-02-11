import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/notice.dart';
import '../providers/notice_provider.dart';
import '../providers/notification_provider.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../widgets/animated_bookmark_button.dart';
import '../widgets/modals/full_list_modal.dart';
import 'notice_detail_screen.dart';
import 'calendar_screen.dart';
import 'recommend_screen.dart';
import 'profile_screen.dart';
import 'category_notice_screen.dart';
import 'notification_screen.dart';
import 'search_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  String? _selectedCategory; // 선택된 카테고리 필터
  int _currentCardIndex = 0; // 현재 카드 인덱스
  late PageController _cardPageController; // 카드 페이지 컨트롤러
  final ScrollController _homeScrollController = ScrollController(); // 홈 탭 스크롤 컨트롤러

  // 카테고리 목록 (이모지 포함)
  final List<Map<String, dynamic>> _categories = [
    {'name': '학사', 'emoji': '🎓'},
    {'name': '장학', 'emoji': '💰'},
    {'name': '취업', 'emoji': '💼'},
    {'name': '행사', 'emoji': '🎉'},
    {'name': '교육', 'emoji': '📚'},
    {'name': '공모전', 'emoji': '🏆'},
  ];

  @override
  void initState() {
    super.initState();
    _cardPageController = PageController(viewportFraction: 1.0);
    // 홈 화면용 경량 API 병렬 호출 (fetchNotices(100) 제거)
    final provider = context.read<NoticeProvider>();
    Future.microtask(() {
      provider.fetchPopularNotices();        // 카드1: HOT 게시물 (10개)
      provider.fetchBookmarkedNotices();     // 카드2: 저장한 일정
      provider.fetchRecommendedNotices(limit: 10); // 카드3: AI 추천 (10개)
      provider.fetchWeeklyDeadlineNotices(); // 카드4: 이번 주 마감
    });
  }

  @override
  void dispose() {
    _cardPageController.dispose();
    _homeScrollController.dispose();
    super.dispose();
  }

  // 하단 네비게이션 탭 변경
  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });

    // MyBro 탭 선택 시 3개 API 호출 (캐시 유효하면 스킵)
    if (index == 2) {
      final provider = context.read<NoticeProvider>();
      provider.fetchRecommendedNotices();      // 캐시 있으면 스킵
      provider.fetchDepartmentPopularNotices(); // 캐시 있으면 스킵
      provider.fetchUpcomingDeadlineNotices();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: GestureDetector(
          onTap: () {
            if (_selectedIndex != 0) {
              setState(() => _selectedIndex = 0);
            } else {
              _homeScrollController.animateTo(
                0,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut,
              );
            }
          },
          child: Consumer<AuthService>(
            builder: (context, authService, child) {
              final name = authService.userName;
              if (authService.isAuthenticated && name != null && name.isNotEmpty) {
                return Text(
                  '$name님!',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                );
              }
              return const Text(
                'Hey bro',
                style: TextStyle(fontWeight: FontWeight.bold),
              );
            },
          ),
        ),
        actions: [
          // 검색 아이콘
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SearchScreen(),
                ),
              );
            },
          ),
          // 알림 아이콘 (읽지 않은 알림 개수 뱃지)
          Consumer<NotificationProvider>(
            builder: (context, notificationProvider, child) {
              return Stack(
                children: [
                  IconButton(
                    icon: const Icon(Icons.notifications_outlined),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const NotificationScreen(),
                        ),
                      );
                    },
                  ),
                  if (notificationProvider.hasUnread)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: AppTheme.errorColor,
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        child: Text(
                          notificationProvider.unreadCount > 9
                              ? '9+'
                              : '${notificationProvider.unreadCount}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          // 설정 아이콘
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SettingsScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: _buildBody(),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF060E1F) : Colors.white,
          border: Border(
            top: BorderSide(
              color: isDark ? Colors.white10 : Colors.grey.shade200,
              width: 1,
            ),
          ),
        ),
        child: Theme(
          data: Theme.of(context).copyWith(
            hoverColor: Colors.transparent,
            splashColor: Colors.transparent,
          ),
          child: BottomNavigationBar(
            currentIndex: _selectedIndex,
            onTap: _onItemTapped,
            type: BottomNavigationBarType.fixed,
            backgroundColor: isDark ? const Color(0xFF060E1F) : Colors.white,
            selectedItemColor: isDark ? AppTheme.primaryLight : AppTheme.primaryColor,
            unselectedItemColor: isDark ? Colors.white54 : AppTheme.textSecondary,
            elevation: 0,
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.home_outlined),
                activeIcon: Icon(Icons.home),
                label: '홈',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.calendar_month_outlined),
                activeIcon: Icon(Icons.calendar_month),
                label: '일정',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.auto_awesome_outlined),
                activeIcon: Icon(Icons.auto_awesome),
                label: 'MyBro',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.person_outline),
                activeIcon: Icon(Icons.person),
                label: '마이페이지',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    return IndexedStack(
      index: _selectedIndex,
      children: [
        _buildHomeTab(),
        _buildCalendarTab(),
        _buildRecommendTab(),
        _buildProfileTab(),
      ],
    );
  }

  // 홈 탭 UI
  Widget _buildHomeTab() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return RefreshIndicator(
      onRefresh: () async {
        final provider = context.read<NoticeProvider>();
        await Future.wait([
          provider.fetchPopularNotices(),
          provider.fetchBookmarkedNotices(),
          provider.fetchRecommendedNotices(limit: 10),
          provider.fetchWeeklyDeadlineNotices(),
        ]);
      },
      child: SingleChildScrollView(
        controller: _homeScrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 배너 + 카테고리 영역
            Container(
              color: isDark ? const Color(0xFF0F2854) : Colors.white,
              child: Column(
                children: [
                  // 배너 슬라이드
                  _buildBannerSlider(),
                  // 카테고리 필터 (제목 제거, 여백 없이 바로 연결)
                  _buildCategoryFilter(),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // 추천 정보 섹션
            Container(
              color: isDark ? const Color(0xFF0A1D40) : Colors.grey.shade100,
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: _buildSectionTitle('추천 정보'),
                  ),
                  const SizedBox(height: 16),
                  // 슬라이드 카드
                  _buildSlideCards(),
                ],
              ),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  // MyBro 소개 배너 (Edge-to-edge, 토스 스타일)
  Widget _buildBannerSlider() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: () => _showMybroInfoModal(context),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [const Color(0xFF1C4D8D), const Color(0xFF0F2854)]
                : [AppTheme.primaryColor, AppTheme.primaryDark],
          ),
        ),
        child: Row(
          children: [
            // 텍스트 영역
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'MyBro',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'AI가 추천하는 맞춤형 공지사항',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white.withOpacity(0.8),
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '탭해서 자세히 알아보기',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.white.withOpacity(0.55),
                    ),
                  ),
                ],
              ),
            ),
            // 아이콘 영역
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: const Icon(
                Icons.auto_awesome_rounded,
                size: 28,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// mybro 기능 소개 모달
  void _showMybroInfoModal(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.65,
          ),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF060E1F) : Colors.white,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppRadius.xl),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 핸들바
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // 헤더
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppTheme.primaryColor, AppTheme.primaryDark],
                        ),
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                      child: const Icon(
                        Icons.auto_awesome_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'MyBro 기능 안내',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : AppTheme.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'AI 기반 맞춤형 추천 서비스',
                            style: TextStyle(
                              fontSize: 13,
                              color: isDark ? Colors.white54 : AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              // 기능 목록
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                  child: Column(
                    children: [
                      _buildFeatureItem(
                        isDark,
                        icon: Icons.auto_awesome_rounded,
                        color: const Color(0xFFA855F7),
                        title: 'AI 맞춤 추천',
                        description: '관심 카테고리와 열람 패턴을 분석하여\n나에게 딱 맞는 공지사항을 추천합니다.',
                      ),
                      const SizedBox(height: 14),
                      _buildFeatureItem(
                        isDark,
                        icon: Icons.push_pin_rounded,
                        color: const Color(0xFFFF6B6B),
                        title: '오늘 꼭 봐야 할 공지',
                        description: '긴급, 마감 임박, 인기 공지를\n종합 분석하여 오늘의 필수 공지를 알려줍니다.',
                      ),
                      const SizedBox(height: 14),
                      _buildFeatureItem(
                        isDark,
                        icon: Icons.star_rounded,
                        color: const Color(0xFF7C8CF8),
                        title: '학과/학년 인기 공지',
                        description: '같은 학과, 같은 학년 학생들이\n가장 많이 본 공지를 보여줍니다.',
                      ),
                      const SizedBox(height: 14),
                      _buildFeatureItem(
                        isDark,
                        icon: Icons.alarm_rounded,
                        color: const Color(0xFFFB923C),
                        title: '마감 임박 알림',
                        description: '신청 마감이 다가오는 공지를\n마감일 기준으로 정렬하여 보여줍니다.',
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// 모달 기능 항목 위젯 (토스 스타일 - 배경 없이 깔끔하게)
  Widget _buildFeatureItem(
    bool isDark, {
    required IconData icon,
    required Color color,
    required String title,
    required String description,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.white54 : AppTheme.textSecondary,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 카테고리 필터 UI (6개 한 줄 배치, 미니멀 디자인)
  Widget _buildCategoryFilter() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: _categories.map((category) {
          final categoryName = category['name'] as String;
          final isSelected = _selectedCategory == categoryName;
          final categoryColor = AppTheme.getCategoryColor(categoryName, isDark: isDark);

          return Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _selectedCategory = categoryName;
                });
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => CategoryNoticeScreen(
                      categoryName: categoryName,
                      categoryColor: categoryColor,
                    ),
                  ),
                ).then((_) {
                  // 화면 복귀 시 카테고리 선택 상태 초기화
                  setState(() {
                    _selectedCategory = null;
                  });
                });
              },
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 이모지 (배경 없이 깔끔하게)
                    Text(
                      category['emoji'] as String,
                      style: TextStyle(
                        fontSize: 26,
                        color: isSelected
                            ? null
                            : isDark ? Colors.white70 : null,
                      ),
                    ),
                    const SizedBox(height: 6),
                    // 카테고리 이름
                    Text(
                      categoryName,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                        color: isSelected
                            ? categoryColor
                            : isDark ? Colors.white70 : AppTheme.textPrimary,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // 슬라이드 카드 섹션 (트렌디한 디자인)
  Widget _buildSlideCards() {
    return Column(
      children: [
        SizedBox(
          height: 340,
          child: PageView.builder(
            controller: _cardPageController,
            physics: const BouncingScrollPhysics(),
            itemCount: 4,
            padEnds: false,
            onPageChanged: (index) {
              setState(() {
                _currentCardIndex = index;
              });
            },
            itemBuilder: (context, index) {
              switch (index) {
                case 0:
                  return _buildCard(_buildPopularCardContent());
                case 1:
                  return _buildCard(_buildSavedEventsCardContent());
                case 2:
                  return _buildCard(_buildAIRecommendCardContent());
                case 3:
                  return _buildCard(_buildWeeklyInfoCardContent());
                default:
                  return const SizedBox();
              }
            },
          ),
        ),
        // 카드 하단 인디케이터
        const SizedBox(height: 12),
        Builder(
          builder: (context) {
            final isDarkIndicator = Theme.of(context).brightness == Brightness.dark;
            final indicatorColor = isDarkIndicator ? AppTheme.primaryLight : AppTheme.primaryColor;
            return Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(4, (index) {
                final isActive = _currentCardIndex == index;
                return Container(
                  width: 6.0,
                  height: 6.0,
                  margin: const EdgeInsets.symmetric(horizontal: 3.0),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isActive
                        ? indicatorColor
                        : indicatorColor.withOpacity(0.3),
                  ),
                );
              }),
            );
          },
        ),
      ],
    );
  }

  /// 카드 래퍼
  Widget _buildCard(Widget cardContent) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F2854) : Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: isDark ? null : AppShadow.soft,
      ),
      child: cardContent,
    );
  }

  // 카드 1: 인기 게시물 (미니멀 디자인)
  Widget _buildPopularCardContent() {
    return Consumer<NoticeProvider>(
      builder: (context, provider, child) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final popularNotices = provider.popularNotices.take(5).toList();

        return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: Row(
                  children: [
                    const Icon(
                      Icons.local_fire_department_rounded,
                      color: Color(0xFFFF6B6B),
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'HOT 게시물',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : AppTheme.textPrimary,
                              letterSpacing: -0.3,
                            ),
                          ),
                          Text(
                            '조회수 TOP 5',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? Colors.white54 : AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // 전체보기 버튼
                    GestureDetector(
                      onTap: () => FullListModal.showPopular(context),
                      child: Text(
                        '전체보기',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white54 : AppTheme.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              // 리스트 레이아웃 (위→아래 정렬)
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: popularNotices.length,
                  itemBuilder: (context, index) {
                    final notice = popularNotices[index];
                    return InkWell(
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => NoticeDetailScreen(noticeId: notice.id),
                          ),
                        );
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 10.0),
                        child: Row(
                          children: [
                            // 순위 표시
                            SizedBox(
                              width: 20,
                              child: Text(
                                '${index + 1}',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: index < 3 ? const Color(0xFFFF6B6B) : (isDark ? Colors.white54 : AppTheme.textSecondary),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                notice.title,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.visibility, size: 12, color: isDark ? Colors.white38 : AppTheme.textSecondary),
                                const SizedBox(width: 2),
                                Text(
                                  '${notice.views}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isDark ? Colors.white38 : AppTheme.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
      },
    );
  }

  // 카드 2: 저장한 일정
  Widget _buildSavedEventsCardContent() {
    return Consumer<NoticeProvider>(
      builder: (context, provider, child) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        // 북마크된 공지 전체 표시 (마감일 있는 것 우선, 임박한 순)
        final bookmarked = List<Notice>.from(provider.bookmarkedNotices);
        final now = DateTime.now();
        bookmarked.sort((a, b) {
          if (a.deadline == null && b.deadline == null) return 0;
          if (a.deadline == null) return 1;
          if (b.deadline == null) return -1;
          final aExpired = a.deadline!.isBefore(now);
          final bExpired = b.deadline!.isBefore(now);
          if (aExpired && !bExpired) return 1;
          if (!aExpired && bExpired) return -1;
          if (aExpired && bExpired) return b.deadline!.compareTo(a.deadline!);
          return a.deadline!.compareTo(b.deadline!);
        });
        final topEvents = bookmarked.take(5).toList();

        return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: Row(
                  children: [
                    const Icon(Icons.bookmark_rounded, color: Color(0xFF7C8CF8), size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '저장한 일정',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : AppTheme.textPrimary,
                              letterSpacing: -0.3,
                            ),
                          ),
                          Text(
                            '마감 임박 순',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? Colors.white54 : AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // 전체보기 버튼
                    GestureDetector(
                      onTap: () => FullListModal.showSavedEvents(context),
                      child: Text(
                        '전체보기',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white54 : AppTheme.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              // 리스트 레이아웃 (아이템 수 무관하게 위→아래 정렬)
              Expanded(
                child: topEvents.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.event_busy, size: 48, color: isDark ? Colors.white38 : AppTheme.textHint),
                            const SizedBox(height: 8),
                            Text(
                              '저장된 일정이 없습니다',
                              style: TextStyle(color: isDark ? Colors.white54 : AppTheme.textSecondary),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: topEvents.length,
                        itemBuilder: (context, index) {
                          final notice = topEvents[index];
                          return InkWell(
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) => NoticeDetailScreen(noticeId: notice.id),
                                ),
                              );
                            },
                            borderRadius: BorderRadius.circular(8),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      notice.title,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                        color: isDark ? Colors.white : AppTheme.textPrimary,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (notice.daysUntilDeadline != null) ...[
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: notice.daysUntilDeadline! <= 3
                                            ? AppTheme.errorColor.withOpacity(isDark ? 0.2 : 0.12)
                                            : AppTheme.infoColor.withOpacity(isDark ? 0.2 : 0.12),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        'D-${notice.daysUntilDeadline}',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: notice.daysUntilDeadline! <= 3
                                              ? AppTheme.errorColor
                                              : AppTheme.infoColor,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
      },
    );
  }

  // 카드 3: AI 추천
  Widget _buildAIRecommendCardContent() {
    return Consumer<NoticeProvider>(
      builder: (context, provider, child) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        // AI 추천: 백엔드 하이브리드 검색 기반 맞춤 추천
        final aiRecommended = provider.recommendedNotices.take(5).toList();

        return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: Row(
                  children: [
                    const Icon(Icons.auto_awesome, color: Color(0xFFA855F7), size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'AI 추천',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : AppTheme.textPrimary,
                              letterSpacing: -0.3,
                            ),
                          ),
                          Text(
                            '맞춤 공지사항',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? Colors.white54 : AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // 전체보기 버튼
                    GestureDetector(
                      onTap: () => FullListModal.showAIRecommend(
                        context,
                        onMoreTap: () => _onItemTapped(2),
                      ),
                      child: Text(
                        '전체보기',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white54 : AppTheme.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              // 리스트 레이아웃 (위→아래 정렬)
              Expanded(
                child: provider.isRecommendedLoading && aiRecommended.isEmpty
                    ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                    : aiRecommended.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.auto_awesome, size: 40, color: isDark ? Colors.white38 : AppTheme.textHint),
                                const SizedBox(height: 8),
                                Text(
                                  '추천 공지사항이 없습니다',
                                  style: TextStyle(fontSize: 13, color: isDark ? Colors.white54 : AppTheme.textSecondary),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(12),
                            itemCount: aiRecommended.length,
                            itemBuilder: (context, index) {
                              final notice = aiRecommended[index];
                              return InkWell(
                                onTap: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (context) => NoticeDetailScreen(noticeId: notice.id),
                                    ),
                                  );
                                },
                                borderRadius: BorderRadius.circular(8),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 10.0),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          notice.title,
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w500,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      if (notice.category.isNotEmpty) ...[
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: AppTheme.getCategoryColor(notice.category, isDark: isDark).withOpacity(isDark ? 0.2 : 0.12),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            notice.category,
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: AppTheme.getCategoryColor(notice.category, isDark: isDark),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
              ),
            ],
          );
      },
    );
  }

  // 카드 4: 이번 주 주요 정보
  Widget _buildWeeklyInfoCardContent() {
    return Consumer<NoticeProvider>(
      builder: (context, provider, child) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        // 이번 주 마감 공지 (경량 API로 서버에서 필터링 완료)
        final weeklyNotices = provider.weeklyDeadlineNotices.take(5).toList();

        return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: Row(
                  children: [
                    const Icon(Icons.date_range_rounded, color: Color(0xFF38BDF8), size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '이번 주 일정',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : AppTheme.textPrimary,
                              letterSpacing: -0.3,
                            ),
                          ),
                          Text(
                            '마감 예정 공지사항',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? Colors.white54 : AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: () => FullListModal.showWeeklySchedule(context),
                      child: Text(
                        '전체보기',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white54 : AppTheme.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: weeklyNotices.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.event_available, size: 48, color: isDark ? Colors.white38 : AppTheme.textHint),
                            const SizedBox(height: 8),
                            Text(
                              '이번 주 일정이 없습니다',
                              style: TextStyle(color: isDark ? Colors.white54 : AppTheme.textSecondary),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: weeklyNotices.length,
                        itemBuilder: (context, index) {
                          final notice = weeklyNotices[index];
                          final dDay = notice.daysUntilDeadline;
                          return InkWell(
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) => NoticeDetailScreen(noticeId: notice.id),
                                ),
                              );
                            },
                            borderRadius: BorderRadius.circular(8),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      notice.title,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                        color: isDark ? Colors.white : AppTheme.textPrimary,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (dDay != null) ...[
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: dDay <= 3
                                            ? AppTheme.errorColor.withOpacity(isDark ? 0.2 : 0.12)
                                            : const Color(0xFF38BDF8).withOpacity(isDark ? 0.2 : 0.12),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        'D-$dDay',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: dDay <= 3
                                              ? AppTheme.errorColor
                                              : const Color(0xFF38BDF8),
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
      },
    );
  }

  /// 카테고리 모달 표시
  void _showCategoryBottomSheet(BuildContext context, String categoryName, Color categoryColor) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // 카테고리에 맞는 아이콘 찾기
    final categoryData = _categories.firstWhere((c) => c['name'] == categoryName);
    final categoryIcon = categoryData['icon'] as IconData;

    // 카테고리별 공지사항을 백엔드 API로 조회
    context.read<NoticeProvider>().fetchNoticesByCategory(categoryName);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) => Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF060E1F) : AppTheme.backgroundColor,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppRadius.xl),
            ),
          ),
          child: Column(
            children: [
              // 핸들바
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // 헤더
              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: categoryColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                      child: Icon(
                        categoryIcon,
                        color: categoryColor,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            categoryName,
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white : AppTheme.textPrimary,
                                ),
                          ),
                          Text(
                            '카테고리별 공지사항',
                            style: TextStyle(
                              fontSize: 14,
                              color: isDark ? Colors.white54 : AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              // 공지사항 리스트
              Expanded(
                child: Consumer<NoticeProvider>(
                  builder: (context, provider, child) {
                    final categoryNotices = provider.categoryNotices;

                    if (provider.isLoading) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (categoryNotices.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.inbox_outlined,
                              size: 64,
                              color: isDark ? Colors.white38 : AppTheme.textHint,
                            ),
                            const SizedBox(height: AppSpacing.md),
                            Text(
                              '해당 카테고리의 공지사항이 없습니다',
                              style: TextStyle(
                                fontSize: 16,
                                color: isDark ? Colors.white54 : AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.all(AppSpacing.md),
                      itemCount: categoryNotices.length,
                      itemBuilder: (context, index) {
                        final notice = categoryNotices[index];
                        return _buildCategoryNoticeCard(context, notice, categoryColor);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 카테고리 모달용 공지사항 카드
  Widget _buildCategoryNoticeCard(BuildContext context, notice, Color categoryColor) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => NoticeDetailScreen(noticeId: notice.id),
            ),
          );
        },
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Stack(
            children: [
              // 북마크 오버레이 (오른쪽 상단, 애니메이션)
              Positioned(
                top: 0,
                right: 0,
                child: Consumer<NoticeProvider>(
                  builder: (context, provider, child) {
                    return AnimatedBookmarkButton(
                      isBookmarked: notice.isBookmarked,
                      onTap: () => provider.toggleBookmark(notice.id),
                      activeColor: categoryColor,
                      inactiveColor: isDark ? Colors.white38 : AppTheme.textSecondary,
                      size: 22,
                    );
                  },
                ),
              ),
              // 콘텐츠 영역
              Padding(
                padding: const EdgeInsets.only(right: 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 뱃지 행
                    Row(
                      children: [
                        if (notice.priority != null) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: _getPriorityColor(notice.priority!),
                              borderRadius: BorderRadius.circular(AppRadius.xs),
                            ),
                            child: Text(
                              notice.priority!,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                        ],
                        if (notice.isNew) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.errorColor,
                              borderRadius: BorderRadius.circular(AppRadius.xs),
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
                        if (notice.deadline != null && notice.daysUntilDeadline != null) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: (notice.daysUntilDeadline! <= 3 ? AppTheme.errorColor : AppTheme.infoColor)
                                  .withOpacity(isDark ? 0.2 : 0.1),
                              borderRadius: BorderRadius.circular(AppRadius.xs),
                              border: Border.all(
                                color: (notice.daysUntilDeadline! <= 3 ? AppTheme.errorColor : AppTheme.infoColor)
                                    .withOpacity(0.4),
                              ),
                            ),
                            child: Text(
                              'D-${notice.daysUntilDeadline}',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: notice.daysUntilDeadline! <= 3 ? AppTheme.errorColor : AppTheme.infoColor,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),

                    const SizedBox(height: AppSpacing.sm),

                    // 제목 (고정 높이 영역 - 2줄 기준)
                    SizedBox(
                      height: 42,
                      child: Text(
                        notice.title,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),

                    // AI 요약
                    if (notice.aiSummary != null) ...[
                      const SizedBox(height: AppSpacing.sm),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withOpacity(isDark ? 0.15 : 0.08),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: (isDark ? AppTheme.primaryLight : AppTheme.primaryColor).withOpacity(0.3)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.auto_awesome, size: 14, color: isDark ? AppTheme.primaryLight : AppTheme.primaryColor),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                notice.aiSummary!,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark ? Colors.white70 : AppTheme.primaryDark,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: AppSpacing.sm),

                    // 메타 정보 (고정 위치)
                    Row(
                      children: [
                        Icon(
                          Icons.visibility_outlined,
                          size: 14,
                          color: isDark ? Colors.white38 : AppTheme.textSecondary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${notice.views}',
                          style: TextStyle(
                            color: isDark ? Colors.white38 : AppTheme.textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          notice.formattedDate,
                          style: TextStyle(
                            color: isDark ? Colors.white24 : AppTheme.textHint,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 섹션 제목
  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
    );
  }

  // 공지사항 리스트 (가로 스크롤)
  Widget _buildNoticeList() {
    return Consumer<NoticeProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(AppSpacing.xl),
              child: CircularProgressIndicator(),
            ),
          );
        }

        final notices = provider.customizedNotices;

        if (notices.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(AppSpacing.xl),
              child: Text('맞춤 공지사항이 없습니다.'),
            ),
          );
        }

        return SizedBox(
          height: 200,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: notices.length,
            itemBuilder: (context, index) {
              final notice = notices[index];
              return _buildHorizontalNoticeCard({
                'id': notice.id,
                'title': notice.title,
                'category': notice.category,
                'date': notice.formattedDate,
                'isNew': notice.isNew,
                'views': notice.views,
                'author': notice.author,
                'aiSummary': notice.aiSummary,
                'priority': notice.priority,
                'deadline': notice.deadline?.toIso8601String(),
                'isBookmarked': notice.isBookmarked,
              });
            },
          ),
        );
      },
    );
  }

  // 인기 공지사항 리스트
  Widget _buildPopularNoticeList() {
    return Consumer<NoticeProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(AppSpacing.xl),
              child: CircularProgressIndicator(),
            ),
          );
        }

        final notices = provider.popularNotices;

        if (notices.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(AppSpacing.xl),
              child: Text('인기 공지사항이 없습니다.'),
            ),
          );
        }

        return Column(
          children: notices.map((notice) {
            return _buildNoticeCard({
              'id': notice.id,
              'title': notice.title,
              'category': notice.category,
              'date': notice.formattedDate,
              'isNew': notice.isNew,
              'views': notice.views,
              'author': notice.author,
              'aiSummary': notice.aiSummary,
              'priority': notice.priority,
              'deadline': notice.deadline?.toIso8601String(),
              'isBookmarked': notice.isBookmarked,
            });
          }).toList(),
        );
      },
    );
  }

  // 가로 스크롤용 공지사항 카드
  Widget _buildHorizontalNoticeCard(Map<String, dynamic> notice) {
    return Container(
      width: 300,
      margin: const EdgeInsets.only(right: 12),
      child: Card(
        child: InkWell(
          onTap: () {
            // 공지사항 상세 화면으로 이동
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => NoticeDetailScreen(
                  noticeId: notice['id'] as String,
                ),
              ),
            );
          },
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // 카테고리, 중요도, NEW 뱃지, 북마크
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.secondaryContainer,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        notice['category'] as String,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSecondaryContainer,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    if (notice['priority'] != null) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: _getPriorityColor(notice['priority'] as String),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          notice['priority'] as String,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                    if (notice['isNew'] == true) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.errorColor,
                          borderRadius: BorderRadius.circular(4),
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
                    const Spacer(),
                    // 북마크 아이콘
                    IconButton(
                      icon: Icon(
                        notice['isBookmarked'] == true
                            ? Icons.bookmark
                            : Icons.bookmark_border,
                        size: 20,
                      ),
                      color: notice['isBookmarked'] == true
                          ? (Theme.of(context).brightness == Brightness.dark ? AppTheme.primaryLight : AppTheme.primaryColor)
                          : AppTheme.textSecondary,
                      onPressed: () {
                        context.read<NoticeProvider>().toggleBookmark(notice['id'] as String);
                      },
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      tooltip: notice['isBookmarked'] == true ? '북마크 해제' : '북마크 추가',
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // 제목
                Text(
                  notice['title'] as String,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                // AI 요약 (있는 경우)
                if (notice['aiSummary'] != null) ...[
                  Builder(builder: (context) {
                    final isDark = Theme.of(context).brightness == Brightness.dark;
                    final aiAccent = isDark ? AppTheme.primaryLight : AppTheme.primaryColor;
                    return Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: aiAccent.withOpacity(isDark ? 0.15 : 0.08),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: aiAccent.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.auto_awesome, size: 14, color: aiAccent),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              notice['aiSummary'] as String,
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark ? Colors.white70 : AppTheme.primaryDark,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                  const SizedBox(height: 8),
                ],
                const Spacer(),
                // 작성자 (있는 경우)
                if (notice['author'] != null) ...[
                  Row(
                    children: [
                      Icon(
                        Icons.person_outline,
                        size: 14,
                        color: AppTheme.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          notice['author'] as String,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: AppTheme.textSecondary,
                              ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                ],
                // 날짜와 조회수
                Row(
                  children: [
                    Icon(
                      Icons.calendar_today,
                      size: 14,
                      color: AppTheme.textSecondary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      notice['date'] as String,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppTheme.textSecondary,
                          ),
                    ),
                    const SizedBox(width: 12),
                    Icon(
                      Icons.visibility_outlined,
                      size: 14,
                      color: AppTheme.textSecondary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${notice['views']}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppTheme.textSecondary,
                          ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 공지사항 카드 (세로 리스트용)
  Widget _buildNoticeCard(Map<String, dynamic> notice) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          // 공지사항 상세 화면으로 이동
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => NoticeDetailScreen(
                noticeId: notice['id'] as String,
              ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 제목, 뱃지, 북마크
              Row(
                children: [
                  Expanded(
                    child: Text(
                      notice['title'] as String,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (notice['priority'] != null) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _getPriorityColor(notice['priority'] as String),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        notice['priority'] as String,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                  if (notice['isNew'] == true) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.errorColor,
                        borderRadius: BorderRadius.circular(4),
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
                  const SizedBox(width: 8),
                  // 북마크 아이콘
                  IconButton(
                    icon: Icon(
                      notice['isBookmarked'] == true
                          ? Icons.bookmark
                          : Icons.bookmark_border,
                      size: 20,
                    ),
                    color: notice['isBookmarked'] == true
                        ? (Theme.of(context).brightness == Brightness.dark ? AppTheme.primaryLight : AppTheme.primaryColor)
                        : AppTheme.textSecondary,
                    onPressed: () {
                      context.read<NoticeProvider>().toggleBookmark(notice['id'] as String);
                    },
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    tooltip: notice['isBookmarked'] == true ? '북마크 해제' : '북마크 추가',
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // AI 요약 (있는 경우)
              if (notice['aiSummary'] != null) ...[
                Builder(builder: (context) {
                  final isDark = Theme.of(context).brightness == Brightness.dark;
                  final aiAccent = isDark ? AppTheme.primaryLight : AppTheme.primaryColor;
                  return Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: aiAccent.withOpacity(isDark ? 0.15 : 0.08),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: aiAccent.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.auto_awesome, size: 14, color: aiAccent),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            notice['aiSummary'] as String,
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? Colors.white70 : AppTheme.primaryDark,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
                const SizedBox(height: 8),
              ],
              // 카테고리와 날짜
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      notice['category'] as String,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSecondaryContainer,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    notice['date'] as String,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                  ),
                  if (notice['views'] != null) ...[
                    const Spacer(),
                    Icon(
                      Icons.visibility_outlined,
                      size: 16,
                      color: AppTheme.textSecondary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${notice['views']}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppTheme.textSecondary,
                          ),
                    ),
                  ],
                ],
              ),
              // 작성자 (있는 경우)
              if (notice['author'] != null) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.person_outline,
                      size: 14,
                      color: AppTheme.textSecondary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      notice['author'] as String,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppTheme.textSecondary,
                          ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // 캘린더 탭
  Widget _buildCalendarTab() {
    return const CalendarScreen();
  }

  // mybro 추천 탭
  Widget _buildRecommendTab() {
    return const RecommendScreen();
  }

  // 프로필 탭
  Widget _buildProfileTab() {
    return const ProfileScreen();
  }

  // 중요도에 따른 색상 반환
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
