import '../services/supabase_service.dart';
import '../models/user_profile.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/error_message_service.dart';

class UserProfileService {
  static Future<UserProfile?> getCurrentUserProfile() async {
    try {
      final user = SupabaseService.client.auth.currentUser;
      if (user == null) return null;

      final response =
          await SupabaseService.client
              .from('profiles')
              .select()
              .eq('id', user.id)
              .single();

      return UserProfile.fromJson(response);
    } catch (e) {
      return null;
    }
  }

  /// Get user profile by email address
  static Future<UserProfile?> getUserProfileByEmail(String email) async {
    try {
      final response =
          await SupabaseService.client
              .from('profiles')
              .select()
              .eq('email', email)
              .single();

      return UserProfile.fromJson(response);
    } catch (e) {
      return null;
    }
  }

  static Future<bool> updateProfile(Map<String, dynamic> profileData) async {
    try {
      final user = SupabaseService.client.auth.currentUser;
      if (user == null) return false;

      await SupabaseService.client
          .from('profiles')
          .upsert(profileData, onConflict: 'id');

      return true;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> updateUserProfile(UserProfile profile) async {
    try {
      final user = SupabaseService.client.auth.currentUser;
      if (user == null) return false;

      final updateData = <String, dynamic>{
        'full_name': profile.fullName,
        'email': profile.email,
        'student_id': profile.studentId,
        'phone': profile.phone,
        'college': profile.college,
        'branch': profile.branch,
        'semester': profile.semester,
        'profile_image_url': profile.profileImageUrl,
      };

      await SupabaseService.client
          .from('profiles')
          .update(updateData)
          .eq('id', user.id);

      return true;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> checkStudentIdExists(String studentId) async {
    try {
      final response = await SupabaseService.client
          .from('profiles')
          .select('id')
          .eq('student_id', studentId)
          .limit(1);

      return (response as List).isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  /// Uploads a profile image to Cloudinary and updates the user's profile with the image URL.
  static Future<String?> uploadProfileImageToCloudinary(File imageFile) async {
    try {
      const cloudName = 'dg7kwis9z';
      const uploadPreset = 'EduNest_Prpfile_pic';

      final user = SupabaseService.client.auth.currentUser;
      if (user == null) return null;

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final publicId = 'profile_pictures/user_${user.id}_$timestamp';

      final url = Uri.parse(
        'https://api.cloudinary.com/v1_1/$cloudName/image/upload',
      );

      final request =
          http.MultipartRequest('POST', url)
            ..fields['upload_preset'] = uploadPreset
            ..fields['public_id'] = publicId
            ..files.add(
              await http.MultipartFile.fromPath('file', imageFile.path),
            );

      final response = await request.send();

      if (response.statusCode == 200) {
        final resStr = await response.stream.bytesToString();
        final resJson = json.decode(resStr);
        return resJson['secure_url'];
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Uploads the profile image to Cloudinary and updates the Supabase profile with the image URL.
  static Future<String?> uploadProfileImage(File imageFile) async {
    try {
      final user = SupabaseService.client.auth.currentUser;
      if (user == null) return null;

      final imageUrl = await uploadProfileImageToCloudinary(imageFile);

      if (imageUrl != null) {
        await SupabaseService.client
            .from('profiles')
            .update({'profile_image_url': imageUrl})
            .eq('id', user.id);

        return imageUrl;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Deletes all user data from the database including profile, test results, and other related data.
  /// This method should be called before deleting the user account.
  static Future<bool> deleteUserData() async {
    try {
      final user = SupabaseService.client.auth.currentUser;
      if (user == null) return false;

      final userId = user.id;

      // Delete test results
      await SupabaseService.client
          .from('test_results')
          .delete()
          .eq('user_id', userId);

      // Delete profile
      await SupabaseService.client.from('profiles').delete().eq('id', userId);

      // Note: The user account itself will be deleted by Supabase auth
      // when the user is deleted from the auth.users table

      return true;
    } catch (e) {
      return false;
    }
  }

  /// Completely deletes the user account and all associated data.
  /// This is a destructive operation that cannot be undone.
  static Future<bool> deleteUserAccount() async {
    try {
      final user = SupabaseService.client.auth.currentUser;
      if (user == null) return false;

      final session = SupabaseService.client.auth.currentSession;
      if (session == null) return false;

      // Get user email before deletion for clearing saved credentials
      final userEmail = user.email;

      // Try to call the Supabase Edge Function first (complete deletion)
      try {
        final response = await SupabaseService.client.functions.invoke(
          'delete-user-account',
          headers: {'Authorization': 'Bearer ${session.accessToken}'},
        );

        if (response.status == 200) {
          // Successfully deleted from both database and auth
          await SupabaseService.client.auth.signOut();

          // Clear saved credentials for this user
          await _clearSavedCredentials(userEmail);

          return true;
        }
      } catch (functionError) {}

      // Fallback: Delete data locally and sign out
      // Note: This will only delete data, not the auth user

      final dataDeleted = await deleteUserData();
      if (dataDeleted) {
        await SupabaseService.client.auth.signOut();

        // Clear saved credentials for this user
        await _clearSavedCredentials(userEmail);

        return true;
      }

      return false;
    } catch (e) {
      return false;
    }
  }

  /// Clears saved credentials for a specific user email
  static Future<void> _clearSavedCredentials(String? userEmail) async {
    if (userEmail == null || userEmail.isEmpty) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final savedCredentials = prefs.getStringList('saved_credentials') ?? [];

      // Remove credentials for this specific email
      final updatedCredentials =
          savedCredentials.where((credential) {
            final parts = credential.split('||');
            return parts.isNotEmpty && parts[0] != userEmail;
          }).toList();

      await prefs.setStringList('saved_credentials', updatedCredentials);
    } catch (e) {
      // Error handling with user-friendly message
      ErrorMessageService.getFriendlyMessage(e);
    }
  }
}
