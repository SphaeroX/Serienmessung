import 'package:flutter/material.dart';

import '../../recording/domain/measurement.dart';
import '../../study/domain/study.dart';
import '../domain/boundary.dart';

/// Colors for steps (by position), repeated for long step lists.
const stepColors = [
  Color(0xFF4FC3F7),
  Color(0xFF81C784),
  Color(0xFFFFB74D),
  Color(0xFFBA68C8),
  Color(0xFFF06292),
  Color(0xFF4DB6AC),
  Color(0xFFDCE775),
  Color(0xFF9575CD),
];

/// Scrolling timeline below the video.
///
/// The playhead stays fixed in the middle and the timeline moves underneath,
/// repainting on every change of [position] (driven by a ticker, so it runs
/// smoothly at display rate). Drag to scrub, pinch to zoom, long-press a
/// marker and drag to move it.
class VideoTimeline extends StatefulWidget {
  const VideoTimeline({
    super.key,
    required this.position,
    required this.durationMicros,
    required this.measurements,
    required this.steps,
    required this.onSeek,
    required this.onMoveBoundary,
    this.onScrubStart,
  });

  final ValueNotifier<int> position;
  final int durationMicros;
  final List<Measurement> measurements;
  final List<StepDefinition> steps;
  final void Function(int micros) onSeek;
  final void Function(Boundary boundary, int to) onMoveBoundary;
  final VoidCallback? onScrubStart;

  /// Default zoom: logical pixels per second of video.
  static const defaultPxPerSecond = 60.0;

  @override
  State<VideoTimeline> createState() => _VideoTimelineState();
}

class _VideoTimelineState extends State<VideoTimeline> {
  double _pps = VideoTimeline.defaultPxPerSecond;
  double _ppsAtScaleStart = VideoTimeline.defaultPxPerSecond;
  Boundary? _active;
  int? _activeTo;

  double _xOf(int t, double width) =>
      width / 2 + (t - widget.position.value) * _pps / 1e6;

  int _microsForDx(double dx) => (dx / _pps * 1e6).round();

  void _scaleStart(ScaleStartDetails d) {
    _ppsAtScaleStart = _pps;
    widget.onScrubStart?.call();
  }

  void _scaleUpdate(ScaleUpdateDetails d) {
    if (d.pointerCount >= 2) {
      setState(() => _pps = (_ppsAtScaleStart * d.scale).clamp(5.0, 600.0));
      return;
    }
    if (_active != null) return;
    final target = widget.position.value - _microsForDx(d.focalPointDelta.dx);
    widget.onSeek(target.clamp(0, widget.durationMicros));
  }

  void _longPressStart(LongPressStartDetails d, double width) {
    Boundary? best;
    var bestDist = 24.0;
    for (final b in movableBoundaries(widget.measurements)) {
      final dist = (_xOf(b.at, width) - d.localPosition.dx).abs();
      if (dist < bestDist) {
        bestDist = dist;
        best = b;
      }
    }
    if (best != null) {
      setState(() {
        _active = best;
        _activeTo = best!.at;
      });
    }
  }

  void _longPressMove(LongPressMoveUpdateDetails d) {
    final b = _active;
    if (b == null) return;
    final to = clampBoundary(
      b,
      b.at + _microsForDx(d.localOffsetFromOrigin.dx),
    );
    setState(() => _activeTo = to);
    // The video follows the marker.
    widget.onSeek(to);
  }

  void _longPressEnd(LongPressEndDetails d) {
    final b = _active;
    final to = _activeTo;
    setState(() {
      _active = null;
      _activeTo = null;
    });
    if (b != null && to != null && to != b.at) widget.onMoveBoundary(b, to);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        return GestureDetector(
          key: const Key('timeline'),
          behavior: HitTestBehavior.opaque,
          onScaleStart: _scaleStart,
          onScaleUpdate: _scaleUpdate,
          onLongPressStart: (d) => _longPressStart(d, width),
          onLongPressMoveUpdate: _longPressMove,
          onLongPressEnd: _longPressEnd,
          child: CustomPaint(
            size: Size(width, 64),
            painter: _TimelinePainter(
              position: widget.position,
              pxPerSecond: _pps,
              duration: widget.durationMicros,
              measurements: widget.measurements,
              stepIndex: {for (final s in widget.steps) s.id: s.position},
              active: _active,
              activeTo: _activeTo,
              track: scheme.surfaceContainerHighest,
              text: scheme.onSurfaceVariant,
              special: scheme.error,
              playhead: scheme.primary,
            ),
          ),
        );
      },
    );
  }
}

