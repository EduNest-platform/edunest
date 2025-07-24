class ErrorMessageService {
  static String getFriendlyMessage(dynamic error) {
    final errorStr = error.toString().toLowerCase();

    if (errorStr.contains('invalid login credentials') ||
        errorStr.contains('wrong password') ||
        errorStr.contains('user not found')) {
      return 'Invalid email or password. Please try again.';
    }
    if (errorStr.contains('network') || errorStr.contains('socket')) {
      return 'Network error. Please check your connection and try again.';
    }
    if (errorStr.contains('timeout')) {
      return 'Request timed out. Please try again later.';
    }
    if (errorStr.contains('email already in use')) {
      return 'This email is already registered. Please use another email.';
    }
    if (errorStr.contains('permission denied')) {
      return 'You do not have permission to perform this action.';
    }
    if (errorStr.contains('too many requests')) {
      return 'Too many attempts. Please wait and try again.';
    }
    // Add more mappings as needed

    return 'Something went wrong. Please try again.';
  }
}
