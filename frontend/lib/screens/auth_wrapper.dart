import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/fcm_service.dart';
import '../providers/notification_provider.dart';
import 'home_screen.dart';
import 'login_screen.dart';

/// 인증 상태 래퍼
/// 앱 시작 시 로그인 상태를 확인하고 적절한 화면으로 이동합니다.
/// AuthService의 상태 변경을 자동으로 감지하여 화면을 전환합니다.
/// 로그인 시 FCM 푸시 알림을 초기화합니다.
class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _fcmInitialized = false;

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthService>(
      builder: (context, authService, child) {
        if (authService.isAuthenticated) {
          // 로그인 상태: FCM 초기화
          _initFCMIfNeeded(context);
          return const HomeScreen();
        } else {
          // 로그아웃 상태: FCM 초기화 플래그 리셋
          _fcmInitialized = false;
          return const LoginScreen();
        }
      },
    );
  }

  /// FCM 초기화 (로그인 후 1회만 실행)
  void _initFCMIfNeeded(BuildContext context) {
    if (_fcmInitialized) return;
    _fcmInitialized = true;

    // build 완료 후 비동기로 FCM 초기화
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final fcmService = context.read<FCMService>();
      final notificationProvider = context.read<NotificationProvider>();

      // 포그라운드 메시지 수신 시 NotificationProvider에 알림 추가
      fcmService.onMessageReceived = (message) {
        final type = message.data['type'] ?? 'new_notice';
        final noticeId = message.data['notice_id'] ?? '';

        if (type == 'deadline') {
          // 마감 임박 알림
          final daysUntil = int.tryParse(message.data['days_until'] ?? '') ?? 0;
          notificationProvider.createDeadlineNotification(
            noticeId: noticeId,
            noticeTitle: message.notification?.title ?? '마감 임박',
            deadline: DateTime.now().add(Duration(days: daysUntil)),
            reminderDays: daysUntil,
          );
        } else {
          // 새 공지사항 알림
          notificationProvider.createNewNoticeNotification(
            noticeId: noticeId,
            noticeTitle: message.notification?.title ?? '새 공지사항',
            category: message.data['category'] ?? '',
          );
        }
      };

      // FCM 초기화 (Firebase init + 토큰 등록 + 리스너 설정)
      fcmService.initialize();

      // 백엔드에서 알림 내역 조회
      notificationProvider.fetchFromBackend();
    });
  }
}
