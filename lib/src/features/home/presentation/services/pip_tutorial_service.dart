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
    String? videoAsset,
    String? deepLink,
  }) async {
    final asset =
        videoAsset ?? _defaultAssetForTarget(target);
    final targetKey = target.name;
    try {
      await _channel.invokeMethod('start', {
        'target': targetKey,
        'video': asset,
        'deepLink': deepLink,
      });
    } on PlatformException {
      rethrow;
    } catch (_) {
      rethrow;
    }
  }

  Future<void> stopTutorial() async {
    try {
      await _channel.invokeMethod('stop');
    } catch (_) {
      // best effort; ignore stop failures
    }
  }

  String _defaultAssetForTarget(PipTutorialTarget target) {
    if (target == PipTutorialTarget.instagram) {
      return 'assets/videos/instagram-tutorial.mp4';
    }
    return 'assets/videos/pip-test.mp4';
  }
}
