import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/app_state.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';
import '../utils/date_format.dart';

/// 已預約頁:加入或發起招募、以及排入活動後的預約總覽。
class BookedPage extends StatelessWidget {
  const BookedPage({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final bookings = state.bookings;
    final totalCost = bookings.fold<int>(0, (sum, b) => sum + b.cost);
    return Scaffold(
      appBar: AppBar(title: const Text('已預約行程')),
      body: bookings.isEmpty
          ? _empty()
          : Column(
              children: [
                _Summary(count: bookings.length, totalCost: totalCost),
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    itemCount: bookings.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, i) => _BookingCard(booking: bookings[i]),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _empty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.bookmark_border, size: 56, color: AppColors.textSecondary),
          const SizedBox(height: 12),
          Text('還沒有預約,\n排入活動或加入招募後會出現在這裡!',
              textAlign: TextAlign.center, style: TextStyle(color: AppColors.textSecondary, height: 1.5)),
        ],
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.count, required this.totalCost});
  final int count;
  final int totalCost;
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [AppColors.primary, AppColors.primaryDark]),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          _stat('預約數', '$count'),
          Container(width: 1, height: 36, color: Colors.white24),
          _stat('預估花費', 'NT\$ $totalCost'),
        ],
      ),
    );
  }

  Widget _stat(String label, String value) {
    return Expanded(
      child: Column(
        children: [
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 13)),
        ],
      ),
    );
  }
}

class _BookingCard extends StatelessWidget {
  const _BookingCard({required this.booking});
  final Booking booking;

  @override
  Widget build(BuildContext context) {
    final color = _sourceColor(booking.source);
    final dateStr = booking.date == null ? '時間待定' : AppDate.monthDayWeek(booking.date!);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
              child: Icon(_sourceIcon(booking.source), color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(booking.title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
                        child: Text(booking.source.label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
                      ),
                      const SizedBox(width: 8),
                      Text(dateStr, style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                      if (booking.city != null) ...[
                        const SizedBox(width: 6),
                        Text('· ${booking.city}', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            Text(booking.cost == 0 ? '免費' : 'NT\$ ${booking.cost}',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: booking.cost == 0 ? AppColors.primaryDark : AppColors.accent)),
          ],
        ),
      ),
    );
  }

  Color _sourceColor(BookingSource s) => switch (s) {
        BookingSource.hosted => AppColors.accent,
        BookingSource.joined => AppColors.primary,
        BookingSource.activity => const Color(0xFF7C6FF0),
      };

  IconData _sourceIcon(BookingSource s) => switch (s) {
        BookingSource.hosted => Icons.campaign,
        BookingSource.joined => Icons.group_add,
        BookingSource.activity => Icons.event_available,
      };
}