import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/app_constants.dart';

class ShareExtensionConfigService {
  static const String _appGroupId = 'group.com.snaplook.snaplook';

  static Future<void> initializeSharedConfig() async {
    if (!Platform.isIOS) {
      debugPrint('ShareExtensionConfig: Skipping (not iOS)');
      return;
    }

    try {
      final prefs = await SharedPreferences.getInstance();

      // Save SerpAPI key
      final serpKey = AppConstants.serpApiKey;
      await prefs.setString('flutter.SerpApiKey', serpKey);
      debugPrint('ShareExtensionConfig: Saved SerpApiKey');

      // Save detector endpoint
      final endpoint = AppConstants.serpDetectorEndpoint;
      await prefs.setString('flutter.DetectorEndpoint', endpoint);
      debugPrint('ShareExtensionConfig: Saved DetectorEndpoint: $endpoint');

      debugPrint('ShareExtensionConfig: Configuration saved successfully');
    } catch (e) {
      debugPrint('ShareExtensionConfig: Failed to save config: $e');
    }
  }
}
