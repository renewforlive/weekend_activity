import 'package:flutter/material.dart';

import '../l10n/auth_strings.dart';
import '../pages/sign_in_page.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';

/// 確認使用者已用 email 登入,未登入則引導至登入頁。
///
/// 回傳 true 表示可以繼續原本的操作(已登入,或剛登入成功)。
/// 招募的發起與加入都要先過這一關。
Future<bool> requireSignIn(BuildContext context) async {
  if (AuthService.instance.isAuthenticated) return true;

  final proceed = await showModalBottomSheet<bool>(
    context: context,
    backgroundColor: AppColors.background,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_outline, size: 44, color: AppColors.primary),
            const SizedBox(height: 16),
            Text(
              AuthStrings.needSignInForRecruitment,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(AuthStrings.signInNow),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(AuthStrings.maybeLater),
            ),
          ],
        ),
      ),
    ),
  );

  if (proceed != true || !context.mounted) return false;

  final signedIn = await Navigator.push<bool>(
    context,
    MaterialPageRoute(builder: (_) => const SignInPage()),
  );
  return signedIn == true;
}