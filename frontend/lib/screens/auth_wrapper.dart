import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/fcm_service.dart';
import '../providers/notice_provider.dart';
import '../providers/notification_provider.dart';
import '../theme/app_theme.dart';
import 'home_screen.dart';
import 'login_screen.dart';
import 'reset_password_screen.dart';

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
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthService>(
      builder: (context, authService, child) {
        if (authService.isAuthenticated) {
          // 비밀번호 재설정 세션인 경우 재설정 화면으로 이동
          if (authService.isPasswordRecovery) {
            return const ResetPasswordScreen();
          }
          // 로그인 직후 로딩 화면 표시
          if (!_fcmInitialized) {
            _startInitialization(context);
            return _buildLoadingScreen(context);
          }
          if (_isLoading) {
            return _buildLoadingScreen(context);
          }
          return const HomeScreen();
        } else {
          // 로그아웃 상태: 플래그 리셋
          _fcmInitialized = false;
          _isLoading = false;
          return const LoginScreen();
        }
      },
    );
  }

  /// 로그인 후 초기화 시작 (FCM + 알림 로드)
  void _startInitialization(BuildContext context) {
    _fcmInitialized = true;
    _isLoading = true;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
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

      // AI 추천 사전 로드 (MyBro 탭 진입 시 즉시 표시를 위해)
      final noticeProvider = context.read<NoticeProvider>();
      noticeProvider.fetchRecommendedNotices();
      noticeProvider.fetchDepartmentPopularNotices();

      // 최소 로딩 시간 보장 (빈 화면 방지)
      await Future.delayed(const Duration(milliseconds: 1200));

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    });
  }

  /// 로딩 화면 UI
  Widget _buildLoadingScreen(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? [const Color(0xFF060E1F), const Color(0xFF0F2854)]
                : [AppTheme.primaryColor, AppTheme.primaryDark],
          ),
        ),
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 앱 로고 텍스트
              Text(
                'HeyBro',
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: -1.0,
                ),
              ),
              SizedBox(height: 24),
              // 로딩 인디케이터
              SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white70),
                ),
              ),
              SizedBox(height: 16),
              // 안내 텍스트
              Text(
                '공지사항을 불러오는 중...',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white60,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
