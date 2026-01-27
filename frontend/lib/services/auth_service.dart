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

  bool get isAuthenticated => _currentUser != null;

  AuthService(this._apiService) {
    _currentUser = _supabase.auth.currentUser;
    _updateApiToken();

    // 인증 상태 변경 감지
    _supabase.auth.onAuthStateChange.listen((data) {
      final AuthChangeEvent event = data.event;
      final Session? session = data.session;

      _currentUser = session?.user;
      
      if (event == AuthChangeEvent.signedIn || event == AuthChangeEvent.tokenRefreshed) {
        _apiService.setToken(session?.accessToken);
      } else if (event == AuthChangeEvent.signedOut) {
        _apiService.setToken(null);
      }
      
      notifyListeners();
    });
  }

  /// 초기 토큰 설정
  void _updateApiToken() {
    final session = _supabase.auth.currentSession;
    _apiService.setToken(session?.accessToken);
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
