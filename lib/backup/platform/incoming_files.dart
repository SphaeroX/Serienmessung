import 'dart:async';

import 'package:flutter/services.dart';

/// Files the user opened with the app or shared to it from another app
/// (mail, messenger, file manager), as their text content.
abstract class IncomingFiles {
  /// Emits files waiting since the app started, then each new one.
  Stream<String> get files;
}

/// Platform channel `dev.cyclescope/incoming_files`: the native side
/// (`MainActivity.kt`, `IncomingFiles` in `ios/Runner/AppDelegate.swift`)
/// keeps received files until Dart takes them with `takeIncomingFiles` and
/// calls `filesWaiting` when new ones arrive while the app runs.
class PlatformIncomingFiles implements IncomingFiles {
  static const _channel = MethodChannel('dev.cyclescope/incoming_files');

  @override
  Stream<String> get files {
    late final StreamController<String> controller;

    Future<void> take() async {
      try {
        final list =
            await _channel.invokeListMethod<String>('takeIncomingFiles') ??
            const [];
        list.forEach(controller.add);
      } on MissingPluginException {
        // No native side on this platform (tests, desktop).
      } on PlatformException {
        // A file could not be read; nothing to import.
      }
    }

    controller = StreamController<String>(
      onListen: () {
        _channel.setMethodCallHandler((call) async {
          if (call.method == 'filesWaiting') await take();
        });
        take();
      },
      onCancel: () => _channel.setMethodCallHandler(null),
    );
    return controller.stream;
  }
}
