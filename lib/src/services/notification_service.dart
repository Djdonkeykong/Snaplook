import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  String? _currentToken;

  Future<void> initialize() async {
    try {
      debugPrint('[NotificationService] Initializing...');

      // Request permission
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      debugPrint('[NotificationService] Permission status: ${settings.authorizationStatus}');

      if (settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional) {
        // Get FCM token
        await _registerToken();

        // Listen for token refresh
        _messaging.onTokenRefresh.listen(_onTokenRefresh);

        debugPrint('[NotificationService] Initialized successfully');
      } else {
        debugPrint('[NotificationService] Permission denied');
      }
    } catch (e, stackTrace) {
      debugPrint('[NotificationService] Error initializing: $e');
      debugPrint('[NotificationService] Stack trace: $stackTrace');
    }
  }

  Future<void> _registerToken() async {
    try {
      final token = await _messaging.getToken();
      if (token != null) {
        _currentToken = token;
        debugPrint('[NotificationService] FCM Token: $token');
        await _saveTokenToDatabase(token);
      } else {
        debugPrint('[NotificationService] Failed to get FCM token');
      }
    } catch (e) {
      debugPrint('[NotificationService] Error getting token: $e');
    }
  }

  Future<void> _onTokenRefresh(String token) async {
    debugPrint('[NotificationService] Token refreshed: $token');
    _currentToken = token;
    await _saveTokenToDatabase(token);
  }

  Future<void> _saveTokenToDatabase(String token) async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) {
        debugPrint('[NotificationService] No authenticated user - token will be saved after login');
        return;
      }

      debugPrint('[NotificationService] Saving token to database for user: $userId');

      await Supabase.instance.client.from('fcm_tokens').upsert({
        'user_id': userId,
        'token': token,
        'platform': defaultTargetPlatform.name,
        'updated_at': DateTime.now().toIso8601String(),
      });

      debugPrint('[NotificationService] Token saved successfully');
    } catch (e, stackTrace) {
      debugPrint('[NotificationService] Error saving token: $e');
      debugPrint('[NotificationService] Stack trace: $stackTrace');
    }
  }

  Future<void> deleteToken() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;

      debugPrint('[NotificationService] Deleting token for user: $userId');

      await Supabase.instance.client
          .from('fcm_tokens')
          .delete()
          .eq('user_id', userId)
          .eq('token', _currentToken ?? '');

      await _messaging.deleteToken();
      _currentToken = null;

      debugPrint('[NotificationService] Token deleted successfully');
    } catch (e) {
      debugPrint('[NotificationService] Error deleting token: $e');
    }
  }

  Future<void> registerTokenForUser() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      debugPrint('[NotificationService] No user to register token for');
      return;
    }

    if (_currentToken != null) {
      await _saveTokenToDatabase(_currentToken!);
    } else {
      await _registerToken();
    }
  }

  String? get currentToken => _currentToken;
}
