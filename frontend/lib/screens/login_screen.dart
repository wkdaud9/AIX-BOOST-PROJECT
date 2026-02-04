import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/auth_service.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/loading_button.dart';
import '../widgets/form_section.dart';
import '../theme/app_theme.dart';
import 'signup_screen.dart';

/// 로그인 화면
/// 이메일과 비밀번호를 입력받아 Supabase Auth로 인증합니다.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  /// 폼 키 (유효성 검사용)
  final _formKey = GlobalKey<FormState>();

  /// 이메일 입력 컨트롤러
  final _emailController = TextEditingController();

  /// 비밀번호 입력 컨트롤러
  final _passwordController = TextEditingController();

  /// 로딩 상태
  bool _isLoading = false;

  /// 폼 에러 메시지
  String? _formError;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  /// 로그인 처리
  /// 폼 유효성 검사 후 AuthService.signIn 호출
  Future<void> _handleLogin() async {
    // 1. 폼 유효성 검사
    if (!_formKey.currentState!.validate()) {
      setState(() {
        _formError = '이메일과 비밀번호를 확인해주세요.';
      });
      return;
    }

    // 2. 로딩 상태 시작
    setState(() {
      _isLoading = true;
      _formError = null;
    });

    try {
      // 3. AuthService.signIn 호출
      await context.read<AuthService>().signIn(
        _emailController.text.trim(),
        _passwordController.text,
      );

      // 4. 성공: AuthWrapper가 자동으로 HomeScreen으로 이동

    } on AuthException catch (e) {
      // 5. Supabase 인증 에러 처리
      if (!mounted) return;

      String errorMessage = '로그인에 실패했습니다.';
      if (e.message.contains('Invalid login credentials') ||
          e.message.contains('Invalid email or password')) {
        errorMessage = '이메일 또는 비밀번호가 올바르지 않습니다.';
      } else if (e.message.contains('Email not confirmed')) {
        errorMessage = '이메일 인증이 필요합니다.';
      }

      setState(() {
        _formError = errorMessage;
      });
    } catch (e) {
      // 6. 기타 에러
      if (!mounted) return;

      setState(() {
        _formError = '네트워크 오류가 발생했습니다.';
      });
    } finally {
      // 7. 로딩 상태 종료
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// 이메일 유효성 검사
  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return '이메일을 입력해주세요.';
    }

    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(value)) {
      return '올바른 이메일 주소를 입력해주세요.';
    }

    return null;
  }

  /// 비밀번호 유효성 검사
  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return '비밀번호를 입력해주세요.';
    }

    if (value.length < 6) {
      return '비밀번호는 6자 이상이어야 합니다.';
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 상단 여백
                const SizedBox(height: AppSpacing.xxl + AppSpacing.lg),

                // 로고/타이틀 영역
                Icon(
                  Icons.school,
                  size: 80,
                  color: AppTheme.primaryColor,
                ),
                const SizedBox(height: AppSpacing.lg),

                Text(
                  'AIX-Boost',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryColor,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),

                Text(
                  '군산대학교 맞춤형 공지 큐레이션',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                ),

                const SizedBox(height: AppSpacing.xxl + AppSpacing.md),

                // 로그인 정보 박스
                FormSection(
                  errorMessage: _formError,
                  children: [
                    CustomTextField(
                      controller: _emailController,
                      labelText: '이메일',
                      keyboardType: TextInputType.emailAddress,
                      validator: _validateEmail,
                      prefixIcon: const Icon(Icons.email_outlined),
                      onEditingComplete: () => FocusScope.of(context).nextFocus(),
                    ),
                    CustomTextField(
                      controller: _passwordController,
                      labelText: '비밀번호',
                      isPassword: true,
                      validator: _validatePassword,
                      prefixIcon: const Icon(Icons.lock_outlined),
                      onEditingComplete: _handleLogin,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),

                // 로그인 버튼
                LoadingButton(
                  onPressed: _handleLogin,
                  text: '로그인',
                  isLoading: _isLoading,
                  width: double.infinity,
                  height: 52,
                ),
                const SizedBox(height: AppSpacing.md),

                // 회원가입 링크
                TextButton(
                  onPressed: _isLoading
                      ? null
                      : () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => const SignUpScreen(),
                            ),
                          );
                        },
                  child: const Text('계정이 없으신가요? 회원가입'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
