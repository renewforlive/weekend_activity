import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/app_state.dart';
import '../l10n/auth_strings.dart';
import '../pages/sign_in_page.dart';
import '../services/auth_service.dart';
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
          ),
          child: Row(
            children: [
              Icon(
                signedIn ? Icons.verified_user : Icons.person_outline,
                color: signedIn ? AppColors.primary : AppColors.textSecondary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      signedIn ? (state.userEmail ?? '') : AuthStrings.guestMode,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (!signedIn) ...[
                      const SizedBox(height: 2),
                      Text(
                        AuthStrings.guestHint,
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              signedIn
                  ? TextButton(
                      onPressed: () => _confirmSignOut(context),
                      child: Text(
                        AuthStrings.signOutAction,
                        style: const TextStyle(color: AppColors.danger),
                      ),
                    )
                  : ElevatedButton(
                      onPressed: () => _goSignIn(context),
                      child: Text(AuthStrings.signInAction),
                    ),
            ],
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
}