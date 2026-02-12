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
  List<Notice> _popularNotices = [];
  List<Notice> _departmentPopularNotices = [];
  List<Notice> _essentialNotices = []; // MyBro 탭: 오늘 필수
  List<Notice> _deadlineSoonNotices = []; // MyBro 탭: 마감 임박
  List<Notice> _weeklyDeadlineNotices = []; // 홈 카드4용 이번 주 마감
  bool _isLoading = false;
  bool _isRecommendedLoading = false;
  bool _isDepartmentPopularLoading = false;
  bool _isEssentialLoading = false;
  bool _isDeadlineSoonLoading = false;
  bool _isPopularLoading = false;
  bool _isBookmarkedLoading = false;
  bool _isWeeklyDeadlineLoading = false;

  /// 추천 캐시 유효시간 (5분)
  static const _cacheDuration = Duration(minutes: 5);
  DateTime? _recommendedLastFetched;
  /// AI 추천 실패 시 최신순 폴백 사용 여부 (UI에서 "AI 추천" vs "최신순" 구분용)
  bool _isRecommendedFallback = false;
  DateTime? _departmentPopularLastFetched;
  DateTime? _essentialLastFetched;
  DateTime? _deadlineSoonLastFetched;

  /// 추천 공지 풀 (무한 환형 스크롤용, 한번에 로드)
  static const _fetchSize = 30;
  List<Notice> _recommendedPool = [];

  String? _error;
  /// AI 추천 실패 시 폴백 상태 여부
  bool get isRecommendedFallback => _isRecommendedFallback;
  String? _departmentPopularDept;
  int? _departmentPopularGrade;

  // Getter
  List<Notice> get notices => _notices;
  /// 카테고리별 공지사항 목록 (fetchNoticesByCategory 결과)
  List<Notice> get categoryNotices => _categoryNotices;
  List<Notice> get bookmarkedNotices => _bookmarkedNotices;
  /// AI 맞춤 추천 공지사항 목록 (전체 풀 반환, 무한 환형 스크롤용)
  List<Notice> get recommendedNotices => _recommendedPool;
  /// 학과/학년 인기 공지사항 목록 (백엔드 API 결과)
  List<Notice> get departmentPopularNotices => _departmentPopularNotices;
  /// 홈 카드4용 이번 주 마감 공지사항 (경량 API)
  List<Notice> get weeklyDeadlineNotices => _weeklyDeadlineNotices;
  /// MyBro 탭: 오늘 필수 공지사항 (백엔드 점수 기반)
  List<Notice> get essentialNotices => _essentialNotices;
  /// MyBro 탭: 마감 임박 공지사항 (오늘~D+7, 백엔드 API)
  List<Notice> get deadlineSoonNotices => _deadlineSoonNotices;
  bool get isLoading => _isLoading;
  bool get isRecommendedLoading => _isRecommendedLoading;
  bool get isDepartmentPopularLoading => _isDepartmentPopularLoading;
  bool get isEssentialLoading => _isEssentialLoading;
  bool get isDeadlineSoonLoading => _isDeadlineSoonLoading;
  bool get isPopularLoading => _isPopularLoading;
  bool get isBookmarkedLoading => _isBookmarkedLoading;
  bool get isWeeklyDeadlineLoading => _isWeeklyDeadlineLoading;
  String? get error => _error;
  String? get departmentPopularDept => _departmentPopularDept;
  int? get departmentPopularGrade => _departmentPopularGrade;

  /// 맞춤 공지사항 가져오기 (사용자 관심사 기반)
  List<Notice> get customizedNotices {
    // TODO: 실제로는 백엔드 API에서 사용자 맞춤 공지사항을 가져옴
    // 백엔드에서 이미 published_at 기준으로 정렬되어 오므로, 순서 유지
    final newNotices = _notices.where((notice) => notice.isNew).toList();
    // published_at 기준 내림차순 정렬 (최신순)
    newNotices.sort((a, b) => b.date.compareTo(a.date));
    return newNotices;
  }

  /// 인기 공지사항 (DB 전체 조회수 기준, API로 가져옴)
  List<Notice> get popularNotices => _popularNotices;

  /// 학과/학년 관련 인기 공지 (조회수+북마크 기준 상위 5개)
  /// 학과 카테고리에 매칭되는 공지에 부스트 점수 부여
  List<Notice> getDepartmentPopularNotices(String? department, int? grade) {
    if (_notices.isEmpty) return [];

    final scored = _notices.map((notice) {
      double score = notice.views + (notice.bookmarkCount * 3).toDouble();

      // 학과 관련 공지 부스트 (카테고리, 태그, 제목에 학과명 포함 시)
      if (department != null && department.isNotEmpty) {
        final deptLower = department.toLowerCase();
        if (notice.category.toLowerCase().contains(deptLower) ||
            notice.title.toLowerCase().contains(deptLower) ||
            notice.tags.any((tag) => tag.toLowerCase().contains(deptLower))) {
          score += 50;
        }
      }

      // 학년 관련 공지 부스트
      if (grade != null) {
        final gradeStr = '$grade학년';
        if (notice.title.contains(gradeStr) || notice.content.contains(gradeStr)) {
          score += 30;
        }
      }

      return MapEntry(notice, score);
    }).toList();

    scored.sort((a, b) => b.value.compareTo(a.value));
    return scored.take(30).map((e) => e.key).toList();
  }

  /// 사용자 선호도 변경 시 추천 관련 캐시를 모두 무효화합니다.
  /// 프로필 편집 모달에서 카테고리/학과/학년 변경 후 호출합니다.
  void invalidateRecommendationCache() {
    _recommendedLastFetched = null;
    _departmentPopularLastFetched = null;
    _essentialLastFetched = null;
    _deadlineSoonLastFetched = null;
  }

  /// AI 맞춤 추천 공지사항 로드
  /// [limit] 가져올 개수 (기본 30, 홈에서는 10으로 호출)
  /// 캐시가 유효하면 재호출 스킵
  Future<void> fetchRecommendedNotices({bool force = false, int? limit}) async {
    final fetchLimit = limit ?? _fetchSize;

    // 캐시 유효 시 스킵 (데이터가 있고, TTL 내)
    if (!force &&
        _recommendedPool.isNotEmpty &&
        _recommendedLastFetched != null &&
        DateTime.now().difference(_recommendedLastFetched!) < _cacheDuration) {
      return;
    }

    _isRecommendedLoading = true;
    _error = null;
    notifyListeners();

    // 최대 2회 시도 (첫 시도 + 재시도 1회)
    for (int attempt = 1; attempt <= 2; attempt++) {
      try {
        final results = await _apiService.getRecommendedNotices(
          limit: fetchLimit,
          offset: 0,
          minScore: 0.3,
        );

        _recommendedPool = results.map((json) => Notice.fromJson(_convertSearchResult(json))).toList();
        _syncBookmarkState(_recommendedPool);
        _recommendedLastFetched = DateTime.now();
        _isRecommendedFallback = false;
        _isRecommendedLoading = false;
        notifyListeners();
        return;
      } catch (e) {
        if (kDebugMode) {
          print('AI 추천 API 시도 $attempt 실패: $e');
        }
        if (attempt < 2) {
          await Future.delayed(const Duration(seconds: 2));
          continue;
        }
      }
    }

    // 2회 모두 실패 시 최신 공지로 폴백
    _isRecommendedLoading = false;
    _isRecommendedFallback = true;
    if (_notices.isNotEmpty) {
      final sorted = List<Notice>.from(_notices)
        ..sort((a, b) => b.date.compareTo(a.date));
      _recommendedPool = sorted.take(30).toList();
      if (kDebugMode) {
        print('AI 추천 API 실패, 최신순 폴백 사용 (${_recommendedPool.length}건)');
      }
    }
    _error = null;
    notifyListeners();
  }

  /// 학과/학년 인기 공지사항 가져오기 (백엔드 API 호출)
  /// 캐시가 유효하면 재호출 스킵, force=true 시 강제 갱신
  Future<void> fetchDepartmentPopularNotices({bool force = false}) async {
    // 캐시 유효 시 스킵
    if (!force &&
        _departmentPopularNotices.isNotEmpty &&
        _departmentPopularLastFetched != null &&
        DateTime.now().difference(_departmentPopularLastFetched!) < _cacheDuration) {
      return;
    }

    _isDepartmentPopularLoading = true;
    notifyListeners();

    try {
      final result = await _apiService.getPopularInMyGroup(limit: 30);
      final notices = (result['notices'] as List<dynamic>?) ?? [];
      final group = result['group'] as Map<String, dynamic>?;

      // RPC 응답 필드 매핑: notice_id→id, view_count_in_group→view_count
      _departmentPopularNotices =
          notices.map((json) {
            final mapped = Map<String, dynamic>.from(json);
            if (mapped.containsKey('notice_id') && !mapped.containsKey('id')) {
              mapped['id'] = mapped['notice_id'];
            }
            if (mapped.containsKey('view_count_in_group') && !mapped.containsKey('view_count')) {
              mapped['view_count'] = mapped['view_count_in_group'];
            }
            return Notice.fromJson(mapped);
          }).toList();
      _syncBookmarkState(_departmentPopularNotices);
      _departmentPopularDept = group?['department']?.toString();
      _departmentPopularGrade = group?['grade'] as int?;
      _departmentPopularLastFetched = DateTime.now();
      _isDepartmentPopularLoading = false;
      notifyListeners();
    } catch (e) {
      _isDepartmentPopularLoading = false;
      if (kDebugMode) {
        print('학과 인기 공지 API 실패, 로컬 폴백: $e');
      }
      // 로컬 폴백: 기존 로직 사용
      _departmentPopularNotices = [];
      notifyListeners();
    }
  }

  /// 오늘 필수 공지사항 가져오기 (백엔드 점수 기반 정렬)
  /// 캐시가 유효하면 재호출 스킵, force=true 시 강제 갱신
  Future<void> fetchEssentialNotices({bool force = false}) async {
    // 캐시 유효 시 스킵
    if (!force &&
        _essentialNotices.isNotEmpty &&
        _essentialLastFetched != null &&
        DateTime.now().difference(_essentialLastFetched!) < _cacheDuration) {
      return;
    }

    _isEssentialLoading = true;
    notifyListeners();

    try {
      final data = await _apiService.getEssentialNotices(limit: 10);
      _essentialNotices = data.map((json) => Notice.fromJson(json)).toList();
      _syncBookmarkState(_essentialNotices);
      _essentialLastFetched = DateTime.now();
      _isEssentialLoading = false;
      notifyListeners();
    } catch (e) {
      _isEssentialLoading = false;
      if (kDebugMode) {
        print('오늘 필수 공지 조회 실패: $e');
      }
      notifyListeners();
    }
  }

  /// 마감 임박 공지사항 가져오기 (백엔드 API, 오늘~D+7 마감일순)
  /// 캐시가 유효하면 재호출 스킵, force=true 시 강제 갱신
  Future<void> fetchDeadlineSoonNotices({bool force = false}) async {
    // 캐시 유효 시 스킵
    if (!force &&
        _deadlineSoonNotices.isNotEmpty &&
        _deadlineSoonLastFetched != null &&
        DateTime.now().difference(_deadlineSoonLastFetched!) < _cacheDuration) {
      return;
    }

    _isDeadlineSoonLoading = true;
    notifyListeners();

    try {
      final data = await _apiService.getDeadlineSoonNotices(limit: 10);
      _deadlineSoonNotices = data.map((json) => Notice.fromJson(json)).toList();
      _syncBookmarkState(_deadlineSoonNotices);
      _deadlineSoonLastFetched = DateTime.now();
      _isDeadlineSoonLoading = false;
      notifyListeners();
    } catch (e) {
      _isDeadlineSoonLoading = false;
      if (kDebugMode) {
        print('마감 임박 공지 조회 실패: $e');
      }
      notifyListeners();
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
  /// null 값에 대한 안전한 처리를 포함합니다.
  Map<String, dynamic> _convertSearchResult(Map<String, dynamic> searchResult) {
    return {
      'id': searchResult['id'] ?? searchResult['notice_id'] ?? '',
      'title': searchResult['title'] ?? '',
      'content': searchResult['content'] ?? '',
      'category': searchResult['category'] ?? '공지사항',
      'published_at': searchResult['published_at'],
      'source_url': searchResult['source_url'],
      'view_count': searchResult['view_count'] ?? 0,
      'ai_summary': searchResult['ai_summary'],
      'author': searchResult['author'],
      'deadline': searchResult['deadline'],
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

  /// 이번 주 마감 공지사항 가져오기 (홈 카드4용 경량 API)
  Future<void> fetchWeeklyDeadlineNotices({int limit = 10}) async {
    _isWeeklyDeadlineLoading = true;
    notifyListeners();
    try {
      final data = await _apiService.getDeadlineNotices(limit: limit);
      final notices = data.map((json) => Notice.fromJson(json)).toList();
      // 마감 안 된 건(D-day >= 0)을 먼저, 마감된 건(D-day < 0)을 뒤로 정렬
      notices.sort((a, b) {
        final aDays = a.daysUntilDeadline ?? 0;
        final bDays = b.daysUntilDeadline ?? 0;
        final aExpired = aDays < 0 ? 1 : 0;
        final bExpired = bDays < 0 ? 1 : 0;
        if (aExpired != bExpired) return aExpired - bExpired;
        return aDays - bDays; // 임박한 순서
      });
      _syncBookmarkState(notices);
      _weeklyDeadlineNotices = notices;
    } catch (e) {
      debugPrint('이번 주 마감 공지 조회 실패: $e');
    }
    _isWeeklyDeadlineLoading = false;
    notifyListeners();
  }

  /// 사용자 북마크 공지사항 가져오기 (홈 카드2용 경량 API)
  Future<void> fetchBookmarkedNotices({int limit = 10}) async {
    _isBookmarkedLoading = true;
    notifyListeners();
    try {
      final data = await _apiService.getBookmarkedNotices(limit: limit);
      // 북마크 목록이므로 isBookmarked: true 보장 (API가 필드 미반환 시 대비)
      _bookmarkedNotices = data.map((json) =>
          Notice.fromJson(json).copyWith(isBookmarked: true)).toList();
    } catch (e) {
      debugPrint('북마크 공지 조회 실패: $e');
    }
    _isBookmarkedLoading = false;
    notifyListeners();
  }

  /// 조회수 기준 인기 공지사항 가져오기 (홈 카드 5개 + 전체보기 10개)
  Future<void> fetchPopularNotices({int limit = 10}) async {
    _isPopularLoading = true;
    notifyListeners();
    try {
      final data = await _apiService.getPopularNotices(limit: limit);
      _popularNotices = data.map((json) => Notice.fromJson(json)).toList();
    } catch (e) {
      debugPrint('인기 공지 조회 실패: $e');
    }
    _isPopularLoading = false;
    notifyListeners();
  }

  /// 백엔드에서 공지사항 목록 가져오기
  Future<void> fetchNotices() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // 백엔드 API 호출 (is_bookmarked, bookmark_count 포함)
      final noticesData = await _apiService.getNotices(limit: 100);

      // Notice 객체로 변환 (API가 is_bookmarked, bookmark_count 직접 반환)
      _notices = noticesData.map((json) => Notice.fromJson(json)).toList();
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
        _error = null;
        notifyListeners();
      }
    }
  }

  /// 북마크 리스트를 모든 소스에서 재구성합니다.
  void _rebuildBookmarkedNotices() {
    final seen = <String>{};
    final result = <Notice>[];

    // 모든 공지 리스트에서 북마크된 공지 수집 (중복 제외)
    final allSources = [_notices, _categoryNotices, _bookmarkedNotices,
        _recommendedPool, _popularNotices, _essentialNotices,
        _deadlineSoonNotices, _weeklyDeadlineNotices, _departmentPopularNotices];
    for (final list in allSources) {
      for (final n in list) {
        if (n.isBookmarked && seen.add(n.id)) result.add(n);
      }
    }

    _bookmarkedNotices = result;
  }

  /// 새로 fetch한 리스트에 기존 북마크 상태를 동기화하는 헬퍼
  /// API 응답에는 isBookmarked가 없으므로, _bookmarkedNotices 기준으로 설정
  void _syncBookmarkState(List<Notice> list) {
    final bookmarkIds = _bookmarkedNotices.map((n) => n.id).toSet();
    for (var i = 0; i < list.length; i++) {
      if (bookmarkIds.contains(list[i].id) && !list[i].isBookmarked) {
        list[i] = list[i].copyWith(isBookmarked: true);
      }
    }
  }

  /// 리스트에서 noticeId를 찾아 북마크 상태를 업데이트하는 헬퍼
  /// 반환값: 업데이트된 인덱스 (-1이면 미발견)
  int _updateBookmarkInList(List<Notice> list, String noticeId, bool newState, int countDelta) {
    final idx = list.indexWhere((n) => n.id == noticeId);
    if (idx != -1) {
      list[idx] = list[idx].copyWith(
        isBookmarked: newState,
        bookmarkCount: list[idx].bookmarkCount + countDelta,
      );
    }
    return idx;
  }

  /// 현재 북마크 상태 확인 (UI 표시 기준과 동일하게 _bookmarkedNotices 기준)
  bool _findCurrentBookmarkState(String noticeId) {
    return _bookmarkedNotices.any((n) => n.id == noticeId);
  }

  /// 공지사항 북마크 토글 (백엔드 API 연동)
  Future<void> toggleBookmark(String noticeId) async {
    // 현재 북마크 상태를 UI 기준으로 확인
    final previousState = _findCurrentBookmarkState(noticeId);
    final newState = !previousState;
    final countDelta = newState ? 1 : -1;

    // 롤백용 이전 상태 캡처 (수정 전에 저장해야 정확한 복원 가능)
    final previousBookmarks = List<Notice>.from(_bookmarkedNotices);

    // 모든 리스트에서 낙관적 업데이트
    final allLists = [_notices, _recommendedPool, _categoryNotices,
        _popularNotices, _essentialNotices, _deadlineSoonNotices,
        _weeklyDeadlineNotices, _departmentPopularNotices];
    for (final list in allLists) {
      _updateBookmarkInList(list, noticeId, newState, countDelta);
    }

    // _bookmarkedNotices 직접 업데이트 (해제 시 isBookmarked=false 설정)
    final bmIndex = _bookmarkedNotices.indexWhere((n) => n.id == noticeId);
    if (!newState && bmIndex != -1) {
      _bookmarkedNotices[bmIndex] = _bookmarkedNotices[bmIndex].copyWith(
        isBookmarked: false,
      );
    }

    _rebuildBookmarkedNotices();
    notifyListeners();

    try {
      // 백엔드 API 호출
      await _apiService.toggleBookmark(noticeId);
    } catch (e) {
      // API 실패 시 모든 리스트 롤백
      for (final list in allLists) {
        _updateBookmarkInList(list, noticeId, previousState, -countDelta);
      }
      _bookmarkedNotices = previousBookmarks;
      notifyListeners();

      if (kDebugMode) {
        print('북마크 API 에러 (로컬 유지): $e');
      }
    }
  }

  /// 백엔드에서 북마크 목록 가져오기
  Future<void> fetchBookmarks() async {
    try {
      final bookmarks = await _apiService.getBookmarks();

      // API 응답에서 Notice 객체 생성 (독립적인 북마크 리스트)
      _bookmarkedNotices = bookmarks.map((b) {
        return Notice.fromJson(b).copyWith(isBookmarked: true);
      }).toList();

      // 모든 리스트의 북마크 상태를 동기화
      final bookmarkIds = _bookmarkedNotices.map((n) => n.id).toSet();
      final allLists = [_notices, _categoryNotices, _recommendedPool,
          _popularNotices, _essentialNotices, _deadlineSoonNotices,
          _weeklyDeadlineNotices, _departmentPopularNotices];
      for (final list in allLists) {
        for (var i = 0; i < list.length; i++) {
          final shouldBeBookmarked = bookmarkIds.contains(list[i].id);
          if (list[i].isBookmarked != shouldBeBookmarked) {
            list[i] = list[i].copyWith(isBookmarked: shouldBeBookmarked);
          }
        }
      }

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

      // 조회 기록 저장 (인기 공지 집계용, 실패해도 무시)
      _apiService.recordNoticeView(noticeId);

      // 로컬 상태 업데이트
      final index = _notices.indexWhere((n) => n.id == noticeId);
      final isBookmarked = _bookmarkedNotices.any((n) => n.id == noticeId);
      if (index != -1) {
        // 기존 항목 업데이트 (북마크 상태 유지)
        _notices[index] = notice.copyWith(
          isBookmarked: _notices[index].isBookmarked || isBookmarked,
        );
      } else {
        // _notices에 없는 공지 → 추가 (캘린더/검색/알림에서 진입한 경우)
        _notices.add(notice.copyWith(isBookmarked: isBookmarked));
      }
      notifyListeners();

      return _notices.firstWhere((n) => n.id == noticeId);
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
