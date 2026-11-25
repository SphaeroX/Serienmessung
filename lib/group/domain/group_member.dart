import '../../study/domain/study.dart';
import 'study_group.dart';

/// One entry of a group in its order: a study or an area (a group inside
/// the group).
sealed class GroupMember {
  const GroupMember();

  /// Place in the group; studies and areas share one position space.
  int get position;

  MemberKey get key;
}

final class StudyMember extends GroupMember {
  const StudyMember(this.study);

  final Study study;

  @override
  int get position => study.groupPosition;

  @override
  MemberKey get key => MemberKey.study(study.id);
}

final class AreaMember extends GroupMember {
  const AreaMember(this.group);

  final StudyGroup group;

  @override
  int get position => group.parentPosition;

  @override
  MemberKey get key => MemberKey.area(group.id);
}

/// Identifies a group member: a study or an area by its id.
final class MemberKey {
  const MemberKey.study(this.id) : isArea = false;
  const MemberKey.area(this.id) : isArea = true;

  final int id;
  final bool isArea;

  @override
  bool operator ==(Object other) =>
      other is MemberKey && other.id == id && other.isArea == isArea;

  @override
  int get hashCode => Object.hash(id, isArea);

  @override
  String toString() => isArea ? 'area $id' : 'study $id';
}

/// Thrown when a group would end up inside itself (directly or through
/// its areas).
class GroupCycleException implements Exception {
  const GroupCycleException(this.groupId, this.parentId);

  final int groupId;
  final int parentId;

  @override
  String toString() =>
      'GroupCycleException: group $groupId cannot go into group $parentId, '
      'which is the group itself or one of its areas';
}
