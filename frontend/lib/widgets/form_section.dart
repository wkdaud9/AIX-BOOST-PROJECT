import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// 폼 섹션 위젯
/// 여러 입력 필드를 박스로 그룹핑하여 표시합니다.
class FormSection extends StatelessWidget {
  final String? title;
  final List<Widget> children;
  final String? errorMessage;

  const FormSection({
    super.key,
    this.title,
    required this.children,
    this.errorMessage,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 섹션 제목
        if (title != null) ...[
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 12),
            child: Text(
              title!,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
            ),
          ),
        ],

        // 입력 필드를 감싸는 카드
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: errorMessage != null
                  ? AppTheme.errorColor
                  : Colors.grey.shade300,
              width: errorMessage != null ? 2 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              for (int i = 0; i < children.length; i++) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: children[i],
                ),
                // 마지막 아이템이 아니면 구분선 추가
                if (i < children.length - 1)
                  Divider(
                    height: 1,
                    thickness: 1,
                    color: Colors.grey.shade200,
                    indent: 16,
                    endIndent: 16,
                  ),
              ],
            ],
          ),
        ),

        // 에러 메시지
        if (errorMessage != null) ...[
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Row(
              children: [
                Icon(
                  Icons.error_outline,
                  size: 16,
                  color: AppTheme.errorColor,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    errorMessage!,
                    style: TextStyle(
                      color: AppTheme.errorColor,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
