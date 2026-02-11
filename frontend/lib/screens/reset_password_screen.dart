import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/auth_service.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/loading_button.dart';
import '../widgets/form_section.dart';
import '../theme/app_theme.dart';

/// 비밀번호 재설정 화면
/// Supabase recovery 세션에서 새 비밀번호를 설정합니다.
class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  /// 폼 키 (유효성 검사용)
  final _formKey = GlobalKey<FormState>();

  /// 새 비밀번호 입력 컨트롤러
  final _passwordController = TextEditingController();

  /// 비밀번호 확인 입력 컨트롤러
  final _confirmController = TextEditingController();

  /// 로딩 상태
  bool _isLoading = false;

  /// 변경 완료 상태
  bool _isChanged = false;

  /// 폼 에러 메시지
  String? _formError;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  /// 비밀번호 유효성 검사 (최소 8자 + 특수문자 1개 이상)
  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return '새 비밀번호를 입력해주세요.';
    }
    if (value.length < 8) {
      return '8자 이상 입력해주세요.';
    }
    final specialCharRegex = RegExp(r'[!@#$%^&*(),.?":{}|<>]');
    if (!specialCharRegex.hasMatch(value)) {
      return '특수문자를 1개 이상 포함해주세요.';
    }
    return null;
  }

  /// 비밀번호 확인 유효성 검사
  String? _validateConfirm(String? value) {
    if (value == null || value.isEmpty) {
      return '비밀번호를 다시 입력해주세요.';
    }
    if (value != _passwordController.text) {
      return '비밀번호가 일치하지 않습니다.';
    }
    return null;
  }

  /// 비밀번호 변경 처리
  Future<void> _handleChangePassword() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _formError = null;
    });

    try {
      await context.read<AuthService>().updatePassword(
            _passwordController.text,
          );

      if (!mounted) return;
      setState(() {
        _isChanged = true;
      });
    } on AuthException catch (e) {
      if (!mounted) return;
      debugPrint('[비밀번호 변경 에러] ${e.message}');

      String errorMessage = '비밀번호 변경에 실패했습니다.';
      if (e.message.contains('same password')) {
        errorMessage = '이전과 동일한 비밀번호는 사용할 수 없습니다.';
      }

      setState(() {
        _formError = errorMessage;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _formError = '네트워크 오류가 발생했습니다.';
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// 로그아웃 후 로그인 화면으로 이동
  Future<void> _goToLogin() async {
    await context.read<AuthService>().signOut();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('비밀번호 재설정'),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: _isChanged
              ? _buildSuccessView(isDark)
              : _buildForm(colorScheme, isDark),
        ),
      ),
    );
  }

  /// 새 비밀번호 입력 폼
  Widget _buildForm(ColorScheme colorScheme, bool isDark) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppSpacing.xxl),

          // 안내 아이콘
          Icon(
            Icons.lock_reset,
            size: 64,
            color: isDark ? AppTheme.primaryLight : AppTheme.primaryColor,
          ),
          const SizedBox(height: AppSpacing.lg),

          // 안내 텍스트
          Text(
            '새 비밀번호를 설정해주세요',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: AppSpacing.sm),

          Text(
            '8자 이상, 특수문자 1개 이상 포함',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurface.withOpacity(0.6),
                ),
          ),
          const SizedBox(height: AppSpacing.xxl),

          // 비밀번호 입력 필드
          FormSection(
            errorMessage: _formError,
            children: [
              CustomTextField(
                controller: _passwordController,
                labelText: '새 비밀번호',
                isPassword: true,
                validator: _validatePassword,
                prefixIcon: const Icon(Icons.lock_outlined),
                onEditingComplete: () => FocusScope.of(context).nextFocus(),
              ),
              CustomTextField(
                controller: _confirmController,
                labelText: '비밀번호 확인',
                isPassword: true,
                validator: _validateConfirm,
                prefixIcon: const Icon(Icons.lock_outlined),
                onEditingComplete: _handleChangePassword,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),

          // 변경 버튼
          LoadingButton(
            onPressed: _handleChangePassword,
            text: '비밀번호 변경',
            isLoading: _isLoading,
            width: double.infinity,
            height: 52,
          ),
        ],
      ),
    );
  }

  /// 변경 완료 안내 화면
  Widget _buildSuccessView(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: AppSpacing.xxl + AppSpacing.lg),

        // 완료 아이콘
        Icon(
          Icons.check_circle_outline,
          size: 72,
          color: isDark ? AppTheme.primaryLight : AppTheme.primaryColor,
        ),
        const SizedBox(height: AppSpacing.lg),

        // 완료 타이틀
        Text(
          '비밀번호가 변경되었습니다',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: AppSpacing.md),

        // 안내 문구
        Text(
          '새 비밀번호로 다시 로그인해주세요.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              ),
        ),
        const SizedBox(height: AppSpacing.xxl),

        // 로그인으로 이동 버튼
        OutlinedButton(
          onPressed: _goToLogin,
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(double.infinity, 52),
          ),
          child: const Text('로그인으로 이동'),
        ),
      ],
    );
  }
}
