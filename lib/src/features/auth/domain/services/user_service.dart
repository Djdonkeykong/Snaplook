import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_model.dart';

class UserService {
  final _supabase = Supabase.instance.client;

  Future<UserModel?> getCurrentUser() async {
    try {
      final authUser = _supabase.auth.currentUser;
      if (authUser == null) return null;

      final response = await _supabase
          .from('users')
          .select()
          .eq('id', authUser.id)
          .single();

      return UserModel.fromJson(response);
    } catch (e) {
      print('Error fetching current user: $e');
      return null;
    }
  }

  Future<UserModel?> getUserById(String userId) async {
    try {
      final response = await _supabase
          .from('users')
          .select()
          .eq('id', userId)
          .single();

      return UserModel.fromJson(response);
    } catch (e) {
      print('Error fetching user by ID: $e');
      return null;
    }
  }

  Future<void> updateUser({
    String? fullName,
    String? avatarUrl,
    String? gender,
    bool? notificationEnabled,
  }) async {
    try {
      final authUser = _supabase.auth.currentUser;
      if (authUser == null) throw Exception('No authenticated user');

      final updates = <String, dynamic>{
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (fullName != null) updates['full_name'] = fullName;
      if (avatarUrl != null) updates['avatar_url'] = avatarUrl;
      if (gender != null) updates['gender'] = gender;
      if (notificationEnabled != null) updates['notification_enabled'] = notificationEnabled;

      await _supabase
          .from('users')
          .update(updates)
          .eq('id', authUser.id);
    } catch (e) {
      print('Error updating user: $e');
      rethrow;
    }
  }

  /// Save onboarding preferences for a new user
  Future<void> saveOnboardingPreferences({
    required String gender,
    required bool notificationEnabled,
  }) async {
    try {
      final authUser = _supabase.auth.currentUser;
      if (authUser == null) throw Exception('No authenticated user');

      // Minimal save: upsert gender/notification and timestamps.
      await _supabase.from('users').upsert({
        'id': authUser.id,
        'email': authUser.email,
        'gender': gender,
        'notification_enabled': notificationEnabled,
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'id');

      // Verify the save by reading back
      final verification = await _supabase
          .from('users')
          .select('gender, notification_enabled')
          .eq('id', authUser.id)
          .single();

      print('[UserService] VERIFICATION: Database shows gender=${verification['gender']}, notification_enabled=${verification['notification_enabled']}');

      if (verification['gender'] != gender) {
        throw Exception('Gender verification failed! Expected: $gender, Got: ${verification['gender']}');
      }
    } catch (e) {
      print('[UserService] Error saving onboarding preferences: $e');
      rethrow;
    }
  }

  Stream<UserModel?> watchUser(String userId) {
    return _supabase
        .from('users')
        .stream(primaryKey: ['id'])
        .eq('id', userId)
        .map((data) {
          if (data.isEmpty) return null;
          return UserModel.fromJson(data.first);
        });
  }
}
