import 'package:cyclescope/study/presentation/github_logo.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('gitHubMarkPath', () {
    test('fills a square of the given size', () {
      final bounds = gitHubMarkPath(24).getBounds();
      expect(bounds.left, closeTo(0, 0.1));
      expect(bounds.top, closeTo(0, 0.1));
      expect(bounds.right, closeTo(24, 0.1));
      // The ring is open at the bottom, where the cat's body meets the edge.
      expect(bounds.bottom, inInclusiveRange(23, 24));
    });

    test('is a filled circle with the cat cut out', () {
      final path = gitHubMarkPath(16);
      // Ring at the top and the left of the circle.
      expect(path.contains(const Offset(8, 0.4)), isTrue);
      expect(path.contains(const Offset(1, 8)), isTrue);
      // Face of the cat.
      expect(path.contains(const Offset(8, 8)), isFalse);
      // Corner outside the circle.
      expect(path.contains(const Offset(0.5, 0.5)), isFalse);
    });
  });

  testWidgets('takes size and color from the icon theme', (tester) async {
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: IconTheme(
            data: IconThemeData(size: 30, color: Color(0xFF123456)),
            child: GitHubLogo(),
          ),
        ),
      ),
    );
    expect(tester.getSize(find.byType(GitHubLogo)), const Size(30, 30));
    final paint = tester.widget<CustomPaint>(
      find.descendant(
        of: find.byType(GitHubLogo),
        matching: find.byType(CustomPaint),
      ),
    );
    expect(
      (paint.painter! as GitHubLogoPainter).color,
      const Color(0xFF123456),
    );
  });
}
