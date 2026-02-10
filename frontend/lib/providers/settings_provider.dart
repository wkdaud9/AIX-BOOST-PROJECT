import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';

/// 알림 모드 enum
enum NotificationMode {
  allOff,       // 모두 끔
  scheduleOnly, // 일정만 켬
  noticeOnly,   // 공지만 켬
  allOn,        // 모두 켬
}

/// 앱 설정 상태 관리 Provider
/// 테마, 알림 설정 등을 관리하고 SharedPreferences로 영속화
class SettingsProvider with ChangeNotifier {
  static const String _themeModeKey = 'theme_mode';
  static const String _pushNotificationKey = 'push_notification_enabled';
  static const String _scheduleNotificationKey = 'schedule_notification_enabled';
  static const String _deadlineReminderDaysKey = 'deadline_reminder_days';
  static const String _notificationModeKey = 'notification_mode';

  SharedPreferences? _prefs;
  final ApiService _apiService = ApiService();
  String? _userId;

  // 테마 설정
  ThemeMode _themeMode = ThemeMode.system;

  // 알림 설정
  bool _pushNotificationEnabled = true;
  bool _scheduleNotificationEnabled = true;
  int _deadlineReminderDays = 3; // D-3 기본값
  NotificationMode _notificationMode = NotificationMode.allOn;

  // 초기화 완료 여부
  bool _isInitialized = false;

  // Getters
  ThemeMode get themeMode => _themeMode;
  bool get pushNotificationEnabled => _pushNotificationEnabled;
  bool get scheduleNotificationEnabled => _scheduleNotificationEnabled;
  int get deadlineReminderDays => _deadlineReminderDays;
  bool get isInitialized => _isInitialized;
  NotificationMode get notificationMode => _notificationMode;

  /// 설정 초기화 (앱 시작 시 호출)
  Future<void> initialize({String? userId}) async {
    if (_isInitialized) return;

    _prefs = await SharedPreferences.getInstance();
    _userId = userId;
    await _loadSettings();

    // 로그인 상태면 백엔드에서 알림 설정 동기화
    if (_userId != null) {
      await _syncFromBackend();
    }

    _isInitialized = true;
    notifyListeners();
  }

  /// SharedPreferences에서 설정 로드
  Future<void> _loadSettings() async {
    if (_prefs == null) return;

    // 테마 모드 로드
    final themeModeIndex = _prefs!.getInt(_themeModeKey);
    if (themeModeIndex != null && themeModeIndex < ThemeMode.values.length) {
      _themeMode = ThemeMode.values[themeModeIndex];
    }

    // 알림 설정 로드
    _pushNotificationEnabled = _prefs!.getBool(_pushNotificationKey) ?? true;
    _scheduleNotificationEnabled = _prefs!.getBool(_scheduleNotificationKey) ?? true;
    _deadlineReminderDays = _prefs!.getInt(_deadlineReminderDaysKey) ?? 3;

    // 알림 모드 로드
    final notificationModeIndex = _prefs!.getInt(_notificationModeKey);
    if (notificationModeIndex != null && notificationModeIndex < NotificationMode.values.length) {
      _notificationMode = NotificationMode.values[notificationModeIndex];
    }
  }

  /// 테마 모드 변경
  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return;

