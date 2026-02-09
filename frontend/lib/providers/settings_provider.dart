import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 앱 설정 상태 관리 Provider
/// 테마, 알림 설정 등을 관리하고 SharedPreferences로 영속화
class SettingsProvider with ChangeNotifier {
  static const String _themeModeKey = 'theme_mode';
  static const String _pushNotificationKey = 'push_notification_enabled';
  static const String _scheduleNotificationKey = 'schedule_notification_enabled';
  static const String _deadlineReminderDaysKey = 'deadline_reminder_days';

  SharedPreferences? _prefs;

  // 테마 설정
  ThemeMode _themeMode = ThemeMode.system;

  // 알림 설정
  bool _pushNotificationEnabled = true;
  bool _scheduleNotificationEnabled = true;
  int _deadlineReminderDays = 3; // D-3 기본값

  // 초기화 완료 여부
  bool _isInitialized = false;

  // Getters
  ThemeMode get themeMode => _themeMode;
  bool get pushNotificationEnabled => _pushNotificationEnabled;
  bool get scheduleNotificationEnabled => _scheduleNotificationEnabled;
  int get deadlineReminderDays => _deadlineReminderDays;
  bool get isInitialized => _isInitialized;

  /// 설정 초기화 (앱 시작 시 호출)
  Future<void> initialize() async {
    if (_isInitialized) return;

    _prefs = await SharedPreferences.getInstance();
    await _loadSettings();
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
    notifyListeners();
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

    await _prefs?.remove(_themeModeKey);
    await _prefs?.remove(_pushNotificationKey);
    await _prefs?.remove(_scheduleNotificationKey);
    await _prefs?.remove(_deadlineReminderDaysKey);

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
