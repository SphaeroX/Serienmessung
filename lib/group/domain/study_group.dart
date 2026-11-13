/// A named group of studies, e.g. the machines of one production line.
class StudyGroup {
  const StudyGroup({
    required this.id,
    required this.name,
    required this.description,
    required this.createdAt,
  });

  final int id;
  final String name;
  final String description;
  final DateTime createdAt;
}

/// Group plus figures for the group list.
class GroupSummary {
  const GroupSummary({required this.group, required this.studyCount});

  final StudyGroup group;
  final int studyCount;
}
