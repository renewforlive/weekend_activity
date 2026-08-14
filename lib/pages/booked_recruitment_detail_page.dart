import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/app_state.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';
import '../utils/date_format.dart';

class BookedRecruitmentDetailPage extends StatelessWidget {
  const BookedRecruitmentDetailPage({super.key, required this.recruitmentId});

  final String recruitmentId;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    RecruitmentPost? post;
    for (final item in state.recruitments) {
      if (item.id == recruitmentId) {
        post = item;
        break;
      }
    }
    if (post == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('招募詳情')),
        body: const Center(child: Text('這個招募已不存在或無法讀取。')),
      );
    }

    final canSeeMeeting = post.canSeeMeetingInfo(state.currentUserId);
    return Scaffold(
      appBar: AppBar(title: const Text('招募詳情')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: [
          _InfoCard(post: post, canSeeMeeting: canSeeMeeting),
          const SizedBox(height: 16),
          _MembersCard(post: post),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.post, required this.canSeeMeeting});

  final RecruitmentPost post;
  final bool canSeeMeeting;

  @override
  Widget build(BuildContext context) {
    final activity = post.relatedActivity;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              post.title,
              style: const TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '招募者：${post.author}',
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 14),
            Text(
              post.content,
              style: const TextStyle(
                fontSize: 15,
                height: 1.55,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _Tag(
                  Icons.group_outlined,
                  '${post.joinedCount} / ${post.headcount} 人',
                ),
                _Tag(
                  Icons.payments_outlined,
                  post.cost == 0 ? '免費' : 'NT\$ ${post.cost}',
                ),
                _Tag(Icons.wc_outlined, _genderText(post.genderPref)),
                if (activity != null && activity.city.isNotEmpty)
                  _Tag(Icons.place_outlined, activity.city),
                if (activity?.date != null)
                  _Tag(
                    Icons.calendar_today_outlined,
                    AppDate.monthDayWeek(activity!.date),
                  ),
              ],
            ),
            if (canSeeMeeting && post.hasMeetingInfo) ...[
              const SizedBox(height: 18),
              const Divider(),
              const SizedBox(height: 8),
              const Text(
                '集合資訊',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: AppColors.primaryDark,
                ),
              ),
              if (post.meetingPoint.isNotEmpty)
                _InfoRow(Icons.place_outlined, '地點', post.meetingPoint),
              if (post.meetingTime != null)
                _InfoRow(
                  Icons.schedule_outlined,
                  '時間',
                  AppDate.monthDayWeekTime(post.meetingTime!),
                ),
              if (post.contactInfo.isNotEmpty)
                _InfoRow(
                  Icons.contact_phone_outlined,
                  '聯絡方式',
                  post.contactInfo,
                ),
            ],
          ],
        ),
      ),
    );
  }

  String _genderText(GenderPref value) => switch (value) {
    GenderPref.male => '限男性',
    GenderPref.female => '限女性',
    GenderPref.balanced => '男女均衡',
    GenderPref.any => '不限性別',
  };
}

class _MembersCard extends StatelessWidget {
  const _MembersCard({required this.post});

  final RecruitmentPost post;

  @override
  Widget build(BuildContext context) {
    final members = post.activeMembers;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.people_alt_outlined,
                  color: AppColors.primaryDark,
                ),
                const SizedBox(width: 8),
                Text(
                  '加入成員 (${members.length})',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...members.map((member) => _MemberRow(member: member)),
          ],
        ),
      ),
    );
  }
}

class _MemberRow extends StatefulWidget {
  const _MemberRow({required this.member});
  final RecruitmentMember member;

  @override
  State<_MemberRow> createState() => _MemberRowState();
}

class _MemberRowState extends State<_MemberRow> {
  late final Future<PublicProfile?> _profileFuture;

