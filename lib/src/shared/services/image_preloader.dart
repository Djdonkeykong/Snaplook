import 'package:flutter/material.dart';

class ImagePreloader {
  static ImagePreloader? _instance;
  static ImagePreloader get instance => _instance ??= ImagePreloader._();

  ImagePreloader._();

  bool _isSocialMediaShareImageLoaded = false;

  bool get isSocialMediaShareImageLoaded => _isSocialMediaShareImageLoaded;

  Future<void> preloadSocialMediaShareImage(BuildContext context) async {
    if (_isSocialMediaShareImageLoaded) return;

    try {
      await precacheImage(
        const AssetImage('assets/images/social_media_share_mobile_screen.png'),
        context,
      );
      _isSocialMediaShareImageLoaded = true;
      debugPrint('[ImagePreloader] Social media share image preloaded successfully');
    } catch (e) {
      debugPrint('[ImagePreloader] Error preloading social media share image: $e');
    }
  }

  void reset() {
    _isSocialMediaShareImageLoaded = false;
  }
}
