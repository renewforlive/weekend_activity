import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/app_state.dart';
import '../theme/app_theme.dart';

/// 個人頁:頭像、照片、暱稱、自介、是否參與過活動、開啟招募次數。
class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  static const List<int> _avatarColors = [
    0xFF3BB273, 0xFFFF9F45, 0xFF7C6FF0, 0xFF4AA8D8, 0xFFE5896B, 0xFFEBA83A,
  ];

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final p = state.profile;
    return Scaffold(
      appBar: AppBar(
        title: const Text('個人頁'),
        actions: [
          IconButton(
            onPressed: () => _editProfile(context, state),
            icon: const Icon(Icons.edit_outlined, color: AppColors.primary),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Center(
            child: Column(
              children: [
                CircleAvatar(
                  radius: 48,
                  backgroundColor: Color(p.avatarColorValue),
                  child: Text(
                    p.nickname.characters.first,
                    style: const TextStyle(fontSize: 40, color: Colors.white, fontWeight: FontWeight.w800),
                  ),
                ),
                const SizedBox(height: 12),
                Text(p.nickname, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(p.bio, textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.5)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(child: _StatCard(icon: Icons.verified, label: '是否參與過活動', value: state.hasParticipated ? '已參與' : '尚未參與', color: state.hasParticipated ? AppColors.primary : AppColors.textSecondary)),
              const SizedBox(width: 12),
              Expanded(child: _StatCard(icon: Icons.campaign, label: '開啟招募次數', value: '${state.hostedRecruitmentCount} 次', color: AppColors.accent)),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              const Text('我的照片', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              // 照片區
              const Spacer(),
              TextButton.icon(
                onPressed: () => _addPhoto(context, state),
                icon: const Icon(Icons.add_a_photo_outlined, size: 18, color: AppColors.primary),
                label: const Text('新增', style: TextStyle(color: AppColors.primary)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _PhotoGrid(photos: p.photos, onRemove: state.removePhoto),
          const SizedBox(height: 24),
          const Text('頭像顏色', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 12,
            children: [
              for (final c in _avatarColors)
                GestureDetector(
                  onTap: () => state.updateProfile(avatarColorValue: c),
                  child: Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      color: Color(c),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: p.avatarColorValue == c ? AppColors.textPrimary : Colors.transparent,
                        width: 3,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _editProfile(BuildContext context, AppState state) async {
    final nickCtrl = TextEditingController(text: state.profile.nickname);
    final bioCtrl = TextEditingController(text: state.profile.bio);
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('編輯個人資料'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nickCtrl, decoration: const InputDecoration(labelText: '暱稱')),
            const SizedBox(height: 12),
            TextField(controller: bioCtrl, maxLines: 3, decoration: const InputDecoration(labelText: '自我介紹')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          ElevatedButton(
            onPressed: () {
              state.updateProfile(nickname: nickCtrl.text, bio: bioCtrl.text);
              Navigator.pop(ctx);
            },
            child: const Text('儲存'),
          ),
        ],
      ),
    );
  }

  Future<void> _addPhoto(BuildContext context, AppState state) async {
    const emojis = ['🌿', '🏞️', '☕', '🏃', '🎸', '🍜', '📸', '⛰️', '🏐', '🎯', '🌊', '🚴'];
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('挑一張照片(用圖示代表)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12, runSpacing: 12,
              children: [
                for (final e in emojis)
                  GestureDetector(
                    onTap: () { state.addPhoto(e); Navigator.pop(ctx); },
                    child: Container(
                      width: 56, height: 56,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: AppColors.soft, borderRadius: BorderRadius.circular(14)),
                      child: Text(e, style: const TextStyle(fontSize: 28)),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.icon, required this.label, required this.value, required this.color});
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          const SizedBox(height: 10),
          Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: color)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}

class _PhotoGrid extends StatelessWidget {
  const _PhotoGrid({required this.photos, required this.onRemove});
  final List<String> photos;
  final ValueChanged<int> onRemove;
  @override
  Widget build(BuildContext context) {
    if (photos.isEmpty) {
      return Container(
        height: 90,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16)),
        child: Text('還沒有照片,點右上角新增', style: TextStyle(color: AppColors.textSecondary)),
      );
    }
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: photos.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4, crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 1,
      ),
      itemBuilder: (context, i) => GestureDetector(
        onLongPress: () => onRemove(i),
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(color: AppColors.soft, borderRadius: BorderRadius.circular(14)),
          child: Text(photos[i], style: const TextStyle(fontSize: 30)),
        ),
      ),
    );
  }
}