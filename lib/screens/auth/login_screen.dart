import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import '../../controllers/login_controller.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/auth_service.dart';
import 'change_password_screen.dart';
import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => LoginController(),
      child: const _LoginScreenBody(),
    );
  }
}

class _LoginScreenBody extends StatefulWidget {
  const _LoginScreenBody();

  @override
  State<_LoginScreenBody> createState() => _LoginScreenBodyState();
}

class _LoginScreenBodyState extends State<_LoginScreenBody> {
  final _formKey = GlobalKey<FormState>();
  LoginController? _controller;

  List<Map<String, String>> _savedCredentials = [];
  bool _loadingSaved = false;

  String _friendlyError(String? error) {
    if (error == null) return '';
    if (error.contains('ClientException') ||
        error.contains('SocketException') ||
        error.contains('TimeoutException') ||
        error.contains('Failed host lookup')) {
      return 'No internet connection. Please check your network and try again.';
    }
    return error;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _controller = Provider.of<LoginController>(context, listen: false);
    _loadSavedCredentials();
    _handleRouteArguments();
  }

  void _handleRouteArguments() {
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    if (args != null && args['prefillEmail'] != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _controller?.emailController.text = args['prefillEmail'];
      });
    }
  }

  Future<void> _loadSavedCredentials() async {
    setState(() => _loadingSaved = true);
    final prefs = await SharedPreferences.getInstance();
    final creds = prefs.getStringList('saved_credentials') ?? [];
    setState(() {
      _savedCredentials =
          creds.map((e) {
            final parts = e.split('||');
            return {
              'email': parts[0],
              'password': parts.length > 1 ? parts[1] : '',
            };
          }).toList();
      _loadingSaved = false;
    });
  }

  Future<void> _saveCredential(String email, String password) async {
    final prefs = await SharedPreferences.getInstance();
    final creds = prefs.getStringList('saved_credentials') ?? [];
    final entry = '$email||$password';
    creds.removeWhere((e) => e.split('||')[0] == email);
    creds.add(entry);
    await prefs.setStringList('saved_credentials', creds);
    _loadSavedCredentials();
  }

  void _showSavedCredentials() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) {
        if (_loadingSaved) {
          return const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (_savedCredentials.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: Text('No saved credentials')),
          );
        }
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
              decoration: const BoxDecoration(
                color: Color(0xFFF7FAFC),
                borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: const [
                      Icon(
                        Icons.key_rounded,
                        color: Color(0xFF90A4AE),
                        size: 22,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Saved Credentials',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 17,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: _savedCredentials.length,
                      separatorBuilder: (_, __) => const Divider(),
                      itemBuilder: (ctx, i) {
                        final cred = _savedCredentials[i];
                        return ListTile(
                          leading: const Icon(
                            Icons.account_circle_rounded,
                            color: Colors.blue,
                          ),
                          title: Text(
                            cred['email'] ?? '',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            cred['password'] != null &&
                                    cred['password']!.isNotEmpty
                                ? '••••••••'
                                : '',
                            style: const TextStyle(letterSpacing: 2),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(
                                  Icons.delete_outline,
                                  color: Colors.redAccent,
                                ),
                                tooltip: 'Delete',
                                onPressed: () async {
                                  final email = cred['email'] ?? '';
                                  setModalState(() {
                                    _savedCredentials.removeAt(i);
                                  });
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Credential deleted'),
                                        duration: const Duration(seconds: 1),
                                      ),
                                    );
                                  }
                                  // Update SharedPreferences in background
                                  final prefs =
                                      await SharedPreferences.getInstance();
                                  final creds =
                                      prefs.getStringList(
                                        'saved_credentials',
                                      ) ??
                                      [];
                                  creds.removeWhere(
                                    (e) => e.split('||')[0] == email,
                                  );
                                  await prefs.setStringList(
                                    'saved_credentials',
                                    creds,
                                  );
                                },
                              ),
                              IconButton(
                                icon: const Icon(Icons.arrow_forward_rounded),
                                onPressed: () {
                                  _controller?.emailController.text =
                                      cred['email'] ?? '';
                                  _controller?.passwordController.text =
                                      cred['password'] ?? '';
                                  Navigator.pop(context);
                                },
                              ),
                            ],
                          ),
                          onTap: () {
                            _controller?.emailController.text =
                                cred['email'] ?? '';
                            _controller?.passwordController.text =
                                cred['password'] ?? '';
                            Navigator.pop(context);
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _showForgotPasswordDialog(BuildContext context) async {
    final emailController = TextEditingController(
      text: _controller?.emailController.text ?? '',
    );
    String? error;
    bool isLoading = false;
    await showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              title: Row(
                children: const [
                  Icon(
                    Icons.lock_reset_rounded,
                    color: Colors.blueAccent,
                    size: 26,
                  ),
                  SizedBox(width: 10),
                  Text(
                    'Reset Password',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 6),
                  const Text(
                    'Enter your email to receive a password reset link.',
                    style: TextStyle(fontSize: 14, color: Colors.black87),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: 'Email',
                      prefixIcon: const Icon(Icons.email_outlined),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      error!,
                      style: const TextStyle(color: Colors.red, fontSize: 13),
                    ),
                  ],
                ],
              ),
              actionsPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
              actions: [
                TextButton(
                  onPressed:
                      () =>
                          Navigator.of(
                            dialogContext,
                            rootNavigator: true,
                          ).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed:
                      isLoading
                          ? null
                          : () async {
                            setState(() {
                              isLoading = true;
                              error = null;
                            });
                            try {
                              await Supabase.instance.client.auth
                                  .resetPasswordForEmail(
                                    emailController.text.trim(),
                                  );
                              if (context.mounted) {
                                Navigator.of(
                                  dialogContext,
                                  rootNavigator: true,
                                ).pop();
                                await showDialog(
                                  context: context,
                                  builder:
                                      (ctx) => AlertDialog(
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            18,
                                          ),
                                        ),
                                        title: Row(
                                          children: const [
                                            Icon(
                                              Icons.mark_email_read_rounded,
                                              color: Colors.green,
                                              size: 26,
                                            ),
                                            SizedBox(width: 10),
                                            Text(
                                              'Email Sent',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                        content: const Padding(
                                          padding: EdgeInsets.only(
                                            top: 8.0,
                                            bottom: 4.0,
                                          ),
                                          child: Text(
                                            'A password reset email has been sent. Please check your inbox.',
                                            style: TextStyle(fontSize: 15),
                                          ),
                                        ),
                                        actionsPadding: EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 8,
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed:
                                                () =>
                                                    Navigator.of(
                                                      ctx,
                                                      rootNavigator: true,
                                                    ).pop(),
                                            child: const Text('OK'),
                                          ),
                                        ],
                                      ),
                                );
                              }
                            } catch (e) {
                              setState(() {
                                error =
                                    'Failed to send reset email. Please check the email address.';
                                isLoading = false;
                              });
                            }
                          },
                  child:
                      isLoading
                          ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                          : const Text('Send'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  void dispose() {
    _controller?.disposeControllers();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = Provider.of<LoginController>(context);
    final isDesktop = Platform.isWindows || Platform.isMacOS;
    final cardMaxWidth = isDesktop ? 420.0 : double.infinity;
    final cardPadding =
        isDesktop
            ? const EdgeInsets.symmetric(horizontal: 32, vertical: 32)
            : const EdgeInsets.symmetric(horizontal: 28, vertical: 36);
    final titleFontSize = isDesktop ? 22.0 : 24.0;
    final subtitleFontSize = isDesktop ? 13.0 : 14.0;
    final buttonFontSize = isDesktop ? 15.0 : 16.0;
    final buttonPadding =
        isDesktop
            ? const EdgeInsets.symmetric(vertical: 12)
            : const EdgeInsets.symmetric(vertical: 14);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        // Show confirmation dialog before closing app
        final shouldClose = await showDialog<bool>(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Row(
                children: [
                  Icon(
                    Icons.exit_to_app_rounded,
                    color: Colors.orange,
                    size: 24,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Exit App',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              content: Text(
                'Are you sure you want to exit EduNest?',
                style: GoogleFonts.poppins(fontSize: 14),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text(
                    'Cancel',
                    style: GoogleFonts.poppins(
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    'Exit',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            );
          },
        );
        if (shouldClose == true) {
          exit(0);
        }
      },
      child: Scaffold(
        body: Stack(
          children: [
            Container(
              width: double.infinity,
              height: double.infinity,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppTheme.primaryBlue, AppTheme.primaryLight],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Center(
                child: SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: cardMaxWidth),
                    child: Card(
                      elevation: 8,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      margin:
                          isDesktop
                              ? const EdgeInsets.symmetric(horizontal: 0)
                              : const EdgeInsets.symmetric(horizontal: 24),
                      child: Padding(
                        padding: cardPadding,
                        child: Form(
                          key: _formKey,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Logo Placeholder
                              Container(
                                width: 64,
                                height: 64,
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryLight,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: const Icon(
                                  Icons.school,
                                  size: 40,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 18),
                              Text(
                                'Welcome to EduNest',
                                style: GoogleFonts.poppins(
                                  fontSize: titleFontSize,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.primaryBlue,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Your Academic Resource Nest',
                                style: GoogleFonts.poppins(
                                  fontSize: subtitleFontSize,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 28),
                              // Email Field
                              TextFormField(
                                controller: controller.emailController,
                                keyboardType: TextInputType.emailAddress,
                                decoration: InputDecoration(
                                  prefixIcon: const Icon(Icons.email_outlined),
                                  labelText: 'Email',
                                  suffixIcon: IconButton(
                                    icon: const Icon(
                                      Icons.key_rounded,
                                      color: Colors.blueAccent,
                                    ),
                                    tooltip: 'Show saved credentials',
                                    onPressed: _showSavedCredentials,
                                  ),
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter your email';
                                  }
                                  if (!RegExp(
                                    r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                                  ).hasMatch(value)) {
                                    return 'Enter a valid email';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 18),
                              // Password Field
                              TextFormField(
                                controller: controller.passwordController,
                                obscureText: true,
                                decoration: const InputDecoration(
                                  prefixIcon: Icon(Icons.lock_outline),
                                  labelText: 'Password',
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter your password';
                                  }
                                  if (value.length < 6) {
                                    return 'Password must be at least 6 characters';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),
                              Align(
                                alignment: Alignment.centerRight,
                                child: Padding(
                                  padding: EdgeInsets.only(right: 2),
                                  child: TextButton(
                                    onPressed: () async {
                                      await _showForgotPasswordDialog(context);
                                    },
                                    style: TextButton.styleFrom(
                                      padding: EdgeInsets.zero,
                                      minimumSize: Size(0, 0),
                                      tapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                    ),
                                    child: Text(
                                      'Forgot Password?',
                                      style: GoogleFonts.poppins(
                                        color: AppTheme.primaryBlue,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 24),
                              // Error Message
                              if (controller.errorMessage != null)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: Text(
                                    _friendlyError(controller.errorMessage),
                                    style: const TextStyle(
                                      color: Colors.red,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              // Sign up instead button (when user doesn't exist)
                              if (controller.userNotFound)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: SizedBox(
                                    width: double.infinity,
                                    child: OutlinedButton(
                                      onPressed: () {
                                        Navigator.pushReplacementNamed(
                                          context,
                                          '/signup',
                                        );
                                      },
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 12,
                                        ),
                                        side: const BorderSide(
                                          color: AppTheme.primaryBlue,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                      ),
                                      child: Text(
                                        'Sign Up Instead',
                                        style: GoogleFonts.poppins(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14,
                                          color: AppTheme.primaryBlue,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              // Login Button
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed:
                                      controller.isLoading
                                          ? null
                                          : () async {
                                            if (_formKey.currentState!
                                                .validate()) {
                                              final result =
                                                  await controller
                                                      .loginWithEmail();
                                              if (result.success && mounted) {
                                                await _saveCredential(
                                                  controller
                                                      .emailController
                                                      .text,
                                                  controller
                                                      .passwordController
                                                      .text,
                                                );
                                                if (!mounted) return;
                                                if (result.needsProfileSetup) {
                                                  Navigator.pushReplacementNamed(
                                                    context,
                                                    '/profile-setup',
                                                  );
                                                } else if (result
                                                    .hasCompletedAcademicPath) {
                                                  Navigator.pushReplacementNamed(
                                                    context,
                                                    '/academic-path-review',
                                                  );
                                                } else {
                                                  Navigator.pushReplacementNamed(
                                                    context,
                                                    '/home',
                                                  );
                                                }
                                              }
                                            }
                                          },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.primaryBlue,
                                    padding: buttonPadding,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                  child:
                                      controller.isLoading
                                          ? const SizedBox(
                                            width: 22,
                                            height: 22,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white,
                                            ),
                                          )
                                          : Text(
                                            'Login',
                                            style: GoogleFonts.poppins(
                                              fontWeight: FontWeight.w600,
                                              fontSize: buttonFontSize,
                                              color: Colors.white,
                                            ),
                                          ),
                                ),
                              ),
                              const SizedBox(height: 18),
                              // Sign up link
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    "Don't have an account?",
                                    style: GoogleFonts.poppins(
                                      fontSize: 13,
                                      color: AppTheme.textSecondary,
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      Navigator.pushReplacementNamed(
                                        context,
                                        '/signup',
                                      );
                                    },
                                    child: Text(
                                      'Sign up',
                                      style: GoogleFonts.poppins(
                                        fontWeight: FontWeight.w600,
                                        color: AppTheme.primaryBlue,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),

                              if (AuthService.currentUser != null)
                                SizedBox(
                                  width: double.infinity,
                                  child: OutlinedButton(
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder:
                                              (context) =>
                                                  const ChangePasswordScreen(),
                                        ),
                                      );
                                    },
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 12,
                                      ),
                                      side: const BorderSide(
                                        color: AppTheme.primaryBlue,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                    child: Text(
                                      'Change Password',
                                      style: GoogleFonts.poppins(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                        color: AppTheme.primaryBlue,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
