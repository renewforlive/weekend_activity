import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../data/app_state.dart';
import '../models/escape_room_venue.dart';
import '../theme/app_theme.dart';
import '../utils/date_format.dart';
import '../utils/official_website.dart';

class EscapeRoomDetailPage extends StatelessWidget {
  const EscapeRoomDetailPage({super.key, required this.venue});
  final EscapeRoomVenue venue;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(venue.name, overflow: TextOverflow.ellipsis)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF7C3AED).withValues(alpha: .1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                const Icon(Icons.key_outlined, color: Color(0xFF7C3AED), size: 29),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    venue.summary,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      height: 1.45,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _InfoRow(icon: Icons.place_outlined, label: '地址', value: venue.address),
          _InfoRow(icon: Icons.verified_outlined, label: '資料核實', value: venue.verifiedAt),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: () => openOfficialWebsite(
              context,
              url: venue.officialUrl,
              nativePageBuilder: (_) => _EscapeRoomWebViewPage(
                title: venue.name,
                url: venue.officialUrl,
              ),
            ),
            icon: const Icon(Icons.open_in_new, size: 18),
            label: const Text('查看官方頁面／預約'),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: AppTheme.buttonHeight,
            child: ElevatedButton.icon(
              onPressed: () => _pickDateAndSchedule(context),
              icon: const Icon(Icons.event_available),
              label: const Text('排入行程'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickDateAndSchedule(BuildContext context) async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null || !context.mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 14, minute: 0),
    );
    if (time == null || !context.mounted) return;
    final at = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    await context.read<AppState>().addEscapeRoomToSchedule(venue, at);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${venue.name}  ${AppDate.monthDayWeekTime(at)}')),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppColors.primary, size: 18),
        const SizedBox(width: 11),
        SizedBox(
          width: 70,
          child: Text(label, style: const TextStyle(color: AppColors.textSecondary)),
        ),
        Expanded(child: Text(value, style: const TextStyle(color: AppColors.textPrimary))),
      ],
    ),
  );
}

class _EscapeRoomWebViewPage extends StatefulWidget {
  const _EscapeRoomWebViewPage({required this.title, required this.url});
  final String title;
  final String url;

  @override
  State<_EscapeRoomWebViewPage> createState() => _EscapeRoomWebViewPageState();
}

class _EscapeRoomWebViewPageState extends State<_EscapeRoomWebViewPage> {
  late final WebViewController _controller;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (_) => setState(() => _loading = true),
        onPageFinished: (_) => setState(() => _loading = false),
      ))
      ..loadRequest(Uri.parse(widget.url));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.title, overflow: TextOverflow.ellipsis)),
    body: Stack(children: [
      WebViewWidget(controller: _controller),
      if (_loading) const LinearProgressIndicator(),
    ]),
  );
}
