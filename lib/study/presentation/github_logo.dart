import 'dart:typed_data';

import 'package:flutter/widgets.dart';

/// The project's source code repository, linked from the home screen.
final repositoryUrl = Uri.parse('https://github.com/SphaeroX/Serienmessung');

/// The GitHub mark (Octicons `mark-github`, 16 × 16 grid), scaled to a
/// square of [size]. Drawn as a path so no image asset or SVG package is
/// needed and it takes any color.
Path gitHubMarkPath(double size) {
  final mark = Path()
    ..moveTo(8, 0)
    ..relativeCubicTo(4.42, 0, 8, 3.58, 8, 8)
    ..relativeArcToPoint(
      const Offset(-5.45, 7.59),
      radius: const Radius.circular(8.013),
    )
    ..relativeCubicTo(-0.4, 0.08, -0.55, -0.17, -0.55, -0.38)
    ..relativeCubicTo(0, -0.27, 0.01, -1.13, 0.01, -2.2)
    ..relativeCubicTo(0, -0.75, -0.25, -1.23, -0.54, -1.48)
    ..relativeCubicTo(1.78, -0.2, 3.65, -0.88, 3.65, -3.95)
    ..relativeCubicTo(0, -0.88, -0.31, -1.59, -0.82, -2.15)
    ..relativeCubicTo(0.08, -0.2, 0.36, -1.02, -0.08, -2.12)
    ..relativeCubicTo(0, 0, -0.67, -0.22, -2.2, 0.82)
    ..relativeCubicTo(-0.64, -0.18, -1.32, -0.27, -2, -0.27)
    ..relativeCubicTo(-0.68, 0, -1.36, 0.09, -2, 0.27)
    ..relativeCubicTo(-1.53, -1.03, -2.2, -0.82, -2.2, -0.82)
    ..relativeCubicTo(-0.44, 1.1, -0.16, 1.92, -0.08, 2.12)
    ..relativeCubicTo(-0.51, 0.56, -0.82, 1.28, -0.82, 2.15)
    ..relativeCubicTo(0, 3.06, 1.86, 3.75, 3.64, 3.95)
    ..relativeCubicTo(-0.23, 0.2, -0.44, 0.55, -0.51, 1.07)
    ..relativeCubicTo(-0.46, 0.21, -1.61, 0.55, -2.33, -0.66)
    ..relativeCubicTo(-0.15, -0.24, -0.6, -0.83, -1.23, -0.82)
    ..relativeCubicTo(-0.67, 0.01, -0.27, 0.38, 0.01, 0.53)
    ..relativeCubicTo(0.34, 0.19, 0.73, 0.9, 0.82, 1.13)
    ..relativeCubicTo(0.16, 0.45, 0.68, 1.31, 2.69, 0.94)
    ..relativeCubicTo(0, 0.67, 0.01, 1.3, 0.01, 1.49)
    ..relativeCubicTo(0, 0.21, -0.15, 0.45, -0.55, 0.38)
    ..arcToPoint(const Offset(0, 8), radius: const Radius.circular(7.995))
    ..relativeCubicTo(0, -4.42, 3.58, -8, 8, -8)
    ..close();
  final s = size / 16;
  return mark.transform(
    Float64List.fromList([s, 0, 0, 0, 0, s, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1]),
  );
}

/// The GitHub mark as an icon: size and color come from the [IconTheme],
/// like an [Icon], so it fits into an [IconButton] in any theme.
class GitHubLogo extends StatelessWidget {
  const GitHubLogo({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = IconTheme.of(context);
    final size = theme.size ?? 24;
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: GitHubLogoPainter(theme.color ?? const Color(0xFF000000)),
      ),
    );
  }
}

/// Paints [gitHubMarkPath] in [color], centered in the available square.
class GitHubLogoPainter extends CustomPainter {
  const GitHubLogoPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final side = size.shortestSide;
    canvas.translate((size.width - side) / 2, (size.height - side) / 2);
    canvas.drawPath(gitHubMarkPath(side), Paint()..color = color);
  }

  @override
  bool shouldRepaint(GitHubLogoPainter oldDelegate) =>
      oldDelegate.color != color;
}
