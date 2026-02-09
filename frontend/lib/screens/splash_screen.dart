import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'auth_wrapper.dart';

/// 스플래시 화면 - 앱 브랜딩 + 슬로건 + 로딩 애니메이션
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _titleController;
  late AnimationController _sloganController;
  late Animation<double> _titleFade;
  late Animation<Offset> _titleSlide;
  late Animation<double> _sloganFade;
  late Animation<double> _loadingFade;

  @override
  void initState() {
    super.initState();

    // 앱 이름 + 아이콘 애니메이션 (페이드 + 슬라이드)
    _titleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _titleFade = CurvedAnimation(
      parent: _titleController,
      curve: Curves.easeOut,
    );
    _titleSlide = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _titleController,
      curve: Curves.easeOut,
    ));

    // 슬로건 + 로딩 인디케이터 애니메이션
    _sloganController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _sloganFade = CurvedAnimation(
      parent: _sloganController,
      curve: Curves.easeIn,
    );
    _loadingFade = CurvedAnimation(
      parent: _sloganController,
      curve: const Interval(0.3, 1.0, curve: Curves.easeIn),
    );

    _startAnimations();
  }

  /// 애니메이션 시퀀스 시작
  Future<void> _startAnimations() async {
    // 타이틀 페이드인
    _titleController.forward();

    // 400ms 후 슬로건 페이드인
    await Future.delayed(const Duration(milliseconds: 400));
    if (mounted) _sloganController.forward();

    // 총 2초 후 다음 화면으로 이동
    await Future.delayed(const Duration(milliseconds: 1600));
    if (mounted) _navigateToApp();
  }

  /// AuthWrapper로 페이드 전환
  void _navigateToApp() {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const AuthWrapper(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _sloganController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [const Color(0xFF1A1A2E), const Color(0xFF2D2B55)]
                : [AppTheme.primaryColor, AppTheme.primaryDark],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const Spacer(flex: 3),

              // 앱 아이콘
              SlideTransition(
                position: _titleSlide,
                child: FadeTransition(
                  opacity: _titleFade,
                  child: Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(AppRadius.xl),
                    ),
                    child: const Icon(
                      Icons.school_rounded,
                      size: 48,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 28),

              // 앱 이름
              SlideTransition(
                position: _titleSlide,
                child: FadeTransition(
                  opacity: _titleFade,
                  child: const Text(
                    'Hey bro',
                    style: TextStyle(
                      fontSize: 42,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: -1.0,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 14),

              // 슬로건
              FadeTransition(
                opacity: _sloganFade,
                child: Text(
                  'AI가 추천하는 대학 생활 정보 도우미',
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.white.withOpacity(0.8),
                    fontWeight: FontWeight.w400,
                    letterSpacing: 0.2,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),

              const SizedBox(height: 8),

              // 부가 설명
              FadeTransition(
                opacity: _sloganFade,
                child: Text(
                  '공지, 일정, 기회를 한 번에 관리하는\n스마트 캠퍼스 앱',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withOpacity(0.55),
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),

              const Spacer(flex: 2),

              // 로딩 인디케이터
              FadeTransition(
                opacity: _loadingFade,
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Colors.white.withOpacity(0.7),
                  ),
                ),
              ),

              const SizedBox(height: 48),
            ],
          ),
        ),
      ),
    );
  }
}
