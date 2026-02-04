import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:provider/provider.dart';
import '../models/notice.dart';
import '../providers/notice_provider.dart';
import '../theme/app_theme.dart';
import 'notice_detail_screen.dart';

/// 캘린더 화면 - 공지사항 일정 표시
class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

enum ViewMode { calendar, list }
enum SortMode { deadline, recent }

class _CalendarScreenState extends State<CalendarScreen> {
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  ViewMode _viewMode = ViewMode.calendar; // 보기 모드 (캘린더/리스트)
  SortMode _sortMode = SortMode.deadline; // 정렬 모드 (마감순/최신저장순)

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('일정'),
        actions: [
          // 보기 모드 전환 버튼
          Container(
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: Icon(
                _viewMode == ViewMode.calendar ? Icons.list : Icons.calendar_month,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
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
    return Consumer<NoticeProvider>(
      builder: (context, provider, child) {
        // 북마크된 공지사항 중 마감일이 있는 것만 필터링
        var bookmarkedWithDeadline = provider.bookmarkedNotices
            .where((n) => n.deadline != null)
            .toList();

        // 정렬
        if (_sortMode == SortMode.deadline) {
          // 마감 임박 순 (마감일이 가까운 순)
          bookmarkedWithDeadline.sort((a, b) => a.deadline!.compareTo(b.deadline!));
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
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: AppSpacing.md),
                          Text(
                            '저장된 일정이 없습니다.',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            '공지사항을 북마크에 저장하면\n여기에 일정이 표시됩니다.',
                            style: TextStyle(
                              color: Colors.grey[500],
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

  /// 정렬 옵션
  Widget _buildSortOptions() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          const Text(
            '정렬',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: SegmentedButton<SortMode>(
              segments: const [
                ButtonSegment<SortMode>(
                  value: SortMode.deadline,
                  label: Text('마감 임박 순'),
                  icon: Icon(Icons.alarm, size: 16),
                ),
                ButtonSegment<SortMode>(
                  value: SortMode.recent,
                  label: Text('최신 저장 순'),
                  icon: Icon(Icons.schedule, size: 16),
                ),
              ],
              selected: {_sortMode},
              onSelectionChanged: (Set<SortMode> newSelection) {
                setState(() {
                  _sortMode = newSelection.first;
                });
              },
              style: ButtonStyle(
                visualDensity: VisualDensity.compact,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 리스트 보기용 이벤트 카드
  Widget _buildListEventCard(Notice notice) {
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
                      color: AppTheme.getCategoryColor(notice.category)
                          .withOpacity(0.1),
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      border: Border.all(
                        color: AppTheme.getCategoryColor(notice.category),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      notice.category,
                      style: TextStyle(
                        color: AppTheme.getCategoryColor(notice.category),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const Spacer(),
                  if (notice.daysUntilDeadline != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: notice.isDeadlineSoon
                            ? AppTheme.errorColor
                            : AppTheme.infoColor,
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      child: Text(
                        notice.daysUntilDeadline! > 0
                            ? 'D-${notice.daysUntilDeadline}'
                            : '마감',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
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

  /// 캘린더 위젯
  Widget _buildCalendar() {
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
              // 이벤트 마커 표시
              eventLoader: (day) {
                return _getEventsForDay(day, provider.notices);
              },
              // 스타일 설정
              calendarStyle: CalendarStyle(
                todayDecoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.5),
                  shape: BoxShape.circle,
                ),
                selectedDecoration: const BoxDecoration(
                  color: AppTheme.primaryColor,
                  shape: BoxShape.circle,
                ),
                markerDecoration: const BoxDecoration(
                  color: AppTheme.secondaryColor,
                  shape: BoxShape.circle,
                ),
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
                  color: AppTheme.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                formatButtonTextStyle: const TextStyle(
                  color: AppTheme.primaryColor,
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

  /// 선택된 날짜의 공지사항 목록
  Widget _buildEventList() {
    return Consumer<NoticeProvider>(
      builder: (context, provider, child) {
        final events = _getEventsForDay(_selectedDay ?? _focusedDay, provider.notices);

        if (events.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.event_busy,
                  size: 64,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  '해당 날짜에 일정이 없습니다.',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(AppSpacing.md),
          itemCount: events.length,
          itemBuilder: (context, index) {
            final notice = events[index];
            return _buildEventCard(notice);
          },
        );
      },
    );
  }

  /// 이벤트 카드
  Widget _buildEventCard(Notice notice) {
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
              // 카테고리와 마감일 뱃지
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.getCategoryColor(notice.category)
                          .withOpacity(0.1),
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      border: Border.all(
                        color: AppTheme.getCategoryColor(notice.category),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      notice.category,
                      style: TextStyle(
                        color: AppTheme.getCategoryColor(notice.category),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (notice.deadline != null && notice.isDeadlineSoon) ...[
                    const SizedBox(width: AppSpacing.sm),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.errorColor,
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      child: Text(
                        'D-${notice.daysUntilDeadline}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
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

              // 날짜 정보
              Row(
                children: [
                  Icon(
                    Icons.access_time,
                    size: 16,
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

  /// 특정 날짜의 이벤트 가져오기
  List<Notice> _getEventsForDay(DateTime day, List<Notice> notices) {
    return notices.where((notice) {
      // 공지 날짜 또는 마감일이 해당 날짜와 일치하는 경우
      final noticeDate = DateTime(
        notice.date.year,
        notice.date.month,
        notice.date.day,
      );
      final targetDate = DateTime(day.year, day.month, day.day);

      bool matchesNoticeDate = isSameDay(noticeDate, targetDate);
      bool matchesDeadline = notice.deadline != null &&
          isSameDay(
            DateTime(
              notice.deadline!.year,
              notice.deadline!.month,
              notice.deadline!.day,
            ),
            targetDate,
          );

      return matchesNoticeDate || matchesDeadline;
    }).toList();
  }
}
