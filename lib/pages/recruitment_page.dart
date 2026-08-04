import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/app_state.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';
import '../utils/date_format.dart';
import '../widgets/recruitment_editor.dart';

/// 招募討論版:瀏覽揪團貼文、加入/退出、發起新招募。
class RecruitmentPage extends StatelessWidget {
  const RecruitmentPage({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final posts = state.recruitments;
    return Scaffold(
      appBar: AppBar(title: const Text('招募討論版')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showRecruitmentEditor(context),
        icon: const Icon(Icons.campaign),
        label: const Text('發起招募'),
      ),
      body: posts.isEmpty
          ? _empty()
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
              itemCount: posts.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, i) => _PostCard(post: posts[i]),
            ),
    );
  }

  Widget _empty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.forum_outlined, size: 56, color: AppColors.textSecondary),
          const SizedBox(height: 12),
          Text('還沒有招募貼文,\n點右下角發起第一則揪團吧!',
              textAlign: TextAlign.center, style: TextStyle(color: AppColors.textSecondary, height: 1.5)),
        ],
      ),
    );
  }
}

class _PostCard extends StatelessWidget {
  const _PostCard({required this.post});
  final RecruitmentPost post;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final joined = state.hasJoined(post);
    final full = post.isFull;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: AppColors.soft,
                  child: Text(
                    post.author.characters.first,
                    style: const TextStyle(color: AppColors.primaryDark, fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(post.author,
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                      Text(_ago(post.createdAt),
                          style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(post.title,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            const SizedBox(height: 6),
            Text(post.content,
                style: TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.5)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _Tag(icon: Icons.group, text: '${post.joinedCount}/${post.headcount} 人'),
                _Tag(icon: Icons.wc, text: post.genderPref.label),
                _Tag(icon: Icons.payments, text: post.cost == 0 ? '免費' : 'NT\$ ${post.cost}'),
                if (post.relatedActivity != null)
                  _Tag(icon: Icons.place, text: post.relatedActivity!.city),
              ],
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: joined
                  ? OutlinedButton.icon(
                      onPressed: () => state.toggleJoin(post),
                      icon: const Icon(Icons.check_circle),
                      label: const Text('已加入(點擊退出)'),
                      style: OutlinedButton.styleFrom(foregroundColor: AppColors.primaryDark),
                    )
                  : ElevatedButton.icon(
                      onPressed: full ? null : () => state.toggleJoin(post),
                      icon: Icon(full ? Icons.block : Icons.group_add),
                      label: Text(full ? '人數已滿' : '我要加入'),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  static String _ago(DateTime t) {
    final diff = DateTime.now().difference(t);
    if (diff.inMinutes < 1) return '剛剛';
    if (diff.inMinutes < 60) return '${diff.inMinutes} 分鐘前';
    if (diff.inHours < 24) return '${diff.inHours} 小時前';
    if (diff.inDays < 7) return '${diff.inDays} 天前';
    return AppDate.monthDay(t);
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: AppColors.soft, borderRadius: BorderRadius.circular(10)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.primaryDark),
          const SizedBox(width: 4),
          Text(text, style: const TextStyle(fontSize: 12, color: AppColors.primaryDark, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}