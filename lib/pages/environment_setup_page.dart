import 'package:flutter/material.dart';

import '../services/app_environment.dart';
import '../theme/app_theme.dart';

class EnvironmentSetupPage extends StatelessWidget {
  const EnvironmentSetupPage({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: AppTheme.light,
    home: Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.settings_suggest_outlined,
                  size: 54,
                  color: AppColors.primary,
                ),
                const SizedBox(height: 18),
                Text(
                  '${AppEnvironmentConfig.appName} 尚未設定後端',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  '請使用獨立的測試 Supabase 專案設定後再建置。\n測試版不會連線到正式資料。',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textSecondary, height: 1.5),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
