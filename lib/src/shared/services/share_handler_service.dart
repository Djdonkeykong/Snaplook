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
    print("[SHARE HANDLER SERVICE] Setting up method call handler");
    platform.setMethodCallHandler((call) async {
      print("[SHARE HANDLER SERVICE] Received method call: ${call.method}");
      if (call.method == 'onSharedData') {
        print("[SHARE HANDLER SERVICE] onSharedData called from native - checking for data");
        await checkForSharedData();
      }
    });
    print("[SHARE HANDLER SERVICE] Method call handler setup complete");
  }

  Future<Map<String, dynamic>?> checkForSharedData() async {
    print("[SHARE HANDLER SERVICE] checkForSharedData called");
    try {
      print("[SHARE HANDLER SERVICE] Invoking getSharedData on native side");
      final result = await platform.invokeMethod('getSharedData');
      print("[SHARE HANDLER SERVICE] Native result: ${result != null ? 'GOT DATA' : 'NO DATA'}");

      if (result != null && result is Map) {
        final data = Map<String, dynamic>.from(result);
        print("[SHARE HANDLER SERVICE] Data keys: ${data.keys.toList()}");
        print("[SHARE HANDLER SERVICE] Data type: ${data['type']}");

        // Process the shared data
        if (data.containsKey('image') && data['image'] != null) {
          print("[SHARE HANDLER SERVICE] Decoding base64 image");
          // Decode base64 image
          final base64String = data['image'] as String;
          final imageBytes = base64Decode(base64String);
          data['imageBytes'] = imageBytes;
          print("[SHARE HANDLER SERVICE] Image bytes length: ${imageBytes.length}");
        }

        // Clear the shared data from native side
        print("[SHARE HANDLER SERVICE] Clearing shared data from native");
        await clearSharedData();

        // Notify listeners
        if (onSharedData != null) {
          print("[SHARE HANDLER SERVICE] Notifying listener with data");
          onSharedData!(data);
        } else {
          print("[SHARE HANDLER SERVICE WARNING] No onSharedData listener set!");
        }

        return data;
      }
    } catch (e) {
      print("[SHARE HANDLER SERVICE ERROR] Error checking for shared data: $e");
      debugPrint('Error checking for shared data: $e');
    }

    print("[SHARE HANDLER SERVICE] No shared data found");
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
