/// A named group of studies, e.g. the machines of one production line.
///
/// A group can lie in a parent group ([parentId]); it is then an area of
/// that group, e.g. one section of a large plant.
class StudyGroup {
  const StudyGroup({
    required this.id,
    required this.name,
    required this.description,
    required this.createdAt,
    this.parentId,
    this.parentPosition = 0,
    this.bufferCapacity = 0,
    this.bufferStoreMicros = 0,
    this.bufferRetrieveMicros = 0,
    this.conveyorCapacity = 0,
    this.conveyorTransportMicros = 0,
  });

  /// Buffer before this area in its parent group (0 = none), like the
  /// buffer before a station (`Study.bufferCapacity`). It belongs to the
  /// plant, not to the area: it only works where the area stands in the
  /// parent's line, on the area's first station.
  final int bufferCapacity;
  final int bufferStoreMicros;
  final int bufferRetrieveMicros;

  bool get hasBuffer => bufferCapacity > 0;

  /// Conveyor before this area in its parent group (0 = none).
  final int conveyorCapacity;
  final int conveyorTransportMicros;

  bool get hasConveyor => conveyorCapacity > 0;

  /// Whether anything stands before this area in its parent group.
  bool get hasLink => hasBuffer || hasConveyor;

  final int id;
  final String name;
  final String description;
  final DateTime createdAt;

  /// The group this group is an area of; null at the top level.
  final int? parentId;

  /// Place in the parent group; shares one position space with the studies
  /// of that group (`study.group_position`).
  final int parentPosition;
}

/// Group plus figures for the group list.
class GroupSummary {
  const GroupSummary({
    required this.group,
    required this.studyCount,
    this.areaCount = 0,
    int? totalStudyCount,
  }) : totalStudyCount = totalStudyCount ?? studyCount;

  final StudyGroup group;

  /// Studies directly in the group.
  final int studyCount;

  /// Groups directly in the group (its areas).
  final int areaCount;

  /// Studies in the group and in all areas below it.
  final int totalStudyCount;
}
