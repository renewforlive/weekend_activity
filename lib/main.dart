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
      ),
    );
  }
}
