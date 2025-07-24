import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import '../../controllers/signup_controller.dart';
import 'package:provider/provider.dart';
import 'email_confirmation_screen.dart';
import 'dart:io';

class SignupScreen extends StatelessWidget {
  const SignupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => SignupController(),
      child: const _SignupScreenBody(),
    );
  }
}

class _SignupScreenBody extends StatefulWidget {
  const _SignupScreenBody();

  @override
  State<_SignupScreenBody> createState() => _SignupScreenBodyState();
}

class _SignupScreenBodyState extends State<_SignupScreenBody> {
  final _formKey = GlobalKey<FormState>();
  SignupController? _controller;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _controller = Provider.of<SignupController>(context, listen: false);
  }

  @override
  void dispose() {
    _controller?.disposeControllers();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = Provider.of<SignupController>(context);
    final isDesktop = Platform.isWindows || Platform.isMacOS;
    final cardMaxWidth = isDesktop ? 560.0 : double.infinity;
    final cardPadding =
        isDesktop
            ? const EdgeInsets.symmetric(horizontal: 40, vertical: 28)
            : const EdgeInsets.symmetric(horizontal: 28, vertical: 36);
    final titleFontSize = isDesktop ? 22.0 : 22.0;
    final subtitleFontSize = isDesktop ? 15.0 : 14.0;
    final fieldFontSize = isDesktop ? 16.0 : 15.0;
    final buttonFontSize = isDesktop ? 16.0 : 16.0;
    final buttonPadding =
        isDesktop
            ? const EdgeInsets.symmetric(vertical: 14)
            : const EdgeInsets.symmetric(vertical: 14);
    final fieldAlign = isDesktop ? TextAlign.left : TextAlign.start;
    final labelAlign = isDesktop ? TextAlign.left : TextAlign.start;
    return Scaffold(
      body: Container(
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
                elevation: 10,
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
                      crossAxisAlignment:
                          isDesktop
                              ? CrossAxisAlignment.start
                              : CrossAxisAlignment.center,
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
                        Align(
                          alignment:
                              isDesktop
                                  ? Alignment.centerLeft
                                  : Alignment.center,
                          child: Text(
                        'Create your EduNest account',
                        style: GoogleFonts.poppins(
                              fontSize: titleFontSize,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryBlue,
                            ),
                            textAlign: labelAlign,
                          ),
                      ),
                      const SizedBox(height: 8),
                        Align(
                          alignment:
                              isDesktop
                                  ? Alignment.centerLeft
                                  : Alignment.center,
                          child: Text(
                        'Access all your academic resources',
                        style: GoogleFonts.poppins(
                              fontSize: subtitleFontSize,
                          color: AppTheme.textSecondary,
                            ),
                            textAlign: labelAlign,
                          ),
                        ),
                        const SizedBox(height: 24),
                      // Name Field
                      TextFormField(
                        controller: controller.nameController,
                          textAlign: fieldAlign,
                          style: TextStyle(fontSize: fieldFontSize),
                          decoration: InputDecoration(
                            prefixIcon: const Icon(Icons.person_outline),
                          labelText: 'Name',
                            labelStyle: TextStyle(fontSize: fieldFontSize),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your name';
                          }
                          return null;
                        },
                      ),
                        const SizedBox(height: 14),
                      // Email Field
                      TextFormField(
                        controller: controller.emailController,
                        keyboardType: TextInputType.emailAddress,
                          textAlign: fieldAlign,
                          style: TextStyle(fontSize: fieldFontSize),
                          decoration: InputDecoration(
                            prefixIcon: const Icon(Icons.email_outlined),
                          labelText: 'Email',
                            labelStyle: TextStyle(fontSize: fieldFontSize),
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
                        const SizedBox(height: 14),
                      // Password Field
                      TextFormField(
                        controller: controller.passwordController,
                        obscureText: true,
                          textAlign: fieldAlign,
                          style: TextStyle(fontSize: fieldFontSize),
                          decoration: InputDecoration(
                            prefixIcon: const Icon(Icons.lock_outline),
                          labelText: 'Password',
                            labelStyle: TextStyle(fontSize: fieldFontSize),
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
                        const SizedBox(height: 14),
                      // Confirm Password Field
                      TextFormField(
                        controller: controller.confirmPasswordController,
                        obscureText: true,
                          textAlign: fieldAlign,
                          style: TextStyle(fontSize: fieldFontSize),
                          decoration: InputDecoration(
                            prefixIcon: const Icon(Icons.lock_outline),
                          labelText: 'Confirm Password',
                            labelStyle: TextStyle(fontSize: fieldFontSize),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please confirm your password';
                          }
                          if (value != controller.passwordController.text) {
                            return 'Passwords do not match';
                          }
                          return null;
                        },
                      ),
                        const SizedBox(height: 20),
                      // Error Message
                      if (controller.errorMessage != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Text(
                            controller.errorMessage!,
                            style: const TextStyle(
                              color: Colors.red,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      // Login instead button (when user has existing account)
                      if (controller.hasExistingAccount)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: SizedBox(
                            width: double.infinity,
                            child: OutlinedButton(
                              onPressed: () {
                                Navigator.pushReplacementNamed(
                                  context,
                                  '/login',
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
                                'Login Instead',
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                  color: AppTheme.primaryBlue,
                                ),
                              ),
                            ),
                          ),
                        ),
                      // Sign Up Button
                      SizedBox(
                        width: double.infinity,
                          child: MouseRegion(
                            cursor:
                                isDesktop
                                    ? SystemMouseCursors.click
                                    : MouseCursor.defer,
                        child: ElevatedButton(
                          onPressed:
                              controller.isLoading
                                  ? null
                                  : () async {
                                    if (_formKey.currentState!.validate()) {
                                          final status =
                                              await controller.signUp();
                                      if (mounted) {
                                        switch (status) {
                                          case SignupStatus.success:
                                            Navigator.pushReplacementNamed(
                                              context,
                                              '/login',
                                            );
                                            break;
                                          case SignupStatus
                                              .emailConfirmationRequired:
                                            Navigator.pushReplacement(
                                              context,
                                              MaterialPageRoute(
                                                builder:
                                                    (
                                                      context,
                                                    ) => EmailConfirmationScreen(
                                                      email:
                                                          controller
                                                              .emailController
                                                              .text
                                                              .trim(),
                                                    ),
                                              ),
                                            );
                                            break;
                                          case SignupStatus.existingUser:
                                            break;
                                          case SignupStatus.error:
                                            break;
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
                                textStyle: TextStyle(fontSize: buttonFontSize),
                                elevation: isDesktop ? 4 : 2,
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
                                    'Sign Up',
                                    style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.w600,
                                          fontSize: buttonFontSize,
                                      color: Colors.white,
                                    ),
                                  ),
                        ),
                      ),
                        ),
                        const SizedBox(height: 16),
                      // Login link
                      Row(
                          mainAxisAlignment:
                              isDesktop
                                  ? MainAxisAlignment.start
                                  : MainAxisAlignment.center,
                        children: [
                          Text(
                            'Already have an account?',
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                                Navigator.pushReplacementNamed(
                                  context,
                                  '/login',
                                );
                            },
                            child: Text(
                              'Login',
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w600,
                                color: AppTheme.primaryBlue,
                              ),
                            ),
                          ),
                        ],
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
    );
  }
}
 