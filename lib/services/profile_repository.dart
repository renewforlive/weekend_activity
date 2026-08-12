import 'dart:io';

import 'package:path/path.dart' as p;

import '../models/models.dart';
import 'supabase_config.dart';

/// 個人資料、頭像與照片的遠端存取。
class ProfileRepository {
  static const _profiles = 'profiles';
  static const _photos = 'profile_photos';

  /// 讀取目前使用者的個人資料。
  ///
  /// 若後端尚無紀錄則補建一筆,避免後續 update 因為列不存在而靜默失效。
  Future<UserProfile?> fetchOrCreateProfile() async {
    final uid = SupabaseConfig.userId;
    if (uid == null) return null;

    var row = await SupabaseConfig.client
        .from(_profiles)
        .select()
        .eq('id', uid)
        .maybeSingle();

    // upsert 避免與 trigger 併發時撞主鍵。
    row ??= await SupabaseConfig.client
        .from(_profiles)
        .upsert({'id': uid})
        .select()
        .single();

    final photos = await fetchPhotos();
    final nickname = (row['nickname'] as String?)?.trim();
    final avatarPath = (row['avatar_path'] as String?)?.trim();

    // 有頭像路徑才組公開網址。
    String? avatarUrl;
    if (avatarPath != null && avatarPath.isNotEmpty) {
      avatarUrl = SupabaseConfig.client.storage
          .from(SupabaseConfig.photoBucket)
          .getPublicUrl(avatarPath);
    }

    final rawAvatarColor = (row['avatar_color'] as num?)?.toInt();
    final avatarColor =
        rawAvatarColor != null && UserProfile.isValidAvatarColor(rawAvatarColor)
        ? rawAvatarColor
        : UserProfile.defaultAvatarColor;

    // 舊帳號或空值一律補上預設色，確保每位使用者都恰有一個有效的頭像顏色。
    if (rawAvatarColor != avatarColor) {
      await SupabaseConfig.client
          .from(_profiles)
          .update({'avatar_color': avatarColor})
          .eq('id', uid);
    }

    return UserProfile(
      nickname: (nickname != null && nickname.isNotEmpty) ? nickname : '我',
      bio: (row['bio'] as String?) ?? '',
      avatarColorValue: avatarColor,
      avatarUrl: avatarUrl,
      avatarPath: avatarPath,
      photos: photos,
    );
  }

  /// 更新個人資料(只更新有傳入的欄位)。
  Future<void> updateProfile({
    String? nickname,
    String? bio,
    int? avatarColorValue,
  }) async {
    final uid = SupabaseConfig.userId;
    if (uid == null) return;

    final payload = <String, dynamic>{};
    if (nickname != null && nickname.trim().isNotEmpty) {
      payload['nickname'] = nickname.trim();
    }
    if (bio != null) payload['bio'] = bio.trim();
    if (avatarColorValue != null) payload['avatar_color'] = avatarColorValue;
    if (payload.isEmpty) return;

    // 用 update 只改指定欄位,避免 upsert 整列替換把 avatar_path 等欄位清掉。
    // 若列尚不存在(理論上 fetchOrCreateProfile 已建立)則補 insert。
    final updated = await SupabaseConfig.client
        .from(_profiles)
        .update(payload)
        .eq('id', uid)
        .select('id');

    if ((updated as List).isEmpty) {
      payload['id'] = uid;
      await SupabaseConfig.client.from(_profiles).insert(payload);
    }
  }

  /// 上傳頭像。成功回傳公開網址與 Storage 路徑。
  ///
  /// 舊頭像在新檔案上傳成功後才移除,避免上傳失敗卻已刪掉舊圖。
  Future<({String url, String path})?> uploadAvatar(
    String localPath, {
    String? oldPath,
  }) async {
    final uid = SupabaseConfig.userId;
    if (uid == null) return null;

    final file = File(localPath);
    if (!await file.exists()) return null;

    final ext = p.extension(localPath).isNotEmpty
        ? p.extension(localPath)
        : '.jpg';
    // 放在 avatar 子資料夾與照片牆區隔;第一層仍是 uid 以符合 Storage 政策。
    final storagePath =
        '$uid/avatar/${DateTime.now().millisecondsSinceEpoch}$ext';

    await SupabaseConfig.client.storage
        .from(SupabaseConfig.photoBucket)
        .upload(storagePath, file);

    // 列已由 fetchOrCreateProfile 保證存在,用 update 只改這個欄位。
    await SupabaseConfig.client
        .from(_profiles)
        .update({'avatar_path': storagePath})
        .eq('id', uid);

    // 新頭像已就位,清掉舊檔。
    if (oldPath != null && oldPath.isNotEmpty && oldPath != storagePath) {
      try {
        await SupabaseConfig.client.storage
            .from(SupabaseConfig.photoBucket)
            .remove([oldPath]);
      } catch (_) {
        // 舊檔清除失敗不影響結果。
      }
    }

    final url = SupabaseConfig.client.storage
        .from(SupabaseConfig.photoBucket)
        .getPublicUrl(storagePath);
    return (url: url, path: storagePath);
  }

