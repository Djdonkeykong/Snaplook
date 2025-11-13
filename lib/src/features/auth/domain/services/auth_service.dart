import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:flutter/services.dart';
import '../../../../services/subscription_sync_service.dart';

class AuthService {
  final _supabase = Supabase.instance.client;
  static const _authChannel = MethodChannel('snaplook/auth');
  StreamSubscription<AuthState>? _authSubscription;

  User? get currentUser => _supabase.auth.currentUser;
  bool get isAuthenticated => currentUser != null;

  Stream<AuthState> get authStateChanges => _supabase.auth.onAuthStateChange;

  // Initialize and sync current auth state to share extension
  Future<void> syncAuthState() async {
    print('[AuthService] syncAuthState called');
    print('[AuthService] isAuthenticated: $isAuthenticated');
    print('[AuthService] currentUser: ${currentUser?.id ?? "null"}');

    User? initialUser;
    if (isAuthenticated) {
      initialUser = await _waitForAuthenticatedUser(
        context: 'initial sync',
        timeout: const Duration(seconds: 2),
      );

      if (initialUser == null) {
        print('[Auth] WARNING: Unable to resolve user for initial sync - deferring until auth events fire');
      }
    }

    await _updateAuthFlag(
      isAuthenticated,
      userId: initialUser?.id,
    );

    // Also listen for auth state changes and sync automatically
    _authSubscription?.cancel();
    _authSubscription = _supabase.auth.onAuthStateChange.listen((authState) {
      print('[Auth] Auth state changed: ${authState.event}');
      print('[Auth] Event session: ${authState.session != null ? "exists" : "null"}');
      print('[Auth] Event user: ${authState.session?.user.id ?? "null"}');
      print('[Auth] Current user (at event time): ${currentUser?.id ?? "null"}');

      // IMPORTANT: Only sync if we have a valid user, or if we're explicitly signing out
      // This prevents race conditions where session exists but user is momentarily null
      final hasSession = authState.session != null;
      final hasUser = authState.session?.user != null;

      if (hasSession && hasUser) {
        // Valid authenticated state - sync it
        final userId = authState.session!.user.id;
        print('[Auth] Valid auth state - syncing userId: $userId');
        _updateAuthFlag(true, userId: userId);
      } else if (!hasSession) {
        // Explicitly signed out - clear auth
        print('[Auth] No session - clearing auth state');
        _updateAuthFlag(false);
      } else {
        // Session exists but no user - this is a race condition, skip sync
        print('[Auth] WARNING: Session exists but no user - skipping sync to prevent clearing userId');
      }
    });

    print('[AuthService] Auth listener set up');
  }

  void dispose() {
    _authSubscription?.cancel();
  }

  // Update the authentication flag and user ID for share extension via method channel
  Future<void> _updateAuthFlag(
    bool isAuthenticated, {
    String? userId,
  }) async {
    try {
      String? effectiveUserId = userId;
      if (isAuthenticated) {
        effectiveUserId ??= currentUser?.id;

        if (effectiveUserId == null) {
          print('[Auth] INFO: Authenticated but userId not yet available - waiting briefly before syncing');
          final resolvedUser = await _waitForAuthenticatedUser(
            context: 'authenticated sync',
            timeout: const Duration(seconds: 2),
          );
          effectiveUserId = resolvedUser?.id;
        }

        if (effectiveUserId == null) {
          print('[Auth] WARNING: Skipping auth sync - userId still null after waiting');
          return;
        }
      }

      print('[Auth] Calling setAuthFlag method channel...');
      print('[Auth]   - isAuthenticated: $isAuthenticated');
      print('[Auth]   - userId: $effectiveUserId');

      // IMPORTANT: Always send the current state, even if null
      // This ensures old user_id values are cleared from UserDefaults
      final result = await _authChannel.invokeMethod('setAuthFlag', {
        'isAuthenticated': isAuthenticated,
        'userId': effectiveUserId,  // Will be null if not authenticated, clearing old values
      });

      print('[Auth] Method channel call completed, result: $result');

      if (isAuthenticated && effectiveUserId != null) {
        print('[Auth] Synced to share extension - authenticated with userId: $effectiveUserId');
      } else {
        print('[Auth] Synced to share extension - NOT authenticated, cleared user_id');
      }
    } catch (e) {
      print('[Auth] ERROR calling method channel: $e');
      print('[Auth] Stack trace: ${StackTrace.current}');
    }
  }

