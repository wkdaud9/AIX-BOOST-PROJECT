import 'package:flutter/foundation.dart';
import '../models/notice.dart';
import '../services/api_service.dart';

/// 공지사항 상태 관리 Provider
class NoticeProvider with ChangeNotifier {
  final ApiService _apiService;

  NoticeProvider({ApiService? apiService})
      : _apiService = apiService ?? ApiService();

  List<Notice> _notices = [];
  List<Notice> _categoryNotices = [];
  List<Notice> _bookmarkedNotices = [];
  List<Notice> _recommendedNotices = [];
  bool _isLoading = false;
  bool _isRecommendedLoading = false;
  String? _error;

  // Getter
  List<Notice> get notices => _notices;
  /// 카테고리별 공지사항 목록 (fetchNoticesByCategory 결과)
  List<Notice> get categoryNotices => _categoryNotices;
  List<Notice> get bookmarkedNotices => _bookmarkedNotices;
  /// AI 맞춤 추천 공지사항 목록 (백엔드 하이브리드 검색 결과)
  List<Notice> get recommendedNotices => _recommendedNotices;
  bool get isLoading => _isLoading;
  bool get isRecommendedLoading => _isRecommendedLoading;
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

  /// AI 맞춤 추천 공지사항 가져오기 (백엔드 하이브리드 검색 API 호출)
  Future<void> fetchRecommendedNotices() async {
    _isRecommendedLoading = true;
    _error = null;
    notifyListeners();

    try {
      final results = await _apiService.getRecommendedNotices(
        limit: 20,
        minScore: 0.3,
      );

      _recommendedNotices = results.map((json) => Notice.fromJson(_convertSearchResult(json))).toList();
      _isRecommendedLoading = false;
      notifyListeners();
    } catch (e) {
      _isRecommendedLoading = false;
      notifyListeners();

      // API 에러 시 로컬 필터링으로 폴백 (개발용)
      if (kDebugMode) {
        print('AI 추천 API 에러, 로컬 필터링 사용: $e');
        _recommendedNotices = _notices
            .where((n) => n.priority != null || n.aiSummary != null)
            .take(10)
            .toList();
        _error = null;
        notifyListeners();
      }
    }
  }

  /// 카테고리별 공지사항 가져오기 (로컬 필터링)
  List<Notice> getNoticesByCategory(String category) {
    return _notices.where((notice) => notice.category == category).toList();
  }

  /// 카테고리별 공지사항 가져오기 (백엔드 API 호출)
  Future<void> fetchNoticesByCategory(String category) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // 백엔드 API 호출 (카테고리 필터 적용)
      final noticesData = await _apiService.getNotices(
        category: category,
        limit: 100,
      );

      // 카테고리별 결과를 별도 상태에 저장 (_notices 전체 목록은 유지)
      _categoryNotices = noticesData.map((json) => Notice.fromJson(json)).toList();

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = '공지사항을 불러오는데 실패했습니다: $e';
      _isLoading = false;
      notifyListeners();

      // 에러 발생 시 로컬 필터링 사용 (개발용)
      if (kDebugMode) {
        print('API 에러 발생, 로컬 필터링 사용: $e');
        _categoryNotices = _notices.where((n) => n.category == category).toList();
        _error = null;
        notifyListeners();
      }
    }
  }

  /// 공지사항 검색 (백엔드 API 호출 - 제목 + 벡터 하이브리드 검색)
  ///
  /// [query] 검색 키워드 (2자 이상)
  /// 반환값: 검색 결과 리스트 (점수순 정렬)
  Future<List<Notice>> searchNotices(String query) async {
    // 2자 미만이면 로컬 필터링으로 폴백
    if (query.length < 2) {
      return _searchNoticesLocal(query);
    }

    try {
      // 백엔드 API 호출
      final results = await _apiService.searchNotices(
        query: query,
        limit: 50,
        minScore: 0.2,
      );

      // Notice 객체로 변환
      return results.map((json) => Notice.fromJson(_convertSearchResult(json))).toList();
    } catch (e) {
      // API 에러 시 로컬 필터링으로 폴백
      if (kDebugMode) {
        print('검색 API 에러, 로컬 검색 사용: $e');
      }
      return _searchNoticesLocal(query);
    }
  }

  /// 검색 결과를 Notice.fromJson 형식으로 변환
  /// 백엔드 응답 필드: total_score, title_score, vector_score (하위 호환: similarity)
  Map<String, dynamic> _convertSearchResult(Map<String, dynamic> searchResult) {
    return {
      'id': searchResult['id'],
      'title': searchResult['title'] ?? '',
      'content': searchResult['content'] ?? '',
      'category': searchResult['category'] ?? '공지사항',
      'published_at': searchResult['published_at'],
      'source_url': searchResult['source_url'],
      'view_count': searchResult['view_count'] ?? 0,
      'ai_summary': searchResult['ai_summary'],
      // 검색 점수 정보 (total_score 우선, similarity 폴백)
      'search_score': searchResult['total_score'] ?? searchResult['similarity'] ?? 0,
      'title_match': searchResult['title_match'] ?? false,
    };
  }

  /// 로컬 검색 (폴백용)
  List<Notice> _searchNoticesLocal(String query) {
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

  /// 공지사항 북마크 토글 (백엔드 API 연동)
  Future<void> toggleBookmark(String noticeId) async {
    // 낙관적 업데이트: 먼저 로컬 상태 변경
    final index = _notices.indexWhere((n) => n.id == noticeId);
    final previousState = index != -1 ? _notices[index].isBookmarked : false;

    if (index != -1) {
      _notices[index] = _notices[index].copyWith(
        isBookmarked: !_notices[index].isBookmarked,
      );
      _bookmarkedNotices = _notices.where((n) => n.isBookmarked).toList();
      notifyListeners();
    }

    try {
      // 백엔드 API 호출
      await _apiService.toggleBookmark(noticeId);
    } catch (e) {
      // API 실패 시 로컬 상태 롤백
      if (index != -1) {
        _notices[index] = _notices[index].copyWith(
          isBookmarked: previousState,
        );
        _bookmarkedNotices = _notices.where((n) => n.isBookmarked).toList();
        notifyListeners();
      }

      if (kDebugMode) {
        print('북마크 API 에러 (로컬 유지): $e');
      }
    }
  }

  /// 백엔드에서 북마크 목록 가져오기
  Future<void> fetchBookmarks() async {
    try {
      final bookmarks = await _apiService.getBookmarks();
      final bookmarkIds = bookmarks.map((b) => b['id'] as String).toSet();

      // 기존 공지사항의 북마크 상태 동기화
      for (var i = 0; i < _notices.length; i++) {
        final shouldBeBookmarked = bookmarkIds.contains(_notices[i].id);
        if (_notices[i].isBookmarked != shouldBeBookmarked) {
          _notices[i] = _notices[i].copyWith(isBookmarked: shouldBeBookmarked);
        }
      }
      _bookmarkedNotices = _notices.where((n) => n.isBookmarked).toList();
      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        print('북마크 목록 조회 에러: $e');
      }
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
        category: '학사',
        date: DateTime.now().subtract(const Duration(days: 1)),
        isNew: true,
        views: 234,
        tags: ['수강신청', '학사일정'],
        deadline: DateTime.now().add(const Duration(days: 2)),
        aiSummary: '2월 5일부터 학년별 수강신청 시작. 4학년부터 순차적으로 진행.',
        priority: '중요',
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
        aiSummary: '1학기 국가장학금 2차 신청 마감 임박. 2월 1일까지 신청 가능.',
        priority: '중요',
        author: '학생지원팀',
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
