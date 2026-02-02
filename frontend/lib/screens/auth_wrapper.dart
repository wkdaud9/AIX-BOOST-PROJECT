import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import 'home_screen.dart';
import 'login_screen.dart';

/// 인증 상태 래퍼
/// 앱 시작 시 로그인 상태를 확인하고 적절한 화면으로 이동합니다.
/// AuthService의 상태 변경을 자동으로 감지하여 화면을 전환합니다.
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthService>(
      builder: (context, authService, child) {
        // 로그인 상태에 따라 화면 분기
        if (authService.isAuthenticated) {
          return const HomeScreen();
        } else {
          return const LoginScreen();
        }
      },
    );
  }
}
