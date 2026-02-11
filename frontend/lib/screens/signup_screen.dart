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

  /// 학년 표시용 컨트롤러
  final _gradeController = TextEditingController();

  /// 선택된 학년
  int? _selectedGrade;

  /// 선택된 관심 카테고리
  final Set<String> _selectedCategories = {};

  /// 사용 가능한 카테고리 목록 (백엔드 카테고리와 일치)
  final List<String> _availableCategories = [
    '학사',
    '장학',
    '취업',
    '행사',
    '교육',
    '공모전',
  ];

  /// 2026학년도 군산대학교 대학별 학과/학부 목록
  static const Map<String, List<String>> _departmentsByCollege = {
    '컴퓨터소프트웨어특성화대학': [
      '컴퓨터정보공학과', '인공지능융합학과', '임베디드소프트웨어학과',
      '소프트웨어학과', 'IT융합통신공학과',
    ],
    '인문콘텐츠융합대학': [
      '국어국문학과', '영어영문학과', '일어일문학과',
      '중어중문학과', '역사학과', '철학과',
    ],
    '해양·바이오특성화대학': [
      '생명과학과', '해양수산공공인재학과', '해양생명과학과',
      '해양생물자원학과', '수산생명의학과', '식품영양학과',
      '기관공학과', '식품생명공학과',
    ],
    'ICC특성화대학부': [
      '미디어문화학부', '아동학부', '사회복지학부',
      '법행정경찰학부', '간호학부', '의류학부', '해양경찰학부',
      '체육학부', '산업디자인학부', '기계공학부',
      '건축공학부', '공간디자인융합기술학부',
    ],
    '경영특성화대학': [
      '경영학부', '국제물류학과', '무역학과', '회계학부',
      '금융부동산경제학과', '벤처창업학과',
    ],
    '자율전공대학': [
      '자율전공학부', '미술학과', '음악과', '조선공학과',
    ],
    '첨단·에너지대학': [
      '이차전지·에너지학부', '스마트오션모빌리티공학과',
      '바이오헬스학과', '스마트시티학과',
    ],
    '융합과학공학대학': [
      '전자공학과', '전기공학과', '신소재공학과', '화학공학과',
      '환경공학과', '토목공학과', '해양건설공학과',
      '첨단과학기술학부', '수학과',
    ],
  };

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
    _gradeController.dispose();
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
        errorMessage = '비밀번호는 8자 이상이며 특수문자를 포함해야 합니다.';
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
      builder: (dialogContext) {
        final isDark = Theme.of(dialogContext).brightness == Brightness.dark;
        final accentColor = isDark ? AppTheme.primaryLight : AppTheme.primaryColor;
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
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
                      activeColor: accentColor,
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
                    Navigator.of(dialogContext).pop();
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: isDark ? Colors.white : accentColor,
                  ),
                  child: const Text('완료',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// 학과 선택 바텀시트
  Future<void> _showDepartmentPicker() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        final isDark = Theme.of(sheetContext).brightness == Brightness.dark;
        final accentColor = isDark ? AppTheme.primaryLight : AppTheme.primaryColor;
        final sheetColorScheme = Theme.of(sheetContext).colorScheme;
        String searchQuery = '';
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            // 검색어로 학과 필터링
            final filteredColleges = <String, List<String>>{};
            _departmentsByCollege.forEach((college, depts) {
              if (searchQuery.isEmpty) {
                filteredColleges[college] = depts;
              } else {
                final matched = depts
                    .where((d) => d.contains(searchQuery))
                    .toList();
                if (matched.isNotEmpty) {
                  filteredColleges[college] = matched;
                }
              }
            });

            return DraggableScrollableSheet(
              initialChildSize: 0.7,
              maxChildSize: 0.9,
              minChildSize: 0.5,
              expand: false,
              builder: (context, scrollController) {
                // 리스트 아이템 빌드
                final items = <Widget>[];
                filteredColleges.forEach((college, depts) {
                  // 대학 헤더
                  items.add(
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                      child: Text(
                        college,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              color: accentColor,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ),
                  );
                  // 학과 항목
                  for (final dept in depts) {
                    final isSelected = _departmentController.text == dept;
                    items.add(
                      ListTile(
                        dense: true,
                        title: Text(
                          dept,
                          style: TextStyle(
                            color: isSelected
                                ? accentColor
                                : sheetColorScheme.onSurface,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                        trailing: isSelected
                            ? Icon(Icons.check,
                                color: accentColor, size: 20)
                            : null,
                        onTap: () {
                          setState(() {
                            _departmentController.text = dept;
                            _studentInfoError = null;
                          });
                          Navigator.of(context).pop();
                        },
                      ),
                    );
                  }
                });

                return Column(
                  children: [
                    // 상단 핸들 바
                    Container(
                      margin: const EdgeInsets.only(top: 12),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: sheetColorScheme.onSurface.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    // 제목
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        '학과 선택',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                      ),
                    ),
                    // 검색 필드
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: TextField(
                        autofocus: false,
                        decoration: InputDecoration(
                          hintText: '학과 검색...',
                          prefixIcon: const Icon(Icons.search),
                          contentPadding:
                              const EdgeInsets.symmetric(vertical: 12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onChanged: (value) {
                          setSheetState(() {
                            searchQuery = value.trim();
                          });
                        },
                      ),
                    ),
                    const SizedBox(height: 8),
                    // 학과 목록
                    Expanded(
                      child: items.isEmpty
                          ? const Center(child: Text('검색 결과가 없습니다'))
                          : ListView(
                              controller: scrollController,
                              children: items,
                            ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  /// 학년 선택 바텀시트
  Future<void> _showGradePicker() async {
    await showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        final isDark = Theme.of(sheetContext).brightness == Brightness.dark;
        final accentColor = isDark ? AppTheme.primaryLight : AppTheme.primaryColor;
        final sheetColorScheme = Theme.of(sheetContext).colorScheme;
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 상단 핸들 바
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: sheetColorScheme.onSurface.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // 제목
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  '학년 선택',
                  style: Theme.of(sheetContext).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ),
              // 학년 목록
              ...[1, 2, 3, 4].map((grade) {
                final isSelected = _selectedGrade == grade;
                return ListTile(
                  title: Text(
                    '$grade학년',
                    style: TextStyle(
                      color: isSelected ? accentColor : sheetColorScheme.onSurface,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  trailing: isSelected
                      ? Icon(Icons.check, color: accentColor, size: 20)
                      : null,
                  onTap: () {
                    setState(() {
                      _selectedGrade = grade;
                      _gradeController.text = '$grade학년';
                      _studentInfoError = null;
                    });
                    Navigator.of(sheetContext).pop();
                  },
                );
              }),
              const SizedBox(height: 8),
            ],
          ),
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

  /// 비밀번호 유효성 검사 (최소 8자 + 특수문자 1개 이상)
  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return '비밀번호를 입력해주세요';
    }

    if (value.length < 8) {
      return '8자 이상 입력해주세요';
    }

    // 특수문자 포함 여부 확인
    final specialCharRegex = RegExp(r'[!@#$%^&*(),.?":{}|<>]');
    if (!specialCharRegex.hasMatch(value)) {
      return '특수문자를 1개 이상 포함해주세요';
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
      return '학과를 선택해주세요';
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
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
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
                        color: colorScheme.onSurface.withOpacity(0.6),
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
                    TextFormField(
                      controller: _departmentController,
                      readOnly: true,
                      onTap: _showDepartmentPicker,
                      decoration: const InputDecoration(
                        labelText: '학과',
                        prefixIcon: Icon(Icons.school_outlined),
                      ),
                      validator: _validateDepartment,
                    ),
                    // 학년 선택 (바텀시트)
                    TextFormField(
                      readOnly: true,
                      onTap: _showGradePicker,
                      controller: _gradeController,
                      decoration: const InputDecoration(
                        labelText: '학년',
                        prefixIcon: Icon(Icons.stairs_outlined),
                      ),
                      validator: (value) {
                        if (_selectedGrade == null) {
                          return '학년을 선택해주세요';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xl),

                // 관심 카테고리 섹션 (강조된 박스 디자인)
                Builder(builder: (context) {
                  final isDark = Theme.of(context).brightness == Brightness.dark;
                  final accentColor = isDark ? AppTheme.primaryLight : AppTheme.primaryColor;
                  return Container(
                    decoration: BoxDecoration(
                      color: accentColor.withOpacity(isDark ? 0.1 : 0.05),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: accentColor.withOpacity(0.3),
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
                                color: accentColor,
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
                                          color: accentColor,
                                        ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '맞춤 공지사항을 위해 선택해주세요',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(
                                          color: colorScheme.onSurface.withOpacity(0.6),
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
                              backgroundColor: accentColor,
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
                                backgroundColor: accentColor,
                                side: BorderSide.none,
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
                  );
                }),

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
