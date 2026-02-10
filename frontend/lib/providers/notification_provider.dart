import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_notification.dart';
import '../services/api_service.dart';

/// 알림 상태 관리 Provider
/// 백엔드 API에서 알림을 조회하고, 로컬 캐시(SharedPreferences)로 영속화
class NotificationProvider with ChangeNotifier {
  static const String _notificationsKey = 'app_notifications';
  static const int _maxNotifications = 100; // 최대 저장 개수

  SharedPreferences? _prefs;
  ApiService? _apiService;
  List<AppNotification> _notifications = [];
  bool _isInitialized = false;
  bool _isLoading = false;

  // Getters
  List<AppNotification> get notifications => List.unmodifiable(_notifications);
  int get unreadCount => _notifications.where((n) => !n.isRead).length;
  bool get hasUnread => unreadCount > 0;
  bool get isInitialized => _isInitialized;
  bool get isLoading => _isLoading;

  /// ApiService 설정 (ProxyProvider에서 호출)
  void updateApiService(ApiService apiService) {
    _apiService = apiService;
  }

  /// 초기화 (앱 시작 시 호출)
  Future<void> initialize() async {
    if (_isInitialized) return;

    _prefs = await SharedPreferences.getInstance();
    await _loadNotifications();
    _isInitialized = true;
    notifyListeners();
  }

  /// SharedPreferences에서 알림 목록 로드
  Future<void> _loadNotifications() async {
    if (_prefs == null) return;

    final jsonString = _prefs!.getString(_notificationsKey);
    if (jsonString != null && jsonString.isNotEmpty) {
      try {
        final List<dynamic> jsonList = json.decode(jsonString);
        _notifications = jsonList
            .map((item) => AppNotification.fromJson(item as Map<String, dynamic>))
            .toList();
        // 최신순 정렬
        _notifications.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      } catch (e) {
        debugPrint('알림 로드 오류: $e');
        _notifications = [];
      }
    }
  }

  /// 알림 목록 저장
  Future<void> _saveNotifications() async {
    if (_prefs == null) return;

    // 최대 개수 제한
    if (_notifications.length > _maxNotifications) {
      _notifications = _notifications.take(_maxNotifications).toList();
    }

    final jsonList = _notifications.map((n) => n.toJson()).toList();
    await _prefs!.setString(_notificationsKey, json.encode(jsonList));
  }

