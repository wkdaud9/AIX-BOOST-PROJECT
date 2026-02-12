import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../firebase_options.dart';
import '../screens/notice_detail_screen.dart';
import 'api_service.dart';

/// Firebase 백그라운드 메시지 핸들러 (top-level 함수여야 함)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  debugPrint('[FCM] 백그라운드 메시지 수신: ${message.notification?.title}');
}

/// FCM 푸시 알림 서비스
/// Firebase Cloud Messaging 초기화, 토큰 관리, 알림 수신 처리를 담당합니다.
/// flutter_local_notifications로 포그라운드 알림 표시 및 알림 탭 네비게이션을 처리합니다.
class FCMService {
  late FirebaseMessaging _messaging;
  final ApiService _apiService;

  /// flutter_local_notifications 플러그인 (포그라운드 알림 표시용)
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  /// 글로벌 네비게이터 키 (알림 탭 시 화면 전환용)
  GlobalKey<NavigatorState>? _navigatorKey;

  /// 앱 종료 상태에서 알림 탭으로 열었을 때 보류 메시지
  RemoteMessage? _pendingMessage;

  /// 스트림 구독 (dispose용)
  StreamSubscription<String>? _tokenRefreshSub;
  StreamSubscription<RemoteMessage>? _foregroundMessageSub;
  StreamSubscription<RemoteMessage>? _messageOpenedAppSub;

  String? _currentToken;
  String? get currentToken => _currentToken;

  /// 알림 수신 콜백 (NotificationProvider에서 설정)
  void Function(RemoteMessage message)? onMessageReceived;

  FCMService(this._apiService);

