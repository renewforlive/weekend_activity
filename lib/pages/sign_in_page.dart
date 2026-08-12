import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/app_state.dart';
import '../l10n/auth_strings.dart';
import '../services/auth_service.dart';
import '../services/biometric_lock_service.dart';
import '../theme/app_theme.dart';
import '../widgets/auth_form_field.dart';
import 'forgot_password_page.dart';
import 'sign_up_page.dart';

/// 登入頁。成功後 pop(true),呼叫端據此判斷是否繼續原本的操作。
class SignInPage extends StatefulWidget {
  const SignInPage({super.key});

  @override
  State<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends State<SignInPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  bool _loading = false;
  bool _rememberAccount = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadRememberedEmail();
  }

  Future<void> _loadRememberedEmail() async {
    final email = await BiometricLockService.instance.rememberedEmail();
    if (!mounted) return;
    setState(() {
      if (email != null && email.isNotEmpty) _emailCtrl.text = email;
      _rememberAccount = email != null && email.isNotEmpty;
    });
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;
    final result = await AuthService.instance.signIn(
      email: email,
      password: password,
    );

    if (!mounted) return;

    if (result.isSuccess) {
      if (await BiometricLockService.instance.isEnabled) {
        await BiometricLockService.instance.saveCredentials(
          email: email,
          password: password,
        );
      }
      // 換身分後重新載入資料,確保看到的是這個帳號的內容。
      if (_rememberAccount) {
        await BiometricLockService.instance.setRememberedEmail(email);
      } else {
        await BiometricLockService.instance.setRememberedEmail(null);
      }
      await _completeSignIn();
    } else {
      setState(() {
        _loading = false;
        _error = result.error;
      });
    }
  }

  Future<void> _completeSignIn() async {
    await context.read<AppState>().loadRemoteData();
    if (!mounted) return;
    Navigator.pop(context, true);
  }

  Future<void> _signInWithBiometrics() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final credentials = await BiometricLockService.instance
          .authenticateAndReadCredentials();
      if (credentials == null) {
        if (mounted) setState(() => _loading = false);
        return;
      }
      final result = await AuthService.instance.signIn(
        email: credentials.email,
        password: credentials.password,
      );
      if (!mounted) return;
      if (result.isSuccess) {
        await _completeSignIn();
      } else {
        setState(() {
          _loading = false;
          _error = result.error;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(AuthStrings.signInTitle)),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
            children: [
              const SizedBox(height: 8),
              Icon(Icons.groups, size: 56, color: AppColors.primary),
              const SizedBox(height: 12),
              Text(
                AuthStrings.signInHint,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
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
                  if (value.isEmpty) {
                    return AuthStrings.emailRequired;
                  }
                  if (!AuthValidators.isValidEmail(value)) {
                    return AuthStrings.emailInvalid;
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              PasswordField(
                controller: _passwordCtrl,
                label: AuthStrings.passwordLabel,
                textInputAction: TextInputAction.done,
                enabled: !_loading,
                onFieldSubmitted: (_) => _submit(),
                validator: (v) {
                  if ((v ?? '').isEmpty) return AuthStrings.passwordRequired;
                  return null;
                },
              ),
              Row(
                children: [
                  Checkbox(
                    value: _rememberAccount,
                    onChanged: _loading
                        ? null
                        : (value) =>
                              setState(() => _rememberAccount = value ?? false),
                  ),
                  Text(
                    AuthStrings.rememberAccount,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: _loading
                        ? null
                        : () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const ForgotPasswordPage(),
                            ),
                          ),
                    child: Text(AuthStrings.forgotPasswordLink),
                  ),
                ],
              ),
              if (_error != null) ...[
                const SizedBox(height: 4),
                AuthErrorBanner(message: _error!),
              ],
              const SizedBox(height: 20),
              AuthSubmitButton(
                label: AuthStrings.signInAction,
                loading: _loading,
                onPressed: _submit,
              ),
              FutureBuilder<bool>(
                future: BiometricLockService.instance.hasSavedCredentials,
                builder: (context, snapshot) => snapshot.data == true
                    ? Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: OutlinedButton.icon(
                          onPressed: _loading ? null : _signInWithBiometrics,
                          icon: const Icon(Icons.face_outlined),
                          label: Text(AuthStrings.biometricSignIn),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    AuthStrings.noAccountYet,
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                  TextButton(
                    onPressed: _loading ? null : _goToSignUp,
                    child: Text(AuthStrings.signUpAction),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 導向註冊頁。註冊成功時一併關閉登入頁,把結果往上傳。
  Future<void> _goToSignUp() async {
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const SignUpPage()),
    );
    if (ok == true && mounted) {
      Navigator.pop(context, true);
    }
  }
}
