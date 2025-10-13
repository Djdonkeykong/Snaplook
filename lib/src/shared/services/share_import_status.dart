import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class ShareImportStatus {
  static const MethodChannel _channel =
      MethodChannel('com.snaplook.snaplook/share_status');

  static Future<void> markProcessing() => _updateStatus('processing');

  static Future<void> markComplete() async {
    final didUpdate = await _updateStatus('completed');
    if (didUpdate) {
      return;
    }

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

  static Future<void> configure({
    String? scrapingBeeApiKey,
  }) async {
    final payload = <String, dynamic>{};
    if (scrapingBeeApiKey != null) {
      payload['scrapingBeeApiKey'] = scrapingBeeApiKey;
    }

    if (payload.isEmpty) {
      return;
    }

    try {
      await _channel.invokeMethod(
        'configureShareExtension',
        payload,
      );
    } on MissingPluginException {
      // Share extension not available on this platform.
    } catch (error, stackTrace) {
      debugPrint(
        'ShareImportStatus configure failed: $error\n$stackTrace',
      );
    }
  }

  static Future<bool> _updateStatus(String status) async {
    try {
      await _channel.invokeMethod(
        'updateShareProcessingStatus',
        {
          'status': status,
        },
      );
      return true;
    } on MissingPluginException {
      return false;
    } catch (error, stackTrace) {
      debugPrint(
        'ShareImportStatus updateStatus($status) failed: $error\n$stackTrace',
      );
      return false;
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
