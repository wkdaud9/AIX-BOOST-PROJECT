import 'package:dio/dio.dart';
import '../env_config.dart';

/// Backend API와 통신하는 서비스 클래스
/// RESTful API 호출 및 응답 처리를 담당합니다.
class ApiService {
  late final Dio _dio;
  final String baseUrl;

  ApiService({String? baseUrl})
      : baseUrl = baseUrl ?? EnvConfig.backendUrl {
    _dio = Dio(BaseOptions(
      baseUrl: this.baseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      headers: {
        'Content-Type': 'application/json',
      },
    ));
  }

  /// 인증 토큰 설정
  void setToken(String? token) {
    if (token != null) {
      _dio.options.headers['Authorization'] = 'Bearer $token';
    } else {
      _dio.options.headers.remove('Authorization');
    }
  }

  /// 관리자: 공지사항 크롤링 수동 실행
  Future<Map<String, dynamic>> crawlNotices({int maxPages = 1, List<String>? categories}) async {
    try {
      final response = await _dio.post('/api/notices/crawl', data: {
        'max_pages': maxPages,
        'categories': categories,
      });
      return _handleResponse(response);
    } catch (e) {
      throw _handleError(e);
    }
  }

  /// 헬스 체크 API 호출
  Future<Map<String, dynamic>> healthCheck() async {
    try {
      final response = await _dio.get('/health');
      return _handleResponse(response);
    } catch (e) {
      throw _handleError(e);
    }
  }

