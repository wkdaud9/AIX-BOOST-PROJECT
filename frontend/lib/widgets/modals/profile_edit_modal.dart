import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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
  final _departmentController = TextEditingController();

  String _selectedGrade = '1학년';
  Set<String> _selectedCategories = {};
  bool _isLoading = false;

  final List<String> _grades = ['1학년', '2학년', '3학년', '4학년', '대학원'];
  final List<String> _categories = ['학사', '장학', '취업', '행사', '교육', '공모전'];

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
      _departmentController.text = user?['department'] ?? '';
      _selectedGrade = user?['grade'] ?? '1학년';

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
    _departmentController.dispose();
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
            color: isDark ? const Color(0xFF1A1A2E) : Colors.white,
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

                        // 학과
                        _buildLabel('학과/전공'),
                        const SizedBox(height: AppSpacing.sm),
                        TextFormField(
                          controller: _departmentController,
                          decoration: InputDecoration(
                            hintText: '학과를 입력하세요',
                            prefixIcon: Icon(
                              Icons.school_outlined,
                              color: isDark ? Colors.white54 : AppTheme.textSecondary,
                            ),
                          ),
                        ),

                        const SizedBox(height: AppSpacing.lg),

                        // 학년
                        _buildLabel('학년'),
                        const SizedBox(height: AppSpacing.sm),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF2D2D44) : AppTheme.surfaceLight,
                            borderRadius: BorderRadius.circular(AppRadius.md),
                            border: Border.all(
                              color: isDark
                                  ? Colors.white24
                                  : AppTheme.textHint.withOpacity(0.3),
                            ),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _selectedGrade,
                              isExpanded: true,
                              icon: Icon(
                                Icons.keyboard_arrow_down,
                                color: isDark ? Colors.white54 : AppTheme.textSecondary,
                              ),
                              items: _grades.map((grade) {
                                return DropdownMenuItem(
                                  value: grade,
                                  child: Text(grade),
                                );
                              }).toList(),
                              onChanged: (value) {
                                if (value != null) {
                                  setState(() => _selectedGrade = value);
                                }
                              },
                            ),
                          ),
                        ),

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
                        Wrap(
                          spacing: AppSpacing.sm,
                          runSpacing: AppSpacing.sm,
                          children: _categories.map((category) {
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
                        ),

                        const SizedBox(height: AppSpacing.xxl),

                        // 버튼
                        Row(
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
                        ),

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
