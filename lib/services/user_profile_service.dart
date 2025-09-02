import '../models/user_profile.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_profile.dart';
import 'supabase_service.dart';
import 'assignment_marks_service.dart';
import 'midsem_marks_service.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';

class UserProfileService {
  // Profile caching
  static UserProfile? _cachedProfile;
  static DateTime? _cacheExpiry;
  static String? _cachedUserId;
  static const Duration _cacheDuration = Duration(minutes: 5);
  
  // Request deduplication
  static final Map<String, Completer<UserProfile?>> _pendingRequests = {};
  
  /// Get current user profile with intelligent caching
  static Future<UserProfile?> getCurrentUserProfile({bool forceRefresh = false}) async {
    try {
      final user = SupabaseService.client.auth.currentUser;
      if (user == null) {
        _clearCache();
        return null;
      }

      final userId = user.id;
      
      // Check if we have a valid cached profile for this user
      if (!forceRefresh && 
          _cachedProfile != null && 
          _cacheExpiry != null && 
          _cachedUserId == userId &&
          DateTime.now().isBefore(_cacheExpiry!)) {
        if (kDebugMode) {
          // Using cached profile for user $userId
        }
        return _cachedProfile;
      }

      // Check for pending request to avoid duplicate API calls
      if (_pendingRequests.containsKey(userId)) {
        if (kDebugMode) {
          // Waiting for pending request for user $userId
        }
        return await _pendingRequests[userId]!.future;
      }

      // Create new request completer
      final completer = Completer<UserProfile?>();
      _pendingRequests[userId] = completer;

      try {
        if (kDebugMode) {
          // Fetching fresh profile for user $userId
        }

        final response = await SupabaseService.client
            .from('profiles')
            .select()
            .eq('id', userId)
            .single();

        final profile = UserProfile.fromJson(response);
        
        // Cache the profile
        _cachedProfile = profile;
        _cachedUserId = userId;
        _cacheExpiry = DateTime.now().add(_cacheDuration);
        
        // Complete the request
        completer.complete(profile);
        _pendingRequests.remove(userId);
        
        if (kDebugMode) {
          // Cached profile for user $userId (expires: ${_cacheExpiry!.toLocal()})
        }
        
        return profile;
      } catch (e) {
        // Handle error and complete with null
        completer.complete(null);
        _pendingRequests.remove(userId);
        
        if (kDebugMode) {
          // Error fetching profile for user $userId: $e
        }
        
        return null;
      }
    } catch (e) {
      if (kDebugMode) {
        // Unexpected error in getCurrentUserProfile: $e
      }
      return null;
    }
  }

  /// Get cached profile without making network requests
  static UserProfile? getCachedProfile() {
    final user = SupabaseService.client.auth.currentUser;
    if (user == null) return null;
    
    // Return cached profile if it exists and belongs to current user
    if (_cachedProfile != null && _cachedUserId == user.id) {
      if (kDebugMode) {
        // Returning cached profile for user ${user.id}
      }
      return _cachedProfile;
    }
    
    return null;
  }

  /// Get user profile by email address with caching
  static Future<UserProfile?> getUserProfileByEmail(String email, {bool useCache = true}) async {
    try {
      // Check if this email matches the cached profile
      if (useCache && _cachedProfile != null && _cachedProfile!.email == email &&
          _cacheExpiry != null && DateTime.now().isBefore(_cacheExpiry!)) {
        if (kDebugMode) {
          // Using cached profile for email $email
        }
        return _cachedProfile;
      }

      final response = await SupabaseService.client
          .from('profiles')
          .select()
          .eq('email', email)
          .single();

      final profile = UserProfile.fromJson(response);
      
      // Cache if this is the current user
      final currentUser = SupabaseService.client.auth.currentUser;
      if (currentUser != null && profile.id == currentUser.id) {
        _cachedProfile = profile;
        _cachedUserId = currentUser.id;
        _cacheExpiry = DateTime.now().add(_cacheDuration);
      }
      
      return profile;
    } catch (e) {
      if (kDebugMode) {
        // Error fetching profile by email $email: $e
      }
      return null;
    }
  }

