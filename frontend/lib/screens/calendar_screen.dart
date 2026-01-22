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

class _CalendarScreenState extends State<CalendarScreen> {
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // 캘린더
          _buildCalendar(),

          const Divider(height: 1),

          // 선택된 날짜의 공지사항 목록
          Expanded(
            child: _buildEventList(),
          ),
        ],
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
