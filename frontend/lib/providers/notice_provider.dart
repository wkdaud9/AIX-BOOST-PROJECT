import 'package:flutter/foundation.dart';
import '../models/notice.dart';
import '../services/api_service.dart';

/// 공지사항 상태 관리 Provider
class NoticeProvider with ChangeNotifier {
  final ApiService _apiService;

  NoticeProvider({ApiService? apiService})
      : _apiService = apiService ?? ApiService();

  List<Notice> _notices = [];
  List<Notice> _bookmarkedNotices = [];
  bool _isLoading = false;
  String? _error;

  // Getter
  List<Notice> get notices => _notices;
  List<Notice> get bookmarkedNotices => _bookmarkedNotices;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// 맞춤 공지사항 가져오기 (사용자 관심사 기반)
  List<Notice> get customizedNotices {
    // TODO: 실제로는 백엔드 API에서 사용자 맞춤 공지사항을 가져옴
    // 백엔드에서 이미 published_at 기준으로 정렬되어 오므로, 순서 유지
    final newNotices = _notices.where((notice) => notice.isNew).toList();
    // published_at 기준 내림차순 정렬 (최신순)
    newNotices.sort((a, b) => b.date.compareTo(a.date));
    return newNotices;
  }

  /// 인기 공지사항 가져오기 (조회수 기준)
  List<Notice> get popularNotices {
    final sorted = List<Notice>.from(_notices);
    sorted.sort((a, b) => b.views.compareTo(a.views));
    return sorted.take(5).toList();
  }

  /// 카테고리별 공지사항 가져오기
  List<Notice> getNoticesByCategory(String category) {
    return _notices.where((notice) => notice.category == category).toList();
  }

  /// 공지사항 검색
  List<Notice> searchNotices(String query) {
    final lowerQuery = query.toLowerCase();
    return _notices.where((notice) {
      return notice.title.toLowerCase().contains(lowerQuery) ||
          notice.content.toLowerCase().contains(lowerQuery) ||
          notice.tags.any((tag) => tag.toLowerCase().contains(lowerQuery));
    }).toList();
  }

  /// 백엔드에서 공지사항 목록 가져오기
  Future<void> fetchNotices() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // 실제 백엔드 API 호출
      final noticesData = await _apiService.getNotices(limit: 100);

      // Notice 객체로 변환
      _notices = noticesData.map((json) => Notice.fromJson(json)).toList();

      // 북마크된 공지사항 필터링
      _bookmarkedNotices = _notices.where((n) => n.isBookmarked).toList();

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = '공지사항을 불러오는데 실패했습니다: $e';
      _isLoading = false;
      notifyListeners();

