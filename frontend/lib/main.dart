import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'screens/splash_screen.dart';
import 'theme/app_theme.dart';
import 'providers/notice_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/notification_provider.dart';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'services/auth_service.dart';
import 'services/api_service.dart';

Future<void> main() async {
  // .env 파일 로드
  await dotenv.load(fileName: ".env");

  // Supabase 초기화
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL'] ?? '',
    anonKey: dotenv.env['SUPABASE_ANON_KEY'] ?? '',
  );

  runApp(const AIXBoostApp());
}

class AIXBoostApp extends StatelessWidget {
  const AIXBoostApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // 1. ApiService 생성 (모든 통신의 기초)
        Provider<ApiService>(
          create: (_) => ApiService(),
        ),
        // 2. AuthService 생성 (ApiService 의존)
        ChangeNotifierProxyProvider<ApiService, AuthService>(
          create: (context) => AuthService(context.read<ApiService>()),
          update: (_, apiService, previous) => previous ?? AuthService(apiService),
        ),
        // 3. NoticeProvider 생성 (ApiService 의존)
        ChangeNotifierProxyProvider<ApiService, NoticeProvider>(
          create: (context) => NoticeProvider(apiService: context.read<ApiService>()),
          update: (_, apiService, previous) =>
              previous ?? NoticeProvider(apiService: apiService),
        ),
        // 4. SettingsProvider 생성 (테마, 알림 설정 관리)
        ChangeNotifierProvider<SettingsProvider>(
          create: (_) => SettingsProvider()..initialize(),
        ),
        // 5. NotificationProvider 생성 (알림 목록 관리)
        ChangeNotifierProvider<NotificationProvider>(
          create: (_) => NotificationProvider()..initialize(),
        ),
      ],
      child: Consumer<SettingsProvider>(
        builder: (context, settings, child) {
          return MaterialApp(
            title: 'Hey bro',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: settings.themeMode,
            home: const SplashScreen(),
          );
        },
      ),
    );
  }
}
