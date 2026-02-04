import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/api_service.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/loading_button.dart';
import '../widgets/form_section.dart';
import '../theme/app_theme.dart';

/// 회원가입 화면
/// 이메일, 비밀번호, 이름, 학번, 학과, 학년, 관심 카테고리를 입력받아 회원가입합니다.
class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  /// 폼 키 (유효성 검사용)
  final _formKey = GlobalKey<FormState>();

  /// 이메일 입력 컨트롤러
  final _emailController = TextEditingController();

  /// 비밀번호 입력 컨트롤러
  final _passwordController = TextEditingController();

  /// 비밀번호 확인 입력 컨트롤러
  final _confirmPasswordController = TextEditingController();

  /// 이름 입력 컨트롤러
  final _nameController = TextEditingController();

  /// 학번 입력 컨트롤러
  final _studentIdController = TextEditingController();

  /// 학과 입력 컨트롤러
  final _departmentController = TextEditingController();

  /// 선택된 학년
  int? _selectedGrade;

  /// 선택된 관심 카테고리
  final Set<String> _selectedCategories = {};

  /// 사용 가능한 카테고리 목록
  final List<String> _availableCategories = [
    '학사공지',
    '장학',
    '취업',
    '학생활동',
    '시설',
    '기타',
  ];

  /// 로딩 상태
  bool _isLoading = false;

  /// 계정 정보 박스 에러
  String? _accountError;

  /// 학생 정보 박스 에러
  String? _studentInfoError;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _nameController.dispose();
    _studentIdController.dispose();
    _departmentController.dispose();
    super.dispose();
  }

  /// 회원가입 처리
  Future<void> _handleSignUp() async {
    // 에러 초기화
    setState(() {
      _accountError = null;
      _studentInfoError = null;
    });

    // 1. 폼 유효성 검사
    final isValid = _formKey.currentState!.validate();

    // 2. 비밀번호 일치 확인
    if (_passwordController.text != _confirmPasswordController.text) {
      setState(() {
        _accountError = '비밀번호가 일치하지 않습니다.';
      });
      return;
    }

    // 3. 학년 선택 확인
    if (_selectedGrade == null) {
      setState(() {
        _studentInfoError = '학년을 선택해주세요.';
      });
      return;
    }

    // 4. 관심 카테고리 선택 확인
    if (_selectedCategories.isEmpty) {
      _showErrorMessage('관심 카테고리를 최소 1개 이상 선택해주세요.');
      return;
    }

    if (!isValid) {
      return;
    }

    // 5. 로딩 상태 시작
    setState(() => _isLoading = true);

    try {
      final supabase = Supabase.instance.client;

      // 6. Supabase Auth 회원가입
      final authResponse = await supabase.auth.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      if (authResponse.user == null) {
        throw Exception('회원가입에 실패했습니다.');
      }

      final userId = authResponse.user!.id;

      // 7. 백엔드 API 호출하여 users 및 user_preferences 테이블에 데이터 저장
      try {
        if (!mounted) return;
        final apiService = context.read<ApiService>();
        await apiService.createUserProfile(
          userId: userId,
          email: _emailController.text.trim(),
          name: _nameController.text.trim(),
          studentId: _studentIdController.text.trim(),
          department: _departmentController.text.trim(),
          grade: _selectedGrade!,
          categories: _selectedCategories.toList(),
        );

        // 8. 백엔드 API 성공 후 로그아웃
        await supabase.auth.signOut();
      } catch (apiError) {
        // 백엔드 API 실패 시 auth.users에서도 삭제 (롤백)
        try {
          if (!mounted) return;
          final apiService = context.read<ApiService>();
          await apiService.deleteUser(userId);
        } catch (_) {
          // 삭제 실패해도 계속 진행
        }
        await supabase.auth.signOut();
        // 원래 에러를 다시 던짐
        rethrow;
      }

      // 9. 성공 메시지 표시
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('회원가입이 완료되었습니다! 로그인해주세요.'),
          backgroundColor: AppTheme.primaryColor,
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.all(16),
        ),
      );

      // 10. 로그인 화면으로 이동
      Navigator.of(context).pop();
    } on AuthException catch (e) {
      // 11. Supabase 에러 처리
      if (!mounted) return;

      String errorMessage = '회원가입에 실패했습니다.';
      if (e.message.contains('User already registered') ||
          e.message.contains('already been registered')) {
        errorMessage = '이미 가입된 이메일입니다.';
      } else if (e.message.contains('Password should be')) {
        errorMessage = '비밀번호는 6자 이상이어야 합니다.';
      }

      setState(() {
        _accountError = errorMessage;
      });
    } catch (e) {
      // 12. 기타 에러 (백엔드 API 에러 포함)
      if (!mounted) return;

      // Exception 메시지에서 실제 에러 메시지만 추출
      String errorMessage = e.toString();
      if (errorMessage.startsWith('Exception: ')) {
        errorMessage = errorMessage.substring('Exception: '.length);
      }

      // 에러 메시지 분류
      if (errorMessage.contains('학번')) {
        setState(() {
          _studentInfoError = errorMessage;
        });
      } else if (errorMessage.contains('이메일')) {
        setState(() {
          _accountError = errorMessage;
        });
      } else {
        _showErrorMessage(errorMessage);
      }
    } finally {
      // 13. 로딩 상태 종료
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// 에러 메시지 표시
  void _showErrorMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppTheme.errorColor,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  /// 관심 카테고리 선택 다이얼로그
  Future<void> _showCategoryDialog() async {
    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Text('관심 카테고리 선택'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: _availableCategories.map((category) {
                    final isSelected = _selectedCategories.contains(category);
                    return CheckboxListTile(
                      title: Text(category),
                      value: isSelected,
                      activeColor: AppTheme.primaryColor,
                      onChanged: (value) {
                        setDialogState(() {
                          setState(() {
                            if (value == true) {
                              _selectedCategories.add(category);
                            } else {
                              _selectedCategories.remove(category);
                            }
                          });
                        });
                      },
                    );
                  }).toList(),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: const Text('완료'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// 이메일 유효성 검사
  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return '이메일을 입력해주세요';
    }

    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(value)) {
      return '올바른 이메일 형식이 아닙니다';
    }

    return null;
  }

  /// 비밀번호 유효성 검사
  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return '비밀번호를 입력해주세요';
    }

    if (value.length < 6) {
      return '6자 이상 입력해주세요';
    }

    return null;
  }

  /// 비밀번호 확인 유효성 검사
  String? _validateConfirmPassword(String? value) {
    if (value == null || value.isEmpty) {
      return '비밀번호를 다시 입력해주세요';
    }

    if (value != _passwordController.text) {
      return '비밀번호가 일치하지 않습니다';
    }

    return null;
  }

  /// 학번 유효성 검사
  String? _validateStudentId(String? value) {
    if (value == null || value.isEmpty) {
      return '학번을 입력해주세요';
    }

    return null;
  }

  /// 학과 유효성 검사
  String? _validateDepartment(String? value) {
    if (value == null || value.isEmpty) {
      return '학과를 입력해주세요';
    }

    return null;
  }

  /// 이름 유효성 검사
  String? _validateName(String? value) {
    if (value == null || value.isEmpty) {
      return '이름을 입력해주세요';
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('회원가입'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: AppSpacing.md),

                // 안내 문구
                Text(
                  '군산대학교 학생 정보를 입력해주세요',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                ),
                const SizedBox(height: AppSpacing.xl),

                // 계정 정보 박스
                FormSection(
                  title: '계정 정보',
                  errorMessage: _accountError,
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
                      onEditingComplete: () => FocusScope.of(context).nextFocus(),
                    ),
                    CustomTextField(
                      controller: _confirmPasswordController,
                      labelText: '비밀번호 확인',
                      isPassword: true,
                      validator: _validateConfirmPassword,
                      prefixIcon: const Icon(Icons.lock_outlined),
                      onEditingComplete: () => FocusScope.of(context).nextFocus(),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xl),

                // 학생 정보 박스
                FormSection(
                  title: '학생 정보',
                  errorMessage: _studentInfoError,
                  children: [
                    CustomTextField(
                      controller: _nameController,
                      labelText: '이름',
                      validator: _validateName,
                      prefixIcon: const Icon(Icons.person_outline),
                      onEditingComplete: () => FocusScope.of(context).nextFocus(),
                    ),
                    CustomTextField(
                      controller: _studentIdController,
                      labelText: '학번',
                      keyboardType: TextInputType.number,
                      validator: _validateStudentId,
                      prefixIcon: const Icon(Icons.badge_outlined),
                      onEditingComplete: () => FocusScope.of(context).nextFocus(),
                    ),
                    CustomTextField(
                      controller: _departmentController,
                      labelText: '학과',
                      validator: _validateDepartment,
                      prefixIcon: const Icon(Icons.school_outlined),
                      onEditingComplete: () => FocusScope.of(context).nextFocus(),
                    ),
                    // 학년 선택 드롭다운
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: DropdownButtonFormField<int>(
                        decoration: const InputDecoration(
                          labelText: '학년',
                          prefixIcon: Icon(Icons.stairs_outlined),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                        ),
                        items: [1, 2, 3, 4].map((grade) {
                          return DropdownMenuItem(
                            value: grade,
                            child: Text('$grade학년'),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedGrade = value;
                            _studentInfoError = null;
                          });
                        },
                        validator: (value) {
                          if (value == null) {
                            return '학년을 선택해주세요';
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xl),

                // 관심 카테고리 섹션 (강조된 박스 디자인)
                Container(
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppTheme.primaryColor.withValues(alpha: 0.3),
                      width: 2,
                    ),
                  ),
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 헤더 섹션
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.star_rounded,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '관심 카테고리',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.primaryColor,
                                      ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '맞춤 공지사항을 위해 선택해주세요',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                        color: AppTheme.textSecondary,
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: AppSpacing.lg),

                      // 카테고리 선택 버튼
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _showCategoryDialog,
                          icon: const Icon(Icons.category_outlined),
                          label: Text(
                            _selectedCategories.isEmpty
                                ? '카테고리 선택하기'
                                : '${_selectedCategories.length}개 카테고리 선택됨',
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.lg,
                              vertical: AppSpacing.md,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),

                      // 선택된 카테고리 칩 표시
                      if (_selectedCategories.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.md),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _selectedCategories.map((category) {
                            return Chip(
                              label: Text(
                                category,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              backgroundColor: AppTheme.primaryColor,
                              deleteIcon: const Icon(
                                Icons.close,
                                size: 18,
                                color: Colors.white,
                              ),
                              onDeleted: () {
                                setState(() {
                                  _selectedCategories.remove(category);
                                });
                              },
                            );
                          }).toList(),
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: AppSpacing.xl),

                // 회원가입 버튼
                LoadingButton(
                  onPressed: _handleSignUp,
                  text: '회원가입',
                  isLoading: _isLoading,
                  width: double.infinity,
                  height: 52,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
