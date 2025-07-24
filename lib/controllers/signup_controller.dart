import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';

enum SignupStatus { success, emailConfirmationRequired, existingUser, error }

class SignupController extends ChangeNotifier {
  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();

  bool _isLoading = false;
  String? _errorMessage;
  bool _hasExistingAccount = false;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get hasExistingAccount => _hasExistingAccount;

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
      setLoading(false);
      return SignupStatus.error;
    } catch (e) {
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
