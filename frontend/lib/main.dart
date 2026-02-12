import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'screens/splash_screen.dart';
import 'theme/app_theme.dart';
import 'providers/notice_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/notification_provider.dart';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'services/auth_service.dart';
import 'services/api_service.dart';
import 'services/fcm_service.dart';
import 'env_config.dart';

/// 글로벌 네비게이터 키 (FCM 알림 탭 시 화면 전환용)
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Supabase 초기화 (--dart-define으로 주입된 환경변수 사용)
  await Supabase.initialize(
    url: EnvConfig.supabaseUrl,
    anonKey: EnvConfig.supabaseAnonKey,
  );

  runApp(const AIXBoostApp());
}

/// 웹에서 마우스 드래그로도 스크롤 가능하도록 하는 커스텀 ScrollBehavior
class AppScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
      };
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
        // 4. SettingsProvider 생성 (테마, 알림 설정 관리, ApiService 의존)
        ChangeNotifierProxyProvider<ApiService, SettingsProvider>(
          create: (_) => SettingsProvider()..initialize(),
          update: (_, apiService, previous) {
            previous?.updateApiService(apiService);
            return previous ?? (SettingsProvider()
              ..updateApiService(apiService)
              ..initialize());
          },
        ),
        // 5. NotificationProvider 생성 (ApiService 의존, 알림 목록 관리)
        ChangeNotifierProxyProvider<ApiService, NotificationProvider>(
          create: (_) => NotificationProvider()..initialize(),
          update: (_, apiService, previous) {
            previous?.updateApiService(apiService);
            return previous ?? (NotificationProvider()
              ..updateApiService(apiService)
              ..initialize());
          },
        ),
        // 6. FCMService 생성 (ApiService 의존, 푸시 알림 처리)
        ProxyProvider<ApiService, FCMService>(
          create: (context) => FCMService(context.read<ApiService>()),
          update: (_, apiService, previous) =>
              previous ?? FCMService(apiService),
        ),
      ],
      child: Consumer<SettingsProvider>(
        builder: (context, settings, child) {
          return MaterialApp(
            title: 'Hey bro',
            navigatorKey: navigatorKey,
            debugShowCheckedModeBanner: false,
            scrollBehavior: AppScrollBehavior(),
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
