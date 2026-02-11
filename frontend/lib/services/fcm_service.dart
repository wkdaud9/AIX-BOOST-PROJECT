import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../firebase_options.dart';
import 'api_service.dart';

/// Firebase 백그라운드 메시지 핸들러 (top-level 함수여야 함)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  debugPrint('[FCM] 백그라운드 메시지 수신: ${message.notification?.title}');
}

/// FCM 푸시 알림 서비스
/// Firebase Cloud Messaging 초기화, 토큰 관리, 알림 수신 처리를 담당합니다.
class FCMService {
  late FirebaseMessaging _messaging;
  final ApiService _apiService;

  String? _currentToken;
  String? get currentToken => _currentToken;

  /// 알림 수신 콜백 (NotificationProvider에서 설정)
  void Function(RemoteMessage message)? onMessageReceived;

  FCMService(this._apiService);

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
        _messaging.onTokenRefresh.listen((newToken) {
          debugPrint('[FCM] 토큰 갱신됨');
          _registerTokenWithValue(newToken);
        });

        // 포그라운드 메시지 수신 리스너
        FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

        // 알림 탭으로 앱 열었을 때 처리
        FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);

        // 앱이 종료 상태에서 알림 탭으로 열었을 때
        final initialMessage = await _messaging.getInitialMessage();
        if (initialMessage != null) {
          _handleMessageOpenedApp(initialMessage);
        }
      } else {
        debugPrint('[FCM] 알림 권한 거부됨');
      }
    } catch (e) {
      debugPrint('[FCM] 초기화 실패: $e');
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

  /// 포그라운드 메시지 수신 처리
  void _handleForegroundMessage(RemoteMessage message) {
    debugPrint('[FCM] 포그라운드 메시지: ${message.notification?.title}');

    // 콜백이 등록되어 있으면 호출 (NotificationProvider에서 로컬 알림 추가)
    onMessageReceived?.call(message);
  }

  /// 알림 탭으로 앱 열었을 때 처리
  void _handleMessageOpenedApp(RemoteMessage message) {
    debugPrint('[FCM] 알림 탭으로 앱 열림: ${message.data}');
    // 추후 공지 상세 화면 이동 등 처리 가능
    // final noticeId = message.data['notice_id'];
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
}
