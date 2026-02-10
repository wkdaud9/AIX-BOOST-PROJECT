import 'dart:math';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'auth_wrapper.dart';

/// 스플래시 화면 - 핸드사인 애니메이션 (Hey! → Bro! → HeyBro)
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  /// 현재 애니메이션 단계 (0: 대기, 1: 손흔들기, 2: 주먹인사, 3: 하이파이브)
  int _phase = 0;

  // Phase 1: 손 흔들기 (👋)
  late AnimationController _waveController;
  late Animation<double> _waveFade;
  late Animation<double> _waveRotation;
  late Animation<double> _heyFade;

  // Phase 2: 주먹 인사 (🤜🤛)
  late AnimationController _fistController;
  late Animation<double> _fistFade;
  late Animation<double> _leftFistSlide;
  late Animation<double> _rightFistSlide;
  late Animation<double> _fistBump;
  late Animation<double> _broFade;

  // Phase 3: 하이파이브 (🖐🖐) + HeyBro 등장
  late AnimationController _highFiveController;
  late Animation<double> _highFiveFade;
  late Animation<double> _leftHandSlide;
  late Animation<double> _rightHandSlide;
  late Animation<double> _logoScale;
  late Animation<double> _logoFade;
  late Animation<double> _sloganFade;

  @override
  void initState() {
    super.initState();
    _initPhase1();
    _initPhase2();
    _initPhase3();
    _startAnimations();
  }

  /// Phase 1 초기화: 손 흔들기
  void _initPhase1() {
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _waveFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _waveController,
        curve: const Interval(0, 0.3, curve: Curves.easeOut),
      ),
    );

    // 손 흔들기 회전 (좌우 반복)
    _waveRotation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0, end: 0.15), weight: 15),
      TweenSequenceItem(tween: Tween(begin: 0.15, end: -0.15), weight: 20),
      TweenSequenceItem(tween: Tween(begin: -0.15, end: 0.12), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 0.12, end: -0.12), weight: 20),
      TweenSequenceItem(tween: Tween(begin: -0.12, end: 0), weight: 25),
    ]).animate(CurvedAnimation(
      parent: _waveController,
      curve: const Interval(0.15, 0.85, curve: Curves.easeInOut),
    ));

    _heyFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _waveController,
        curve: const Interval(0.25, 0.55, curve: Curves.easeOut),
      ),
    );
  }

  /// Phase 2 초기화: 주먹 인사
  void _initPhase2() {
    _fistController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _fistFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _fistController,
        curve: const Interval(0, 0.25, curve: Curves.easeOut),
      ),
    );

    // 양 주먹이 바깥에서 안으로 모였다가 부딪히는 효과
    _leftFistSlide = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: -80, end: -8), weight: 40),
      TweenSequenceItem(tween: Tween(begin: -8, end: -16), weight: 20),
      TweenSequenceItem(tween: Tween(begin: -16, end: -8), weight: 40),
    ]).animate(CurvedAnimation(
      parent: _fistController,
      curve: const Interval(0, 0.7, curve: Curves.easeOut),
    ));

    _rightFistSlide = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 80, end: 8), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 8, end: 16), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 16, end: 8), weight: 40),
    ]).animate(CurvedAnimation(
      parent: _fistController,
      curve: const Interval(0, 0.7, curve: Curves.easeOut),
    ));

    // 부딪힐 때 스케일 효과
    _fistBump = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1, end: 1), weight: 35),
      TweenSequenceItem(tween: Tween(begin: 1, end: 1.15), weight: 10),
      TweenSequenceItem(tween: Tween(begin: 1.15, end: 1), weight: 15),
      TweenSequenceItem(tween: Tween(begin: 1, end: 1), weight: 40),
    ]).animate(CurvedAnimation(
      parent: _fistController,
      curve: Curves.easeInOut,
    ));

    _broFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _fistController,
        curve: const Interval(0.35, 0.6, curve: Curves.easeOut),
      ),
    );
  }

  /// Phase 3 초기화: 하이파이브 + HeyBro 로고
  void _initPhase3() {
    _highFiveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    _highFiveFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _highFiveController,
        curve: const Interval(0, 0.15, curve: Curves.easeOut),
      ),
    );

    // 양손이 안으로 모였다가 → 부딪힘 → 벌어짐
    _leftHandSlide = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: -100, end: 0), weight: 25),
      TweenSequenceItem(tween: Tween(begin: 0, end: 0), weight: 15),
      TweenSequenceItem(tween: Tween(begin: 0, end: -120), weight: 60),
    ]).animate(CurvedAnimation(
      parent: _highFiveController,
      curve: const Interval(0, 0.7, curve: Curves.easeInOut),
    ));

    _rightHandSlide = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 100, end: 0), weight: 25),
      TweenSequenceItem(tween: Tween(begin: 0, end: 0), weight: 15),
      TweenSequenceItem(tween: Tween(begin: 0, end: 120), weight: 60),
    ]).animate(CurvedAnimation(
      parent: _highFiveController,
      curve: const Interval(0, 0.7, curve: Curves.easeInOut),
    ));

    // 손이 벌어질 때 로고 등장
    _logoScale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0, end: 0), weight: 35),
      TweenSequenceItem(
        tween: Tween(begin: 0, end: 1.1),
        weight: 30,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.1, end: 1),
        weight: 35,
      ),
    ]).animate(CurvedAnimation(
      parent: _highFiveController,
      curve: const Interval(0, 0.8, curve: Curves.easeOut),
    ));

    _logoFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _highFiveController,
        curve: const Interval(0.35, 0.55, curve: Curves.easeOut),
      ),
    );

    _sloganFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _highFiveController,
        curve: const Interval(0.6, 0.85, curve: Curves.easeOut),
      ),
    );
  }

  /// 애니메이션 시퀀스 실행
  Future<void> _startAnimations() async {
    await Future.delayed(const Duration(milliseconds: 200));

    // Phase 1: 손 흔들기 (👋 Hey!)
    if (!mounted) return;
    setState(() => _phase = 1);
    _waveController.forward();
    await Future.delayed(const Duration(milliseconds: 900));

    // Phase 2: 주먹 인사 (🤜🤛 Bro!)
    if (!mounted) return;
    setState(() => _phase = 2);
    _fistController.forward();
    await Future.delayed(const Duration(milliseconds: 900));

    // Phase 3: 하이파이브 → HeyBro 등장
    if (!mounted) return;
    setState(() => _phase = 3);
    _highFiveController.forward();
    await Future.delayed(const Duration(milliseconds: 1600));

    // 다음 화면으로 이동
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
    _waveController.dispose();
    _fistController.dispose();
    _highFiveController.dispose();
    super.dispose();
  }

  /// 이모지를 흰색 실루엣으로 변환하는 헬퍼
  Widget _whiteEmoji(String emoji, double size) {
    return ColorFiltered(
      colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
      child: Text(
        emoji,
        style: TextStyle(fontSize: size),
      ),
    );
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
                ? [const Color(0xFF060E1F), const Color(0xFF0F2854)]
                : [AppTheme.primaryColor, AppTheme.primaryDark],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const Spacer(flex: 2),

              // 핸드사인 애니메이션 영역
              SizedBox(
                height: 280,
                child: _buildCurrentPhase(),
              ),

              const Spacer(flex: 1),

              // 하단 슬로건 (Phase 3에서 등장)
              if (_phase == 3)
                AnimatedBuilder(
                  animation: _highFiveController,
                  builder: (context, child) {
                    return Opacity(
                      opacity: _sloganFade.value,
                      child: Column(
                        children: [
                          Text(
                            'AI가 추천하는 대학 생활 정보 도우미',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.white.withOpacity(0.7),
                              fontWeight: FontWeight.w400,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    );
                  },
                ),

              const SizedBox(height: 60),
            ],
          ),
        ),
      ),
    );
  }

  /// 현재 Phase에 맞는 위젯 반환
  Widget _buildCurrentPhase() {
    switch (_phase) {
      case 1:
        return _buildWavePhase();
      case 2:
        return _buildFistBumpPhase();
      case 3:
        return _buildHighFivePhase();
      default:
        return const SizedBox.shrink();
    }
  }

  /// Phase 1: 손 흔들기 👋 + "Hey!"
  Widget _buildWavePhase() {
    return AnimatedBuilder(
      animation: _waveController,
      builder: (context, child) {
        return Opacity(
          opacity: _waveFade.value,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 흔들리는 손 (흰색)
              Transform.rotate(
                angle: _waveRotation.value * pi,
                child: _whiteEmoji('👋', 80),
              ),

              const SizedBox(height: 24),

              // "Hey!" 텍스트
              Opacity(
                opacity: _heyFade.value,
                child: const Text(
                  'Hey!',
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Phase 2: 주먹 인사 🤜🤛 + "Bro!"
  Widget _buildFistBumpPhase() {
    return AnimatedBuilder(
      animation: _fistController,
      builder: (context, child) {
        return Opacity(
          opacity: _fistFade.value,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 양 주먹 (흰색)
              Transform.scale(
                scale: _fistBump.value,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Transform.translate(
                      offset: Offset(_leftFistSlide.value, 0),
                      child: _whiteEmoji('🤜', 64),
                    ),
                    Transform.translate(
                      offset: Offset(_rightFistSlide.value, 0),
                      child: _whiteEmoji('🤛', 64),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // "Bro!" 텍스트
              Opacity(
                opacity: _broFade.value,
                child: const Text(
                  'Bro!',
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Phase 3: 하이파이브 🖐🖐 → 벌어지면서 HeyBro 로고 등장
  Widget _buildHighFivePhase() {
    return AnimatedBuilder(
      animation: _highFiveController,
      builder: (context, child) {
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 하이파이브 + 로고 영역
            SizedBox(
              height: 140,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // 왼손 (흰색)
                  Opacity(
                    opacity: _highFiveFade.value,
                    child: Transform.translate(
                      offset: Offset(_leftHandSlide.value, 0),
                      child: _whiteEmoji('🤚', 64),
                    ),
                  ),

                  // 오른손 (흰색)
                  Opacity(
                    opacity: _highFiveFade.value,
                    child: Transform.translate(
                      offset: Offset(_rightHandSlide.value, 0),
                      child: _whiteEmoji('🖐', 64),
                    ),
                  ),

                  // HeyBro 로고 (손이 벌어질 때 등장)
                  Opacity(
                    opacity: _logoFade.value,
                    child: Transform.scale(
                      scale: _logoScale.value,
                      child: Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(AppRadius.xl),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 20,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.all(8),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(AppRadius.lg),
                          child: Image.asset(
                            'assets/images/icon_main.png',
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // "HeyBro" 텍스트
            Opacity(
              opacity: _logoFade.value,
              child: Transform.scale(
                scale: _logoScale.value,
                child: const Text(
                  'HeyBro',
                  style: TextStyle(
                    fontSize: 42,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: -1.0,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
