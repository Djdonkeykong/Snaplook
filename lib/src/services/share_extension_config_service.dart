import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../../core/constants/app_constants.dart';

class ShareExtensionConfigService {
  static const String _appGroupId = 'group.com.snaplook.snaplook';
  static const MethodChannel _channel = MethodChannel('snaplook/share_config');

  static Future<void> initializeSharedConfig() async {
    if (!Platform.isIOS) {
      debugPrint('ShareExtensionConfig: Skipping (not iOS)');
      return;
    }

    try {
      // Use method channel to write to app group UserDefaults (iOS native)
      final serpKey = AppConstants.serpApiKey;
      final endpoint = AppConstants.serpDetectAndSearchEndpoint;

      await _channel.invokeMethod('saveSharedConfig', {
        'appGroupId': _appGroupId,
        'serpApiKey': serpKey,
        'detectorEndpoint': endpoint,
      });

      debugPrint('ShareExtensionConfig: ✅ Saved SerpApiKey to app group');
      debugPrint('ShareExtensionConfig: ✅ Saved DetectorEndpoint: $endpoint');
      debugPrint('ShareExtensionConfig: Configuration saved successfully');
    } catch (e) {
      debugPrint('ShareExtensionConfig: ❌ Failed to save config: $e');
    }
  }
}