  /// 공지사항 목록 조회
  ///
  /// [category] 카테고리 필터 (선택)
  /// [limit] 가져올 개수 (기본 20)
  /// [offset] 건너뛸 개수 (페이지네이션)
  Future<List<Map<String, dynamic>>> getNotices({
    String? category,
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'limit': limit,
        'offset': offset,
      };
      if (category != null) {
        queryParams['category'] = category;
      }

      final response = await _dio.get('/api/notices/', queryParameters: queryParams);
      return _handleListResponse(response);
    } catch (e) {
      throw _handleError(e);
    }
  }

  /// 조회수 기준 인기 공지사항 조회 (DB 전체 대상)
  Future<List<Map<String, dynamic>>> getPopularNotices({int limit = 5}) async {
    try {
      final response = await _dio.get('/api/notices/popular', queryParameters: {'limit': limit});
      return _handleListResponse(response);
    } catch (e) {
      throw _handleError(e);
    }
  }

  /// 특정 공지사항 상세 조회
  Future<Map<String, dynamic>> getNoticeById(String noticeId) async {
    try {
      final response = await _dio.get('/api/notices/$noticeId');
      return _handleResponse(response);
    } catch (e) {
      throw _handleError(e);
    }
  }

  /// 공지사항 통계 조회
  Future<Map<String, dynamic>> getStatistics() async {
    try {
      final response = await _dio.get('/api/notices/stats');
      return _handleResponse(response);
    } catch (e) {
      throw _handleError(e);
    }
  }

  /// 캘린더 이벤트 조회
  ///
  /// [month] 조회할 월 (예: "2026-02")
  Future<List<Map<String, dynamic>>> getCalendarEvents({String? month}) async {
    try {
      final queryParams = <String, dynamic>{};
      if (month != null) {
        queryParams['month'] = month;
      }

      final response = await _dio.get(
        '/api/calendar/events',
        queryParameters: queryParams,
      );
      return _handleListResponse(response, listKey: 'events');
    } catch (e) {
      throw _handleError(e);
    }
  }

  /// 회원가입 후 사용자 프로필 및 선호도 생성
  Future<Map<String, dynamic>> createUserProfile({
    required String userId,
    required String email,
    required String name,
    required String studentId,
    required String department,
    required int grade,
    required List<String> categories,
  }) async {
    try {
      final response = await _dio.post('/api/users/profile', data: {
        'user_id': userId,
        'email': email,
        'name': name,
        'student_id': studentId,
        'department': department,
        'grade': grade,
        'categories': categories,
      });
      return _handleResponse(response);
    } catch (e) {
      throw _handleError(e);
    }
  }

  /// 사용자 프로필 조회
  Future<Map<String, dynamic>> getUserProfile(String userId) async {
    try {
      final response = await _dio.get('/api/users/profile/$userId');
      return _handleResponse(response);
    } catch (e) {
      throw _handleError(e);
    }
  }

  /// 사용자 프로필(이름, 학과, 학년) 업데이트
  Future<Map<String, dynamic>> updateUserProfile({
    required String userId,
    String? name,
    String? department,
    int? grade,
  }) async {
    try {
      final data = <String, dynamic>{};
      if (name != null) data['name'] = name;
      if (department != null) data['department'] = department;
      if (grade != null) data['grade'] = grade;

      final response = await _dio.put('/api/users/profile/$userId', data: data);
      return _handleResponse(response);
    } catch (e) {
      throw _handleError(e);
    }
  }

  /// 사용자 선호도(카테고리) 업데이트
  Future<Map<String, dynamic>> updateUserPreferences({
    required String userId,
    required List<String> categories,
  }) async {
    try {
      final response = await _dio.put('/api/users/preferences/$userId', data: {
        'categories': categories,
      });
      return _handleResponse(response);
    } catch (e) {
      throw _handleError(e);
    }
  }

  /// 사용자 삭제 (회원가입 롤백용)
  Future<void> deleteUser(String userId) async {
    try {
      await _dio.delete('/api/users/profile/$userId');
    } catch (e) {
      // 삭제 실패해도 무시 (이미 삭제되었을 수 있음)
    }
  }

  /// AI 맞춤 추천 공지사항 조회 (사용자 관심사 기반 하이브리드 검색)
  ///
  /// [limit] 최대 결과 수 (기본 20)
  /// [minScore] 최소 관련도 점수 (기본 0.3)
  Future<List<Map<String, dynamic>>> getRecommendedNotices({
    int limit = 20,
    double minScore = 0.3,
  }) async {
    try {
      final response = await _dio.get(
        '/api/search/notices',
        queryParameters: {
          'limit': limit,
          'min_score': minScore,
          'rerank': 'true',
        },
        options: Options(
          receiveTimeout: const Duration(seconds: 30),
        ),
      );
      return _handleListResponse(response, listKey: 'notices');
    } catch (e) {
      throw _handleError(e);
    }
  }

  /// 우리 학과/학년 인기 공지사항 조회
  ///
  /// [limit] 최대 결과 수 (기본 20)
  /// 반환값: {"notices": [...], "total": N, "group": {"department": "...", "grade": N}}
  Future<Map<String, dynamic>> getPopularInMyGroup({int limit = 20}) async {
    try {
      final response = await _dio.get(
        '/api/notices/popular-in-my-group',
        queryParameters: {'limit': limit},
      );
      return _handleResponse(response);
    } catch (e) {
      throw _handleError(e);
    }
  }

  /// 북마크 토글 (추가/제거)
  ///
  /// [noticeId] 공지사항 ID
  /// 반환값: {"bookmarked": true/false, "notice_id": "uuid"}
  Future<Map<String, dynamic>> toggleBookmark(String noticeId) async {
    try {
      final response = await _dio.post('/api/bookmarks/$noticeId');
      return _handleResponse(response);
    } catch (e) {
      throw _handleError(e);
    }
  }

  /// 사용자의 북마크 목록 조회
  Future<List<Map<String, dynamic>>> getBookmarks({
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      final response = await _dio.get(
        '/api/bookmarks',
        queryParameters: {
          'limit': limit,
          'offset': offset,
        },
      );
      return _handleListResponse(response, listKey: 'bookmarks');
    } catch (e) {
      throw _handleError(e);
    }
  }

  /// FCM 디바이스 토큰 등록
  Future<void> registerFCMToken({
    required String token,
    required String deviceType,
  }) async {
    try {
      await _dio.post('/api/notifications/token', data: {
        'token': token,
        'device_type': deviceType,
      });
    } catch (e) {
      throw _handleError(e);
    }
  }

  /// FCM 디바이스 토큰 해제 (로그아웃 시)
  Future<void> unregisterFCMToken({required String token}) async {
    try {
      await _dio.delete('/api/notifications/token', data: {
        'token': token,
      });
    } catch (e) {
      throw _handleError(e);
    }
  }

  /// 알림 내역 조회
  Future<Map<String, dynamic>> getNotifications({
    int limit = 20,
    int offset = 0,
    bool unreadOnly = false,
  }) async {
    try {
      final response = await _dio.get(
        '/api/notifications',
        queryParameters: {
          'limit': limit,
          'offset': offset,
          'unread_only': unreadOnly.toString(),
        },
      );
      return _handleResponse(response);
    } catch (e) {
      throw _handleError(e);
    }
  }

  /// 알림 읽음 처리
  Future<void> markNotificationAsRead(String notificationId) async {
    try {
      await _dio.put('/api/notifications/$notificationId/read');
    } catch (e) {
      throw _handleError(e);
    }
  }

  /// 전체 알림 읽음 처리
  Future<void> markAllNotificationsAsRead() async {
    try {
      await _dio.put('/api/notifications/read-all');
    } catch (e) {
      throw _handleError(e);
    }
  }

  /// 알림 설정 조회
  Future<Map<String, dynamic>> getNotificationSettings(String userId) async {
    try {
      final response = await _dio.get(
        '/api/users/preferences/$userId/notification-settings',
      );
      return _handleResponse(response);
    } catch (e) {
      throw _handleError(e);
    }
  }

  /// 알림 설정 업데이트
  Future<Map<String, dynamic>> updateNotificationSettings({
    required String userId,
    String? notificationMode,
    int? deadlineReminderDays,
  }) async {
    try {
      final data = <String, dynamic>{};
      if (notificationMode != null) {
        data['notification_mode'] = notificationMode;
      }
      if (deadlineReminderDays != null) {
        data['deadline_reminder_days'] = deadlineReminderDays;
      }
      final response = await _dio.put(
        '/api/users/preferences/$userId/notification-settings',
        data: data,
      );
      return _handleResponse(response);
    } catch (e) {
      throw _handleError(e);
    }
  }

  /// 공지사항 조회 기록 (인기 공지 집계용)
  Future<void> recordNoticeView(String noticeId) async {
    try {
      await _dio.post('/api/notices/$noticeId/view');
    } catch (e) {
      // 조회 기록 실패는 무시 (사용자 경험에 영향 없음)
      print('조회 기록 실패: $e');
    }
  }

  /// 키워드로 공지사항 검색 (제목 + 벡터 하이브리드 검색)
  ///
  /// [query] 검색 키워드 (2자 이상)
  /// [limit] 최대 결과 수 (기본 20)
  /// [minScore] 최소 점수 (기본 0.3)
  Future<List<Map<String, dynamic>>> searchNotices({
    required String query,
    int limit = 20,
    double minScore = 0.3,
  }) async {
    try {
      final response = await _dio.get(
        '/api/search/notices/keyword',
        queryParameters: {
          'q': query,
          'limit': limit,
          'min_score': minScore,
        },
      );
      return _handleListResponse(response, listKey: 'notices');
    } catch (e) {
      throw _handleError(e);
    }
  }

  /// API 응답 처리 (공통 포맷: {"status": "success", "data": {...}})
  /// 200(OK), 201(Created), 204(No Content) 등 성공 상태 코드를 처리합니다.
  Map<String, dynamic> _handleResponse(Response response) {
    final statusCode = response.statusCode ?? 0;

    // 204 No Content는 빈 데이터 반환
    if (statusCode == 204) {
      return {};
    }

    if (statusCode >= 200 && statusCode < 300) {
      if (response.data is! Map<String, dynamic>) {
        throw Exception('API Error: 예상치 못한 응답 형식');
      }
      final data = response.data as Map<String, dynamic>;
      if (data['status'] == 'success') {
        final responseData = data['data'];
        // data가 List인 경우 첫 번째 요소 반환 (Supabase .single() 호환)
        if (responseData is List) {
          if (responseData.isNotEmpty) {
            return Map<String, dynamic>.from(responseData.first);
          }
          return {};
        }
        if (responseData is Map<String, dynamic>) {
          return responseData;
        }
        return {};
      } else {
        throw Exception('API Error: ${data['message'] ?? 'Unknown error'}');
      }
    } else {
      throw Exception('HTTP Error: $statusCode');
    }
  }

  /// 리스트 형태의 API 응답 처리
  /// {"status": "success", "data": [...]} 또는 {"status": "success", "data": {"key": [...]}}
  List<Map<String, dynamic>> _handleListResponse(Response response, {String? listKey}) {
    final statusCode = response.statusCode ?? 0;

    if (statusCode >= 200 && statusCode < 300) {
      if (response.data is! Map<String, dynamic>) {
        return [];
      }
      final responseData = response.data as Map<String, dynamic>;
      if (responseData['status'] == 'success' && responseData.containsKey('data')) {
        final data = responseData['data'];

        // data가 직접 리스트인 경우
        if (listKey == null && data is List) {
          return List<Map<String, dynamic>>.from(data);
        }

        // data가 Map이고 특정 키로 리스트를 가져오는 경우
        if (listKey != null && data is Map<String, dynamic> && data.containsKey(listKey)) {
          return List<Map<String, dynamic>>.from(data[listKey]);
        }
      }
    }
    return [];
  }

  /// 에러 처리
  Exception _handleError(dynamic error) {
    if (error is DioException) {
      switch (error.type) {
        case DioExceptionType.connectionTimeout:
          return Exception('연결 시간 초과');
        case DioExceptionType.receiveTimeout:
          return Exception('응답 시간 초과');
        case DioExceptionType.badResponse:
          // 백엔드에서 반환한 에러 메시지 파싱
          if (error.response?.data != null) {
            try {
              final data = error.response!.data as Map<String, dynamic>;
              if (data['message'] != null) {
                return Exception(data['message']);
              }
            } catch (_) {
              // 파싱 실패 시 기본 메시지
            }
          }
          return Exception('서버 오류: ${error.response?.statusCode}');
        default:
          return Exception('네트워크 오류: ${error.message}');
      }
    }
    return Exception('알 수 없는 오류: $error');
  }
}
