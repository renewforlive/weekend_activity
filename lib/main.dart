import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'data/app_state.dart';
import 'l10n/app_strings.dart';
import 'pages/home_page.dart';
import 'services/notification_service.dart';
import 'services/supabase_config.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await SupabaseConfig.init();
    await SupabaseConfig.ensureSignedIn();
  } catch (e) {
    debugPrint('Supabase initialization failed: $e');
  }
  await NotificationService.instance.init();
  await NotificationService.instance.requestPermissions();
  runApp(const WeekendActivityApp());
}

class WeekendActivityApp extends StatelessWidget {
  const WeekendActivityApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppState(),
      child: MaterialApp(
        title: AppStrings.appTitle,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        home: const HomePage(),
      ),
    );
  }
}
