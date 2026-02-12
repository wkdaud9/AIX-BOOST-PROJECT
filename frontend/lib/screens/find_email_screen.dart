import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/loading_button.dart';
import '../widgets/form_section.dart';
import '../theme/app_theme.dart';
import 'forgot_password_screen.dart';

/// 아이디 찾기 화면
/// 학번과 이름을 입력받아 등록된 이메일(마스킹)을 조회합니다.
class FindEmailScreen extends StatefulWidget {
  const FindEmailScreen({super.key});

  @override
  State<FindEmailScreen> createState() => _FindEmailScreenState();
}

class _FindEmailScreenState extends State<FindEmailScreen> {
  /// 폼 키 (유효성 검사용)
  final _formKey = GlobalKey<FormState>();

  /// 학번 입력 컨트롤러
  final _studentIdController = TextEditingController();

  /// 이름 입력 컨트롤러
  final _nameController = TextEditingController();

  /// 로딩 상태
  bool _isLoading = false;

  /// 조회된 마스킹 이메일
  String? _foundEmail;

  /// 폼 에러 메시지
  String? _formError;

  @override
  void dispose() {
    _studentIdController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  /// 학번 유효성 검사
  String? _validateStudentId(String? value) {
    if (value == null || value.isEmpty) {
      return '학번을 입력해주세요.';
    }
    return null;
  }

  /// 이름 유효성 검사
  String? _validateName(String? value) {
    if (value == null || value.isEmpty) {
      return '이름을 입력해주세요.';
    }
    return null;
  }

  /// 아이디 찾기 처리
  Future<void> _handleFindEmail() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _formError = null;
      _foundEmail = null;
    });

    try {
      final apiService = context.read<ApiService>();
      final maskedEmail = await apiService.findEmail(
        studentId: _studentIdController.text.trim(),
        name: _nameController.text.trim(),
      );

      if (!mounted) return;
      setState(() {
        _foundEmail = maskedEmail;
      });
    } catch (e) {
      if (!mounted) return;
      String errorMessage = e.toString();
      if (errorMessage.startsWith('Exception: ')) {
        errorMessage = errorMessage.substring('Exception: '.length);
      }
      setState(() {
        _formError = errorMessage;
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
        title: const Text('아이디 찾기'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: _foundEmail != null
              ? _buildResult(isDark)
              : _buildForm(colorScheme, isDark),
        ),
      ),
    );
  }

  /// 학번 + 이름 입력 폼
  Widget _buildForm(ColorScheme colorScheme, bool isDark) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppSpacing.xxl),

          // 안내 아이콘
          Icon(
            Icons.person_search_outlined,
            size: 64,
            color: isDark ? AppTheme.primaryLight : AppTheme.primaryColor,
          ),
          const SizedBox(height: AppSpacing.lg),

          // 안내 텍스트
          Text(
            '아이디를 잊으셨나요?',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: AppSpacing.sm),

          Text(
            '가입 시 입력한 학번과 이름을 입력하시면\n등록된 이메일을 확인할 수 있습니다.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurface.withOpacity(0.6),
                ),
          ),
          const SizedBox(height: AppSpacing.xxl),

          // 입력 필드
          FormSection(
            errorMessage: _formError,
            children: [
              CustomTextField(
                controller: _studentIdController,
                labelText: '학번',
                keyboardType: TextInputType.number,
                validator: _validateStudentId,
                prefixIcon: const Icon(Icons.badge_outlined),
                onEditingComplete: () => FocusScope.of(context).nextFocus(),
              ),
              CustomTextField(
                controller: _nameController,
                labelText: '이름',
                validator: _validateName,
                prefixIcon: const Icon(Icons.person_outlined),
                onEditingComplete: _handleFindEmail,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),

          // 조회 버튼
          LoadingButton(
            onPressed: _handleFindEmail,
            text: '아이디 찾기',
            isLoading: _isLoading,
            width: double.infinity,
            height: 52,
          ),
        ],
      ),
    );
  }

  /// 조회 결과 화면
  Widget _buildResult(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: AppSpacing.xxl + AppSpacing.lg),

        // 완료 아이콘
        Icon(
          Icons.email_outlined,
          size: 72,
          color: isDark ? AppTheme.primaryLight : AppTheme.primaryColor,
        ),
        const SizedBox(height: AppSpacing.lg),

        // 완료 타이틀
        Text(
          '등록된 이메일을 찾았습니다',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: AppSpacing.lg),

        // 마스킹된 이메일 표시
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          decoration: BoxDecoration(
            color: (isDark ? AppTheme.primaryLight : AppTheme.primaryColor)
                .withOpacity(0.1),
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
              color: (isDark ? AppTheme.primaryLight : AppTheme.primaryColor)
                  .withOpacity(0.3),
            ),
          ),
          child: Text(
            _foundEmail!,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppTheme.primaryLight : AppTheme.primaryColor,
                  letterSpacing: 0.5,
                ),
          ),
        ),
        const SizedBox(height: AppSpacing.xxl),

        // 로그인으로 돌아가기 버튼
        OutlinedButton(
          onPressed: () => Navigator.of(context).pop(),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(double.infinity, 52),
          ),
          child: const Text('로그인으로 돌아가기'),
        ),
        const SizedBox(height: AppSpacing.sm),

        // 비밀번호 찾기 링크
        TextButton(
          onPressed: () {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (context) => const ForgotPasswordScreen(),
              ),
            );
          },
          child: Text(
            '비밀번호가 기억나지 않으시나요?',
            style: TextStyle(
              color: isDark ? Colors.white54 : Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }
}
