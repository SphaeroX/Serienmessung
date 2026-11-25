import '../../study/domain/study.dart';
import 'group_member.dart';
import 'study_group.dart';

/// A study of a flattened group with the areas it lies in, from the
/// opened group's direct area down to its own group (empty for a direct
/// study of the opened group).
class FlatEntry {
  const FlatEntry({required this.study, required this.path});

  /// The study with its effective line fields, see [flattenGroup].
  final Study study;
  final List<StudyGroup> path;
}

/// A direct area of the opened group as a span of the flattened entries:
/// `entries[start]` to `entries[end - 1]` (empty when [start] == [end]).
class LineArea {
  const LineArea({required this.group, required this.start, required this.end});

  final StudyGroup group;
  final int start;
  final int end;

  bool get isEmpty => start == end;
}

/// A group with all its areas as one line.
class FlatLine {
  const FlatLine({required this.entries, required this.areas});

  final List<FlatEntry> entries;

  /// The direct areas of the opened group in line order.
  final List<LineArea> areas;
}

/// Flattens group [rootId] into one line: its studies in group order with
/// each area replaced by its own studies (depth first). [members] holds
/// the members of the root and of every area below it.
///
/// The studies are *effective*: an area is always a station boundary, so
/// the first study of an area and the first study behind an area are
/// neither parallel nor a loader, whatever is stored. The buffer and
/// conveyor stored before an area ([StudyGroup.hasLink]) go to the area's
/// first study (replacing its own); when an area starts with an area that
/// has a link too, the outer one wins. Before the very first study of the
/// line nothing stands, so a link there has no effect. All other fields
/// stay as they are. An empty area adds no study. A cycle in the tree
/// throws a [GroupCycleException].
FlatLine flattenGroup(int rootId, Map<int, List<GroupMember>> members) {
  final entries = <FlatEntry>[];
  final areas = <LineArea>[];
  var boundary = true;
  // The link waiting for the next study (the first of an area).
  StudyGroup? link;

  Study effective(Study study) {
    var result = boundary
        ? study.copyWith(parallel: false, cellLoader: false)
        : study;
    final l = link;
    if (l != null && entries.isNotEmpty) {
      result = result.copyWith(
        bufferCapacity: l.bufferCapacity,
        bufferStoreMicros: l.bufferStoreMicros,
        bufferRetrieveMicros: l.bufferRetrieveMicros,
        conveyorCapacity: l.conveyorCapacity,
        conveyorTransportMicros: l.conveyorTransportMicros,
      );
    }
    link = null;
    return result;
  }

  void walk(int groupId, List<StudyGroup> path, Set<int> open) {
    for (final m in members[groupId] ?? const <GroupMember>[]) {
      switch (m) {
        case StudyMember(:final study):
          entries.add(FlatEntry(study: effective(study), path: path));
          boundary = false;
        case AreaMember(:final group):
          if (!open.add(group.id)) {
            throw GroupCycleException(group.id, groupId);
          }
          final start = entries.length;
          final outer = link;
          if (link == null && group.hasLink) link = group;
          boundary = true;
          walk(group.id, [...path, group], open);
          open.remove(group.id);
          // A link before an empty area is not passed on.
          if (entries.length == start) link = outer;
          boundary = true;
          if (path.isEmpty) {
            areas.add(
              LineArea(group: group, start: start, end: entries.length),
            );
          }
      }
    }
  }

  walk(rootId, const [], {rootId});
  return FlatLine(entries: entries, areas: areas);
}
