import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/app_state.dart';
import '../l10n/app_strings.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';
import '../utils/date_format.dart';
import '../widgets/recruitment_editor.dart';
import '../widgets/require_sign_in.dart';

/// 招募討論版:瀏覽揪團貼文、加入/退出、發起新招募。
class RecruitmentPage extends StatelessWidget {
  const RecruitmentPage({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final posts = state.recruitments;
    return Scaffold(
      appBar: AppBar(title: Text(AppStrings.recruitmentTitle)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _startRecruitment(context),
        icon: const Icon(Icons.campaign),
        label: Text(AppStrings.startRecruitment),
      ),
      body: RefreshIndicator(
        onRefresh: state.loadRemoteData,
        child: posts.isEmpty
            ? Stack(
                children: [
                  ListView(), // 讓下拉手勢在空清單也有效
                  _empty(),
                ],
              )
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
                itemCount: posts.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, i) => _PostCard(post: posts[i]),
              ),
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
          Text(AppStrings.recruitmentEmpty,
              textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textSecondary, height: 1.5)),
        ],
      ),
    );
  }
}

/// 發起招募。未登入時先引導登入,登入成功才開啟編輯表單。
Future<void> _startRecruitment(BuildContext context) async {
  if (!await requireSignIn(context)) return;
  if (!context.mounted) return;
  showRecruitmentEditor(context);
}

/// 加入招募。未登入時先引導登入。
Future<void> _join(BuildContext context, AppState state, RecruitmentPost post) async {
  if (!await requireSignIn(context)) return;
  await state.toggleJoin(post);
}

class _PostCard extends StatelessWidget {
  const _PostCard({required this.post});
  final RecruitmentPost post;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final joined = state.hasJoined(post);
    final full = post.isFull;
    final hosted = post.isHostedBy(state.currentUserId);
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
                      Row(
                        children: [
                          Text(post.author,
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                          if (hosted) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.accent.withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(AppStrings.hostedByMe,
                                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.accent)),
                            ),
                          ],
                        ],
                      ),
                      Text(_ago(post.createdAt),
                          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
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
                _Tag(icon: Icons.group, text: AppStrings.headcountLabel(post.joinedCount, post.headcount)),
                _Tag(icon: Icons.wc, text: AppStrings.genderLabel(post.genderPref)),
                _Tag(icon: Icons.payments, text: AppStrings.costLabel(post.cost)),
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
                      label: Text(AppStrings.joinedTapToLeave),
                      style: OutlinedButton.styleFrom(foregroundColor: AppColors.primaryDark),
                    )
                  : ElevatedButton.icon(
                      onPressed: full ? null : () => _join(context, state, post),
                      icon: Icon(full ? Icons.block : Icons.group_add),
                      label: Text(full ? AppStrings.full : AppStrings.join),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  static String _ago(DateTime t) {
    final diff = DateTime.now().difference(t);
    if (diff.inMinutes < 1) return AppStrings.justNow;
    if (diff.inMinutes < 60) return AppStrings.minutesAgo(diff.inMinutes);
    if (diff.inHours < 24) return AppStrings.hoursAgo(diff.inHours);
    if (diff.inDays < 7) return AppStrings.daysAgo(diff.inDays);
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