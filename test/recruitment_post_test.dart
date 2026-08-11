import 'package:flutter_test/flutter_test.dart';
import 'package:weekend_activity/models/models.dart';

RecruitmentPost _post({
  required int headcount,
  List<RecruitmentMember> members = const [],
}) {
  return RecruitmentPost(
    id: 'r1',
    authorId: 'host',
    title: '週末爬山',
    content: '一起走走',
    headcount: headcount,
    genderPref: GenderPref.any,
    cost: 0,
    author: '主揪',
    createdAt: DateTime(2024, 1, 1),
    members: members,
  );
}

RecruitmentMember _member(
  String uid, {
  MemberStatus status = MemberStatus.approved,
  int guests = 0,
}) {
  return RecruitmentMember(
    userId: uid,
    nickname: uid,
    status: status,
    guestCount: guests,
  );
}

void main() {
  group('名額計算(方案 B:待審核也佔名額)', () {
    test('本人加帶的人都算進名額', () {
      final post = _post(headcount: 4, members: [
        _member('host'), // 1
        _member('a', guests: 2), // 3
      ]);
      expect(post.joinedCount, 4);
      expect(post.remainingSlots, 0);
      expect(post.isFull, isTrue);
    });

    test('待審核者一樣佔名額', () {
      final post = _post(headcount: 4, members: [
        _member('host'),
        _member('a', status: MemberStatus.pending, guests: 1), // 2
      ]);
      expect(post.joinedCount, 3);
      expect(post.remainingSlots, 1);
      expect(post.isFull, isFalse);
    });

    test('被拒絕者釋出名額', () {
      final post = _post(headcount: 4, members: [
        _member('host'),
        _member('a', status: MemberStatus.rejected, guests: 3),
      ]);
      expect(post.joinedCount, 1);
      expect(post.remainingSlots, 3);
    });
  });

  group('成員分類', () {
    final post = _post(headcount: 10, members: [
      _member('host'),
      _member('a', status: MemberStatus.pending),
      _member('b', status: MemberStatus.pending),
      _member('c', status: MemberStatus.rejected),
    ]);

    test('待審核名單', () {
      expect(post.pendingMembers.map((m) => m.userId), ['a', 'b']);
      expect(post.hasPending, isTrue);
    });

    test('已核准名單', () {
      expect(post.approvedMembers.map((m) => m.userId), ['host']);
    });

    test('有效成員排除被拒絕者', () {
      expect(post.activeMembers.length, 3);
    });
  });

  group('集合資訊可見性', () {
    final post = _post(headcount: 4, members: [
      _member('host'),
      _member('approved'),
      _member('pending', status: MemberStatus.pending),
    ]);

    test('發起者看得到', () {
      expect(post.canSeeMeetingInfo('host'), isTrue);
    });

    test('已核准成員看得到', () {
      expect(post.canSeeMeetingInfo('approved'), isTrue);
    });

    test('待審核者看不到', () {
      expect(post.canSeeMeetingInfo('pending'), isFalse);
    });

    test('非成員看不到', () {
      expect(post.canSeeMeetingInfo('stranger'), isFalse);
      expect(post.canSeeMeetingInfo(null), isFalse);
    });
  });

  group('身分判斷', () {
    final post = _post(headcount: 4, members: [
      _member('host'),
      _member('pending', status: MemberStatus.pending),
    ]);

    test('發起者', () {
      expect(post.isHostedBy('host'), isTrue);
      expect(post.isHostedBy('other'), isFalse);
    });

    test('已申請(含待審核)', () {
      expect(post.isJoinedBy('pending'), isTrue);
      expect(post.isJoinedBy('stranger'), isFalse);
    });

    test('已核准', () {
      expect(post.isApprovedFor('host'), isTrue);
      expect(post.isApprovedFor('pending'), isFalse);
    });

    test('memberOf 取回成員紀錄', () {
      expect(post.memberOf('pending')?.status, MemberStatus.pending);
      expect(post.memberOf('stranger'), isNull);
    });
  });

  test('MemberStatus.fromText 解析與預設', () {
    expect(MemberStatus.fromText('approved'), MemberStatus.approved);
    expect(MemberStatus.fromText('rejected'), MemberStatus.rejected);
    expect(MemberStatus.fromText('pending'), MemberStatus.pending);
    expect(MemberStatus.fromText(null), MemberStatus.pending);
    expect(MemberStatus.fromText('unknown'), MemberStatus.pending);
  });
}