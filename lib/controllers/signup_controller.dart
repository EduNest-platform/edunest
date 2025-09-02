import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';

enum SignupStatus { success, emailConfirmationRequired, existingUser, error, rateLimited }

class SignupController extends ChangeNotifier {
  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();

  bool _isLoading = false;
  String? _errorMessage;
  bool _hasExistingAccount = false;
  DateTime? _lastRequestTime;
  int _requestCount = 0;
  int _failureCount = 0;
  static const int _maxRequestsPerMinute = 1;
  static const Duration _requestCooldown = Duration(minutes: 2);
  static const Duration _baseBackoffDelay = Duration(minutes: 1);

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get hasExistingAccount => _hasExistingAccount;
  
  bool get canMakeRequest {
    final now = DateTime.now();
    if (_lastRequestTime == null) return true;
    
    // Reset counters if more than 5 minutes have passed
    if (now.difference(_lastRequestTime!).inMinutes >= 5) {
      _requestCount = 0;
      _failureCount = 0;
      return true;
    }
    
    // Apply exponential backoff for failures
    if (_failureCount > 0) {
      final backoffDelay = Duration(
        minutes: _baseBackoffDelay.inMinutes * (1 << (_failureCount - 1)),
      );
      final timeSinceLastRequest = now.difference(_lastRequestTime!);
      if (timeSinceLastRequest < backoffDelay) {
        return false;
      }
    }
    
    // Check if we're within rate limits
    if (_requestCount >= _maxRequestsPerMinute) {
      final timeSinceLastRequest = now.difference(_lastRequestTime!);
      return timeSinceLastRequest >= _requestCooldown;
    }
    
    return true;
  }
  
  Duration? get remainingCooldown {
    if (_lastRequestTime == null) return null;
    final now = DateTime.now();
    final timeSinceLastRequest = now.difference(_lastRequestTime!);
    
    // Check exponential backoff first
    if (_failureCount > 0) {
      final backoffDelay = Duration(
        minutes: _baseBackoffDelay.inMinutes * (1 << (_failureCount - 1)),
      );
      if (timeSinceLastRequest < backoffDelay) {
        return backoffDelay - timeSinceLastRequest;
      }
    }
    
    // Check rate limit cooldown
    if (_requestCount >= _maxRequestsPerMinute && timeSinceLastRequest < _requestCooldown) {
      return _requestCooldown - timeSinceLastRequest;
    }
    
    return null;
  }

  void setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void setError(String? message) {
    _errorMessage = message;
    notifyListeners();
  }

  void setHasExistingAccount(bool value) {
    _hasExistingAccount = value;
    notifyListeners();
  }

  Future<SignupStatus> signUp() async {
    // Check rate limiting before proceeding
    if (!canMakeRequest) {
      final cooldown = remainingCooldown;
      if (cooldown != null) {
        setError('Too many requests. Please wait ${cooldown.inSeconds} seconds before trying again.');
        return SignupStatus.rateLimited;
      }
    }

    // Update request tracking
    _lastRequestTime = DateTime.now();
    _requestCount++;
    
    setLoading(true);
    setError(null);
    setHasExistingAccount(false);
    try {
      if (passwordController.text != confirmPasswordController.text) {
        setError('Passwords do not match');
        setLoading(false);
        return SignupStatus.error;
      }

      // Sign up with user metadata
      final response = await SupabaseService.client.auth.signUp(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
        data: {'name': nameController.text.trim()},
      );

      if (response.user != null && response.session == null) {
        // User created but email confirmation required
        setLoading(false);
        return SignupStatus.emailConfirmationRequired;
      } else if (response.user != null && response.session != null) {
        // User created and automatically signed in (email confirmation might be disabled)
        // Sign out the user so they need to login manually
        await SupabaseService.client.auth.signOut();

        // Create a basic profile entry that will require completion
        try {
          await SupabaseService.client.from('profiles').upsert({
            'id': response.user!.id,
            'full_name': nameController.text.trim(),
            'email': emailController.text.trim(),
            'created_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          });
        } catch (e) {
          // Don't fail the signup if profile update fails
          // The trigger should have created it already
        }

        setLoading(false);
        return SignupStatus.success;
      } else if (response.session != null) {
        // User already exists and is signed in
        setError(
          'An account with this email already exists. Please try logging in instead.',
        );
        setHasExistingAccount(true);
        setLoading(false);
        return SignupStatus.existingUser;
      } else {
        _failureCount++;
        setError('Sign up failed. Please try again.');
        setLoading(false);
        return SignupStatus.error;
      }
    } on AuthException catch (e) {
      // Handle specific Supabase auth errors
      switch (e.message) {
        case 'User already registered':
        case 'A user with this email address has already been registered':
          setError(
            'An account with this email already exists. Please try logging in instead.',
          );
          setHasExistingAccount(true);
          break;
        case 'Password should be at least 6 characters':
          setError('Password must be at least 6 characters long.');
          break;
        case 'Invalid email':
          setError('Please enter a valid email address.');
          break;
        default:
          setError('Sign up failed: ${e.message}');
      }
      _failureCount++;
      setLoading(false);
      return SignupStatus.error;
    } catch (e) {
      _failureCount++;
      setError('An unexpected error occurred. Please try again.');
      setLoading(false);
      return SignupStatus.error;
    }
  }

  void disposeControllers() {
    nameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
  }
}
