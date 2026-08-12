import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/app_state.dart';
import '../l10n/auth_strings.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../widgets/auth_form_field.dart';

/// 註冊頁。成功後 pop(true)。
///
/// 目前是匿名身分的話會走升級流程,user id 不變,
/// 已排的行程與上傳的照片都會保留。
class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    final result = await AuthService.instance.signUp(
      email: _emailCtrl.text.trim(),
      password: _passwordCtrl.text,
    );

    if (!mounted) return;

    if (result.isSuccess) {
      final messenger = ScaffoldMessenger.of(context);
      if (!result.requiresEmailConfirmation) {
        await context.read<AppState>().loadRemoteData();
      }
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            result.requiresEmailConfirmation
                ? AuthStrings.emailConfirmationSent
                : AuthStrings.signUpSuccess,
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.pop(context, true);
    } else {
      setState(() {
        _loading = false;
        _error = result.error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // 匿名使用者升級時提示資料會保留。
    final isUpgrade = AuthService.instance.isAnonymous;

    return Scaffold(
      appBar: AppBar(title: Text(AuthStrings.signUpTitle)),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
            children: [
              const SizedBox(height: 8),
              const Icon(Icons.person_add_alt, size: 56, color: AppColors.primary),
              if (isUpgrade) ...[
                const SizedBox(height: 12),
                Text(
                  AuthStrings.signUpHint,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
                ),
              ],
              const SizedBox(height: 28),
              AuthFormField(
                controller: _emailCtrl,
                label: AuthStrings.emailLabel,
                icon: Icons.mail_outline,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                enabled: !_loading,
                validator: (v) {
                  final value = (v ?? '').trim();
                  if (value.isEmpty) return AuthStrings.emailRequired;
                  if (!AuthValidators.isValidEmail(value)) return AuthStrings.emailInvalid;
                  return null;
                },
              ),
              const SizedBox(height: 16),
              PasswordField(
                controller: _passwordCtrl,
                label: AuthStrings.passwordLabel,
                textInputAction: TextInputAction.next,
                enabled: !_loading,
                validator: (v) {
                  final value = v ?? '';
                  if (value.isEmpty) return AuthStrings.passwordRequired;
                  if (value.length < AuthValidators.minPasswordLength) {
                    return AuthStrings.passwordTooShort;
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              PasswordField(
                controller: _confirmCtrl,
                label: AuthStrings.confirmPasswordLabel,
                textInputAction: TextInputAction.done,
                enabled: !_loading,
                onFieldSubmitted: (_) => _submit(),
                validator: (v) {
                  if ((v ?? '') != _passwordCtrl.text) {
                    return AuthStrings.passwordMismatch;
                  }
                  return null;
                },
              ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                AuthErrorBanner(message: _error!),
              ],
              const SizedBox(height: 24),
              AuthSubmitButton(
                label: AuthStrings.signUpAction,
                loading: _loading,
                onPressed: _submit,
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    AuthStrings.haveAccount,
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                  TextButton(
                    onPressed: _loading ? null : () => Navigator.pop(context),
                    child: Text(AuthStrings.signInAction),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
