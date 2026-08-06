import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../data/app_state.dart';
import '../l10n/app_strings.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';
import '../widgets/profile_avatar.dart';

/// 個人頁:頭像、照片(可拍照/選相簿)、暱稱、自介、是否參與過活動、開啟招募次數。
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
        title: Text(AppStrings.profileTitle),
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
                GestureDetector(
                  onTap: () => _avatarActions(context, state),
                  child: ProfileAvatar(
                    profile: p,
                    uploading: state.isAvatarUploading,
                  ),
                ),
                const SizedBox(height: 12),
                Text(p.nickname,
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(p.bio,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.5)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  icon: Icons.verified,
                  label: AppStrings.participatedLabel,
                  value: state.hasParticipated ? AppStrings.participated : AppStrings.notParticipated,
                  color: state.hasParticipated ? AppColors.primary : AppColors.textSecondary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  icon: Icons.campaign,
                  label: AppStrings.hostedCountLabel,
                  value: AppStrings.timesLabel(state.hostedRecruitmentCount),
                  color: AppColors.accent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Text(AppStrings.myPhotos,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              const Spacer(),
              TextButton.icon(
                onPressed: () => _addPhoto(context, state),
                icon: const Icon(Icons.add_a_photo_outlined, size: 18, color: AppColors.primary),
                label: Text(AppStrings.add, style: const TextStyle(color: AppColors.primary)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _PhotoGrid(photos: p.photos, onRemove: state.removePhoto),
          const SizedBox(height: 24),
          Text(AppStrings.avatarColor,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
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
        title: Text(AppStrings.editProfile),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nickCtrl, decoration: InputDecoration(labelText: AppStrings.nickname)),
            const SizedBox(height: 12),
            TextField(controller: bioCtrl, maxLines: 3, decoration: InputDecoration(labelText: AppStrings.bio)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(AppStrings.cancel)),
          ElevatedButton(
            onPressed: () {
              state.updateProfile(nickname: nickCtrl.text, bio: bioCtrl.text);
              Navigator.pop(ctx);
            },
            child: Text(AppStrings.save),
          ),
        ],
      ),
    );
  }

  /// 頭像操作:拍照、從相簿選,已有頭像時可移除。
  Future<void> _avatarActions(BuildContext context, AppState state) async {
    final hasAvatar = state.profile.hasAvatar;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: Row(
                  children: [
                    Text(AppStrings.setAvatar,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                  ],
                ),
              ),
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined, color: AppColors.primary),
                title: Text(AppStrings.takePhoto),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickAvatar(context, state, ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined, color: AppColors.primary),
                title: Text(AppStrings.chooseFromGallery),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickAvatar(context, state, ImageSource.gallery);
                },
              ),
              if (hasAvatar)
                ListTile(
                  leading: const Icon(Icons.delete_outline, color: AppColors.danger),
                  title: Text(AppStrings.removeAvatar, style: const TextStyle(color: AppColors.danger)),
                  onTap: () {
                    Navigator.pop(ctx);
                    state.removeAvatar();
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// 取得頭像圖片並上傳。
  Future<void> _pickAvatar(BuildContext context, AppState state, ImageSource source) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final picker = ImagePicker();
      final file = await picker.pickImage(
        source: source,
        maxWidth: 800, // 頭像不需要大圖
        imageQuality: 85,
      );
      if (file == null) return; // 使用者取消
      await state.uploadAvatar(file.path);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(AppStrings.photoFailed)));
    }
  }

  /// 新增照片:可拍照、從相簿選,或用 emoji 佔位。
  Future<void> _addPhoto(BuildContext context, AppState state) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: Row(
                  children: [
                    Text(AppStrings.pickPhoto,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                  ],
                ),
              ),
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined, color: AppColors.primary),
                title: Text(AppStrings.takePhoto),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImage(context, state, ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined, color: AppColors.primary),
                title: Text(AppStrings.chooseFromGallery),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImage(context, state, ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const Icon(Icons.emoji_emotions_outlined, color: AppColors.accent),
                title: Text(AppStrings.useEmoji),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickEmoji(context, state);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 從相機或相簿取得照片。
  Future<void> _pickImage(BuildContext context, AppState state, ImageSource source) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final picker = ImagePicker();
      final file = await picker.pickImage(
        source: source,
        maxWidth: 1600,
        imageQuality: 85,
      );
      if (file == null) return; // 使用者取消
      state.addPhotoFile(file.path);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(AppStrings.photoFailed)));
    }
  }

  /// 用 emoji 當佔位照片。
  Future<void> _pickEmoji(BuildContext context, AppState state) async {
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
            Text(AppStrings.useEmoji, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12, runSpacing: 12,
              children: [
                for (final e in emojis)
                  GestureDetector(
                    onTap: () {
                      state.addPhoto(e);
                      Navigator.pop(ctx);
                    },
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
          Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}

/// 照片格線。實際照片用 Image.file 顯示,emoji 用文字顯示。
/// 點擊放大預覽,長按刪除。
class _PhotoGrid extends StatelessWidget {
  const _PhotoGrid({required this.photos, required this.onRemove});
  final List<ProfilePhoto> photos;
  final ValueChanged<int> onRemove;

  @override
  Widget build(BuildContext context) {
    if (photos.isEmpty) {
      return Container(
        height: 90,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16)),
        child: Text(AppStrings.noPhotos, style: const TextStyle(color: AppColors.textSecondary)),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: photos.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4, crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 1,
          ),
          itemBuilder: (context, i) => GestureDetector(
            onTap: () => _preview(context, photos[i]),
            onLongPress: () => onRemove(i),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: _PhotoTile(photo: photos[i]),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(AppStrings.longPressToRemove,
            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
      ],
    );
  }

  /// 點擊放大預覽(僅圖片,emoji 不預覽)。
  void _preview(BuildContext context, ProfilePhoto photo) {
    if (!photo.isImage) return;
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: GestureDetector(
          onTap: () => Navigator.pop(ctx),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: photo.isRemote
                ? Image.network(photo.value, fit: BoxFit.contain)
                : Image.file(File(photo.value), fit: BoxFit.contain),
          ),
        ),
      ),
    );
  }
}

/// 單張照片格。遠端照片用 Image.network,本機檔案(上傳中)用 Image.file,
/// emoji 用文字。
class _PhotoTile extends StatelessWidget {
  const _PhotoTile({required this.photo});
  final ProfilePhoto photo;

  Widget get _broken => Container(
        color: AppColors.soft,
        alignment: Alignment.center,
        child: const Icon(Icons.broken_image_outlined, color: AppColors.textSecondary),
      );

  @override
  Widget build(BuildContext context) {
    if (photo.isRemote) {
      return Image.network(
        photo.value,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return Container(color: AppColors.soft);
        },
        errorBuilder: (context, _, _) => _broken,
      );
    }
    if (photo.isFile) {
      // 上傳中的暫時狀態,疊一個進度指示。
      return Stack(
        fit: StackFit.expand,
        children: [
          Image.file(File(photo.value), fit: BoxFit.cover, errorBuilder: (context, _, _) => _broken),
          Container(
            color: Colors.black26,
            alignment: Alignment.center,
            child: const SizedBox(
              width: 20, height: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            ),
          ),
        ],
      );
    }
    return Container(
      color: AppColors.soft,
      alignment: Alignment.center,
      child: Text(photo.value, style: const TextStyle(fontSize: 30)),
    );
  }
}