  @override
  void initState() {
    super.initState();
    _profileFuture = context.read<AppState>().fetchPublicProfile(
      widget.member.userId,
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PublicProfile?>(
      future: _profileFuture,
      builder: (context, snapshot) {
        final profile = snapshot.data;
        final name = profile?.nickname ?? widget.member.nickname;
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(vertical: 4),
          leading: _PublicAvatar(
            profile: profile,
            fallbackName: name,
            radius: 23,
          ),
          title: Text(
            name,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          subtitle: Text(
            _memberDetail(widget.member),
            style: const TextStyle(color: AppColors.textSecondary),
          ),
          trailing: const Icon(
            Icons.chevron_right,
            color: AppColors.textSecondary,
          ),
          onTap: profile == null
              ? null
              : () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => PublicProfilePage(
                      profile: profile,
                      participationCount: context
                          .read<AppState>()
                          .participationCountFor(profile.userId),
                    ),
                  ),
                ),
        );
      },
    );
  }

  String _memberDetail(RecruitmentMember member) {
    final parts = <String>[member.isApproved ? '已加入' : '申請中'];
    if (member.guestCount > 0) parts.add('同行 ${member.guestCount} 人');
    return parts.join('・');
  }
}

class PublicProfilePage extends StatelessWidget {
  const PublicProfilePage({
    super.key,
    required this.profile,
    required this.participationCount,
  });

  final PublicProfile profile;
  final int participationCount;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('個人資料')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 28),
        children: [
          Center(
            child: _PublicAvatar(
              profile: profile,
              fallbackName: profile.nickname,
              radius: 48,
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              profile.nickname,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              profile.bio.trim().isEmpty ? '這位使用者還沒有留下自我介紹。' : profile.bio,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
          ),
          if (profile.gender != ProfileGender.undisclosed ||
              profile.age != null) ...[
            const SizedBox(height: 10),
            Center(
              child: Wrap(
                spacing: 8,
                children: [
                  if (profile.gender != ProfileGender.undisclosed)
                    Chip(
                      avatar: const Icon(Icons.person_outline, size: 16),
                      label: Text(profile.gender.label),
                    ),
                  if (profile.age != null)
                    Chip(
                      avatar: const Icon(Icons.cake_outlined, size: 16),
                      label: Text('${profile.age} 歲'),
                    ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.soft,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: [
                Text(
                  '$participationCount',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primaryDark,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  '參與活動次數',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          const Text(
            '感興趣的活動',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          if (profile.interests.isEmpty)
            const Text(
              '尚未選擇興趣活動',
              style: TextStyle(color: AppColors.textSecondary),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: profile.interests
                  .map(
                    (tag) => Chip(
                      avatar: Icon(tag.icon, size: 16),
                      label: Text(tag.label),
                    ),
                  )
                  .toList(),
            ),
          const SizedBox(height: 22),
          const Text(
            '照片牆',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          if (profile.photos.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text(
                  '尚未分享照片',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
            )
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: profile.photos.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemBuilder: (_, index) =>
                  _PhotoTile(photo: profile.photos[index]),
            ),
        ],
      ),
    );
  }
}

class _PublicAvatar extends StatelessWidget {
  const _PublicAvatar({
    required this.profile,
    required this.fallbackName,
    required this.radius,
  });
  final PublicProfile? profile;
  final String fallbackName;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final name = profile?.nickname ?? fallbackName;
    final color = profile?.avatarColorValue ?? UserProfile.defaultAvatarColor;
    final url = profile?.avatarUrl;
    return CircleAvatar(
      radius: radius,
      backgroundColor: Color(color),
      backgroundImage: url == null || url.isEmpty ? null : NetworkImage(url),
      child: url == null || url.isEmpty
          ? Text(
              name.isEmpty ? '?' : name.characters.first,
              style: TextStyle(
                fontSize: radius * .8,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            )
          : null,
    );
  }
}

class _PhotoTile extends StatelessWidget {
  const _PhotoTile({required this.photo});
  final ProfilePhoto photo;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: photo.isEmoji
          ? Container(
              color: AppColors.soft,
              alignment: Alignment.center,
              child: Text(photo.value, style: const TextStyle(fontSize: 35)),
            )
          : Image.network(
              photo.value,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Container(color: AppColors.soft),
            ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag(this.icon, this.text);
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
    decoration: BoxDecoration(
      color: AppColors.soft,
      borderRadius: BorderRadius.circular(9),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: AppColors.primaryDark),
        const SizedBox(width: 5),
        Text(text, style: const TextStyle(fontSize: 12)),
      ],
    ),
  );
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(this.icon, this.label, this.value);
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 9),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 17, color: AppColors.textSecondary),
        const SizedBox(width: 8),
        SizedBox(
          width: 56,
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
