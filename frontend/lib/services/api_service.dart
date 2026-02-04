import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Backend API와 통신하는 서비스 클래스
/// RESTful API 호출 및 응답 처리를 담당합니다.
class ApiService {
  late final Dio _dio;
  final String baseUrl;

  ApiService({String? baseUrl})
      : baseUrl = baseUrl ?? dotenv.env['BACKEND_URL'] ?? 'http://localhost:5000' {
    _dio = Dio(BaseOptions(
      baseUrl: this.baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
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

      // 응답 처리
      if (response.statusCode == 200) {
        final responseData = response.data as Map<String, dynamic>;
        if (responseData['status'] == 'success' && responseData.containsKey('data')) {
          return List<Map<String, dynamic>>.from(responseData['data']);
        }
      }
      return [];
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

      // 응답 처리
      if (response.statusCode == 200) {
        final responseData = response.data as Map<String, dynamic>;
        if (responseData['status'] == 'success' && responseData.containsKey('data')) {
          final data = responseData['data'] as Map<String, dynamic>;
          if (data.containsKey('events')) {
            return List<Map<String, dynamic>>.from(data['events']);
          }
        }
      }
      return [];
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

  /// API 응답 처리 (공통 포맷: {"status": "success", "data": {...}})
  Map<String, dynamic> _handleResponse(Response response) {
    if (response.statusCode == 200) {
      final data = response.data as Map<String, dynamic>;
      if (data['status'] == 'success') {
        return data['data'] as Map<String, dynamic>;
      } else {
        throw Exception('API Error: ${data['message'] ?? 'Unknown error'}');
      }
    } else {
      throw Exception('HTTP Error: ${response.statusCode}');
    }
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
