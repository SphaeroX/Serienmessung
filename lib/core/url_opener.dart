import 'package:flutter/services.dart';

/// Opens a web link in another app (the browser), behind an interface for
/// tests. The app itself makes no network call.
abstract class UrlOpener {
  /// Returns false when no app could open [url].
  Future<bool> open(Uri url);
}

/// Android implementation (see `MainActivity.kt`, method `openUrl`).
class AndroidUrlOpener implements UrlOpener {
  const AndroidUrlOpener();

  static const _methods = MethodChannel('dev.cyclescope/platform');

  @override
  Future<bool> open(Uri url) async {
    try {
      return await _methods.invokeMethod<bool>('openUrl', url.toString()) ??
          false;
    } on MissingPluginException {
      return false; // Not on Android.
    } on PlatformException {
      return false;
    }
  }
}
