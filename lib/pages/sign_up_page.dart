import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../data/app_state.dart';
import '../l10n/auth_strings.dart';
import '../models/models.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../widgets/auth_form_field.dart';
import '../widgets/interest_tag_selector.dart';

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

  ProfileGender? _gender;
  DateTime? _birthDate;
  final Set<InterestTag> _interests = <InterestTag>{};
  XFile? _avatar;
  Uint8List? _avatarBytes;
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
    if (_gender == null ||
        _birthDate == null ||
        _avatar == null ||
        _avatarBytes == null) {
      setState(() {
        _error = '請完成性別、出生年月日與頭像。';
      });
      return;
    }
    final state = context.read<AppState>();

    setState(() {
      _loading = true;
      _error = null;
    });

    final result = await AuthService.instance.signUp(
      email: _emailCtrl.text.trim(),
      password: _passwordCtrl.text,
      profileData: {
        'gender': _gender!.value,
        'birth_date': _dateText(_birthDate!),
        'interests': _interests.map((tag) => tag.value).toList(),
      },
    );

    if (!mounted) return;

    if (result.isSuccess) {
      final messenger = ScaffoldMessenger.of(context);
      if (!result.requiresEmailConfirmation) {
        await state.updateProfile(
          gender: _gender,
          birthDate: _birthDate,
          interests: _interests,
        );
        await state.uploadAvatar(_avatar!.path, bytes: _avatarBytes);
        await state.loadRemoteData();
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

  Future<void> _pickAvatar() async {
    final selected = await _pickImage();
    if (selected == null || !mounted) return;
    setState(() {
      _avatar = selected.file;
      _avatarBytes = selected.bytes;
      _error = null;
    });
  }

  Future<({XFile file, Uint8List bytes})?> _pickImage() async {
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        imageQuality: 85,
      );
      if (picked == null) return null;
      final bytes = await picked.readAsBytes();
      return (file: picked, bytes: bytes);
    } catch (_) {
      if (mounted) setState(() => _error = '無法讀取照片，請重新選擇。');
      return null;
    }
  }

  Future<void> _pickBirthDate() async {
    final today = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime(today.year - 25),
      firstDate: DateTime(1920),
      lastDate: DateTime(today.year - 13, today.month, today.day),
      helpText: '選擇出生年月日',
    );
    if (selected != null && mounted) setState(() => _birthDate = selected);
  }

  String _dateText(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';

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
              const Icon(
                Icons.person_add_alt,
                size: 56,
                color: AppColors.primary,
              ),
              if (isUpgrade) ...[
                const SizedBox(height: 12),
                Text(
                  AuthStrings.signUpHint,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
              const SizedBox(height: 28),
              Center(
                child: InkWell(
                  onTap: _loading ? null : _pickAvatar,
                  customBorder: const CircleBorder(),
                  child: Container(
                    width: 104,
                    height: 104,
                    decoration: BoxDecoration(
                      color: AppColors.soft,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.primary, width: 1.5),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: _avatarBytes == null
                        ? const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.add_a_photo_outlined,
                                color: AppColors.primary,
                              ),
                              SizedBox(height: 4),
                              Text(
                                '上傳頭像',
                                style: TextStyle(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          )
                        : Image.memory(_avatarBytes!, fit: BoxFit.cover),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              const Center(
                child: Text(
                  '請上傳一張自己的頭像',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                '基本資料',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [ProfileGender.male, ProfileGender.female]
                    .map(
                      (gender) => ChoiceChip(
                        label: Text(gender.label),
                        selected: _gender == gender,
                        onSelected: _loading
                            ? null
                            : (_) => setState(() => _gender = gender),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: _loading ? null : _pickBirthDate,
                borderRadius: BorderRadius.circular(14),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: '出生年月日',
                    prefixIcon: Icon(Icons.cake_outlined),
                  ),
                  child: Text(
                    _birthDate == null ? '請選擇出生年月日' : _dateText(_birthDate!),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                '感興趣的活動',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              const Text(
                '可複選，會顯示在你的公開個人頁',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 10),
              InterestTagSelector(
                selected: _interests,
                enabled: !_loading,
                onChanged: (tag) => setState(() {
                  if (_interests.contains(tag)) {
                    _interests.remove(tag);
                  } else {
                    _interests.add(tag);
                  }
                }),
              ),
              const SizedBox(height: 24),
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
