import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  final _supabase = Supabase.instance.client;
  static const String _authFlagKey = 'user_authenticated';
  static const String _appGroupId = 'group.com.snaplook.snaplook';

  User? get currentUser => _supabase.auth.currentUser;
  bool get isAuthenticated => currentUser != null;

  Stream<AuthState> get authStateChanges => _supabase.auth.onAuthStateChange;

  // Update the authentication flag for share extension
  Future<void> _updateAuthFlag(bool isAuthenticated) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_authFlagKey, isAuthenticated);
      print('Auth flag set to: $isAuthenticated');
    } catch (e) {
      print('Error updating auth flag: $e');
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