      // 에러 발생 시 더미 데이터 사용 (개발용)
      if (kDebugMode) {
        print('API 에러 발생, 더미 데이터 사용: $e');
        _notices = _getDummyNotices();
        _bookmarkedNotices = _notices.where((n) => n.isBookmarked).toList();
        _error = null; // 더미 데이터 사용 시 에러 초기화
        notifyListeners();
      }
    }
  }

  /// 공지사항 북마크 토글
  Future<void> toggleBookmark(String noticeId) async {
    try {
      // TODO: 백엔드 API 호출
      // await http.post(Uri.parse('$baseUrl/api/notices/$noticeId/bookmark'));

      final index = _notices.indexWhere((n) => n.id == noticeId);
      if (index != -1) {
        _notices[index] = _notices[index].copyWith(
          isBookmarked: !_notices[index].isBookmarked,
        );

        // 북마크 목록 업데이트
        _bookmarkedNotices = _notices.where((n) => n.isBookmarked).toList();
        notifyListeners();
      }
    } catch (e) {
      _error = '북마크 처리에 실패했습니다: $e';
      notifyListeners();
    }
  }

  /// 공지사항 상세 조회 (조회수 증가)
  Future<Notice?> getNoticeDetail(String noticeId) async {
    try {
      // 백엔드 API 호출
      final noticeData = await _apiService.getNoticeById(noticeId);
      final notice = Notice.fromJson(noticeData);

      // 로컬 상태 업데이트
      final index = _notices.indexWhere((n) => n.id == noticeId);
      if (index != -1) {
        _notices[index] = notice;
        notifyListeners();
      }

      return notice;
    } catch (e) {
      _error = '공지사항을 불러오는데 실패했습니다: $e';
      notifyListeners();

      // 에러 발생 시 로컬 데이터 반환 (개발용)
      if (kDebugMode) {
        print('API 에러 발생, 로컬 데이터 사용: $e');
        try {
          final notice = _notices.firstWhere((n) => n.id == noticeId);
          final index = _notices.indexWhere((n) => n.id == noticeId);
          _notices[index] = notice.copyWith(views: notice.views + 1);
          notifyListeners();
          return _notices[index];
        } catch (_) {
          return null;
        }
      }

      return null;
    }
  }

  /// 더미 데이터 생성 (개발용)
  List<Notice> _getDummyNotices() {
    return [
      Notice(
        id: '1',
        title: '2024학년도 1학기 수강신청 안내',
        content: '''
2024학년도 1학기 수강신청 일정을 다음과 같이 안내합니다.

■ 수강신청 일정
- 4학년: 2024.02.05(월) 10:00 ~ 02.06(화) 18:00
- 3학년: 2024.02.06(화) 10:00 ~ 02.07(수) 18:00
- 2학년: 2024.02.07(수) 10:00 ~ 02.08(목) 18:00
- 1학년: 2024.02.08(목) 10:00 ~ 02.09(금) 18:00

■ 수강정정 기간
- 전 학년: 2024.03.04(월) ~ 03.08(금)

자세한 사항은 학사공지를 참고하시기 바랍니다.
        ''',
        category: '학사공지',
        date: DateTime.now().subtract(const Duration(days: 1)),
        isNew: true,
        views: 234,
        tags: ['수강신청', '학사일정'],
        deadline: DateTime.now().add(const Duration(days: 2)),
      ),
      Notice(
        id: '2',
        title: '2024년 1학기 국가장학금 신청 안내',
        content: '''
2024년 1학기 국가장학금 신청 안내

■ 신청기간
- 1차: 2023.11.22(수) ~ 2023.12.27(수) 18:00
- 2차: 2024.01.03(수) ~ 2024.02.01(목) 18:00

■ 신청방법
- 한국장학재단 홈페이지(www.kosaf.go.kr)에서 온라인 신청

■ 문의
- 학생지원팀: 063-469-4114
        ''',
        category: '장학',
        date: DateTime.now().subtract(const Duration(days: 2)),
        isNew: true,
        views: 412,
        tags: ['장학금', '국가장학금'],
        isBookmarked: true,
        deadline: DateTime.now().add(const Duration(days: 5)),
      ),
      Notice(
        id: '3',
        title: '중앙도서관 임시 휴관 안내',
        content: '''
시설 보수 공사로 인한 중앙도서관 임시 휴관 안내

■ 휴관 기간
- 2024.01.22(월) ~ 01.26(금)

■ 휴관 사유
- 냉난방 시설 교체 공사

■ 대체 이용 시설
- 제2도서관 정상 운영
- 전자도서관 24시간 이용 가능
        ''',
        category: '시설',
        date: DateTime.now().subtract(const Duration(days: 3)),
        isNew: false,
        views: 156,
        tags: ['도서관', '휴관'],
      ),
      Notice(
        id: '4',
        title: '2024년 상반기 동아리 모집 공고',
        content: '''
2024년 상반기 신규 동아리원을 모집합니다.

■ 모집 기간
- 2024.02.20(화) ~ 03.05(화)

■ 모집 대상
- 재학생 전체

■ 지원 방법
- 학생활동 통합시스템에서 온라인 신청

총 50개 동아리가 모집 중입니다.
        ''',
        category: '학생활동',
        date: DateTime.now().subtract(const Duration(days: 4)),
        isNew: false,
        views: 523,
        tags: ['동아리', '모집'],
      ),
      Notice(
        id: '5',
        title: '2024 채용박람회 및 취업특강 안내',
        content: '''
2024 군산대학교 채용박람회 개최 안내

■ 일시
- 2024.03.15(금) 10:00 ~ 17:00

■ 장소
- 대학본부 광장

■ 참가 기업
- 약 80개 기업 참가 예정

■ 프로그램
- 1:1 채용 상담
- 이력서 첨삭 상담
- 모의 면접
- 취업특강

많은 참여 바랍니다.
        ''',
        category: '취업',
        date: DateTime.now().subtract(const Duration(days: 5)),
        isNew: false,
        views: 689,
        tags: ['취업', '채용', '박람회'],
        isBookmarked: true,
        deadline: DateTime.now().add(const Duration(days: 10)),
      ),
    ];
  }
}
