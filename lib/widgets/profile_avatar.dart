import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/local_file.dart';
import '../theme/app_theme.dart';

/// 個人頁頭像。有設定圖片就顯示照片,否則以色塊 + 暱稱首字代替。
/// 右下角相機圖示提示可點擊更換。
class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({
    super.key,
    required this.profile,
    this.uploading = false,
    this.radius = 48,
  });

  final UserProfile profile;

  /// 上傳中時疊上進度指示。
  final bool uploading;

  final double radius;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ClipOval(
          child: SizedBox(
            width: radius * 2,
            height: radius * 2,
            child: _content(),
          ),
        ),
        if (uploading)
          Positioned.fill(
            child: ClipOval(
              child: Container(
                color: Colors.black38,
                alignment: Alignment.center,
                child: const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                ),
              ),
            ),
          ),
        // 可點擊更換的提示
        Positioned(
          right: 0,
          bottom: 0,
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppColors.surface,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.background, width: 2),
            ),
            child: const Icon(Icons.photo_camera, size: 16, color: AppColors.primary),
          ),
        ),
      ],
    );
  }

  Widget _content() {
    if (!profile.hasAvatar) return _fallback();

    final url = profile.avatarUrl!;
    // 上傳中的樂觀更新會先放本機路徑,此時用 Image.file 顯示。
    if (!url.startsWith('http')) {
      final image = localFileImage(url);
      if (image == null) return _fallback();
      return Image(
        image: image,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _fallback(),
      );
    }
    return Image.network(
      url,
      fit: BoxFit.cover,
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return Container(color: AppColors.soft);
      },
      errorBuilder: (_, _, _) => _fallback(),
    );
  }

  /// 沒有頭像(或載入失敗)時的色塊 + 暱稱首字。
  Widget _fallback() {
    final name = profile.nickname.trim();
    final initial = name.isNotEmpty ? name.characters.first : '我';
    return Container(
      color: Color(profile.avatarColorValue),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: TextStyle(
          fontSize: radius * 0.83,
          color: Colors.white,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
