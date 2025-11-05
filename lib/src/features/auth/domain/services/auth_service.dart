import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:flutter/services.dart';

class AuthService {
  final _supabase = Supabase.instance.client;
  static const _authChannel = MethodChannel('snaplook/auth');
  StreamSubscription<AuthState>? _authSubscription;

  User? get currentUser => _supabase.auth.currentUser;
  bool get isAuthenticated => currentUser != null;

  Stream<AuthState> get authStateChanges => _supabase.auth.onAuthStateChange;

  // Initialize and sync current auth state to share extension
  Future<void> syncAuthState() async {
    await _updateAuthFlag(isAuthenticated);

    // Also listen for auth state changes and sync automatically
    _authSubscription?.cancel();
    _authSubscription = _supabase.auth.onAuthStateChange.listen((authState) {
      print('[Auth] Auth state changed: ${authState.event}');
      _updateAuthFlag(authState.session != null);
    });
  }

  void dispose() {
    _authSubscription?.cancel();
  }

  // Update the authentication flag and user ID for share extension via method channel
  Future<void> _updateAuthFlag(bool isAuthenticated) async {
    try {
      final userId = isAuthenticated ? currentUser?.id : null;

      // IMPORTANT: Always send the current state, even if null
      // This ensures old user_id values are cleared from UserDefaults
      await _authChannel.invokeMethod('setAuthFlag', {
        'isAuthenticated': isAuthenticated,
        'userId': userId,  // Will be null if not authenticated, clearing old values
      });

      if (isAuthenticated && userId != null) {
        print('[Auth] Synced to share extension - authenticated with userId: $userId');
      } else {
        print('[Auth] Synced to share extension - NOT authenticated, cleared user_id');
      }
    } catch (e) {
      print('[Auth] Error updating auth flag: $e');
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
      await _updateAuthFlag(true);

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
      await _updateAuthFlag(true);

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
      await _updateAuthFlag(true);

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
      await _updateAuthFlag(true);

      return response;
    } catch (e) {
      print('OTP verification error: $e');
      rethrow;
    }
  }
}