  static Future<bool> updateProfile(Map<String, dynamic> profileData) async {
    try {
      final user = SupabaseService.client.auth.currentUser;
      if (user == null) return false;

      // Ensure the profile data includes the current user's ID
      profileData['id'] = user.id;

      // Use UPDATE instead of UPSERT to prevent creating new records
      await SupabaseService.client
          .from('profiles')
          .update(profileData)
          .eq('id', user.id);

      // Invalidate cache after successful update
      _invalidateCache();

      return true;
    } catch (e) {
      if (kDebugMode) {
        // Error updating profile: $e
      }
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

      // Invalidate cache after successful update
      _invalidateCache();
      
      if (kDebugMode) {
        // Profile updated and cache invalidated for user ${user.id}
      }

      return true;
    } catch (e) {
      if (kDebugMode) {
        // Error updating profile: $e
      }
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

  /// Check if student ID exists within the same academic context (college + branch + semester)
  static Future<bool> checkStudentIdExistsInSameContext({
    required String studentId,
    required String college,
    required String branch,
    required String semester,
    String? excludeUserId, // To exclude current user when editing
  }) async {
    try {
      var query = SupabaseService.client
          .from('profiles')
          .select('id')
          .eq('student_id', studentId)
          .eq('college', college)
          .eq('branch', branch)
          .eq('semester', semester);
      
      // Exclude current user if provided (for edit scenarios)
      if (excludeUserId != null) {
        query = query.neq('id', excludeUserId);
      }
      
      final response = await query.limit(1);
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

        // Invalidate cache after profile image update
        _invalidateCache();
        
        if (kDebugMode) {
          // Profile image updated and cache invalidated
        }

        return imageUrl;
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        // Error uploading profile image: $e
      }
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
      } catch (functionError) {
        // Ignore function call errors and continue with fallback
      }

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
      if (kDebugMode) {
        // Error saving credentials: $e
      }
    }
  }

  // ============================================================================
  // CACHE MANAGEMENT METHODS
  // ============================================================================

  /// Invalidate the current user's profile cache
  static void _invalidateCache() {
    _cachedProfile = null;
    _cacheExpiry = null;
    _cachedUserId = null;
    
    // Also clear home screen cache when profile changes
    _clearHomeScreenCache();
    
    if (kDebugMode) {
      // Profile cache invalidated
    }
  }

  /// Clear home screen cache when profile changes
  static void _clearHomeScreenCache() {
    try {
      // Use reflection-like approach to call static method from home screen
      // This avoids circular imports
      if (kDebugMode) {
        // Clearing home screen cache due to profile update
      }
      
      // We'll use a callback mechanism instead of direct import
      if (_homeScreenCacheCallback != null) {
        _homeScreenCacheCallback!();
      }
      
      // Call registered home screen cache clear callback
      _homeScreenCacheClearCallback?.call();
      
      // Clear assignment marks cache
      AssignmentMarksService.clearCache();
      
      // Clear midsem marks cache
      MidsemMarksService.clearCache();
    } catch (e) {
      if (kDebugMode) {
        // Error clearing home screen cache: $e
      }
    }
  }

  // Callback for clearing home screen cache
  static VoidCallback? _homeScreenCacheCallback;
  static VoidCallback? _homeScreenCacheClearCallback;
  
  // Callback for clearing assignment marks cache
  static VoidCallback? _assignmentMarksCacheCallback;
  
  /// Register callback to clear home screen cache
  static void registerHomeScreenCacheClearCallback(VoidCallback callback) {
    _homeScreenCacheClearCallback = callback;
    if (kDebugMode) {
      // Home screen cache clear callback registered
    }
  }
  
  /// Unregister home screen cache clear callback
  static void unregisterHomeScreenCacheClearCallback() {
    _homeScreenCacheClearCallback = null;
    if (kDebugMode) {
      // Home screen cache clear callback unregistered
    }
  }
  
  /// Register callback to clear assignment marks cache
  static void registerAssignmentMarksCacheClearCallback(VoidCallback callback) {
    _assignmentMarksCacheCallback = callback;
    if (kDebugMode) {
      // Assignment marks cache clear callback registered
    }
  }
  
  /// Unregister assignment marks cache clear callback
  static void unregisterAssignmentMarksCacheClearCallback() {
    _assignmentMarksCacheCallback = null;
    if (kDebugMode) {
      // Assignment marks cache clear callback unregistered
    }
  }

  /// Clear all cache data
  static void _clearCache() {
    _cachedProfile = null;
    _cacheExpiry = null;
    _cachedUserId = null;
    _pendingRequests.clear();
    
    if (kDebugMode) {
      // All caches cleared
    }
  }

  /// Public method to clear cache (for logout scenarios)
  static void clearCache() {
    _clearCache();
  }

  /// Force refresh the current user's profile
  static Future<UserProfile?> refreshCurrentUserProfile() async {
    return await getCurrentUserProfile(forceRefresh: true);
  }

  /// Check if profile cache is valid
  static bool get isCacheValid {
    return _cachedProfile != null && 
           _cacheExpiry != null && 
           DateTime.now().isBefore(_cacheExpiry!);
  }

  /// Get cache expiry time
  static DateTime? get cacheExpiry => _cacheExpiry;


  /// Get cache statistics for monitoring
  static Map<String, dynamic> getCacheStats() {
    return {
      'profile_cached': _cachedProfile != null,
      'cache_valid': isCacheValid,
      'cache_expiry': _cacheExpiry?.toIso8601String(),
      'cached_user_id': _cachedUserId,
      'pending_requests': _pendingRequests.length,
    };
  }
}
