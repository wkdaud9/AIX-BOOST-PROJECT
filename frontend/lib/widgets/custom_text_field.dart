import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 재사용 가능한 입력 필드 위젯
/// 이메일, 비밀번호 등 다양한 입력 타입을 지원합니다.
class CustomTextField extends StatefulWidget {
  final TextEditingController controller;
  final String labelText;
  final String? hintText;
  final bool isPassword;
  final TextInputType keyboardType;
  final String? Function(String?)? validator;
  final String? errorText;
  final bool enabled;
  final int? maxLines;
  final Widget? prefixIcon;
  final VoidCallback? onEditingComplete;
  final List<TextInputFormatter>? inputFormatters;

  const CustomTextField({
    super.key,
    required this.controller,
    required this.labelText,
    this.hintText,
    this.isPassword = false,
    this.keyboardType = TextInputType.text,
    this.validator,
    this.errorText,
    this.enabled = true,
    this.maxLines = 1,
    this.prefixIcon,
    this.onEditingComplete,
    this.inputFormatters,
  });

  @override
  State<CustomTextField> createState() => _CustomTextFieldState();
}

class _CustomTextFieldState extends State<CustomTextField> {
  /// 비밀번호 표시 여부
  bool _obscureText = true;

  @override
  void initState() {
    super.initState();
    _obscureText = widget.isPassword;
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      keyboardType: widget.keyboardType,
      obscureText: widget.isPassword && _obscureText,
      enabled: widget.enabled,
      maxLines: widget.maxLines,
      onEditingComplete: widget.onEditingComplete,
      inputFormatters: widget.inputFormatters,
      decoration: InputDecoration(
        labelText: widget.labelText,
        // hintText 제거 - 더 깔끔한 UI를 위해
        errorText: widget.errorText,
        prefixIcon: widget.prefixIcon,
        suffixIcon: widget.isPassword
            ? IconButton(
                icon: Icon(
                  _obscureText ? Icons.visibility : Icons.visibility_off,
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                ),
                onPressed: () {
                  setState(() {
                    _obscureText = !_obscureText;
                  });
                },
              )
            : null,
      ),
      validator: widget.validator,
      // 유효성 검사 모드를 변경하여 제출 후에만 에러 표시
      autovalidateMode: AutovalidateMode.onUserInteraction,
    );
  }
}