class _TimelinePainter extends CustomPainter {
  _TimelinePainter({
    required this.position,
    required this.pxPerSecond,
    required this.duration,
    required this.measurements,
    required this.stepIndex,
    required this.active,
    required this.activeTo,
    required this.track,
    required this.text,
    required this.special,
    required this.playhead,
  }) : super(repaint: position);

  final ValueNotifier<int> position;
  final double pxPerSecond;
  final int duration;
  final List<Measurement> measurements;
  final Map<int, int> stepIndex;
  final Boundary? active;
  final int? activeTo;
  final Color track;
  final Color text;
  final Color special;
  final Color playhead;

  @override
  void paint(Canvas canvas, Size size) {
    final pos = position.value;
    final mid = size.width / 2;
    double x(int t) => mid + (t - pos) * pxPerSecond / 1e6;
    const top = 18.0;
    final h = size.height - top - 4;

    // Track for the video length.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(x(0), top, x(duration), top + h),
        const Radius.circular(6),
      ),
      Paint()..color = track,
    );

    // Second ticks and labels.
    final visibleFrom = pos - (mid / pxPerSecond * 1e6).round();
    final visibleTo = pos + (mid / pxPerSecond * 1e6).round();
    final step = pxPerSecond >= 40 ? 1 : (pxPerSecond >= 10 ? 5 : 30);
    final tick = Paint()
      ..color = text.withValues(alpha: 0.5)
      ..strokeWidth = 1;
    final firstSecond = (visibleFrom / 1e6).floor().clamp(0, 1 << 30);
    for (var sec = firstSecond; sec * 1e6 <= visibleTo; sec++) {
      if (sec % step != 0 || sec * 1e6 > duration) continue;
      final tx = x(sec * 1000000);
      canvas.drawLine(Offset(tx, top - 4), Offset(tx, top), tick);
      final tp = TextPainter(
        text: TextSpan(
          text: '${sec ~/ 60}:${(sec % 60).toString().padLeft(2, '0')}',
          style: TextStyle(color: text, fontSize: 9),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(tx - tp.width / 2, 0));
    }

    // Step segments and markers.
    final markerPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2;
    for (final m in measurements) {
      var start = m.startMicros;
      var end = m.endMicros;
      final a = active;
      if (a != null && activeTo != null) {
        if (m.id == a.before.id) end = activeTo!;
        if (m.id == a.after.id) start = activeTo!;
      }
      if (end < visibleFrom || start > visibleTo) continue;
      final rect = Rect.fromLTRB(x(start), top, x(end), top + h);
      if (m.kind == MeasurementKind.special) {
        canvas.drawRect(
          Rect.fromLTRB(rect.left, top + h * 0.55, rect.right, rect.bottom),
          Paint()..color = special.withValues(alpha: 0.8),
        );
        continue;
      }
      final color = stepColors[(stepIndex[m.stepId] ?? 0) % stepColors.length];
      canvas.drawRect(rect, Paint()..color = color.withValues(alpha: 0.75));
      canvas.drawLine(rect.topLeft, rect.bottomLeft, markerPaint);
      canvas.drawLine(rect.topRight, rect.bottomRight, markerPaint);
    }

    // Marker being dragged.
    if (activeTo != null) {
      final ax = x(activeTo!);
      canvas.drawLine(
        Offset(ax, top - 6),
        Offset(ax, top + h + 4),
        Paint()
          ..color = playhead
          ..strokeWidth = 4,
      );
    }

    // Fixed playhead.
    final ph = Paint()
      ..color = Colors.redAccent
      ..strokeWidth = 2;
    canvas.drawLine(Offset(mid, top - 6), Offset(mid, size.height), ph);
    final tri = Path()
      ..moveTo(mid - 5, top - 8)
      ..lineTo(mid + 5, top - 8)
      ..lineTo(mid, top - 2)
      ..close();
    canvas.drawPath(tri, ph);
  }

  @override
  bool shouldRepaint(_TimelinePainter old) =>
      old.pxPerSecond != pxPerSecond ||
      old.measurements != measurements ||
      old.activeTo != activeTo ||
      old.duration != duration ||
      old.track != track;
}
