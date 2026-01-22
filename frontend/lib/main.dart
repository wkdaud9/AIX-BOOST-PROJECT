import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'screens/home_screen.dart';
import 'theme/app_theme.dart';
import 'providers/notice_provider.dart';

Future<void> main() async {
  // .env 파일 로드
  await dotenv.load(fileName: ".env");

  runApp(const AIXBoostApp());
}

class AIXBoostApp extends StatelessWidget {
  const AIXBoostApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => NoticeProvider()),
      ],
      child: MaterialApp(
        title: 'AIX-Boost',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        home: const HomeScreen(),
      ),
    );
  }
}
