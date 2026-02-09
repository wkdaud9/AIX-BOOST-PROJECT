import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:carousel_slider/carousel_slider.dart';
import '../models/notice.dart';
import '../providers/notice_provider.dart';
import '../providers/notification_provider.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../widgets/modals/full_list_modal.dart';
import 'notice_detail_screen.dart';
import 'calendar_screen.dart';
import 'recommend_screen.dart';
import 'profile_screen.dart';
import 'category_notice_screen.dart';
import 'notification_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  String? _selectedCategory; // 선택된 카테고리 필터
  int _currentBannerIndex = 0; // 현재 배너 인덱스
  int _currentCardIndex = 0; // 현재 카드 인덱스
  late PageController _cardPageController; // 카드 페이지 컨트롤러

  // 카테고리 목록 (아이콘 포함)
  final List<Map<String, dynamic>> _categories = [
    {'name': '학사', 'icon': Icons.school, 'color': AppTheme.getCategoryColor('학사')},
    {'name': '장학', 'icon': Icons.attach_money, 'color': AppTheme.getCategoryColor('장학')},
    {'name': '취업', 'icon': Icons.work, 'color': AppTheme.getCategoryColor('취업')},
    {'name': '행사', 'icon': Icons.event, 'color': AppTheme.getCategoryColor('행사')},
    {'name': '교육', 'icon': Icons.menu_book, 'color': AppTheme.getCategoryColor('교육')},
    {'name': '공모전', 'icon': Icons.emoji_events, 'color': AppTheme.getCategoryColor('공모전')},
  ];

  // 배너 더미 데이터 (AppTheme 색상 기반)
  final List<Map<String, dynamic>> _banners = [
    {
      'title': '2024학년도 1학기 수강신청 안내',
      'color': AppTheme.getCategoryColor('학사'),
      'icon': Icons.school,
    },
    {
      'title': '국가장학금 신청 기간 안내',
      'color': AppTheme.getCategoryColor('장학'),
      'icon': Icons.attach_money,
    },
    {
      'title': '취업 박람회 개최 안내',
      'color': AppTheme.getCategoryColor('취업'),
      'icon': Icons.work,
    },
    {
      'title': '도서관 열람실 예약 안내',
      'color': AppTheme.getCategoryColor('행사'),
      'icon': Icons.library_books,
    },
  ];

  @override
  void initState() {
    super.initState();
    _cardPageController = PageController(viewportFraction: 1.0);
    // 공지사항 데이터 로드
    final provider = context.read<NoticeProvider>();
    Future.microtask(() {
      provider.fetchNotices();
      provider.fetchRecommendedNotices(); // AI 추천 데이터 로드
    });
  }

  @override
  void dispose() {
    _cardPageController.dispose();
    super.dispose();
  }

  // 하단 네비게이션 탭 변경
  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });

    // mybro 탭 선택 시 추천 목록 갱신 (카테고리 변경 반영)
    if (index == 2) {
      context.read<NoticeProvider>().fetchRecommendedNotices();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Consumer<AuthService>(
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
        actions: [
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
      bottomNavigationBar: Theme(
        data: Theme.of(context).copyWith(
          hoverColor: Colors.transparent,
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: _onItemTapped,
          type: BottomNavigationBarType.fixed,
          selectedItemColor: Theme.of(context).colorScheme.primary,
          unselectedItemColor: isDark ? Colors.white54 : AppTheme.textSecondary,
          elevation: 8,
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
              label: 'mybro',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              activeIcon: Icon(Icons.person),
              label: '마이페이지',
            ),
          ],
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
          provider.fetchNotices(),
          provider.fetchRecommendedNotices(),
        ]);
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 배너 + 카테고리 영역
            Container(
              color: isDark ? const Color(0xFF25253D) : Colors.white,
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
              color: isDark ? const Color(0xFF1E1E35) : Colors.grey.shade100,
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

  // 배너 슬라이더 (트렌디한 디자인)
  Widget _buildBannerSlider() {
    return Column(
      children: [
        CarouselSlider(
          options: CarouselOptions(
            height: 200.0,
            autoPlay: true,
            autoPlayInterval: const Duration(seconds: 4),
            autoPlayAnimationDuration: const Duration(milliseconds: 800),
            autoPlayCurve: Curves.easeInOutCubic,
            enlargeCenterPage: true,
            enlargeFactor: 0.25,
            viewportFraction: 0.92,
            onPageChanged: (index, reason) {
              setState(() {
                _currentBannerIndex = index;
              });
            },
          ),
          items: _banners.map((banner) {
            return Builder(
              builder: (BuildContext context) {
                return Container(
                  width: MediaQuery.of(context).size.width,
                  margin: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 12.0),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        banner['color'] as Color,
                        (banner['color'] as Color).withOpacity(0.75),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(AppRadius.xl),
                    boxShadow: AppShadow.strong,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.xl),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          // TODO: 배너 클릭 시 동작
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('${banner['title']} 클릭')),
                          );
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(AppRadius.md),
                                ),
                                child: Icon(
                                  banner['icon'] as IconData,
                                  size: 32,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 20),
                              Text(
                                banner['title'] as String,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                  height: 1.4,
                                  letterSpacing: -0.3,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            );
          }).toList(),
        ),
        const SizedBox(height: 12),
        // 인디케이터 (동일 크기, 색상만 변경)
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: _banners.asMap().entries.map((entry) {
            final isActive = _currentBannerIndex == entry.key;
            return Container(
              width: 8.0,
              height: 8.0,
              margin: const EdgeInsets.symmetric(horizontal: 4.0),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isActive
                    ? AppTheme.primaryColor
                    : AppTheme.primaryColor.withOpacity(0.25),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 20),
      ],
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
          final categoryColor = category['color'] as Color;

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
                    // 네모 박스 아이콘
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? categoryColor.withOpacity(0.15)
                            : isDark ? const Color(0xFF2D2D44) : AppTheme.textHint.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        category['icon'] as IconData,
                        size: 24,
                        color: isSelected
                            ? categoryColor
                            : isDark ? Colors.white54 : AppTheme.textSecondary,
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
    return SizedBox(
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
              return _buildCardWithIndicator(_buildPopularCardContent());
            case 1:
              return _buildCardWithIndicator(_buildSavedEventsCardContent());
            case 2:
              return _buildCardWithIndicator(_buildAIRecommendCardContent());
            case 3:
              return _buildCardWithIndicator(_buildWeeklyInfoCardContent());
            default:
              return const SizedBox();
          }
        },
      ),
    );
  }

  /// 카드 + 우하단 인디케이터 래퍼
  Widget _buildCardWithIndicator(Widget cardContent) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF25253D) : Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: isDark ? null : AppShadow.soft,
      ),
      child: Stack(
        children: [
          // 카드 내용
          cardContent,
          // 우하단 인디케이터
          Positioned(
            right: 16,
            bottom: 12,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(4, (index) {
                final isActive = _currentCardIndex == index;
                return Container(
                  width: 6.0,
                  height: 6.0,
                  margin: const EdgeInsets.symmetric(horizontal: 3.0),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isActive
                        ? AppTheme.primaryColor
                        : AppTheme.primaryColor.withOpacity(0.25),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
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
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppTheme.warningColor.withOpacity(0.2),
                            AppTheme.warningColor.withOpacity(0.1),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                      child: Icon(
                        Icons.trending_up,
                        color: AppTheme.warningColor,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '인기 게시물',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : AppTheme.textPrimary,
                              letterSpacing: -0.3,
                            ),
                          ),
                          Text(
                            '조회수 기준 상위 5개',
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
              // 고정 레이아웃 (스크롤 없음)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: popularNotices.asMap().entries.map((entry) {
                      final index = entry.key;
                      final notice = entry.value;
                      return Expanded(
                        child: InkWell(
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => NoticeDetailScreen(noticeId: notice.id),
                              ),
                            );
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 2.0),
                            child: Row(
                              children: [
                                // 순위 표시
                                Container(
                                  width: 20,
                                  child: Text(
                                    '${index + 1}',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: index < 3 ? AppTheme.warningColor : (isDark ? Colors.white54 : AppTheme.textSecondary),
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
                        ),
                      );
                    }).toList(),
                  ),
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
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.infoColor.withOpacity(isDark ? 0.2 : 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.event, color: AppTheme.infoColor),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '저장한 일정',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : AppTheme.textPrimary,
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
              // 고정 레이아웃 (스크롤 없음)
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
                    : Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          children: topEvents.asMap().entries.map((entry) {
                            final notice = entry.value;
                            return Expanded(
                              child: InkWell(
                                onTap: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (context) => NoticeDetailScreen(noticeId: notice.id),
                                    ),
                                  );
                                },
                                borderRadius: BorderRadius.circular(8),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 2.0),
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
                              ),
                            );
                          }).toList(),
                        ),
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
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withOpacity(isDark ? 0.2 : 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.auto_awesome, color: AppTheme.primaryColor),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'AI 추천',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : AppTheme.textPrimary,
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
                      onTap: () => FullListModal.showAIRecommend(context),
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
              // 고정 레이아웃 (스크롤 없음)
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
                        : Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              children: aiRecommended.asMap().entries.map((entry) {
                                final notice = entry.value;
                                return Expanded(
                                  child: InkWell(
                                    onTap: () {
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (context) => NoticeDetailScreen(noticeId: notice.id),
                                        ),
                                      );
                                    },
                                    borderRadius: BorderRadius.circular(8),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 2.0),
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
                                                color: AppTheme.getCategoryColor(notice.category).withOpacity(isDark ? 0.2 : 0.12),
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                notice.category,
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                  color: AppTheme.getCategoryColor(notice.category),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
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
        final now = DateTime.now();
        final weekStart = now.subtract(Duration(days: now.weekday - 1));
        final weekEnd = weekStart.add(const Duration(days: 6));

        // 이번 주에 마감되는 공지사항
        final weeklyNotices = provider.notices
            .where((n) =>
              n.deadline != null &&
              n.deadline!.isAfter(weekStart) &&
              n.deadline!.isBefore(weekEnd)
            )
            .take(5)
            .toList();

        return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.successColor.withOpacity(isDark ? 0.2 : 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.calendar_today, color: AppTheme.successColor),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '이번 주 일정',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : AppTheme.textPrimary,
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
                    : ListView.separated(
                        padding: const EdgeInsets.all(12),
                        itemCount: weeklyNotices.length,
                        separatorBuilder: (context, index) => Divider(
                          height: 1,
                          color: isDark ? Colors.white10 : Colors.grey.shade200,
                        ),
                        itemBuilder: (context, index) {
                          final notice = weeklyNotices[index];
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
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          notice.title,
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: isDark ? Colors.white : AppTheme.textPrimary,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '마감: ${notice.deadline!.month}/${notice.deadline!.day}',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: isDark ? Colors.white54 : AppTheme.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppTheme.getCategoryColor(notice.category).withOpacity(isDark ? 0.2 : 0.12),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      notice.category,
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: AppTheme.getCategoryColor(notice.category),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  // 북마크 아이콘
                                  IconButton(
                                    icon: Icon(
                                      notice.isBookmarked
                                          ? Icons.bookmark
                                          : Icons.bookmark_border,
                                      size: 18,
                                    ),
                                    color: notice.isBookmarked
                                        ? Theme.of(context).colorScheme.primary
                                        : (isDark ? Colors.white54 : AppTheme.textSecondary),
                                    onPressed: () {
                                      context.read<NoticeProvider>().toggleBookmark(notice.id);
                                    },
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    tooltip: notice.isBookmarked ? '북마크 해제' : '북마크 추가',
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

  /// 카테고리 모달 표시
  void _showCategoryBottomSheet(BuildContext context, String categoryName, Color categoryColor) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // 카테고리에 맞는 아이콘 찾기
    final categoryData = _categories.firstWhere((c) => c['name'] == categoryName);
    final categoryIcon = categoryData['icon'] as IconData;

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
            color: isDark ? const Color(0xFF1A1A2E) : AppTheme.backgroundColor,
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
                    final categoryNotices = provider.notices
                        .where((n) => n.category == categoryName)
                        .toList();

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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 제목과 뱃지
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      notice.title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (notice.priority != null) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _getPriorityColor(notice.priority!),
                        borderRadius: BorderRadius.circular(AppRadius.sm),
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
                  ],
                  if (notice.isNew) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.errorColor,
                        borderRadius: BorderRadius.circular(AppRadius.sm),
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
                ],
              ),

              // AI 요약
              if (notice.aiSummary != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(isDark ? 0.15 : 0.08),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3)),
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

              // 메타 정보
              Row(
                children: [
                  Icon(
                    Icons.calendar_today,
                    size: 14,
                    color: isDark ? Colors.white54 : AppTheme.textSecondary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    notice.formattedDate,
                    style: TextStyle(
                      color: isDark ? Colors.white54 : AppTheme.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Icon(
                    Icons.visibility,
                    size: 14,
                    color: isDark ? Colors.white54 : AppTheme.textSecondary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${notice.views}',
                    style: TextStyle(
                      color: isDark ? Colors.white54 : AppTheme.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  if (notice.deadline != null && notice.daysUntilDeadline != null) ...[
                    const Spacer(),
                    Text(
                      'D-${notice.daysUntilDeadline}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: notice.daysUntilDeadline! <= 3 ? AppTheme.errorColor : AppTheme.infoColor,
                      ),
                    ),
                  ],
                  const Spacer(),
                  // 북마크 아이콘
                  Consumer<NoticeProvider>(
                    builder: (context, provider, child) {
                      return IconButton(
                        icon: Icon(
                          notice.isBookmarked
                              ? Icons.bookmark
                              : Icons.bookmark_border,
                          size: 20,
                        ),
                        color: notice.isBookmarked
                            ? categoryColor
                            : (isDark ? Colors.white54 : AppTheme.textSecondary),
                        onPressed: () {
                          provider.toggleBookmark(notice.id);
                        },
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        tooltip: notice.isBookmarked ? '북마크 해제' : '북마크 추가',
                      );
                    },
                  ),
                ],
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
                          ? Theme.of(context).colorScheme.primary
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
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.auto_awesome, size: 14, color: AppTheme.primaryColor),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            notice['aiSummary'] as String,
                            style: TextStyle(
                              fontSize: 11,
                              color: AppTheme.primaryDark,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
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
                        ? Theme.of(context).colorScheme.primary
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
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.auto_awesome, size: 14, color: AppTheme.primaryColor),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          notice['aiSummary'] as String,
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.primaryDark,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
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