  /// 네비게이터 키 설정 (auth_wrapper에서 로그인 후 호출)
  /// 보류된 메시지가 있으면 즉시 네비게이션 처리
  void setNavigatorKey(GlobalKey<NavigatorState> key) {
    _navigatorKey = key;
    if (_pendingMessage != null) {
      // 위젯 트리 빌드 완료 후 네비게이션 실행
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _handleMessageOpenedApp(_pendingMessage!);
        _pendingMessage = null;
      });
    }
  }

  /// FCM 초기화 (앱 시작 시 호출)
  Future<void> initialize() async {
    try {
      // Firebase 초기화
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );

      // Firebase 초기화 후 인스턴스 획득
      _messaging = FirebaseMessaging.instance;

      // 백그라운드 메시지 핸들러 등록 (웹에서는 미지원)
      if (!kIsWeb) {
        FirebaseMessaging.onBackgroundMessage(
          _firebaseMessagingBackgroundHandler,
        );
      }

      // 로컬 알림 초기화 + Android 채널 생성
      await _initLocalNotifications();

      // 알림 권한 요청
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional) {
        debugPrint('[FCM] 알림 권한 허용됨');

        // FCM 토큰 발급 및 백엔드 등록
        await _registerToken();

        // 토큰 갱신 리스너
        _tokenRefreshSub = _messaging.onTokenRefresh.listen((newToken) {
          debugPrint('[FCM] 토큰 갱신됨');
          _registerTokenWithValue(newToken);
        });

        // 포그라운드 메시지 수신 리스너
        _foregroundMessageSub = FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

        // 알림 탭으로 앱 열었을 때 처리 (백그라운드 → 포그라운드)
        _messageOpenedAppSub = FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);

        // 앱이 종료 상태에서 알림 탭으로 열었을 때
        final initialMessage = await _messaging.getInitialMessage();
        if (initialMessage != null) {
          if (_navigatorKey?.currentState != null) {
            _handleMessageOpenedApp(initialMessage);
          } else {
            // navigatorKey가 아직 설정되지 않음 → 보류
            _pendingMessage = initialMessage;
          }
        }
      } else {
        debugPrint('[FCM] 알림 권한 거부됨');
      }
    } catch (e) {
      debugPrint('[FCM] 초기화 실패: $e');
    }
  }

  /// 로컬 알림 초기화 (Android 채널 생성 포함)
  /// importance: high → 헤드업(팝업) 알림 + 소리 + 진동
  Future<void> _initLocalNotifications() async {
    // Android 알림 채널 생성 (importance: high → 헤드업 알림)
    const androidChannel = AndroidNotificationChannel(
      'aix_boost_notifications',
      'HeyBro 알림',
      description: '공지사항 및 마감 임박 알림',
      importance: Importance.high,
      enableVibration: true,
      playSound: true,
      showBadge: true,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);

    // 플러그인 초기화 (앱 아이콘을 알림 아이콘으로 사용)
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);

    await _localNotifications.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: _onLocalNotificationTapped,
    );
  }

  /// 로컬 알림 탭 시 처리 (포그라운드에서 표시한 알림을 탭했을 때)
  void _onLocalNotificationTapped(NotificationResponse response) {
    final noticeId = response.payload;
    if (noticeId != null && noticeId.isNotEmpty) {
      _navigateToNoticeDetail(noticeId);
    }
  }

  /// 포그라운드 메시지 수신 처리
  /// FCM은 포그라운드에서 알림을 자동 표시하지 않으므로,
  /// flutter_local_notifications로 직접 표시합니다.
  void _handleForegroundMessage(RemoteMessage message) {
    debugPrint('[FCM] 포그라운드 메시지: ${message.notification?.title}');

    // NotificationProvider 콜백 (알림 목록에 추가)
    onMessageReceived?.call(message);

    // 로컬 알림으로 직접 표시 (헤드업 알림 + 소리 + 진동)
    final notification = message.notification;
    if (notification != null) {
      _localNotifications.show(
        id: notification.hashCode,
        title: notification.title,
        body: notification.body,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'aix_boost_notifications',
            'HeyBro 알림',
            importance: Importance.high,
            priority: Priority.high,
          ),
        ),
        // notice_id를 payload로 전달 → 탭 시 상세 화면 이동
        payload: message.data['notice_id'],
      );
    }
  }

  /// 알림 탭으로 앱 열었을 때 처리 (FCM 알림 클릭)
  /// 백그라운드/종료 상태에서 알림을 탭하면 호출됩니다.
  void _handleMessageOpenedApp(RemoteMessage message) {
    debugPrint('[FCM] 알림 탭으로 앱 열림: ${message.data}');
    final noticeId = message.data['notice_id'];
    if (noticeId != null && noticeId.toString().isNotEmpty) {
      _navigateToNoticeDetail(noticeId.toString(), originalMessage: message);
    }
  }

  /// 공지 상세 화면으로 이동 (실패 시 pendingMessage 보존)
  void _navigateToNoticeDetail(String noticeId, {RemoteMessage? originalMessage}) {
    final navigator = _navigatorKey?.currentState;
    if (navigator != null) {
      navigator.push(
        MaterialPageRoute(
          builder: (_) => NoticeDetailScreen(noticeId: noticeId),
        ),
      );
    } else {
      // 네비게이터가 아직 준비되지 않은 경우 보류 메시지로 저장
      if (originalMessage != null) {
        _pendingMessage = originalMessage;
      }
      debugPrint('[FCM] 네비게이터 없음, 보류 저장 (noticeId: $noticeId)');
    }
  }

  /// FCM 토큰 발급 및 백엔드 등록
  Future<void> _registerToken() async {
    try {
      // 웹에서는 VAPID 키가 필요할 수 있음
      final token = await _messaging.getToken();
      if (token != null) {
        await _registerTokenWithValue(token);
      }
    } catch (e) {
      debugPrint('[FCM] 토큰 발급 실패: $e');
    }
  }

  /// 특정 토큰을 백엔드에 등록
  Future<void> _registerTokenWithValue(String token) async {
    _currentToken = token;
    debugPrint('[FCM] 토큰: ${token.substring(0, 20)}...');

    try {
      // 디바이스 타입 판별
      final deviceType = _getDeviceType();

      await _apiService.registerFCMToken(
        token: token,
        deviceType: deviceType,
      );
      debugPrint('[FCM] 백엔드 토큰 등록 완료 ($deviceType)');
    } catch (e) {
      debugPrint('[FCM] 백엔드 토큰 등록 실패: $e');
    }
  }

  /// 디바이스 타입 판별
  String _getDeviceType() {
    if (kIsWeb) return 'web';
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'android';
      case TargetPlatform.iOS:
        return 'ios';
      default:
        return 'web';
    }
  }

  /// 토큰 해제 (로그아웃 시 호출)
  Future<void> unregisterToken() async {
    if (_currentToken == null) return;

    try {
      await _apiService.unregisterFCMToken(token: _currentToken!);
      debugPrint('[FCM] 토큰 해제 완료');
    } catch (e) {
      debugPrint('[FCM] 토큰 해제 실패: $e');
    }

    _currentToken = null;
  }

  /// 리소스 정리 (스트림 구독 해제, 콜백 초기화)
  void dispose() {
    _tokenRefreshSub?.cancel();
    _foregroundMessageSub?.cancel();
    _messageOpenedAppSub?.cancel();
    onMessageReceived = null;
  }
}
