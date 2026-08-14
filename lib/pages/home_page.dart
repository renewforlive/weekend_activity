import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/app_state.dart';
import '../l10n/app_strings.dart';
import '../theme/app_theme.dart';
import 'activities_page.dart';
import 'booked_page.dart';
import 'profile_page.dart';
import 'recruitment_page.dart';
import 'schedule_page.dart';

/// 底部 5 分頁容器:活動 / 行程 / 招募(中) / 已預約 / 個人頁。
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _index = 0;
  String? _shownError;
  bool _completionPromptShown = false;

  static const _pages = [
    ActivitiesPage(),
    SchedulePage(),
    RecruitmentPage(),
    BookedPage(),
    ProfilePage(),
  ];

  /// 統一顯示同步錯誤,避免各頁重複處理。
  void _watchSyncError(AppState state) {
    final err = state.syncError;
    if (err == null || err == _shownError) return;
    _shownError = err;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(err),
          backgroundColor: AppColors.danger,
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: '關閉',
            textColor: Colors.white,
            onPressed: () {},
          ),
        ),
      );
      state.clearSyncError();
      _shownError = null;
    });
  }

  void _enforceProfileCompletion(AppState state) {
    if (!state.requiresProfileCompletion) {
      _completionPromptShown = false;
      return;
    }
    if (_completionPromptShown) return;
    _completionPromptShown = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || !state.requiresProfileCompletion) {
        _completionPromptShown = false;
        return;
      }
      // 登入頁仍在最上層時，不能先在 HomePage 開啟對話框；否則登入
      // 頁的 pop 會先關掉這個對話框，造成使用者留在登入頁的假象。
      if (ModalRoute.of(context)?.isCurrent != true) {
        _completionPromptShown = false;
        Future<void>.delayed(const Duration(milliseconds: 350), () {
          if (mounted) setState(() {});
        });
        return;
      }
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          title: const Text('請完成個人資料'),
          content: const Text('為維持招募社群的基本辨識與互動品質，請先填寫性別、出生年月日，並上傳頭像。'),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                setState(() => _index = 4);
              },
              child: const Text('前往填寫'),
            ),
          ],
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    _watchSyncError(state);
    _enforceProfileCompletion(state);
    final restricted = state.requiresProfileCompletion;
    return Scaffold(
      body: IndexedStack(index: restricted ? 4 : _index, children: _pages),
      bottomNavigationBar: NavigationBarTheme(
        data: NavigationBarThemeData(
          backgroundColor: AppColors.surface,
          indicatorColor: AppColors.soft,
          labelTextStyle: WidgetStateProperty.resolveWith(
            (states) => TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: states.contains(WidgetState.selected)
                  ? AppColors.primaryDark
                  : AppColors.textSecondary,
            ),
          ),
        ),
        child: NavigationBar(
          height: 68,
          selectedIndex: _index,
          onDestinationSelected: restricted
              ? null
              : (i) => setState(() => _index = i),
          destinations: [
            NavigationDestination(
              icon: const Icon(Icons.explore_outlined),
              selectedIcon: const Icon(Icons.explore, color: AppColors.primary),
              label: AppStrings.navActivities,
            ),
            NavigationDestination(
              icon: const Icon(Icons.event_note_outlined),
              selectedIcon: const Icon(
                Icons.event_note,
                color: AppColors.primary,
              ),
              label: AppStrings.navSchedule,
            ),
            NavigationDestination(
              icon: const Icon(Icons.groups_outlined),
              selectedIcon: const Icon(Icons.groups, color: AppColors.primary),
              label: AppStrings.navRecruitment,
            ),
            NavigationDestination(
              icon: const Icon(Icons.bookmark_outline),
              selectedIcon: const Icon(
                Icons.bookmark,
                color: AppColors.primary,
              ),
              label: AppStrings.navBooked,
            ),
            NavigationDestination(
              icon: const Icon(Icons.person_outline),
              selectedIcon: const Icon(Icons.person, color: AppColors.primary),
              label: AppStrings.navProfile,
            ),
          ],
        ),
      ),
    );
  }
}
