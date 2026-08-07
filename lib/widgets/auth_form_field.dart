import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// 認證頁共用的輸入欄位,統一外觀與驗證顯示。
class AuthFormField extends StatelessWidget {
  const AuthFormField({
    super.key,
    required this.controller,
    required this.label,
    this.icon,
    this.obscure = false,
    this.keyboardType,
    this.textInputAction,
    this.validator,
    this.onFieldSubmitted,
    this.trailing,
    this.enabled = true,
  });

  final TextEditingController controller;
  final String label;
  final IconData? icon;
  final bool obscure;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final String? Function(String?)? validator;
  final void Function(String)? onFieldSubmitted;

  /// 右側元件,例如密碼的顯示/隱藏切換。
  final Widget? trailing;

  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      validator: validator,
      onFieldSubmitted: onFieldSubmitted,
      enabled: enabled,
      autocorrect: false,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: icon != null ? Icon(icon, color: AppColors.textSecondary) : null,
        suffixIcon: trailing,
      ),
    );
  }
}

/// 密碼欄位,附帶顯示/隱藏切換。
class PasswordField extends StatefulWidget {
  const PasswordField({
    super.key,
    required this.controller,
    required this.label,
    this.textInputAction,
    this.validator,
    this.onFieldSubmitted,
    this.enabled = true,
  });

  final TextEditingController controller;
  final String label;
  final TextInputAction? textInputAction;
  final String? Function(String?)? validator;
  final void Function(String)? onFieldSubmitted;
  final bool enabled;

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _hidden = true;

  @override
  Widget build(BuildContext context) {
    return AuthFormField(
      controller: widget.controller,
      label: widget.label,
      icon: Icons.lock_outline,
      obscure: _hidden,
      textInputAction: widget.textInputAction,
      validator: widget.validator,
      onFieldSubmitted: widget.onFieldSubmitted,
      enabled: widget.enabled,
      trailing: IconButton(
        icon: Icon(
          _hidden ? Icons.visibility_outlined : Icons.visibility_off_outlined,
          color: AppColors.textSecondary,
        ),
        onPressed: () => setState(() => _hidden = !_hidden),
      ),
    );
  }
}

/// 認證頁的主要按鈕。載入中顯示轉圈並停用。
class AuthSubmitButton extends StatelessWidget {
  const AuthSubmitButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: loading ? null : onPressed,
        child: loading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
              )
            : Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
      ),
    );
  }
}

/// 錯誤訊息橫幅。
class AuthErrorBanner extends StatelessWidget {
  const AuthErrorBanner({super.key, required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.danger.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, size: 20, color: AppColors.danger),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(fontSize: 13, color: AppColors.danger),
            ),
          ),
        ],
      ),
    );
  }
}

/// 成功訊息橫幅。
class AuthSuccessBanner extends StatelessWidget {
  const AuthSuccessBanner({super.key, required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle_outline, size: 20, color: AppColors.primaryDark),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(fontSize: 13, color: AppColors.primaryDark),
            ),
          ),
        ],
      ),
    );
  }
}

/// 表單驗證工具。
class AuthValidators {
  AuthValidators._();

  static final _emailPattern = RegExp(r'^[\w.+-]+@[\w-]+\.[\w.-]+$');

  static bool isValidEmail(String value) => _emailPattern.hasMatch(value.trim());

  /// 密碼最短長度,與 Supabase 預設一致。
  static const int minPasswordLength = 6;
}