import 'package:cyclescope/core/url_opener.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('dev.cyclescope/platform');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test('asks the platform to open the link', () async {
    MethodCall? received;
    messenger.setMockMethodCallHandler(channel, (call) async {
      received = call;
      return true;
    });
    final opened = await const AndroidUrlOpener().open(
      Uri.parse('https://example.org/a'),
    );
    expect(opened, isTrue);
    expect(received?.method, 'openUrl');
    expect(received?.arguments, 'https://example.org/a');
  });

  test('reports when no app can open the link', () async {
    messenger.setMockMethodCallHandler(channel, (call) async => false);
    expect(
      await const AndroidUrlOpener().open(Uri.parse('https://example.org')),
      isFalse,
    );
  });

  test('reports failure without a platform implementation', () async {
    expect(
      await const AndroidUrlOpener().open(Uri.parse('https://example.org')),
      isFalse,
    );
  });
}
