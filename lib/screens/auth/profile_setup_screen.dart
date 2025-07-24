import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../theme/app_theme.dart';
import '../../controllers/profile_setup_controller.dart';
import '../../services/user_profile_service.dart';
import '../../services/error_message_service.dart';
import '../../mixins/performance_mixin.dart';
import 'dart:io';

class ProfileSetupScreen extends StatelessWidget {
  const ProfileSetupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ProfileSetupController(),
      child: const _ProfileSetupScreenBody(),
    );
  }
}

class _ProfileSetupScreenBody extends StatefulWidget {
  const _ProfileSetupScreenBody();

  @override
  State<_ProfileSetupScreenBody> createState() =>
      _ProfileSetupScreenBodyState();
}

class _ProfileSetupScreenBodyState extends State<_ProfileSetupScreenBody>
    with PerformanceMixin {
  final _formKey = GlobalKey<FormState>();
  ProfileSetupController? _controller;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _controller = Provider.of<ProfileSetupController>(context, listen: false);
  }

  @override
  void initState() {
    super.initState();
    startScreenMonitoring('profile_setup_screen');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final controller = Provider.of<ProfileSetupController>(
        context,
        listen: false,
      );
      controller.fetchColleges();
      controller.loadExistingAcademicPath();
    });
  }

  @override
  void dispose() {
    _controller?.disposeControllers();
    stopScreenMonitoring();
    super.dispose();
  }

  Future<void> _resetOnboardingForNewUser() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('has_seen_onboarding');
  }

  bool _allRequiredFieldsFilled(ProfileSetupController controller) {
    return controller.selectedCollegeId != null &&
        controller.selectedBranchId != null &&
        controller.selectedSemesterId != null;
  }

  Widget _buildCustomDropdown({
    required String label,
    required String hint,
    required IconData icon,
    required String? value,
    required List<Map<String, dynamic>> items,
    required void Function(String?)? onChanged,
    required String? Function(String?) validator,
    bool enabled = true,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppTheme.primaryBlue,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color:
                    enabled
                        ? AppTheme.primaryBlue.withValues(alpha: 0.3)
                        : Colors.grey.withValues(alpha: 0.3),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: DropdownButtonFormField<String>(
              value: value,
              decoration: InputDecoration(
                prefixIcon: Icon(
                  icon,
                  color: enabled ? AppTheme.primaryBlue : Colors.grey,
                  size: 24,
                ),
                hintText: hint,
                hintStyle: GoogleFonts.poppins(
                  color: Colors.grey.shade500,
                  fontSize: 14,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                suffixIcon: Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: enabled ? AppTheme.primaryBlue : Colors.grey,
                  size: 24,
                ),
              ),
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.black87,
                fontWeight: FontWeight.w500,
              ),
              items:
                  items
                      .map(
                        (item) => DropdownMenuItem<String>(
                          value: item['id'].toString(),
                          child: Text(
                            item['name'] ?? '',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      )
                      .toList(),
              onChanged: enabled ? onChanged : null,
              validator: validator,
              dropdownColor: Colors.white,
              icon: const SizedBox.shrink(),
              isExpanded: true,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = Provider.of<ProfileSetupController>(context);
    final isDesktop = Platform.isWindows || Platform.isMacOS;
    final contentMaxWidth = isDesktop ? 600.0 : double.infinity;
    final cardPadding =
        isDesktop ? const EdgeInsets.all(32) : const EdgeInsets.all(24);
    final headerFontSize = isDesktop ? 28.0 : 24.0;
    final subHeaderFontSize = isDesktop ? 18.0 : 16.0;
    final buttonFontSize = isDesktop ? 17.0 : 16.0;
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
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: contentMaxWidth),
              child: Column(
                children: [
                  // Header
                  Padding(
                    padding: cardPadding,
                    child: Column(
                      children: [
                        // Back button and title
                        Row(
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: IconButton(
                                onPressed: () async {
                                  try {
                                    final profile =
                                        await UserProfileService.getCurrentUserProfile();
                                    if (profile?.college != null &&
                                        profile?.branch != null &&
                                        profile?.semester != null) {
                                      if (!mounted) return;
                                      Navigator.pushReplacementNamed(
                                        context,
                                        '/academic-path-review',
                                      );
                                    } else {
                                      if (!mounted) return;
                                      Navigator.pushReplacementNamed(
                                        context,
                                        '/login',
                                      );
                                    }
                                  } catch (e) {
                                    final message =
                                        ErrorMessageService.getFriendlyMessage(
                                          e,
                                        );
                                    if (mounted) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(message),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
                                    }
                                  }
                                },
                                icon: const Icon(
                                  Icons.arrow_back_ios_new_rounded,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Text(
                                'Academic Path',
                                style: GoogleFonts.poppins(
                                  fontSize: headerFontSize,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // Progress indicator
                        Row(
                          children: [
                            Expanded(
                              child: Container(
                                height: 4,
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.3),
                                  borderRadius: BorderRadius.circular(2),
                                ),
                                child: FractionallySizedBox(
                                  alignment: Alignment.centerLeft,
                                  widthFactor:
                                      _allRequiredFieldsFilled(controller)
                                          ? 1.0
                                          : 0.33,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Form
                  Expanded(
                    child: Container(
                      width: double.infinity,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(32),
                          topRight: Radius.circular(32),
                        ),
                      ),
                      child: SingleChildScrollView(
                        padding: cardPadding,
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Welcome Text
                              Text(
                                'Choose Your Academic Path',
                                style: GoogleFonts.poppins(
                                  fontSize: headerFontSize,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.primaryBlue,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Select your college, branch, and semester to access personalized academic resources',
                                style: GoogleFonts.poppins(
                                  fontSize: subHeaderFontSize,
                                  color: AppTheme.textSecondary,
                                  height: 1.5,
                                ),
                              ),
                              const SizedBox(height: 40),
                              // College Dropdown
                              _buildCustomDropdown(
                                label: 'College',
                                hint: 'Select your college',
                                icon: Icons.school_rounded,
                                value: controller.selectedCollegeId,
                                items: controller.colleges,
                                onChanged:
                                    (val) => controller.setSelectedCollege(val),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please select your college';
                                  }
                                  return null;
                                },
                              ),
                              // Branch Dropdown
                              _buildCustomDropdown(
                                label: 'Branch',
                                hint: 'Select your branch',
                                icon: Icons.account_tree_rounded,
                                value: controller.selectedBranchId,
                                items: controller.branches,
                                onChanged:
                                    controller.selectedCollegeId == null
                                        ? null
                                        : (val) =>
                                            controller.setSelectedBranch(val),
                                validator: (value) {
                                  if (controller.selectedCollegeId == null) {
                                    return 'Please select a college first';
                                  }
                                  if (value == null || value.isEmpty) {
                                    return 'Please select your branch';
                                  }
                                  return null;
                                },
                                enabled: controller.selectedCollegeId != null,
                              ),
                              // Semester Dropdown
                              _buildCustomDropdown(
                                label: 'Semester',
                                hint: 'Select your semester',
                                icon: Icons.calendar_today_rounded,
                                value: controller.selectedSemesterId,
                                items: controller.semesters,
                                onChanged:
                                    controller.selectedBranchId == null
                                        ? null
                                        : (val) =>
                                            controller.setSelectedSemester(val),
                                validator: (value) {
                                  if (controller.selectedBranchId == null) {
                                    return 'Please select a branch first';
                                  }
                                  if (value == null || value.isEmpty) {
                                    return 'Please select your semester';
                                  }
                                  return null;
                                },
                                enabled: controller.selectedBranchId != null,
                              ),
                              const SizedBox(height: 32),
                              // Academic Path Summary
                              if (_allRequiredFieldsFilled(controller))
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(24),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        AppTheme.primaryBlue.withValues(
                                          alpha: 0.1,
                                        ),
                                        AppTheme.primaryLight.withValues(
                                          alpha: 0.05,
                                        ),
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: AppTheme.primaryBlue.withValues(
                                        alpha: 0.2,
                                      ),
                                      width: 1.5,
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color: AppTheme.primaryBlue,
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            child: const Icon(
                                              Icons.check_circle_rounded,
                                              color: Colors.white,
                                              size: 20,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Text(
                                            'Your Academic Path',
                                            style: GoogleFonts.poppins(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 18,
                                              color: AppTheme.primaryBlue,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 16),
                                      Container(
                                        padding: const EdgeInsets.all(16),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withValues(
                                                alpha: 0.05,
                                              ),
                                              blurRadius: 10,
                                              offset: const Offset(0, 4),
                                            ),
                                          ],
                                        ),
                                        child: Row(
                                          children: [
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    controller
                                                        .getSelectedCollegeName(),
                                                    style: GoogleFonts.poppins(
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      fontSize: 16,
                                                      color: Colors.black87,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    '${controller.getSelectedBranchName()} • ${controller.getSelectedSemesterName()}',
                                                    style: GoogleFonts.poppins(
                                                      fontSize: 14,
                                                      color:
                                                          AppTheme
                                                              .textSecondary,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Icon(
                                              Icons.verified_rounded,
                                              color: AppTheme.primaryBlue,
                                              size: 24,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              const SizedBox(height: 40),
                              // Error Message
                              if (controller.errorMessage != null)
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(16),
                                  margin: const EdgeInsets.only(bottom: 24),
                                  decoration: BoxDecoration(
                                    color: Colors.red.shade50,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Colors.red.shade200,
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.error_outline_rounded,
                                        color: Colors.red.shade600,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          controller.errorMessage!,
                                          style: GoogleFonts.poppins(
                                            color: Colors.red.shade600,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              // Continue Button
                              SizedBox(
                                width: double.infinity,
                                height: 56,
                                child: ElevatedButton(
                                  onPressed:
                                      controller.isLoading ||
                                              !_allRequiredFieldsFilled(
                                                controller,
                                              )
                                          ? null
                                          : () async {
                                            if (_formKey.currentState!
                                                .validate()) {
                                              final success =
                                                  await controller
                                                      .saveProfile();
                                              if (success && mounted) {
                                                await _resetOnboardingForNewUser();
                                                if (!mounted) return;
                                                Navigator.pushReplacementNamed(
                                                  context,
                                                  '/home',
                                                );
                                              }
                                            }
                                          },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.primaryBlue,
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    shadowColor: Colors.transparent,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    textStyle: TextStyle(
                                      fontSize: buttonFontSize,
                                    ),
                                  ),
                                  child:
                                      controller.isLoading
                                          ? const SizedBox(
                                            width: 24,
                                            height: 24,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white,
                                            ),
                                          )
                                          : Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Text(
                                                controller.selectedCollegeId !=
                                                            null &&
                                                        controller
                                                                .selectedBranchId !=
                                                            null &&
                                                        controller
                                                                .selectedSemesterId !=
                                                            null
                                                    ? 'Update Academic Path'
                                                    : 'Continue to EduNest',
                                                style: GoogleFonts.poppins(
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: buttonFontSize,
                                                  color: Colors.white,
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              const Icon(
                                                Icons.arrow_forward_rounded,
                                                size: 20,
                                                color: Colors.white,
                                              ),
                                            ],
                                          ),
                                ),
                              ),
                              const SizedBox(height: 20),
                            ],
                          ),
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
    );
  }
}
