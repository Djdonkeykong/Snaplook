import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';

class ShareHandlerService {
  static const platform = MethodChannel('com.snaplook.snaplook/share');

  static ShareHandlerService? _instance;

  factory ShareHandlerService() {
    _instance ??= ShareHandlerService._internal();
    return _instance!;
  }

  ShareHandlerService._internal() {
    _setupMethodCallHandler();
  }

  Function(Map<String, dynamic>)? onSharedData;

  void _setupMethodCallHandler() {
    platform.setMethodCallHandler((call) async {
      if (call.method == 'onSharedData') {
        await checkForSharedData();
      }
    });
  }

  Future<Map<String, dynamic>?> checkForSharedData() async {
    try {
      final result = await platform.invokeMethod('getSharedData');

      if (result != null && result is Map) {
        final data = Map<String, dynamic>.from(result);

        // Process the shared data
        if (data.containsKey('image') && data['image'] != null) {
          // Decode base64 image
          final base64String = data['image'] as String;
          final imageBytes = base64Decode(base64String);
          data['imageBytes'] = imageBytes;
        }

        // Clear the shared data from native side
        await clearSharedData();

        // Notify listeners
        if (onSharedData != null) {
          onSharedData!(data);
        }

        return data;
      }
    } catch (e) {
      debugPrint('Error checking for shared data: $e');
    }

    return null;
  }

  Future<void> clearSharedData() async {
    try {
      await platform.invokeMethod('clearSharedData');
    } catch (e) {
      debugPrint('Error clearing shared data: $e');
    }
  }

  void dispose() {
    onSharedData = null;
  }
}
