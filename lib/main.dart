import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'data/app_state.dart';
import 'pages/home_page.dart';
import 'pages/environment_setup_page.dart';
import 'services/app_environment.dart';
import 'services/notification_service.dart';
import 'services/push_notification_service.dart';
import 'services/supabase_config.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!SupabaseConfig.isConfigured) {
    runApp(const EnvironmentSetupPage());
    return;
  }
  try {
    await SupabaseConfig.init();
    await SupabaseConfig.ensureSignedIn();
  } catch (e) {
    debugPrint('Supabase initialization failed: $e');
  }
  await NotificationService.instance.init();
  await NotificationService.instance.requestPermissions();
  await PushNotificationService.instance.initialize();
  runApp(const WeekendActivityApp());
}

class WeekendActivityApp extends StatelessWidget {
  const WeekendActivityApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppState(),
      child: MaterialApp(
        title: AppEnvironmentConfig.appName,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        home: const HomePage(),
        builder: (context, child) {
          if (!kIsWeb || child == null) return child ?? const SizedBox();
          return LayoutBuilder(
            builder: (context, constraints) {
              // Keep the browser experience close to the intended phone UI.
              // Small browser windows still use their full available width.
              if (constraints.maxWidth < 720) return child;
              return Container(
                color: const Color(0xFFE4F3E9),
                alignment: Alignment.center,
                child: Container(
                  width: 520,
                  height: double.infinity,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    border: Border.symmetric(
                      vertical: BorderSide(
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x260D3521),
                        blurRadius: 28,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: child,
                ),
              );
            },
          );
        },
      ),
    );
  }
}
