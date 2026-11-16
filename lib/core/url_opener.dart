import 'package:flutter/services.dart';

/// Opens a web link in another app (the browser), behind an interface for
/// tests. The app itself makes no network call.
abstract class UrlOpener {
  /// Returns false when no app could open [url].
  Future<bool> open(Uri url);
}

/// Platform channel implementation (method `openUrl`, served by
/// `MainActivity.kt` on Android and `PlatformChannel` in
/// `ios/Runner/AppDelegate.swift` on iOS).
class AndroidUrlOpener implements UrlOpener {
  const AndroidUrlOpener();

  static const _methods = MethodChannel('dev.cyclescope/platform');

  @override
  Future<bool> open(Uri url) async {
    try {
      return await _methods.invokeMethod<bool>('openUrl', url.toString()) ??
          false;
    } on MissingPluginException {
      return false; // No channel handler on this platform.
    } on PlatformException {
      return false;
    }
  }
}
