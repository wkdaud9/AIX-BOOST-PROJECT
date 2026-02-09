import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'api_service.dart';

/// 인증 서비스
/// Supabase Auth를 관리하고 API 서비스에 토큰을 설정합니다.
class AuthService extends ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;
  final ApiService _apiService;

  User? _currentUser;
  User? get currentUser => _currentUser;

  /// 사용자 이름 (AppBar 표시용)
  String? _userName;
  String? get userName => _userName;

  /// 사용자 학과
  String? _department;
  String? get department => _department;

  /// 사용자 학년
  int? _grade;
  int? get grade => _grade;

  bool get isAuthenticated => _currentUser != null;

  AuthService(this._apiService) {
    _currentUser = _supabase.auth.currentUser;
    _updateApiToken();

    // 이미 로그인 상태라면 사용자 이름 로드
    if (_currentUser != null) {
      fetchUserName();
    }

    // 인증 상태 변경 감지
    _supabase.auth.onAuthStateChange.listen((data) {
      final AuthChangeEvent event = data.event;
      final Session? session = data.session;

      _currentUser = session?.user;

      if (event == AuthChangeEvent.signedIn || event == AuthChangeEvent.tokenRefreshed) {
        _apiService.setToken(session?.accessToken);
        fetchUserName();
      } else if (event == AuthChangeEvent.signedOut) {
        _apiService.setToken(null);
        _userName = null;
        _department = null;
        _grade = null;
      }

      notifyListeners();
    });
  }

  /// 초기 토큰 설정
  void _updateApiToken() {
    final session = _supabase.auth.currentSession;
    _apiService.setToken(session?.accessToken);
  }

  /// 사용자 이름 조회 (AppBar 표시용)
  Future<void> fetchUserName() async {
    if (_currentUser == null) {
      _userName = null;
      notifyListeners();
      return;
    }
    try {
      final profileData = await _apiService.getUserProfile(_currentUser!.id);
      _userName = profileData['user']?['name'];
      _department = profileData['user']?['department'];
      final gradeValue = profileData['user']?['grade'];
      _grade = gradeValue is int ? gradeValue : int.tryParse('$gradeValue');
      notifyListeners();
    } catch (e) {
      debugPrint('사용자 이름 조회 실패: $e');
    }
  }

  /// 사용자 이름 로컬 업데이트 (프로필 편집 후 즉시 반영)
  void updateUserName(String name) {
    _userName = name;
    notifyListeners();
  }

  /// 이메일 로그인
  Future<void> signIn(String email, String password) async {
    try {
      await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );
    } catch (e) {
      debugPrint('로그인 에러: $e');
      rethrow;
    }
  }

  /// 회원가입
  Future<void> signUp(String email, String password) async {
    try {
      await _supabase.auth.signUp(
        email: email,
        password: password,
      );
    } catch (e) {
      debugPrint('회원가입 에러: $e');
      rethrow;
    }
  }

  /// 로그아웃
  Future<void> signOut() async {
    try {
      await _supabase.auth.signOut();
    } catch (e) {
      debugPrint('로그아웃 에러: $e');
      rethrow;
    }
  }
}
