import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/auth_service.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/loading_button.dart';
import '../widgets/form_section.dart';
import '../theme/app_theme.dart';

/// 비밀번호 찾기 화면 (OTP 방식)
/// 이메일 입력 → 인증코드 전송 → OTP 입력 → 새 비밀번호 설정 → 완료
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  /// 현재 단계 (0: 이메일 입력, 1: OTP 입력, 2: 새 비밀번호, 3: 완료)
  int _step = 0;

  /// 폼 키 (각 단계별 유효성 검사용)
  final _formKey = GlobalKey<FormState>();

  /// 이메일 입력 컨트롤러
  final _emailController = TextEditingController();

  /// OTP 입력 컨트롤러
  final _otpController = TextEditingController();

  /// 새 비밀번호 입력 컨트롤러
  final _passwordController = TextEditingController();

  /// 비밀번호 확인 입력 컨트롤러
  final _confirmController = TextEditingController();

  /// 로딩 상태
  bool _isLoading = false;

  /// 폼 에러 메시지
  String? _formError;

  @override
  void dispose() {
    _emailController.dispose();
    _otpController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
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

  /// OTP 유효성 검사
  String? _validateOtp(String? value) {
    if (value == null || value.isEmpty) {
      return '인증코드를 입력해주세요.';
    }
    if (value.length != 6) {
      return '6자리 인증코드를 입력해주세요.';
    }
    return null;
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

  /// Step 0: 인증코드 전송
  Future<void> _handleSendOtp() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _formError = null;
    });

    try {
      await context.read<AuthService>().resetPassword(
            _emailController.text.trim(),
          );

      if (!mounted) return;
      setState(() {
        _step = 1;
        _formError = null;
      });
    } on AuthException catch (e) {
      if (!mounted) return;
      debugPrint('[인증코드 전송 에러] ${e.message}');
      setState(() {
        _formError = '인증코드 전송에 실패했습니다.';
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

  /// Step 1: OTP 인증
  Future<void> _handleVerifyOtp() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _formError = null;
    });

    try {
      await context.read<AuthService>().verifyRecoveryOtp(
            _emailController.text.trim(),
            _otpController.text.trim(),
          );

      if (!mounted) return;
      setState(() {
        _step = 2;
        _formError = null;
      });
    } on AuthException catch (e) {
      if (!mounted) return;
      debugPrint('[OTP 인증 에러] ${e.message}');

      String errorMessage = '인증코드가 올바르지 않습니다.';
      if (e.message.contains('expired')) {
        errorMessage = '인증코드가 만료되었습니다. 다시 전송해주세요.';
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

  /// Step 2: 비밀번호 변경
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

      // 비밀번호 변경 후 로그아웃
      await context.read<AuthService>().signOut();

      if (!mounted) return;
      setState(() {
        _step = 3;
        _formError = null;
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

  /// 인증코드 재전송
  Future<void> _handleResendOtp() async {
    setState(() {
      _isLoading = true;
      _formError = null;
    });

    try {
      await context.read<AuthService>().resetPassword(
            _emailController.text.trim(),
          );

      if (!mounted) return;
      setState(() {
        _otpController.clear();
        _formError = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('인증코드를 다시 전송했습니다.')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _formError = '재전송에 실패했습니다.';
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('비밀번호 찾기'),
        automaticallyImplyLeading: _step < 3,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: _buildCurrentStep(colorScheme, isDark),
        ),
      ),
    );
  }

  /// 현재 단계에 맞는 위젯 반환
  Widget _buildCurrentStep(ColorScheme colorScheme, bool isDark) {
    switch (_step) {
      case 0:
        return _buildEmailStep(colorScheme, isDark);
      case 1:
        return _buildOtpStep(colorScheme, isDark);
      case 2:
        return _buildPasswordStep(colorScheme, isDark);
      case 3:
        return _buildSuccessStep(isDark);
      default:
        return const SizedBox.shrink();
    }
  }

  /// Step 0: 이메일 입력
  Widget _buildEmailStep(ColorScheme colorScheme, bool isDark) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppSpacing.xxl),

          Icon(
            Icons.lock_reset,
            size: 64,
            color: isDark ? AppTheme.primaryLight : AppTheme.primaryColor,
          ),
          const SizedBox(height: AppSpacing.lg),

          Text(
            '비밀번호를 잊으셨나요?',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: AppSpacing.sm),

          Text(
            '가입 시 사용한 이메일을 입력하시면\n인증코드를 보내드립니다.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurface.withOpacity(0.6),
                ),
          ),
          const SizedBox(height: AppSpacing.xxl),

          FormSection(
            errorMessage: _formError,
            children: [
              CustomTextField(
                controller: _emailController,
                labelText: '이메일',
                keyboardType: TextInputType.emailAddress,
                validator: _validateEmail,
                prefixIcon: const Icon(Icons.email_outlined),
                onEditingComplete: _handleSendOtp,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),

          LoadingButton(
            onPressed: _handleSendOtp,
            text: '인증코드 전송',
            isLoading: _isLoading,
            width: double.infinity,
            height: 52,
          ),
        ],
      ),
    );
  }

  /// Step 1: OTP 입력
  Widget _buildOtpStep(ColorScheme colorScheme, bool isDark) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppSpacing.xxl),

          Icon(
            Icons.mark_email_read_outlined,
            size: 64,
            color: isDark ? AppTheme.primaryLight : AppTheme.primaryColor,
          ),
          const SizedBox(height: AppSpacing.lg),

          Text(
            '인증코드를 입력해주세요',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: AppSpacing.sm),

          Text(
            '${_emailController.text.trim()}(으)로\n6자리 인증코드를 전송했습니다.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurface.withOpacity(0.6),
                ),
          ),
          const SizedBox(height: AppSpacing.xxl),

          FormSection(
            errorMessage: _formError,
            children: [
              CustomTextField(
                controller: _otpController,
                labelText: '인증코드 (6자리)',
                keyboardType: TextInputType.number,
                validator: _validateOtp,
                prefixIcon: const Icon(Icons.pin_outlined),
                onEditingComplete: _handleVerifyOtp,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(6),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),

          LoadingButton(
            onPressed: _handleVerifyOtp,
            text: '인증 확인',
            isLoading: _isLoading,
            width: double.infinity,
            height: 52,
          ),
          const SizedBox(height: AppSpacing.sm),

          // 재전송 링크
          TextButton(
            onPressed: _isLoading ? null : _handleResendOtp,
            child: Text(
              '인증코드 재전송',
              style: TextStyle(
                color: isDark
                    ? Colors.white54
                    : colorScheme.onSurface.withOpacity(0.5),
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Step 2: 새 비밀번호 입력
  Widget _buildPasswordStep(ColorScheme colorScheme, bool isDark) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppSpacing.xxl),

          Icon(
            Icons.lock_open,
            size: 64,
            color: isDark ? AppTheme.primaryLight : AppTheme.primaryColor,
          ),
          const SizedBox(height: AppSpacing.lg),

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

  /// Step 3: 완료
  Widget _buildSuccessStep(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: AppSpacing.xxl + AppSpacing.lg),

        Icon(
          Icons.check_circle_outline,
          size: 72,
          color: isDark ? AppTheme.primaryLight : AppTheme.primaryColor,
        ),
        const SizedBox(height: AppSpacing.lg),

        Text(
          '비밀번호가 변경되었습니다',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: AppSpacing.md),

        Text(
          '새 비밀번호로 다시 로그인해주세요.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              ),
        ),
        const SizedBox(height: AppSpacing.xxl),

        OutlinedButton(
          onPressed: () => Navigator.of(context).pop(),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(double.infinity, 52),
          ),
          child: const Text('로그인으로 돌아가기'),
        ),
      ],
    );
  }
}