    _themeMode = mode;
    await _prefs?.setInt(_themeModeKey, mode.index);
    notifyListeners();
  }

  /// 푸시 알림 설정 변경
  Future<void> setPushNotificationEnabled(bool enabled) async {
    if (_pushNotificationEnabled == enabled) return;

    _pushNotificationEnabled = enabled;
    await _prefs?.setBool(_pushNotificationKey, enabled);
    notifyListeners();
  }

  /// 일정 알림 설정 변경
  Future<void> setScheduleNotificationEnabled(bool enabled) async {
    if (_scheduleNotificationEnabled == enabled) return;

    _scheduleNotificationEnabled = enabled;
    await _prefs?.setBool(_scheduleNotificationKey, enabled);
    notifyListeners();
  }

  /// 마감 알림 일수 설정 변경
  Future<void> setDeadlineReminderDays(int days) async {
    if (_deadlineReminderDays == days) return;

    _deadlineReminderDays = days;
    await _prefs?.setInt(_deadlineReminderDaysKey, days);

    // 백엔드 동기화
    await _syncToBackend();
    notifyListeners();
  }

  /// 알림 모드 설정 변경
  Future<void> setNotificationMode(NotificationMode mode) async {
    if (_notificationMode == mode) return;

    _notificationMode = mode;
    await _prefs?.setInt(_notificationModeKey, mode.index);

    // 기존 bool 값도 동기화
    switch (mode) {
      case NotificationMode.allOff:
        _pushNotificationEnabled = false;
        _scheduleNotificationEnabled = false;
        break;
      case NotificationMode.scheduleOnly:
        _pushNotificationEnabled = false;
        _scheduleNotificationEnabled = true;
        break;
      case NotificationMode.noticeOnly:
        _pushNotificationEnabled = true;
        _scheduleNotificationEnabled = false;
        break;
      case NotificationMode.allOn:
        _pushNotificationEnabled = true;
        _scheduleNotificationEnabled = true;
        break;
    }

    await _prefs?.setBool(_pushNotificationKey, _pushNotificationEnabled);
    await _prefs?.setBool(_scheduleNotificationKey, _scheduleNotificationEnabled);

    // 백엔드 동기화
    await _syncToBackend();
    notifyListeners();
  }

  /// 백엔드에서 알림 설정 동기화 (앱 시작 시)
  Future<void> _syncFromBackend() async {
    if (_userId == null) return;
    try {
      final response = await _apiService.getNotificationSettings(_userId!);
      final mode = response['notification_mode'] as String? ?? 'all_on';
      final days = response['deadline_reminder_days'] as int? ?? 3;

      // 로컬 설정 갱신
      _notificationMode = _modeFromString(mode);
      _deadlineReminderDays = days;
      await _prefs?.setInt(_notificationModeKey, _notificationMode.index);
      await _prefs?.setInt(_deadlineReminderDaysKey, _deadlineReminderDays);
    } catch (e) {
      // 백엔드 실패 시 로컬 설정 유지
    }
  }

  /// 백엔드에 알림 설정 저장 (설정 변경 시)
  Future<void> _syncToBackend() async {
    if (_userId == null) return;
    try {
      await _apiService.updateNotificationSettings(
        userId: _userId!,
        notificationMode: _modeToString(_notificationMode),
        deadlineReminderDays: _deadlineReminderDays,
      );
    } catch (e) {
      // 백엔드 실패 시 로컬 설정은 이미 저장됨
    }
  }

  /// 사용자 ID 설정 (로그인 시 호출)
  void setUserId(String? userId) {
    _userId = userId;
  }

  /// NotificationMode → 백엔드 문자열 변환
  String _modeToString(NotificationMode mode) {
    switch (mode) {
      case NotificationMode.allOff: return 'all_off';
      case NotificationMode.scheduleOnly: return 'schedule_only';
      case NotificationMode.noticeOnly: return 'notice_only';
      case NotificationMode.allOn: return 'all_on';
    }
  }

  /// 백엔드 문자열 → NotificationMode 변환
  NotificationMode _modeFromString(String mode) {
    switch (mode) {
      case 'all_off': return NotificationMode.allOff;
      case 'schedule_only': return NotificationMode.scheduleOnly;
      case 'notice_only': return NotificationMode.noticeOnly;
      default: return NotificationMode.allOn;
    }
  }

  /// 알림 모드 표시 텍스트
  String get notificationModeDisplayText {
    switch (_notificationMode) {
      case NotificationMode.allOff:
        return '모두 끔';
      case NotificationMode.scheduleOnly:
        return '일정만 켬';
      case NotificationMode.noticeOnly:
        return '공지만 켬';
      case NotificationMode.allOn:
        return '모두 켬';
    }
  }

  /// 캐시 초기화 (설정은 유지)
  Future<void> clearCache() async {
    // TODO: 실제 캐시 초기화 로직 구현
    // 이미지 캐시, API 캐시 등 초기화
    notifyListeners();
  }

  /// 모든 설정 초기화 (기본값으로)
  Future<void> resetToDefaults() async {
    _themeMode = ThemeMode.system;
    _pushNotificationEnabled = true;
    _scheduleNotificationEnabled = true;
    _deadlineReminderDays = 3;
    _notificationMode = NotificationMode.allOn;

    await _prefs?.remove(_themeModeKey);
    await _prefs?.remove(_pushNotificationKey);
    await _prefs?.remove(_scheduleNotificationKey);
    await _prefs?.remove(_deadlineReminderDaysKey);
    await _prefs?.remove(_notificationModeKey);

    notifyListeners();
  }

  /// 테마 모드 표시 텍스트
  String get themeModeDisplayText {
    switch (_themeMode) {
      case ThemeMode.system:
        return '시스템 설정';
      case ThemeMode.light:
        return '라이트 모드';
      case ThemeMode.dark:
        return '다크 모드';
    }
  }
}
