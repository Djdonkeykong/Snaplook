import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  FirebaseMessaging? _messaging;
  String? _currentToken;

  Future<void> initialize() async {
    try {
      debugPrint('[NotificationService] Initializing...');

      // Check if Firebase is initialized
      try {
        await Firebase.initializeApp();
      } catch (e) {
        // Already initialized or failed - check if we can access it
        try {
          Firebase.app();
        } catch (e) {
          debugPrint('[NotificationService] Firebase not initialized: $e');
          return;
        }
      }

      _messaging = FirebaseMessaging.instance;

      // Request permission
      final settings = await _messaging!.requestPermission(
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
        _messaging!.onTokenRefresh.listen(_onTokenRefresh);

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
      if (_messaging == null) return;

      // On iOS, we need to ensure APNS token is available first
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        debugPrint('[NotificationService] iOS detected - checking for APNS token...');

        // Try to get APNS token first
        String? apnsToken;
        try {
          apnsToken = await _messaging!.getAPNSToken();
          debugPrint('[NotificationService] APNS token available: ${apnsToken != null}');
        } catch (e) {
          debugPrint('[NotificationService] APNS token not available yet: $e');
        }

        // If APNS token not available, wait a bit and retry
        if (apnsToken == null) {
          debugPrint('[NotificationService] Waiting for APNS token...');
          await Future.delayed(const Duration(seconds: 2));

          try {
            apnsToken = await _messaging!.getAPNSToken();
            debugPrint('[NotificationService] APNS token after wait: ${apnsToken != null}');
          } catch (e) {
            debugPrint('[NotificationService] Still no APNS token: $e');
            // Continue anyway - FCM token might still work
          }
        }
      }

      final token = await _messaging!.getToken();
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
      debugPrint('');
      debugPrint('[NotificationService] ===== SAVING TOKEN TO DATABASE =====');
      debugPrint('[NotificationService] User ID: $userId');
      debugPrint('[NotificationService] Token: $token');
      debugPrint('[NotificationService] Platform: ${defaultTargetPlatform.name}');

      if (userId == null) {
        debugPrint('[NotificationService] ERROR: No authenticated user - token will be saved after login');
        debugPrint('[NotificationService] ======================================');
        return;
      }

      final data = {
        'user_id': userId,
        'token': token,
        'platform': defaultTargetPlatform.name,
        'updated_at': DateTime.now().toIso8601String(),
      };

      debugPrint('[NotificationService] Upserting data: $data');

      await Supabase.instance.client.from('fcm_tokens').upsert(data);

      debugPrint('[NotificationService] SUCCESS: Token saved to database');
      debugPrint('[NotificationService] ======================================');
    } catch (e, stackTrace) {
      debugPrint('[NotificationService] ERROR saving token: $e');
      debugPrint('[NotificationService] Stack trace: $stackTrace');
      debugPrint('[NotificationService] ======================================');
    }
  }

  Future<void> deleteToken() async {
    try {
      if (_messaging == null) return;

      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;

      debugPrint('[NotificationService] Deleting token for user: $userId');

      await Supabase.instance.client
          .from('fcm_tokens')
          .delete()
          .eq('user_id', userId)
          .eq('token', _currentToken ?? '');

      await _messaging!.deleteToken();
      _currentToken = null;

      debugPrint('[NotificationService] Token deleted successfully');
    } catch (e) {
      debugPrint('[NotificationService] Error deleting token: $e');
    }
  }

  Future<void> registerTokenForUser() async {
    debugPrint('');
    debugPrint('[NotificationService] ===== REGISTER TOKEN FOR USER =====');
    final userId = Supabase.instance.client.auth.currentUser?.id;
    debugPrint('[NotificationService] User ID: $userId');
    debugPrint('[NotificationService] Current token: $_currentToken');

    if (userId == null) {
      debugPrint('[NotificationService] ERROR: No user to register token for');
      debugPrint('[NotificationService] ====================================');
      return;
    }

    if (_currentToken != null) {
      debugPrint('[NotificationService] Using existing token: $_currentToken');
      await _saveTokenToDatabase(_currentToken!);
    } else {
      debugPrint('[NotificationService] No existing token, registering new one...');
      await _registerToken();
    }
    debugPrint('[NotificationService] ====================================');
  }

  String? get currentToken => _currentToken;
}