  Future<AuthResponse> signInWithGoogle() async {
    try {
      final googleSignIn = GoogleSignIn.instance;

      // Initialize with server client ID
      await googleSignIn.initialize(
        clientId: '134752292541-4289b71rova6eldn9f67qom4u2qc5onp.apps.googleusercontent.com',
        serverClientId: '134752292541-hekkkdi2mbl0jrdsct0l2n3hjm2sckmh.apps.googleusercontent.com',
      );

      // Authenticate
      final account = await googleSignIn.authenticate();
      if (account == null) {
        throw Exception('Google sign in was cancelled');
      }

      // Get ID token
      final auth = await account.authentication;
      final idToken = auth.idToken;

      if (idToken == null) {
        throw Exception('No ID token found');
      }

      final response = await _supabase.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
      );

      // Update auth flag for share extension
      await _updateAuthFlag(
        true,
        userId: response.user?.id,
      );

      // Sync subscription from RevenueCat to Supabase
      if (response.user != null) {
        await SubscriptionSyncService().linkRevenueCatUser(response.user!.id);
      }

      return response;
    } catch (e) {
      print('Google sign in error: $e');
      rethrow;
    }
  }

  Future<AuthResponse> signInWithApple() async {
    try {
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      final idToken = credential.identityToken;
      if (idToken == null) {
        throw Exception('Failed to get Apple ID token');
      }

      final response = await _supabase.auth.signInWithIdToken(
        provider: OAuthProvider.apple,
        idToken: idToken,
        nonce: credential.state,
      );

      // Update auth flag for share extension
      await _updateAuthFlag(
        true,
        userId: response.user?.id,
      );

      // Sync subscription from RevenueCat to Supabase
      if (response.user != null) {
        await SubscriptionSyncService().linkRevenueCatUser(response.user!.id);
      }

      return response;
    } catch (e) {
      print('Apple sign in error: $e');
      rethrow;
    }
  }

  Future<AuthResponse> signInAnonymously() async {
    try {
      final response = await _supabase.auth.signInAnonymously();

      // Update auth flag for share extension
      await _updateAuthFlag(
        true,
        userId: response.user?.id,
      );

      // Sync subscription from RevenueCat to Supabase
      if (response.user != null) {
        await SubscriptionSyncService().linkRevenueCatUser(response.user!.id);
      }

      return response;
    } catch (e) {
      print('Anonymous sign in error: $e');
      rethrow;
    }
  }

  Future<void> signOut() async {
    try {
      await _supabase.auth.signOut();

      // Clear auth flag for share extension
      await _updateAuthFlag(false);

      // Unlink RevenueCat user
      await SubscriptionSyncService().unlinkRevenueCatUser();
    } catch (e) {
      print('Sign out error: $e');
      rethrow;
    }
  }

  Future<void> signInWithOtp(String email) async {
    try {
      await _supabase.auth.signInWithOtp(
        email: email,
        emailRedirectTo: null,
      );
    } catch (e) {
      print('OTP sign in error: $e');
      rethrow;
    }
  }

  Future<AuthResponse> verifyOtp({
    required String email,
    required String token,
  }) async {
    try {
      final response = await _supabase.auth.verifyOTP(
        email: email,
        token: token,
        type: OtpType.email,
      );

      // Update auth flag for share extension
      await _updateAuthFlag(
        true,
        userId: response.user?.id,
      );

      // Sync subscription from RevenueCat to Supabase
      if (response.user != null) {
        await SubscriptionSyncService().linkRevenueCatUser(response.user!.id);
      }

      return response;
    } catch (e) {
      print('OTP verification error: $e');
      rethrow;
    }
  }

  Future<User?> _waitForAuthenticatedUser({
    required String context,
    required Duration timeout,
  }) async {
    if (!isAuthenticated) {
      print('[Auth] INFO: Skipping user wait for $context - not authenticated');
      return null;
    }

    final stopwatch = Stopwatch()..start();
    const pollInterval = Duration(milliseconds: 100);

    while (stopwatch.elapsed < timeout) {
      final user = _supabase.auth.currentUser;
      if (user != null) {
        return user;
      }
      await Future.delayed(pollInterval);
    }

    try {
      print('[Auth] INFO: Polling timed out for $context - attempting direct user fetch');
      final response = await _supabase.auth.getUser();
      return response.user;
    } catch (e) {
      print('[Auth] WARNING: Failed to fetch user for $context: $e');
      return null;
    }
  }
}