  /// 移除頭像,回到色塊 + 首字樣式。
  Future<void> removeAvatar(String? storagePath) async {
    final uid = SupabaseConfig.userId;
    if (uid == null) return;

    // 用 update 而非 upsert:upsert 會做整列替換,可能把其他欄位重設,
    // 且 null 值在序列化時可能被省略導致清除失效。
    await SupabaseConfig.client
        .from(_profiles)
        .update({'avatar_path': null})
        .eq('id', uid);

    if (storagePath != null && storagePath.isNotEmpty) {
      try {
        await SupabaseConfig.client.storage
            .from(SupabaseConfig.photoBucket)
            .remove([storagePath]);
      } catch (_) {
        // Storage 清除失敗不阻擋欄位更新。
      }
    }
  }

  /// 讀取照片清單(依建立時間排序)。
  Future<List<ProfilePhoto>> fetchPhotos() async {
    final uid = SupabaseConfig.userId;
    if (uid == null) return [];

    return _fetchPhotosFor(uid);
  }

  /// Loads the public information shown when a recruitment member is selected.
  Future<PublicProfile?> fetchPublicProfile(String userId) async {
    final row = await SupabaseConfig.client
        .from(_profiles)
        .select('id, nickname, bio, avatar_color, avatar_path')
        .eq('id', userId)
        .maybeSingle();
    if (row == null) return null;

    final avatarPath = (row['avatar_path'] as String?)?.trim();
    final rawColor = (row['avatar_color'] as num?)?.toInt();
    final avatarColor =
        rawColor != null && UserProfile.isValidAvatarColor(rawColor)
        ? rawColor
        : UserProfile.defaultAvatarColor;
    final nickname = (row['nickname'] as String?)?.trim();
    List<ProfilePhoto> photos = const [];
    try {
      photos = await _fetchPhotosFor(userId);
    } catch (_) {
      // A profile remains viewable if its photo-wall policy is more restrictive.
    }

    return PublicProfile(
      userId: userId,
      nickname: nickname == null || nickname.isEmpty ? '使用者' : nickname,
      bio: (row['bio'] as String?) ?? '',
      avatarColorValue: avatarColor,
      avatarUrl: avatarPath == null || avatarPath.isEmpty
          ? null
          : SupabaseConfig.client.storage
                .from(SupabaseConfig.photoBucket)
                .getPublicUrl(avatarPath),
      photos: photos,
    );
  }

  Future<List<ProfilePhoto>> _fetchPhotosFor(String userId) async {
    final rows = await SupabaseConfig.client
        .from(_photos)
        .select()
        .eq('user_id', userId)
        .order('created_at');

    final list = <ProfilePhoto>[];
    for (final row in rows as List) {
      if (row is! Map) continue;
      final storagePath = row['storage_path'] as String?;
      final emoji = row['emoji'] as String?;
      final id = row['id'] as String?;
      if (storagePath != null && storagePath.isNotEmpty) {
        final url = SupabaseConfig.client.storage
            .from(SupabaseConfig.photoBucket)
            .getPublicUrl(storagePath);
        list.add(ProfilePhoto.remote(url, id: id, storagePath: storagePath));
      } else if (emoji != null && emoji.isNotEmpty) {
        list.add(ProfilePhoto.emoji(emoji, id: id));
      }
    }
    return list;
  }

  /// 上傳照片檔並寫入紀錄。回傳新增的照片(含公開網址)。
  Future<ProfilePhoto?> uploadPhoto(String localPath) async {
    final uid = SupabaseConfig.userId;
    if (uid == null) return null;

    final file = File(localPath);
    if (!await file.exists()) return null;

    // 路徑格式 {uid}/{timestamp}{ext},Storage 政策以第一層資料夾比對身分。
    final ext = p.extension(localPath).isNotEmpty
        ? p.extension(localPath)
        : '.jpg';
    final storagePath = '$uid/${DateTime.now().millisecondsSinceEpoch}$ext';

    await SupabaseConfig.client.storage
        .from(SupabaseConfig.photoBucket)
        .upload(storagePath, file);

    final inserted = await SupabaseConfig.client
        .from(_photos)
        .insert({'user_id': uid, 'storage_path': storagePath})
        .select()
        .single();

    final url = SupabaseConfig.client.storage
        .from(SupabaseConfig.photoBucket)
        .getPublicUrl(storagePath);
    return ProfilePhoto.remote(
      url,
      id: inserted['id'] as String?,
      storagePath: storagePath,
    );
  }

  /// 新增 emoji 佔位照片。
  Future<ProfilePhoto?> addEmojiPhoto(String emoji) async {
    final uid = SupabaseConfig.userId;
    if (uid == null) return null;

    final inserted = await SupabaseConfig.client
        .from(_photos)
        .insert({'user_id': uid, 'emoji': emoji})
        .select()
        .single();
    return ProfilePhoto.emoji(emoji, id: inserted['id'] as String?);
  }

  /// 刪除照片(同時移除 Storage 檔案)。
  Future<void> deletePhoto(ProfilePhoto photo) async {
    final uid = SupabaseConfig.userId;
    if (uid == null || photo.id == null) return;

    if (photo.storagePath != null) {
      try {
        await SupabaseConfig.client.storage
            .from(SupabaseConfig.photoBucket)
            .remove([photo.storagePath!]);
      } catch (_) {
        // Storage 刪除失敗不阻擋資料列刪除。
      }
    }
    await SupabaseConfig.client.from(_photos).delete().eq('id', photo.id!);
  }
}
