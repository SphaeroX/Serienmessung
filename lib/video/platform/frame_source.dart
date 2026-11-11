import 'package:flutter/services.dart';

import '../domain/frame_cache.dart';

/// Decodes single video frames ahead of time, for instant frame stepping.
abstract class FrameSource {
  /// Opens [path]; returns the frame timing or null if frames cannot be
  /// decoded on this device (stepping then falls back to player seeks).
  Future<FrameTiming?> open(String path);

  /// Encoded pictures (JPEG/PNG) of frames [first] .. [first] + [count] - 1.
  Future<List<Uint8List>> frames(int first, int count);

  Future<void> close();
}

/// [FrameSource] backed by Android's `MediaMetadataRetriever` (API 28+),
/// see `MainActivity.kt`.
class ChannelFrameSource implements FrameSource {
  static const _channel = MethodChannel('dev.cyclescope/frames');

  /// Longest side of the decoded pictures (enough for zooming in).
  static const maxSize = 1280;

  @override
  Future<FrameTiming?> open(String path) async {
    try {
      final info = await _channel.invokeMapMethod<String, Object?>('open', {
        'path': path,
      });
      if (info == null) return null;
      final fps = (info['fps'] as num?)?.toDouble() ?? 0;
      final count = (info['frameCount'] as num?)?.toInt() ?? 0;
      if (fps <= 0 || count <= 0) return null;
      return FrameTiming(fps: fps, frameCount: count);
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  @override
  Future<List<Uint8List>> frames(int first, int count) async {
    final list = await _channel.invokeListMethod<Uint8List>('frames', {
      'first': first,
      'count': count,
      'maxSize': maxSize,
    });
    return list ?? const [];
  }

  @override
  Future<void> close() async {
    try {
      await _channel.invokeMethod<void>('close');
    } on Object {
      // Nothing to release.
    }
  }
}