  /// 백엔드에서 알림 목록 조회
  Future<void> fetchFromBackend() async {
    if (_apiService == null) return;

    _isLoading = true;
    notifyListeners();

    try {
      final response = await _apiService!.getNotifications(limit: 100);
      final List<dynamic> rawList = response['notifications'] ?? [];

      final backendNotifications = rawList
          .map((item) => AppNotification.fromBackendJson(
              item as Map<String, dynamic>))
          .toList();

      // 백엔드 데이터로 교체 (FCM으로 받은 로컬 알림은 유지)
      final localOnlyNotifications = _notifications
          .where((local) => local.id.startsWith('system_'))
          .toList();

      _notifications = [...backendNotifications, ...localOnlyNotifications];
      _notifications.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      await _saveNotifications();
    } catch (e) {
      debugPrint('백엔드 알림 조회 실패: $e');
      // 실패 시 로컬 캐시 유지
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 새 알림 추가
  Future<void> addNotification(AppNotification notification) async {
    _notifications.insert(0, notification);
    await _saveNotifications();
    notifyListeners();
  }

  /// 알림 읽음 처리 (로컬 + 백엔드)
  Future<void> markAsRead(String notificationId) async {
    final index = _notifications.indexWhere((n) => n.id == notificationId);
    if (index != -1 && !_notifications[index].isRead) {
      _notifications[index] = _notifications[index].copyWith(isRead: true);
      await _saveNotifications();
      notifyListeners();

      // 백엔드에도 읽음 처리 요청
      try {
        await _apiService?.markNotificationAsRead(notificationId);
      } catch (e) {
        debugPrint('백엔드 읽음 처리 실패: $e');
      }
    }
  }

  /// 모든 알림 읽음 처리 (로컬 + 백엔드)
  Future<void> markAllAsRead() async {
    bool changed = false;
    for (int i = 0; i < _notifications.length; i++) {
      if (!_notifications[i].isRead) {
        _notifications[i] = _notifications[i].copyWith(isRead: true);
        changed = true;
      }
    }
    if (changed) {
      await _saveNotifications();
      notifyListeners();

      // 백엔드에도 전체 읽음 처리 요청
      try {
        await _apiService?.markAllNotificationsAsRead();
      } catch (e) {
        debugPrint('백엔드 전체 읽음 처리 실패: $e');
      }
    }
  }

  /// 알림 삭제
  Future<void> deleteNotification(String notificationId) async {
    _notifications.removeWhere((n) => n.id == notificationId);
    await _saveNotifications();
    notifyListeners();
  }

  /// 모든 알림 삭제
  Future<void> clearAllNotifications() async {
    _notifications.clear();
    await _saveNotifications();
    notifyListeners();
  }

  /// 마감 임박 알림 생성 (북마크 시 호출)
  Future<void> createDeadlineNotification({
    required String noticeId,
    required String noticeTitle,
    required DateTime deadline,
    required int reminderDays,
  }) async {
    final now = DateTime.now();
    final daysUntilDeadline = deadline.difference(now).inDays;

    // 이미 지난 마감일이거나 알림 일수보다 멀면 생성하지 않음
    if (daysUntilDeadline < 0 || daysUntilDeadline > reminderDays) {
      return;
    }

    // 중복 알림 방지 (같은 공지에 대한 알림이 이미 있는지 확인)
    final exists = _notifications.any(
      (n) => n.noticeId == noticeId && n.type == NotificationType.deadline,
    );
    if (exists) return;

    final notification = AppNotification(
      id: 'deadline_${noticeId}_${DateTime.now().millisecondsSinceEpoch}',
      title: '마감 임박 알림',
      body: daysUntilDeadline == 0
          ? '오늘 마감: $noticeTitle'
          : 'D-$daysUntilDeadline: $noticeTitle',
      type: NotificationType.deadline,
      createdAt: DateTime.now(),
      noticeId: noticeId,
    );

    await addNotification(notification);
  }

  /// 새 공지사항 알림 생성
  Future<void> createNewNoticeNotification({
    required String noticeId,
    required String noticeTitle,
    required String category,
  }) async {
    final notification = AppNotification(
      id: 'notice_${noticeId}_${DateTime.now().millisecondsSinceEpoch}',
      title: '새 공지사항',
      body: '[$category] $noticeTitle',
      type: NotificationType.newNotice,
      createdAt: DateTime.now(),
      noticeId: noticeId,
    );

    await addNotification(notification);
  }

  /// 시스템 알림 생성
  Future<void> createSystemNotification({
    required String title,
    required String body,
  }) async {
    final notification = AppNotification(
      id: 'system_${DateTime.now().millisecondsSinceEpoch}',
      title: title,
      body: body,
      type: NotificationType.system,
      createdAt: DateTime.now(),
    );

    await addNotification(notification);
  }

  /// 테스트용 샘플 알림 생성
  Future<void> createSampleNotifications() async {
    final samples = [
      AppNotification(
        id: 'sample_1_${DateTime.now().millisecondsSinceEpoch}',
        title: '마감 임박 알림',
        body: 'D-3: 2025학년도 1학기 수강신청 안내',
        type: NotificationType.deadline,
        createdAt: DateTime.now().subtract(const Duration(hours: 1)),
        noticeId: 'sample_notice_1',
      ),
      AppNotification(
        id: 'sample_2_${DateTime.now().millisecondsSinceEpoch}',
        title: '새 공지사항',
        body: '[장학] 2025학년도 교내장학금 신청 안내',
        type: NotificationType.newNotice,
        createdAt: DateTime.now().subtract(const Duration(hours: 3)),
        noticeId: 'sample_notice_2',
      ),
      AppNotification(
        id: 'sample_3_${DateTime.now().millisecondsSinceEpoch}',
        title: '앱 업데이트',
        body: 'AIX-Boost가 새로운 기능으로 업데이트되었습니다.',
        type: NotificationType.system,
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
      ),
    ];

    for (final sample in samples) {
      // 중복 방지
      final exists = _notifications.any((n) => n.title == sample.title && n.body == sample.body);
      if (!exists) {
        _notifications.insert(0, sample);
      }
    }

    await _saveNotifications();
    notifyListeners();
  }
}
