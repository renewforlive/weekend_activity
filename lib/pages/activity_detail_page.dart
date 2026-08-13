import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../data/app_state.dart';
import '../l10n/app_strings.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';
import '../utils/date_format.dart';
import '../utils/official_website.dart';
import '../widgets/recruitment_editor.dart';
import '../widgets/schedule_time_picker.dart';

class ActivityDetailPage extends StatelessWidget {
  const ActivityDetailPage({super.key, required this.activity});
  final Activity activity;

  @override
  Widget build(BuildContext context) {
    final url = activity.resolvedDetailsUrl;
    final scheduled = context.watch<AppState>().isScheduled(activity);
    return Scaffold(
      appBar: AppBar(title: const Text('活動詳情')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: activity.category.color.withValues(alpha: .15),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          activity.category.icon,
                          color: activity.category.color,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          activity.title,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _DetailRow(
                    Icons.event_outlined,
                    '日期',
                    AppDate.monthDayWeek(activity.date),
                  ),
                  _DetailRow(
                    Icons.place_outlined,
                    '地點',
                    '${activity.city}・${activity.venue}',
                  ),
                  _DetailRow(
                    Icons.payments_outlined,
                    '費用',
                    activity.cost == 0 ? '免費' : 'NT\$ ${activity.cost}',
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Divider(),
                  ),
                  const Text(
                    '活動介紹',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    activity.description,
                    style: const TextStyle(
                      height: 1.6,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  if (url.isNotEmpty) ...[
                    const SizedBox(height: 22),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => openOfficialWebsite(
                          context,
                          url: url,
                          nativePageBuilder: (_) => ActivityWebViewPage(
                            title: activity.title,
                            url: url,
                          ),
                        ),
                        icon: const Icon(Icons.open_in_new),
                        label: Text(AppStrings.openWebsite),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: scheduled
                              ? null
                              : () => showScheduleTimePicker(
                                  context,
                                  activity: activity,
                                ),
                          icon: Icon(
                            scheduled ? Icons.check : Icons.add_task,
                            size: 18,
                          ),
                          label: Text(
                            scheduled
                                ? AppStrings.scheduledAlready
                                : AppStrings.addToSchedule,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => showRecruitmentEditor(
                            context,
                            relatedActivity: activity,
                          ),
                          icon: const Icon(Icons.campaign_outlined, size: 18),
                          label: Text(AppStrings.startRecruitment),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.accent,
                            side: const BorderSide(color: AppColors.accent),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow(this.icon, this.label, this.value);
  final IconData icon;
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppColors.primaryDark),
        const SizedBox(width: 9),
        SizedBox(
          width: 44,
          child: Text(
            label,
            style: const TextStyle(color: AppColors.textSecondary),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    ),
  );
}

class ActivityWebViewPage extends StatefulWidget {
  const ActivityWebViewPage({
    super.key,
    required this.title,
    required this.url,
  });
  final String title;
  final String url;
  @override
  State<ActivityWebViewPage> createState() => _ActivityWebViewPageState();
}

class _ActivityWebViewPageState extends State<ActivityWebViewPage> {
  late final WebViewController _controller;
  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..loadRequest(Uri.parse(widget.url));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.title)),
    body: WebViewWidget(controller: _controller),
  );
}
