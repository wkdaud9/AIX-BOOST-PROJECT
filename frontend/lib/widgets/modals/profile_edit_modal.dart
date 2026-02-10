import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/app_data.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';

/// 프로필 편집 모달 (토스 스타일)
class ProfileEditModal extends StatefulWidget {
  final Map<String, dynamic>? initialProfile;
  final VoidCallback? onSaved;

  const ProfileEditModal({
    super.key,
    this.initialProfile,
    this.onSaved,
  });

  /// 모달 표시
  static void show(BuildContext context, {
    Map<String, dynamic>? initialProfile,
    VoidCallback? onSaved,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ProfileEditModal(
        initialProfile: initialProfile,
        onSaved: onSaved,
      ),
    );
  }

  @override
  State<ProfileEditModal> createState() => _ProfileEditModalState();
}

class _ProfileEditModalState extends State<ProfileEditModal> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();

  String? _selectedDepartment;
  String _selectedGrade = '1학년';
  Set<String> _selectedCategories = {};
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  void _loadInitialData() {
    if (widget.initialProfile != null) {
      final user = widget.initialProfile!['user'];
      final preferences = widget.initialProfile!['preferences'];

      _nameController.text = user?['name'] ?? '';
      _selectedDepartment = user?['department'];

      // grade 필드 타입 변환 (백엔드에서 int로 반환될 수 있음)
      final gradeValue = user?['grade'];
      if (gradeValue != null) {
        if (gradeValue is int) {
          // 숫자를 '학년' 형식으로 변환 (예: 1 -> '1학년', 5 -> '대학원')
          if (gradeValue >= 1 && gradeValue <= 4) {
            _selectedGrade = '${gradeValue}학년';
          } else if (gradeValue == 5) {
            _selectedGrade = '대학원';
          } else {
            _selectedGrade = '1학년';
          }
        } else if (gradeValue is String) {
          _selectedGrade = gradeValue;
        }
      }

      if (preferences?['categories'] != null) {
        _selectedCategories = Set<String>.from(
          (preferences!['categories'] as List).map((e) => e.toString()),
        );
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF060E1F) : Colors.white,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppRadius.xl),
            ),
          ),
          child: Column(
            children: [
              // 핸들바
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // 헤더
              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        '프로필 편집',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),

              const Divider(height: 1),

              // 내용
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 이름
                        _buildLabel('이름'),
                        const SizedBox(height: AppSpacing.sm),
                        TextFormField(
                          controller: _nameController,
                          decoration: InputDecoration(
                            hintText: '이름을 입력하세요',
                            prefixIcon: Icon(
                              Icons.person_outline,
                              color: isDark ? Colors.white54 : AppTheme.textSecondary,
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return '이름을 입력해주세요';
                            }
                            return null;
                          },
                        ),

                        const SizedBox(height: AppSpacing.lg),

                        // 학과/전공 (드롭다운으로 변경)
                        _buildLabel('학과/전공'),
                        const SizedBox(height: AppSpacing.sm),
                        _buildDepartmentSelector(isDark),

                        const SizedBox(height: AppSpacing.lg),

                        // 학년 (드롭다운 - 아래로 펼쳐지는 방식)
                        _buildLabel('학년'),
                        const SizedBox(height: AppSpacing.sm),
                        _buildGradeDropdown(isDark),

                        const SizedBox(height: AppSpacing.lg),

                        // 관심 카테고리
                        _buildLabel('관심 카테고리'),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          '관심 있는 카테고리를 선택하면 맞춤 공지를 받을 수 있어요',
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? Colors.white54 : AppTheme.textSecondary,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        _buildCategoryChips(isDark),

                        const SizedBox(height: AppSpacing.xxl),

                        // 버튼
                        _buildActionButtons(isDark),

                        const SizedBox(height: AppSpacing.lg),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// 학과 선택 위젯 (클릭 시 Bottom Sheet)
  Widget _buildDepartmentSelector(bool isDark) {
    return GestureDetector(
      onTap: () => _showDepartmentPicker(context, isDark),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1C4D8D) : AppTheme.surfaceLight,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: isDark
                ? Colors.white24
                : AppTheme.textHint.withOpacity(0.3),
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.school_outlined,
              color: isDark ? Colors.white54 : AppTheme.textSecondary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _selectedDepartment ?? '학과를 선택하세요',
                style: TextStyle(
                  fontSize: 16,
                  color: _selectedDepartment != null
                      ? (isDark ? Colors.white : AppTheme.textPrimary)
                      : (isDark ? Colors.white38 : AppTheme.textHint),
                ),
              ),
            ),
            Icon(
              Icons.keyboard_arrow_down,
              color: isDark ? Colors.white54 : AppTheme.textSecondary,
            ),
          ],
        ),
      ),
    );
  }

  /// 학과 선택 Bottom Sheet
  void _showDepartmentPicker(BuildContext context, bool isDark) {
    final searchController = TextEditingController();
    String searchQuery = '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            // 검색어로 필터링된 학과 목록
            final filteredDepartments = AppData.departmentsByCollege.entries
                .where((entry) =>
                    searchQuery.isEmpty ||
                    entry.key.contains(searchQuery) ||
                    entry.value.any((dept) => dept.contains(searchQuery)))
                .toList();

            return DraggableScrollableSheet(
              initialChildSize: 0.7,
              minChildSize: 0.5,
              maxChildSize: 0.9,
              builder: (context, scrollController) {
                return Container(
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF060E1F) : Colors.white,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(AppRadius.xl),
                    ),
                  ),
                  child: Column(
                    children: [
                      // 핸들바
                      Container(
                        margin: const EdgeInsets.only(top: 12),
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white24 : Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),

                      // 헤더
                      Padding(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        child: Row(
                          children: [
                            const Expanded(
                              child: Text(
                                '학과 선택',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: () => Navigator.pop(context),
                            ),
                          ],
                        ),
                      ),

                      // 검색 필드
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                        child: TextField(
                          controller: searchController,
                          decoration: InputDecoration(
                            hintText: '학과명 검색',
                            prefixIcon: const Icon(Icons.search),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(AppRadius.md),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.md,
                              vertical: AppSpacing.sm,
                            ),
                          ),
                          onChanged: (value) {
                            setModalState(() {
                              searchQuery = value;
                            });
                          },
                        ),
                      ),

                      const SizedBox(height: AppSpacing.sm),
                      const Divider(height: 1),

                      // 학과 목록
                      Expanded(
                        child: ListView.builder(
                          controller: scrollController,
                          itemCount: filteredDepartments.length,
                          itemBuilder: (context, index) {
                            final entry = filteredDepartments[index];
                            final collegeName = entry.key;
                            final departments = entry.value.where((dept) =>
                                searchQuery.isEmpty || dept.contains(searchQuery)).toList();

                            if (departments.isEmpty) {
                              return const SizedBox.shrink();
                            }

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // 대학 헤더
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: AppSpacing.md,
                                    vertical: AppSpacing.sm,
                                  ),
                                  color: isDark
                                      ? Colors.white.withOpacity(0.05)
                                      : Colors.grey.shade100,
                                  width: double.infinity,
                                  child: Text(
                                    collegeName,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: isDark
                                          ? Colors.white70
                                          : AppTheme.textSecondary,
                                    ),
                                  ),
                                ),
                                // 학과 목록
                                ...departments.map((dept) {
                                  final isSelected = dept == _selectedDepartment;
                                  return ListTile(
                                    title: Text(
                                      dept,
                                      style: TextStyle(
                                        fontWeight: isSelected
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                        color: isSelected
                                            ? AppTheme.primaryColor
                                            : null,
                                      ),
                                    ),
                                    trailing: isSelected
                                        ? const Icon(
                                            Icons.check,
                                            color: AppTheme.primaryColor,
                                          )
                                        : null,
                                    onTap: () {
                                      setState(() {
                                        _selectedDepartment = dept;
                                      });
                                      Navigator.pop(context);
                                    },
                                  );
                                }),
                              ],
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  /// 학년 드롭다운 (아래로 펼쳐지는 방식)
  Widget _buildGradeDropdown(bool isDark) {
    return PopupMenuButton<String>(
      initialValue: _selectedGrade,
      position: PopupMenuPosition.under,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      color: isDark ? const Color(0xFF1C4D8D) : Colors.white,
      onSelected: (value) {
        setState(() => _selectedGrade = value);
      },
      itemBuilder: (context) => AppData.grades.map((grade) {
        return PopupMenuItem(
          value: grade,
          child: Text(grade),
        );
      }).toList(),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: 14,
        ),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1C4D8D) : AppTheme.surfaceLight,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: isDark
                ? Colors.white24
                : AppTheme.textHint.withOpacity(0.3),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                _selectedGrade,
                style: TextStyle(
                  color: isDark ? Colors.white : AppTheme.textPrimary,
                ),
              ),
            ),
            Icon(
              Icons.keyboard_arrow_down,
              color: isDark ? Colors.white54 : AppTheme.textSecondary,
            ),
          ],
        ),
      ),
    );
  }

  /// 카테고리 칩 위젯
  Widget _buildCategoryChips(bool isDark) {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: AppData.categories.map((category) {
        final isSelected = _selectedCategories.contains(category);
        final categoryColor = AppTheme.getCategoryColor(category);

        return GestureDetector(
          onTap: () {
            setState(() {
              if (isSelected) {
                _selectedCategories.remove(category);
              } else {
                _selectedCategories.add(category);
              }
            });
          },
          child: AnimatedContainer(
            duration: AppDuration.fast,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: isSelected
                  ? categoryColor.withOpacity(0.15)
                  : (isDark ? Colors.white12 : Colors.grey.shade100),
              borderRadius: BorderRadius.circular(AppRadius.round),
              border: Border.all(
                color: isSelected
                    ? categoryColor
                    : Colors.transparent,
                width: 1.5,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isSelected) ...[
                  Icon(
                    Icons.check,
                    size: 16,
                    color: categoryColor,
                  ),
                  const SizedBox(width: 4),
                ],
                Text(
                  category,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: isSelected
                        ? FontWeight.w600
                        : FontWeight.normal,
                    color: isSelected
                        ? categoryColor
                        : (isDark ? Colors.white70 : AppTheme.textPrimary),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  /// 액션 버튼 (취소, 저장)
  Widget _buildActionButtons(bool isDark) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () => Navigator.pop(context),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
              side: BorderSide(
                color: isDark ? Colors.white24 : Colors.grey.shade300,
              ),
            ),
            child: const Text('취소'),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          flex: 2,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _saveProfile,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
            ),
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('저장'),
          ),
        ),
      ],
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedCategories.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('최소 1개의 관심 카테고리를 선택해주세요')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final authService = context.read<AuthService>();
      final apiService = context.read<ApiService>();
      final userId = authService.currentUser?.id;

      if (userId != null) {
        // 카테고리 업데이트
        await apiService.updateUserPreferences(
          userId: userId,
          categories: _selectedCategories.toList(),
        );
      }

      if (mounted) {
        // AppBar 사용자 이름 즉시 반영
        authService.updateUserName(_nameController.text.trim());

        Navigator.pop(context);
        widget.onSaved?.call();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('프로필이 저장되었습니다')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('저장 실패: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}
