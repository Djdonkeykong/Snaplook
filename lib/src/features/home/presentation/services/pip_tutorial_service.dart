import 'package:flutter/services.dart';

enum PipTutorialTarget {
  instagram,
  pinterest,
  tiktok,
  photos,
  facebook,
  imdb,
  safari,
  x,
}

class PipTutorialService {
  static const _channel = MethodChannel('pip_tutorial');

  Future<void> startTutorial({
    required PipTutorialTarget target,
    String videoAsset = 'assets/videos/pip-test.mp4',
  }) async {
    final targetKey = target.name;
    try {
      await _channel.invokeMethod('start', {
        'target': targetKey,
        'video': videoAsset,
      });
    } on PlatformException {
      rethrow;
    } catch (_) {
      rethrow;
    }
  }
}
