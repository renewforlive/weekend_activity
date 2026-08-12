import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/app_state.dart';
import '../l10n/auth_strings.dart';
import '../pages/sign_in_page.dart';
import '../services/auth_service.dart';
import '../services/biometric_lock_service.dart';
import '../theme/app_theme.dart';

/// 個人頁的帳號區塊。
///
/// 已登入顯示 email 與登出;訪客模式顯示登入引導。
class AccountSection extends StatelessWidget {
  const AccountSection({super.key});

  @override
  Widget build(BuildContext context) {
    // 透過 AppState 取狀態,登入/登出時才會觸發重建。
    final state = context.watch<AppState>();
    final signedIn = state.isAuthenticated;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AuthStrings.accountSection,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.soft),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: signedIn ? AppColors.soft : AppColors.background,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      signedIn
                          ? Icons.verified_user_outlined
                          : Icons.person_outline,
                      color: signedIn
                          ? AppColors.primaryDark
                          : AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          signedIn
                              ? (state.userEmail ?? '')
                              : AuthStrings.guestMode,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          signedIn ? '已登入帳號' : AuthStrings.guestHint,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (!signedIn)
                ElevatedButton.icon(
                  onPressed: () => _goSignIn(context),
                  icon: const Icon(Icons.login, size: 19),
                  label: Text(AuthStrings.signInAction),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(44),
                  ),
                ),
            ],
          ),
        ),
        if (signedIn) ...[const SizedBox(height: 20), _securityCard(context)],
      ],
    );
  }

  Widget _securityCard(BuildContext context) {
    final service = BiometricLockService.instance;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AuthStrings.securitySection,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.soft),
          ),
          child: FutureBuilder<bool>(
            future: service.isEnabled,
            builder: (context, snapshot) {
              var enabled = snapshot.data ?? false;
              return StatefulBuilder(
                builder: (context, setCardState) => Column(
                  children: [
                    SwitchListTile.adaptive(
                      value: enabled,
                      secondary: const Icon(
                        Icons.face_outlined,
                        color: AppColors.primary,
                      ),
                      title: Text(AuthStrings.biometricLock),
                      subtitle: Text(
                        AuthStrings.biometricLockHint,
                        style: const TextStyle(fontSize: 12),
                      ),
                      onChanged: (value) async {
                        if (value && !await service.canAuthenticate()) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  AuthStrings.biometricNotAvailable,
                                ),
                              ),
                            );
                          }
                          return;
                        }
                        await service.setEnabled(value);
                        setCardState(() => enabled = value);
                      },
                    ),
                    const Divider(height: 1, color: AppColors.soft),
                    ListTile(
                      leading: const Icon(Icons.logout_outlined),
                      title: Text(AuthStrings.signOutAction),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _confirmSignOut(context),
                    ),
                    const Divider(height: 1, color: AppColors.soft),
                    ListTile(
                      leading: const Icon(
                        Icons.delete_forever_outlined,
                        color: AppColors.danger,
                      ),
                      title: Text(
                        AuthStrings.deleteAccountAction,
                        style: const TextStyle(color: AppColors.danger),
                      ),
                      trailing: const Icon(
                        Icons.chevron_right,
                        color: AppColors.danger,
                      ),
                      onTap: () => _confirmDeleteAccount(context),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _goSignIn(BuildContext context) async {
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const SignInPage()),
    );
  }

  /// 登出前確認,並說明行程會保留。
  Future<void> _confirmSignOut(BuildContext context) async {
    final state = context.read<AppState>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(AuthStrings.signOutAction),
        content: Text(AuthStrings.signOutConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(AuthStrings.maybeLater),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            child: Text(AuthStrings.signOutAction),
          ),
        ],
      ),
    );

    if (ok != true) return;

    // 登出後回到匿名身分,重新載入該身分的資料。
    await AuthService.instance.signOut();
    await state.loadRemoteData();
  }

  Future<void> _confirmDeleteAccount(BuildContext context) async {
    final state = context.read<AppState>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(AuthStrings.deleteAccountAction),
        content: Text(AuthStrings.deleteAccountConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(AuthStrings.maybeLater),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            child: Text(AuthStrings.deleteAccountAction),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final result = await AuthService.instance.deleteAccount();
    if (!context.mounted) return;

    if (result.isSuccess) {
      await BiometricLockService.instance.setRememberedEmail(null);
      await BiometricLockService.instance.setEnabled(false);
      state.clearAccountData();
      await state.loadRemoteData();
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(AuthStrings.deleteAccountSuccess)));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.error ?? AuthStrings.deleteAccountFailed),
        ),
      );
    }
  }
}
