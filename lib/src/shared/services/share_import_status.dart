import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class ShareImportStatus {
  static const MethodChannel _channel =
      MethodChannel('com.snaplook.snaplook/share_status');

  static Future<void> markComplete() async {
    try {
      await _channel.invokeMethod('markShareProcessingComplete');
    } on MissingPluginException {
      // Platform does not implement the channel (e.g., Android). No-op.
    } catch (error, stackTrace) {
      debugPrint(
        'ShareImportStatus markComplete failed: $error\n$stackTrace',
      );
    }
  }

  static Future<Map<String, dynamic>?> getCurrentSession() async {
    try {
      final result = await _channel
          .invokeMethod<Map<dynamic, dynamic>>('getShareProcessingSession');
      if (result == null) {
        return null;
      }
      return result.map((key, value) => MapEntry(key.toString(), value));
    } on MissingPluginException {
      return null;
    } catch (error, stackTrace) {
      debugPrint(
        'ShareImportStatus getCurrentSession failed: $error\n$stackTrace',
      );
      return null;
    }
  }
}
