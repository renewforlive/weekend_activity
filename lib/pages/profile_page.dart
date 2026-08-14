import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../data/app_state.dart';
import '../l10n/app_strings.dart';
import '../models/models.dart';
import '../services/local_file.dart';
import '../theme/app_theme.dart';
import '../widgets/profile_avatar.dart';
import '../widgets/account_section.dart';
import '../widgets/interest_tag_selector.dart';

/// 個人頁:頭像、照片(可拍照/選相簿)、暱稱、自介、是否參與過活動、開啟招募次數。
class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

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
          if (state.requiresProfileCompletion) ...[
            const _ProfileCompletionNotice(),
            const SizedBox(height: 16),
          ],
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
                Text(
                  p.nickname,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    p.bio,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                      height: 1.5,
                    ),
                  ),
                ),
                if (p.gender != ProfileGender.undisclosed || p.age != null) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8,
                    children: [
                      if (p.gender != ProfileGender.undisclosed)
                        _ProfileInfoChip(
                          icon: Icons.person_outline,
                          label: p.gender.label,
                        ),
                      if (p.age != null)
                        _ProfileInfoChip(
                          icon: Icons.cake_outlined,
                          label: '${p.age} 歲',
                        ),
                    ],
                  ),
                ],
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
                  value: state.hasParticipated
                      ? AppStrings.participated
                      : AppStrings.notParticipated,
                  color: state.hasParticipated
                      ? AppColors.primary
                      : AppColors.textSecondary,
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
          const Text(
            '感興趣的活動',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          _InterestTags(tags: p.interests),
          const SizedBox(height: 24),
          Row(
            children: [
              Text(
                AppStrings.myPhotos,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () => _addPhoto(context, state),
                icon: const Icon(
                  Icons.add_a_photo_outlined,
                  size: 18,
                  color: AppColors.primary,
                ),
                label: Text(
                  AppStrings.add,
                  style: const TextStyle(color: AppColors.primary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _PhotoGrid(photos: p.photos, onRemove: state.removePhoto),
          const SizedBox(height: 24),
          Text(
            AppStrings.avatarColor,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 12,
            children: [
              for (final c in UserProfile.avatarColors)
                Semantics(
                  button: true,
                  selected: p.avatarColorValue == c,
                  child: InkWell(
                    onTap: () => state.updateProfile(avatarColorValue: c),
                    customBorder: const CircleBorder(),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Color(c),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: p.avatarColorValue == c
                              ? AppColors.textPrimary
                              : Colors.transparent,
                          width: 3,
                        ),
                      ),
                      child: p.avatarColorValue == c
                          ? const Icon(
                              Icons.check,
                              color: Colors.white,
                              size: 20,
                            )
                          : null,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 24),
          const AccountSection(),
        ],
      ),
    );
  }

  Future<void> _editProfile(BuildContext context, AppState state) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => _EditProfilePage(state: state)),
    );
  }

  /// 頭像操作:拍照、從相簿選,已有頭像時可移除。
  Future<void> _avatarActions(BuildContext context, AppState state) async {
    final hasAvatar = state.profile.hasAvatar;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
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
                    Text(
                      AppStrings.setAvatar,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              ListTile(
                leading: const Icon(
                  Icons.photo_camera_outlined,
                  color: AppColors.primary,
                ),
                title: Text(AppStrings.takePhoto),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickAvatar(context, state, ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.photo_library_outlined,
                  color: AppColors.primary,
                ),
                title: Text(AppStrings.chooseFromGallery),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickAvatar(context, state, ImageSource.gallery);
                },
              ),
              if (hasAvatar && !state.isAuthenticated)
                ListTile(
                  leading: const Icon(
                    Icons.delete_outline,
                    color: AppColors.danger,
                  ),
                  title: Text(
                    AppStrings.removeAvatar,
                    style: const TextStyle(color: AppColors.danger),
                  ),
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
  Future<void> _pickAvatar(
    BuildContext context,
    AppState state,
    ImageSource source,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final picker = ImagePicker();
      final file = await picker.pickImage(
        source: source,
        maxWidth: 800, // 頭像不需要大圖
        imageQuality: 85,
      );
      if (file == null) return; // 使用者取消
      await state.uploadAvatar(file.path, bytes: await file.readAsBytes());
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(AppStrings.photoFailed)));
    }
  }

  /// 新增照片:可拍照、從相簿選,或用 emoji 佔位。
  Future<void> _addPhoto(BuildContext context, AppState state) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
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
                    Text(
                      AppStrings.pickPhoto,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              ListTile(
                leading: const Icon(
                  Icons.photo_camera_outlined,
                  color: AppColors.primary,
                ),
                title: Text(AppStrings.takePhoto),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImage(context, state, ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.photo_library_outlined,
                  color: AppColors.primary,
                ),
                title: Text(AppStrings.chooseFromGallery),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImage(context, state, ImageSource.gallery);
                },
              ),
              if (!state.isAuthenticated)
                ListTile(
                  leading: const Icon(
                    Icons.emoji_emotions_outlined,
                    color: AppColors.accent,
                  ),
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
  Future<void> _pickImage(
    BuildContext context,
    AppState state,
    ImageSource source,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final picker = ImagePicker();
      final file = await picker.pickImage(
        source: source,
        maxWidth: 1600,
        imageQuality: 85,
      );
      if (file == null) return; // 使用者取消
      await state.addPhotoFile(file.path, bytes: await file.readAsBytes());
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(AppStrings.photoFailed)));
    }
  }

  /// 用 emoji 當佔位照片。
  Future<void> _pickEmoji(BuildContext context, AppState state) async {
    const emojis = [
      '🌿',
      '🏞️',
      '☕',
      '🏃',
      '🎸',
      '🍜',
      '📸',
      '⛰️',
      '🏐',
      '🎯',
      '🌊',
      '🚴',
    ];
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppStrings.useEmoji,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final e in emojis)
                  GestureDetector(
                    onTap: () {
                      state.addPhoto(e);
                      Navigator.pop(ctx);
                    },
                    child: Container(
                      width: 56,
                      height: 56,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.soft,
                        borderRadius: BorderRadius.circular(14),
                      ),
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

class _EditProfilePage extends StatefulWidget {
  const _EditProfilePage({required this.state});

  final AppState state;

  @override
  State<_EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<_EditProfilePage> {
  late final TextEditingController _nickname;
  late final TextEditingController _bio;
  ProfileGender? _gender;
  DateTime? _birthDate;
  late final Set<InterestTag> _interests;

  @override
  void initState() {
    super.initState();
    final profile = widget.state.profile;
    _nickname = TextEditingController(text: profile.nickname);
    _bio = TextEditingController(text: profile.bio);
    _gender = profile.gender == ProfileGender.undisclosed
        ? null
        : profile.gender;
    _birthDate = profile.birthDate;
    _interests = profile.interests.toSet();
  }

  @override
  void dispose() {
    _nickname.dispose();
    _bio.dispose();
    super.dispose();
  }

  Future<void> _pickBirthDate() async {
    final today = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime(today.year - 25),
      firstDate: DateTime(1920),
      lastDate: DateTime(today.year - 13, today.month, today.day),
      helpText: '選擇出生年月日',
    );
    if (date != null && mounted) setState(() => _birthDate = date);
  }

  String _dateText(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';

  void _save() {
    if (_gender == null || _birthDate == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('請選擇性別並填寫出生年月日。')));
      return;
    }
    widget.state.updateProfile(
      nickname: _nickname.text,
      bio: _bio.text,
      gender: _gender,
      birthDate: _birthDate,
      interests: _interests,
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(AppStrings.editProfile)),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                children: [
                  TextField(
                    controller: _nickname,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(labelText: AppStrings.nickname),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _bio,
                    maxLines: 4,
                    decoration: InputDecoration(labelText: AppStrings.bio),
                  ),
                  const SizedBox(height: 22),
                  const Text(
                    '性別',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [ProfileGender.male, ProfileGender.female]
                        .map(
                          (item) => ChoiceChip(
                            label: Text(item.label),
                            selected: _gender == item,
                            onSelected: (_) => setState(() => _gender = item),
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 16),
                  InkWell(
                    onTap: _pickBirthDate,
                    borderRadius: BorderRadius.circular(14),
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: '出生年月日',
                        prefixIcon: Icon(Icons.cake_outlined),
                      ),
                      child: Text(
                        _birthDate == null ? '尚未填寫' : _dateText(_birthDate!),
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
                  const Text(
                    '感興趣的活動',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  InterestTagSelector(
                    selected: _interests,
                    onChanged: (tag) => setState(() {
                      if (_interests.contains(tag)) {
                        _interests.remove(tag);
                      } else {
                        _interests.add(tag);
                      }
                    }),
                  ),
                ],
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _save,
                    icon: const Icon(Icons.check),
                    label: Text(AppStrings.save),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileCompletionNotice extends StatelessWidget {
  const _ProfileCompletionNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: .13),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.accent.withValues(alpha: .35)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.assignment_ind_outlined, color: AppColors.accent),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              '請完成個人資料：選擇性別、填寫生日與上傳頭像，才能繼續使用 App。',
              style: TextStyle(color: AppColors.textPrimary, height: 1.45),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

/// 照片格線。實際照片用 Image.file 顯示,emoji 用文字顯示。
/// 點擊放大預覽,長按刪除。
class _ProfileInfoChip extends StatelessWidget {
  const _ProfileInfoChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.soft,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppColors.primaryDark),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.primaryDark,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _InterestTags extends StatelessWidget {
  const _InterestTags({required this.tags});

  final Set<InterestTag> tags;

  @override
  Widget build(BuildContext context) {
    if (tags.isEmpty) {
      return const Text(
        '尚未選擇興趣活動',
        style: TextStyle(color: AppColors.textSecondary),
      );
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: tags
          .map(
            (tag) => Chip(
              avatar: Icon(tag.icon, size: 16, color: AppColors.primaryDark),
              label: Text(tag.label),
            ),
          )
          .toList(),
    );
  }
}

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
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          AppStrings.noPhotos,
          style: const TextStyle(color: AppColors.textSecondary),
        ),
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
            crossAxisCount: 4,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 1,
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
        Text(
          AppStrings.longPressToRemove,
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
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
                : _localImage(photo.value, fit: BoxFit.contain),
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
    child: const Icon(
      Icons.broken_image_outlined,
      color: AppColors.textSecondary,
    ),
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
          _localImage(photo.value, fit: BoxFit.cover),
          Container(
            color: Colors.black26,
            alignment: Alignment.center,
            child: const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
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

Widget _localImage(String path, {required BoxFit fit}) {
  final image = localFileImage(path);
  if (image == null) {
    return Container(
      color: AppColors.soft,
      alignment: Alignment.center,
      child: const Icon(Icons.broken_image_outlined),
    );
  }
  return Image(image: image, fit: fit);
}
