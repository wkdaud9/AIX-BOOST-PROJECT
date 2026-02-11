import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'api_service.dart';

/// 인증 서비스
/// Supabase Auth를 관리하고 API 서비스에 토큰을 설정합니다.
/// 사용자 프로필을 SharedPreferences에 캐싱하여 즉시 표시합니다.
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

  /// 비밀번호 재설정(recovery) 세션 여부
  bool _isPasswordRecovery = false;
  bool get isPasswordRecovery => _isPasswordRecovery;

  AuthService(this._apiService) {
    _currentUser = _supabase.auth.currentUser;
    _updateApiToken();

    // 이미 로그인 상태라면 캐시에서 즉시 로드 + 백그라운드 갱신
    if (_currentUser != null) {
      _loadCachedProfile();
      fetchUserName();
    }

    // 인증 상태 변경 감지
    _supabase.auth.onAuthStateChange.listen((data) {
      final AuthChangeEvent event = data.event;
      final Session? session = data.session;

      _currentUser = session?.user;

      if (event == AuthChangeEvent.passwordRecovery) {
        // 비밀번호 재설정 링크로 진입한 경우
        _isPasswordRecovery = true;
        _apiService.setToken(session?.accessToken);
      } else if (event == AuthChangeEvent.signedIn || event == AuthChangeEvent.tokenRefreshed) {
        _apiService.setToken(session?.accessToken);
        if (!_isPasswordRecovery) {
          _loadCachedProfile();
          fetchUserName();
        }
      } else if (event == AuthChangeEvent.signedOut) {
        _apiService.setToken(null);
        _userName = null;
        _department = null;
        _grade = null;
        _isPasswordRecovery = false;
        _clearCachedProfile();
      }

      notifyListeners();
    });
  }

  /// 초기 토큰 설정
  void _updateApiToken() {
    final session = _supabase.auth.currentSession;
    _apiService.setToken(session?.accessToken);
  }

  /// 캐시에서 사용자 프로필 즉시 로드 (API 응답 대기 없이 바로 표시)
  Future<void> _loadCachedProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedName = prefs.getString('user_name');
      final cachedDept = prefs.getString('user_department');
      final cachedGrade = prefs.getInt('user_grade');

      if (cachedName != null && _userName == null) {
        _userName = cachedName;
        _department = cachedDept;
        _grade = cachedGrade;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('프로필 캐시 로드 실패: $e');
    }
  }

  /// 사용자 프로필을 SharedPreferences에 캐싱
  Future<void> _saveCachedProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_userName != null) {
        await prefs.setString('user_name', _userName!);
      }
      if (_department != null) {
        await prefs.setString('user_department', _department!);
      }
      if (_grade != null) {
        await prefs.setInt('user_grade', _grade!);
      }
    } catch (e) {
      debugPrint('프로필 캐시 저장 실패: $e');
    }
  }

  /// 로그아웃 시 캐시 삭제
  Future<void> _clearCachedProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('user_name');
      await prefs.remove('user_department');
      await prefs.remove('user_grade');
    } catch (e) {
      debugPrint('프로필 캐시 삭제 실패: $e');
    }
  }

  /// 사용자 이름 조회 (AppBar 표시용) + 캐시 갱신
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

      // 성공 시 캐시 갱신
      _saveCachedProfile();
    } catch (e) {
      debugPrint('사용자 이름 조회 실패: $e');
    }
  }

  /// 사용자 이름 로컬 업데이트 (프로필 편집 후 즉시 반영)
  void updateUserName(String name) {
    _userName = name;
    notifyListeners();
    _saveCachedProfile();
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

  /// 비밀번호 재설정 이메일 전송
  Future<void> resetPassword(String email) async {
    try {
      await _supabase.auth.resetPasswordForEmail(email);
    } catch (e) {
      debugPrint('비밀번호 재설정 에러: $e');
      rethrow;
    }
  }

  /// OTP 코드로 비밀번호 재설정 인증
  /// Supabase verifyOTP(type: recovery)로 세션을 생성합니다.
  Future<void> verifyRecoveryOtp(String email, String token) async {
    try {
      await _supabase.auth.verifyOTP(
        email: email,
        token: token,
        type: OtpType.recovery,
      );
      _isPasswordRecovery = true;
    } catch (e) {
      debugPrint('OTP 인증 에러: $e');
      rethrow;
    }
  }

  /// 비밀번호 변경 (recovery 세션에서 새 비밀번호 설정)
  Future<void> updatePassword(String newPassword) async {
    try {
      await _supabase.auth.updateUser(
        UserAttributes(password: newPassword),
      );
      _isPasswordRecovery = false;
      notifyListeners();
    } catch (e) {
      debugPrint('비밀번호 변경 에러: $e');
      rethrow;
    }
  }

  /// recovery 상태 초기화 (취소 시)
  void clearPasswordRecovery() {
    _isPasswordRecovery = false;
    notifyListeners();
  }
}
