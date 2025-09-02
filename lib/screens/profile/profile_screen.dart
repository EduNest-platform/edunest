import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import '../../services/auth_service.dart';
import '../../services/user_profile_service.dart';
import '../../models/user_profile.dart';
import '../auth/change_password_screen.dart';
import '../auth/profile_setup_screen.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../widgets/app_text.dart';
import 'personal_info_screen.dart';
import '../../services/error_message_service.dart';
import '../../widgets/desktop_sidebar.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  UserProfile? _userProfile;
  bool _isLoading = true;
  bool _isUploadingImage = false;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    try {
      final profile = await UserProfileService.getCurrentUserProfile();
      setState(() {
        _userProfile = profile;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        final message = ErrorMessageService.getFriendlyMessage(e);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _logout(BuildContext context) async {
    try {
      await AuthService.signOut();

      if (context.mounted) {
        Navigator.pushReplacementNamed(context, '/login');
      }
    } catch (e) {
      final message = ErrorMessageService.getFriendlyMessage(e);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _pickAndUploadProfileImage() async {
    try {
      // Request permissions for Android
      if (Platform.isAndroid) {
        final status = await Permission.photos.request();
        final storageStatus = await Permission.storage.request();
        final cameraStatus = await Permission.camera.request();

        if (!status.isGranted &&
            !storageStatus.isGranted &&
            !cameraStatus.isGranted) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Permission denied for picking images.'),
              ),
            );
          }
          return;
        }
      }

      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );

      if (pickedFile != null) {
        setState(() {
          _isUploadingImage = true;
        });

        final imageFile = File(pickedFile.path);
        final imageUrl = await UserProfileService.uploadProfileImage(imageFile);

        if (imageUrl != null) {
          await _loadUserProfile();
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Profile picture updated successfully!'),
                backgroundColor: Colors.green,
              ),
            );
          }
        } else {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Failed to upload profile picture. Please try again.',
                ),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        final message = ErrorMessageService.getFriendlyMessage(e);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploadingImage = false;
        });
      }
    }
  }

  Widget _buildAcademicPathSection() {
    return Container(
      margin: const EdgeInsets.all(24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.school_rounded,
                  color: AppTheme.primaryBlue,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Academic Path',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryBlue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildProfileField(
            'College',
            Icons.school,
            value: _userProfile?.college ?? 'Not set',
          ),
          const SizedBox(height: 16),
          _buildProfileField(
            'Branch',
            Icons.account_tree,
            value: _userProfile?.branch ?? 'Not set',
          ),
          const SizedBox(height: 16),
          _buildProfileField(
            'Semester',
            Icons.grade,
            value: _userProfile?.semester?.toString() ?? 'Not set',
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ProfileSetupScreen(isEditingExisting: true),
                  ),
                );
              },
              icon: const Icon(Icons.edit_rounded),
              label: Text(
                'Edit Academic Path',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.primaryBlue,
                side: const BorderSide(color: AppTheme.primaryBlue),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileField(
    String label,
    IconData icon, {
    required String value,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppTheme.primaryBlue.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: AppTheme.primaryBlue, size: 16),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textSecondary,
                ),
              ),
              Text(
                value,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAccountActions() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildActionTile(
            icon: Icons.lock_reset_rounded,
            title: 'Change Password',
            subtitle: 'Update your account password',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ChangePasswordScreen(),
                ),
              );
            },
          ),
          const Divider(height: 1, indent: 56, endIndent: 16),
          _buildActionTile(
            icon: Icons.person_rounded,
            title: 'Personal Information',
            subtitle: 'View and edit your details',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const PersonalInfoScreen(),
                ),
              );
            },
          ),
          const Divider(height: 1, indent: 56, endIndent: 16),
          _buildActionTile(
            icon: Icons.security_rounded,
            title: 'Security',
            subtitle: 'Change password and security settings',
            onTap: () {
              Navigator.pushNamed(context, '/security');
            },
          ),
          const Divider(height: 1, indent: 56, endIndent: 16),
          _buildActionTile(
            icon: Icons.notifications_rounded,
            title: 'Notifications',
            subtitle: 'Manage your notification preferences',
            onTap: () {
              Navigator.pushNamed(context, '/settings');
            },
          ),
          const Divider(height: 1, indent: 56, endIndent: 16),
          _buildActionTile(
            icon: Icons.help_rounded,
            title: 'Help & Support',
            subtitle: 'Get help and contact support',
            onTap: () {
              Navigator.pushNamed(context, '/help-support');
            },
          ),
          const Divider(height: 1, indent: 56, endIndent: 16),
          _buildActionTile(
            icon: Icons.delete_forever_rounded,
            title: 'Delete Account',
            subtitle: 'Permanently delete your account and data',
            onTap: () {
              _showDeleteAccountDialog();
            },
            isDestructive: true,
          ),
        ],
      ),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color:
              isDestructive
                  ? Colors.red.withValues(alpha: 0.1)
                  : AppTheme.primaryBlue.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          color: isDestructive ? Colors.red : AppTheme.primaryBlue,
          size: 20,
        ),
      ),
      title: Text(
        title,
        style: GoogleFonts.poppins(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: isDestructive ? Colors.red : Colors.black87,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: GoogleFonts.poppins(
          fontSize: 12,
          color: isDestructive ? Colors.red.shade600 : AppTheme.textSecondary,
        ),
      ),
      trailing: Icon(
        Icons.arrow_forward_ios_rounded,
        color: isDestructive ? Colors.red.shade400 : AppTheme.textSecondary,
        size: 16,
      ),
      onTap: onTap,
    );
  }

  Widget _buildLogoutButton() {
    return Container(
      margin: const EdgeInsets.all(24),
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () => _logout(context),
        icon: const Icon(Icons.logout_rounded),
        label: Text(
          'Logout',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 16),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.red,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
      ),
    );
  }

  void _showDeleteAccountDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(Icons.warning_rounded, color: Colors.red, size: 24),
              const SizedBox(width: 8),
              Text(
                'Delete Account',
                style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Are you sure you want to delete your account? This action cannot be undone and all your data will be permanently lost.',
                style: GoogleFonts.poppins(fontSize: 14),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          color: Colors.red.shade600,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'This will delete:',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.red.shade700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _buildDeleteItem('Your profile information'),
                    _buildDeleteItem('All test results and progress'),
                    _buildDeleteItem('Academic path data'),
                    _buildDeleteItem('Profile picture'),
                    _buildDeleteItem('Your authentication account'),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Cancel',
                style: GoogleFonts.poppins(
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await _performAccountDeletion();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                'Delete Account',
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
  }

  Widget _buildDeleteItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 24, bottom: 4),
      child: Row(
        children: [
          Icon(
            Icons.remove_circle_outline_rounded,
            color: Colors.red.shade500,
            size: 12,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.poppins(
                fontSize: 11,
                color: Colors.red.shade600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _performAccountDeletion() async {
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: Colors.red),
              const SizedBox(height: 16),
              Text(
                'Deleting your account...',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Please wait while we remove all your data.',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
      },
    );

    try {
      final success = await UserProfileService.deleteUserAccount();

      if (context.mounted) {
        Navigator.of(context).pop(); // Close loading dialog

        if (success) {
          // Show success message and navigate to login
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Account and all data deleted successfully'),
                backgroundColor: Colors.green,
              ),
            );

            // Navigate to login screen
            Navigator.pushReplacementNamed(context, '/login');
          }
        } else {
          // Show error message
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Failed to delete account. Please try again.'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop(); // Close loading dialog
        final message = ErrorMessageService.getFriendlyMessage(e);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 900;
    final maxContentWidth = 800.0;
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body:
          isDesktop
              ? Row(
                children: [
                  DesktopSidebar(
                    selected: 'profile',
                    onNavigate: (route) => Navigator.pushNamed(context, route),
                    onLogout: () {
                      // Implement logout logic if needed
                    },
                  ),
                  Expanded(
                    child: CustomScrollView(
                      slivers: [
                        SliverAppBar(
                          expandedHeight: 200,
                          floating: false,
                          pinned: true,
                          backgroundColor: AppTheme.primaryBlue,
                          elevation: 0,
                          title: null,
                          leading: Container(
                            margin: const EdgeInsets.only(
                              left: 16,
                              top: 0,
                              bottom: 16,
                              right: 0,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.9),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.1),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: IconButton(
                              icon: const Icon(
                                Icons.arrow_back_ios_rounded,
                                color: Colors.black87,
                              ),
                              onPressed: () => Navigator.pop(context),
                            ),
                          ),
                          flexibleSpace: LayoutBuilder(
                            builder: (context, constraints) {
                              final double delta = 200 - kToolbarHeight;
                              final double t = ((constraints.maxHeight -
                                          kToolbarHeight) /
                                      delta)
                                  .clamp(0.0, 1.0);
                              final bool collapsed = t < 0.5;
                              final double topPadding = 0.0;
                              return FlexibleSpaceBar(
                                title:
                                    collapsed
                                        ? AppText(
                                          'Profile',
                                          style: GoogleFonts.poppins(
                                            fontSize: 28,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                            letterSpacing: -0.5,
                                          ),
                                        )
                                        : null,
                                titlePadding: const EdgeInsetsDirectional.only(
                                  start: 72,
                                  bottom: 16,
                                ),
                                collapseMode: CollapseMode.parallax,
                                background: Container(
                                  decoration: const BoxDecoration(
                                    gradient: AppTheme.primaryGradient,
                                    // Removed borderRadius for edge-to-edge effect
                                  ),
                                  child: Center(
                                    child: SingleChildScrollView(
                                      physics: NeverScrollableScrollPhysics(),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          SizedBox(height: topPadding),
                                          if (!collapsed)
                                            AppText(
                                              'Profile',
                                              style: GoogleFonts.poppins(
                                                fontSize: 22,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.white,
                                                letterSpacing: -0.5,
                                              ),
                                            ),
                                          if (!collapsed)
                                            const SizedBox(height: 10),
                                          Stack(
                                            alignment: Alignment.center,
                                            children: [
                                              Container(
                                                width: 95,
                                                height: 95,
                                                decoration: BoxDecoration(
                                                  shape: BoxShape.circle,
                                                  color: Colors.white
                                                      .withValues(alpha: 0.2),
                                                  border: Border.all(
                                                    color: Colors.white
                                                        .withValues(alpha: 0.3),
                                                    width: 3,
                                                  ),
                                                  boxShadow: [
                                                    BoxShadow(
                                                      color: Colors.black
                                                          .withValues(
                                                            alpha: 0.1,
                                                          ),
                                                      blurRadius: 16,
                                                      offset: const Offset(
                                                        0,
                                                        8,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                child: CircleAvatar(
                                                  radius: 50,
                                                  backgroundColor: Colors.white,
                                                  child: ClipOval(
                                                    child:
                                                        _isUploadingImage
                                                            ? const Center(
                                                              child: CircularProgressIndicator(
                                                                color:
                                                                    AppTheme
                                                                        .primaryBlue,
                                                              ),
                                                            )
                                                            : (_userProfile
                                                                        ?.profileImageUrl !=
                                                                    null &&
                                                                _userProfile!
                                                                    .profileImageUrl!
                                                                    .isNotEmpty)
                                                            ? Image.network(
                                                              _userProfile!
                                                                  .profileImageUrl!,
                                                              fit: BoxFit.cover,
                                                              width: 91,
                                                              height: 91,
                                                              errorBuilder:
                                                                  (
                                                                    context,
                                                                    error,
                                                                    stackTrace,
                                                                  ) => const Icon(
                                                                    Icons
                                                                        .person_rounded,
                                                                    size: 50,
                                                                    color:
                                                                        AppTheme
                                                                            .primaryBlue,
                                                                  ),
                                                            )
                                                            : const Icon(
                                                              Icons
                                                                  .person_rounded,
                                                              size: 50,
                                                              color:
                                                                  AppTheme
                                                                      .primaryBlue,
                                                            ),
                                                  ),
                                                ),
                                              ),
                                              Positioned(
                                                bottom: 6,
                                                right: 6,
                                                child: GestureDetector(
                                                  onTap:
                                                      _isUploadingImage
                                                          ? null
                                                          : _pickAndUploadProfileImage,
                                                  child: Container(
                                                    padding:
                                                        const EdgeInsets.all(6),
                                                    decoration: BoxDecoration(
                                                      color: Colors.white,
                                                      shape: BoxShape.circle,
                                                      boxShadow: [
                                                        BoxShadow(
                                                          color: Colors.black
                                                              .withValues(
                                                                alpha: 0.08,
                                                              ),
                                                          blurRadius: 6,
                                                        ),
                                                      ],
                                                    ),
                                                    child: Icon(
                                                      Icons.camera_alt_rounded,
                                                      color:
                                                          AppTheme.primaryBlue,
                                                      size: 20,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 10),
                                          Text(
                                            _userProfile?.fullName ?? 'Student',
                                            style: GoogleFonts.poppins(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            AuthService.currentUser?.email ??
                                                'No email',
                                            style: GoogleFonts.poppins(
                                              fontSize: 12,
                                              color: Colors.white.withValues(
                                                alpha: 0.8,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 12),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        SliverToBoxAdapter(
                          child: Align(
                            alignment: Alignment.topCenter,
                            child: Container(
                              constraints: BoxConstraints(
                                maxWidth: maxContentWidth,
                              ),
                              margin: const EdgeInsets.symmetric(vertical: 24),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 32,
                              ),
                              child: Column(
                                children: [
                                  _buildAcademicPathSection(),
                                  const SizedBox(height: 16),
                                  _buildAccountActions(),
                                  const SizedBox(height: 16),
                                  _buildLogoutButton(),
                                  const SizedBox(height: 20),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              )
              : Align(
                alignment: Alignment.topCenter,
                child: Container(
                  constraints:
                      isDesktop
                          ? BoxConstraints(maxWidth: maxContentWidth)
                          : null,
                  margin:
                      isDesktop
                          ? const EdgeInsets.symmetric(vertical: 24)
                          : null,
                  child: CustomScrollView(
                    slivers: [
                      SliverAppBar(
                        expandedHeight: 200,
                        floating: false,
                        pinned: true,
                        backgroundColor: AppTheme.primaryBlue,
                        elevation: 0,
                        title: null,
                        leading: Container(
                          margin: const EdgeInsets.only(
                            left: 16,
                            top: 0,
                            bottom: 16,
                            right: 0,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.9),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.1),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: IconButton(
                            icon: const Icon(
                              Icons.arrow_back_ios_rounded,
                              color: Colors.black87,
                            ),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ),
                        flexibleSpace: LayoutBuilder(
                          builder: (context, constraints) {
                            final double delta = 200 - kToolbarHeight;
                            final double t = ((constraints.maxHeight -
                                        kToolbarHeight) /
                                    delta)
                                .clamp(0.0, 1.0);
                            final bool collapsed = t < 0.5;
                            final double topPadding = 0.0;
                            return FlexibleSpaceBar(
                              title:
                                  collapsed
                                      ? AppText(
                                        'Profile',
                                        style: GoogleFonts.poppins(
                                          fontSize: 28,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                          letterSpacing: -0.5,
                                        ),
                                      )
                                      : null,
                              titlePadding: const EdgeInsetsDirectional.only(
                                start: 72,
                                bottom: 16,
                              ),
                              collapseMode: CollapseMode.parallax,
                              background: Container(
                                decoration: const BoxDecoration(
                                  gradient: AppTheme.primaryGradient,
                                  borderRadius: BorderRadius.only(
                                    bottomLeft: Radius.circular(24),
                                    bottomRight: Radius.circular(24),
                                  ),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    SizedBox(height: topPadding),
                                    if (!collapsed)
                                      AppText(
                                        'Profile',
                                        style: GoogleFonts.poppins(
                                          fontSize: 22,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                          letterSpacing: -0.5,
                                        ),
                                      ),
                                    if (!collapsed) const SizedBox(height: 10),
                                    Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        Container(
                                          width: 95,
                                          height: 95,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: Colors.white.withValues(
                                              alpha: 0.2,
                                            ),
                                            border: Border.all(
                                              color: Colors.white.withValues(
                                                alpha: 0.3,
                                              ),
                                              width: 3,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black.withValues(
                                                  alpha: 0.1,
                                                ),
                                                blurRadius: 16,
                                                offset: const Offset(0, 8),
                                              ),
                                            ],
                                          ),
                                          child: CircleAvatar(
                                            radius: 50,
                                            backgroundColor: Colors.white,
                                            child: ClipOval(
                                              child:
                                                  _isUploadingImage
                                                      ? const Center(
                                                        child: CircularProgressIndicator(
                                                          color:
                                                              AppTheme
                                                                  .primaryBlue,
                                                        ),
                                                      )
                                                      : (_userProfile
                                                                  ?.profileImageUrl !=
                                                              null &&
                                                          _userProfile!
                                                              .profileImageUrl!
                                                              .isNotEmpty)
                                                      ? Image.network(
                                                        _userProfile!
                                                            .profileImageUrl!,
                                                        fit: BoxFit.cover,
                                                        width: 91,
                                                        height: 91,
                                                        errorBuilder:
                                                            (
                                                              context,
                                                              error,
                                                              stackTrace,
                                                            ) => const Icon(
                                                              Icons
                                                                  .person_rounded,
                                                              size: 50,
                                                              color:
                                                                  AppTheme
                                                                      .primaryBlue,
                                                            ),
                                                      )
                                                      : const Icon(
                                                        Icons.person_rounded,
                                                        size: 50,
                                                        color:
                                                            AppTheme
                                                                .primaryBlue,
                                                      ),
                                            ),
                                          ),
                                        ),
                                        Positioned(
                                          bottom: 6,
                                          right: 6,
                                          child: GestureDetector(
                                            onTap:
                                                _isUploadingImage
                                                    ? null
                                                    : _pickAndUploadProfileImage,
                                            child: Container(
                                              padding: const EdgeInsets.all(6),
                                              decoration: BoxDecoration(
                                                color: Colors.white,
                                                shape: BoxShape.circle,
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: Colors.black
                                                        .withValues(
                                                          alpha: 0.08,
                                                        ),
                                                    blurRadius: 6,
                                                  ),
                                                ],
                                              ),
                                              child: Icon(
                                                Icons.camera_alt_rounded,
                                                color: AppTheme.primaryBlue,
                                                size: 20,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      _userProfile?.fullName ?? 'Student',
                                      style: GoogleFonts.poppins(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      AuthService.currentUser?.email ??
                                          'No email',
                                      style: GoogleFonts.poppins(
                                        fontSize: 12,
                                        color: Colors.white.withValues(
                                          alpha: 0.8,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: Padding(
                          padding:
                              isDesktop
                                  ? const EdgeInsets.symmetric(horizontal: 32)
                                  : EdgeInsets.zero,
                          child: Column(
                            children: [
                              _buildAcademicPathSection(),
                              const SizedBox(height: 16),
                              _buildAccountActions(),
                              const SizedBox(height: 16),
                              _buildLogoutButton(),
                              const SizedBox(height: 20),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
    );
  }
}
