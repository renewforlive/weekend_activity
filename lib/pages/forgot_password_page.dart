import 'package:flutter/material.dart';

import '../l10n/auth_strings.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../widgets/auth_form_field.dart';

/// 忘記密碼頁。寄出重設信後停留在本頁顯示結果。
class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();

  bool _loading = false;
  bool _sent = false;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    final result = await AuthService.instance.sendPasswordReset(_emailCtrl.text.trim());

    if (!mounted) return;
    setState(() {
      _loading = false;
      _sent = result.isSuccess;
      _error = result.error;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(AuthStrings.forgotTitle)),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
            children: [
              const SizedBox(height: 8),
              const Icon(Icons.lock_reset, size: 56, color: AppColors.primary),
              const SizedBox(height: 12),
              Text(
                AuthStrings.forgotHint,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.5),
              ),
              const SizedBox(height: 28),
              AuthFormField(
                controller: _emailCtrl,
                label: AuthStrings.emailLabel,
                icon: Icons.mail_outline,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.done,
                enabled: !_loading,
                onFieldSubmitted: (_) => _submit(),
                validator: (v) {
                  final value = (v ?? '').trim();
                  if (value.isEmpty) return AuthStrings.emailRequired;
                  if (!AuthValidators.isValidEmail(value)) return AuthStrings.emailInvalid;
                  return null;
                },
              ),
              if (_sent) ...[
                const SizedBox(height: 16),
                AuthSuccessBanner(message: AuthStrings.resetSent),
              ],
              if (_error != null) ...[
                const SizedBox(height: 16),
                AuthErrorBanner(message: _error!),
              ],
              const SizedBox(height: 24),
              AuthSubmitButton(
                label: AuthStrings.sendResetAction,
                loading: _loading,
                onPressed: _submit,
              ),
              const SizedBox(height: 12),
              Center(
                child: TextButton(
                  onPressed: _loading ? null : () => Navigator.pop(context),
                  child: Text(AuthStrings.backToSignIn),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}