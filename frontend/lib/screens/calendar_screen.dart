import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:provider/provider.dart';
import '../models/notice.dart';
import '../providers/notice_provider.dart';
import '../theme/app_theme.dart';
import 'notice_detail_screen.dart';

/// 캘린더 화면 - 북마크된 공지사항의 마감일 표시 + D-day 마커
class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

enum ViewMode { calendar, list }
enum SortMode { deadline, recent }

class _CalendarScreenState extends State<CalendarScreen> with SingleTickerProviderStateMixin {
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  ViewMode _viewMode = ViewMode.calendar; // 보기 모드 (캘린더/리스트)
  SortMode _sortMode = SortMode.deadline; // 정렬 모드 (마감순/최신저장순)
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_handleTabChange);

    // 북마크 목록 동기화 (캘린더는 북마크된 공지의 마감일만 표시)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<NoticeProvider>().fetchBookmarks();
    });
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    super.dispose();
  }

  void _handleTabChange() {
    if (!_tabController.indexIsChanging) {
      setState(() {
        _sortMode = _tabController.index == 0 ? SortMode.deadline : SortMode.recent;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          '일정',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : AppTheme.textPrimary,
          ),
        ),
        elevation: 0,
        actions: [
          // 보기 모드 전환 버튼 (세련된 디자인)
          Container(
            margin: const EdgeInsets.only(right: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? [AppTheme.primaryLight.withOpacity(0.2), AppTheme.primaryLight.withOpacity(0.1)]
                    : [AppTheme.primaryColor.withOpacity(0.15), AppTheme.primaryColor.withOpacity(0.08)],
              ),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: IconButton(
              icon: Icon(
                _viewMode == ViewMode.calendar ? Icons.view_list_rounded : Icons.calendar_month_rounded,
                color: isDark ? AppTheme.primaryLight : AppTheme.primaryColor,
                size: 22,
              ),
              onPressed: () {
                setState(() {
                  _viewMode = _viewMode == ViewMode.calendar
                      ? ViewMode.list
                      : ViewMode.calendar;
                });
              },
              tooltip: _viewMode == ViewMode.calendar ? '리스트 보기' : '캘린더 보기',
            ),
          ),
        ],
      ),
      body: _viewMode == ViewMode.calendar
          ? _buildCalendarView()
          : _buildListView(),
    );
  }


  /// 캘린더 뷰
  Widget _buildCalendarView() {
    return Column(
      children: [
        _buildCalendar(),
        const Divider(height: 1),
        Expanded(
          child: _buildEventList(),
        ),
      ],
    );
  }

  /// 리스트 뷰
  Widget _buildListView() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Consumer<NoticeProvider>(
      builder: (context, provider, child) {
        // 북마크된 공지사항 전체 (마감일 없는 것도 포함)
        var bookmarkedWithDeadline = List<Notice>.from(provider.bookmarkedNotices);

        // 정렬
        if (_sortMode == SortMode.deadline) {
          // 마감 임박 순: 마감일 있는 것 먼저, 지난 것은 뒤로
          final now = DateTime.now();
          bookmarkedWithDeadline.sort((a, b) {
            // 마감일 없는 것은 맨 뒤로
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
        } else {
          // 최신 저장순 (북마크 날짜가 없으므로 공지사항 날짜 기준)
          bookmarkedWithDeadline.sort((a, b) => b.date.compareTo(a.date));
        }

        return Column(
          children: [
            // 정렬 옵션
            _buildSortOptions(),
            const Divider(height: 1),

            // 리스트
            Expanded(
              child: bookmarkedWithDeadline.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.event_busy,
                            size: 64,
                            color: isDark ? Colors.white38 : AppTheme.textHint,
                          ),
                          const SizedBox(height: AppSpacing.md),
                          Text(
                            '저장된 일정이 없습니다.',
                            style: TextStyle(
                              color: isDark ? Colors.white54 : AppTheme.textSecondary,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            '공지사항을 북마크에 저장하면\n여기에 일정이 표시됩니다.',
                            style: TextStyle(
                              color: isDark ? Colors.white38 : AppTheme.textSecondary,
                              fontSize: 14,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      itemCount: bookmarkedWithDeadline.length,
                      itemBuilder: (context, index) {
                        final notice = bookmarkedWithDeadline[index];
                        return _buildListEventCard(notice);
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  /// 정렬 옵션 (탭 방식)
  Widget _buildSortOptions() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: isDark ? Colors.white12 : Colors.grey.shade300,
            width: 1,
          ),
        ),
      ),
      child: TabBar(
        controller: _tabController,
        labelColor: isDark ? AppTheme.primaryLight : AppTheme.primaryColor,
        unselectedLabelColor: isDark ? Colors.white54 : AppTheme.textSecondary,
        labelStyle: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.bold,
        ),
        unselectedLabelStyle: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
        indicatorColor: isDark ? AppTheme.primaryLight : AppTheme.primaryColor,
        indicatorWeight: 3,
        tabs: const [
          Tab(
            icon: Icon(Icons.alarm, size: 20),
            text: '마감 임박순',
          ),
          Tab(
            icon: Icon(Icons.schedule, size: 20),
            text: '최신 저장순',
          ),
        ],
      ),
    );
  }

  /// 리스트 보기용 이벤트 카드
  Widget _buildListEventCard(Notice notice) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => NoticeDetailScreen(
                noticeId: notice.id,
              ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 카테고리와 D-day
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.getCategoryColor(notice.category, isDark: isDark)
                          .withOpacity(0.1),
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      border: Border.all(
                        color: AppTheme.getCategoryColor(notice.category, isDark: isDark),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      notice.category,
                      style: TextStyle(
                        color: AppTheme.getCategoryColor(notice.category, isDark: isDark),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const Spacer(),
                  if (notice.daysUntilDeadline != null)
                    _buildDDayBadge(notice.daysUntilDeadline!),
                ],
              ),

              const SizedBox(height: AppSpacing.sm),

              // 제목
              Text(
                notice.title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),

              const SizedBox(height: AppSpacing.sm),

              // 내용 미리보기
              Text(
                notice.content,
                style: Theme.of(context).textTheme.bodySmall,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),

              const SizedBox(height: AppSpacing.sm),

              // 마감일
              if (notice.deadline != null)
                Row(
                  children: [
                    Icon(
                      Icons.event,
                      size: 14,
                      color: AppTheme.textSecondary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '마감: ${notice.deadline!.year}.${notice.deadline!.month.toString().padLeft(2, '0')}.${notice.deadline!.day.toString().padLeft(2, '0')}',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// D-day 뱃지 위젯
  Widget _buildDDayBadge(int daysLeft) {
    String text;
    Color bgColor;

    if (daysLeft > 0) {
      text = 'D-$daysLeft';
      bgColor = daysLeft <= 3 ? AppTheme.errorColor : AppTheme.infoColor;
    } else if (daysLeft == 0) {
      text = 'D-Day';
      bgColor = AppTheme.errorColor;
    } else {
      text = '마감';
      bgColor = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  /// 캘린더 위젯
  Widget _buildCalendar() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Consumer<NoticeProvider>(
      builder: (context, provider, child) {
        return Card(
          margin: const EdgeInsets.all(AppSpacing.md),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: TableCalendar(
              firstDay: DateTime.utc(2020, 1, 1),
              lastDay: DateTime.utc(2030, 12, 31),
              focusedDay: _focusedDay,
              calendarFormat: _calendarFormat,
              selectedDayPredicate: (day) {
                return isSameDay(_selectedDay, day);
              },
              onDaySelected: (selectedDay, focusedDay) {
                if (!isSameDay(_selectedDay, selectedDay)) {
                  setState(() {
                    _selectedDay = selectedDay;
                    _focusedDay = focusedDay;
                  });
                }
              },
              onFormatChanged: (format) {
                if (_calendarFormat != format) {
                  setState(() {
                    _calendarFormat = format;
                  });
                }
              },
              onPageChanged: (focusedDay) {
                _focusedDay = focusedDay;
              },
              // 이벤트 로더: 북마크된 공지의 마감일만 매칭
              eventLoader: (day) {
                return _getEventsForDay(day, provider.bookmarkedNotices);
              },
              // D-day 마커 커스텀 빌더
              calendarBuilders: CalendarBuilders(
                markerBuilder: (context, day, events) {
                  if (events.isEmpty) return const SizedBox.shrink();

                  // D-day 계산 (오늘 기준)
                  final now = DateTime.now();
                  final today = DateTime(now.year, now.month, now.day);
                  final targetDay = DateTime(day.year, day.month, day.day);
                  final daysLeft = targetDay.difference(today).inDays;

                  String dDayText;
                  Color bgColor;

                  if (daysLeft > 0) {
                    dDayText = 'D-$daysLeft';
                    bgColor = daysLeft <= 3 ? AppTheme.errorColor : AppTheme.infoColor;
                  } else if (daysLeft == 0) {
                    dDayText = 'D-Day';
                    bgColor = AppTheme.errorColor;
                  } else {
                    dDayText = '마감';
                    bgColor = Colors.grey;
                  }

                  final label = dDayText;

                  return Positioned(
                    bottom: 1,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                      decoration: BoxDecoration(
                        color: bgColor,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        label,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  );
                },
              ),
              // 스타일 설정
              calendarStyle: CalendarStyle(
                todayDecoration: BoxDecoration(
                  color: (isDark ? AppTheme.primaryLight : AppTheme.primaryColor).withOpacity(0.5),
                  shape: BoxShape.circle,
                ),
                selectedDecoration: BoxDecoration(
                  color: isDark ? AppTheme.primaryLight : AppTheme.primaryColor,
                  shape: BoxShape.circle,
                ),
                // 커스텀 마커 빌더를 사용하므로 기본 마커 숨김
                markersMaxCount: 0,
                weekendTextStyle: const TextStyle(
                  color: AppTheme.errorColor,
                ),
                outsideDaysVisible: false,
              ),
              headerStyle: HeaderStyle(
                formatButtonVisible: true,
                titleCentered: true,
                formatButtonShowsNext: false,
                formatButtonDecoration: BoxDecoration(
                  color: (isDark ? AppTheme.primaryLight : AppTheme.primaryColor).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                formatButtonTextStyle: TextStyle(
                  color: isDark ? AppTheme.primaryLight : AppTheme.primaryColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
              daysOfWeekStyle: const DaysOfWeekStyle(
                weekendStyle: TextStyle(
                  color: AppTheme.errorColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// 선택된 날짜의 공지사항 목록 (복수 마감일 라벨 포함)
  Widget _buildEventList() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Consumer<NoticeProvider>(
      builder: (context, provider, child) {
        final deadlineEvents = _getDeadlineEventsForDay(
          _selectedDay ?? _focusedDay,
          provider.bookmarkedNotices,
        );

        if (deadlineEvents.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.event_busy,
                  size: 64,
                  color: isDark ? Colors.white38 : AppTheme.textHint,
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  '해당 날짜에 마감 일정이 없습니다.',
                  style: TextStyle(
                    color: isDark ? Colors.white54 : AppTheme.textSecondary,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(AppSpacing.md),
          itemCount: deadlineEvents.length,
          itemBuilder: (context, index) {
            final entry = deadlineEvents[index];
            return _buildEventCard(entry.key, deadlineLabel: entry.value.label);
          },
        );
      },
    );
  }

  /// 이벤트 카드 (deadlineLabel: 복수 마감일의 라벨 표시)
  Widget _buildEventCard(Notice notice, {String? deadlineLabel}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => NoticeDetailScreen(
                noticeId: notice.id,
              ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 카테고리와 D-day 뱃지
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.getCategoryColor(notice.category, isDark: isDark)
                          .withOpacity(0.1),
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      border: Border.all(
                        color: AppTheme.getCategoryColor(notice.category, isDark: isDark),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      notice.category,
                      style: TextStyle(
                        color: AppTheme.getCategoryColor(notice.category, isDark: isDark),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const Spacer(),
                  // D-day 항상 표시 (마감일이 있으면)
                  if (notice.daysUntilDeadline != null)
                    _buildDDayBadge(notice.daysUntilDeadline!),
                ],
              ),

              const SizedBox(height: AppSpacing.sm),

              // 마감 라벨 (복수 마감일인 경우)
              if (deadlineLabel != null && deadlineLabel != '전체 마감')
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    '[$deadlineLabel 마감]',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? AppTheme.primaryLight
                          : AppTheme.primaryColor,
                    ),
                  ),
                ),

              // 제목
              Text(
                notice.title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),

              const SizedBox(height: AppSpacing.sm),

              // 내용 미리보기
              Text(
                notice.content,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),

              const SizedBox(height: AppSpacing.sm),

              // 마감일 정보
              Row(
                children: [
                  Icon(
                    Icons.event,
                    size: 14,
                    color: AppTheme.textSecondary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    notice.deadline != null
                        ? '마감: ${notice.deadline!.year}.${notice.deadline!.month.toString().padLeft(2, '0')}.${notice.deadline!.day.toString().padLeft(2, '0')}'
                        : notice.formattedDate,
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Icon(
                    Icons.visibility,
                    size: 14,
                    color: AppTheme.textSecondary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${notice.views}',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 특정 날짜의 이벤트 가져오기 (북마크된 공지의 모든 마감일 매칭)
  List<Notice> _getEventsForDay(DateTime day, List<Notice> notices) {
    final targetDate = DateTime(day.year, day.month, day.day);

    return notices.where((notice) {
      // 복수 마감일이 있으면 모든 날짜에 매칭
      if (notice.deadlines.isNotEmpty) {
        return notice.deadlines.any((dl) => isSameDay(
          DateTime(dl.date.year, dl.date.month, dl.date.day),
          targetDate,
        ));
      }

      // 단일 deadline 호환
      if (notice.deadline == null) return false;
      return isSameDay(
        DateTime(
          notice.deadline!.year,
          notice.deadline!.month,
          notice.deadline!.day,
        ),
        targetDate,
      );
    }).toList();
  }

  /// 특정 날짜에 해당하는 마감일 라벨 목록 가져오기
  List<MapEntry<Notice, Deadline>> _getDeadlineEventsForDay(DateTime day, List<Notice> notices) {
    final targetDate = DateTime(day.year, day.month, day.day);
    final results = <MapEntry<Notice, Deadline>>[];

    for (final notice in notices) {
      if (notice.deadlines.isNotEmpty) {
        for (final dl in notice.deadlines) {
          if (isSameDay(DateTime(dl.date.year, dl.date.month, dl.date.day), targetDate)) {
            results.add(MapEntry(notice, dl));
          }
        }
      } else if (notice.deadline != null &&
          isSameDay(DateTime(notice.deadline!.year, notice.deadline!.month, notice.deadline!.day), targetDate)) {
        results.add(MapEntry(notice, Deadline(label: '전체 마감', date: notice.deadline!)));
      }
    }

    return results;
  }
}
