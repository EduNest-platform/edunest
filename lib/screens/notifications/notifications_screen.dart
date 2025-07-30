import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import '../../widgets/desktop_sidebar.dart';
import '../../widgets/custom_app_bar.dart';
import '../../widgets/app_text.dart';
import 'package:flutter/foundation.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDesktop =
        kIsWeb ||
        [
          TargetPlatform.macOS,
          TargetPlatform.windows,
          TargetPlatform.linux,
        ].contains(Theme.of(context).platform);
    final maxContentWidth = 600.0;

    Widget content = Center(
      child: Container(
        constraints: BoxConstraints(maxWidth: maxContentWidth),
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(
              Icons.notifications_none_rounded,
              color: AppTheme.primaryBlue,
              size: 56,
            ),
            const SizedBox(height: 18),
            AppText(
              'No Notifications Yet',
              style: GoogleFonts.poppins(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryBlue,
              ),
              maxLines: 2,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            AppText(
              'You have no notifications at the moment. Important updates and alerts will appear here.',
              style: GoogleFonts.poppins(
                fontSize: 15,
                color: AppTheme.textSecondary,
              ),
              maxLines: 3,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );

    if (isDesktop) {
      return Scaffold(
        backgroundColor: Colors.grey.shade50,
        body: Row(
          children: [
            DesktopSidebar(
              selected: 'notifications',
              onNavigate: (route) => Navigator.pushNamed(context, route),
            ),
            Expanded(
              child: Column(
                children: [
                  CustomAppBar(
                    title: 'Notifications',
                    subtitle: 'Stay updated with important alerts',
                    leading: IconButton(
                      icon: const Icon(Icons.arrow_back_ios_rounded),
                      onPressed: () => Navigator.maybePop(context),
                    ),
                  ),
                  Expanded(child: content),
                ],
              ),
            ),
          ],
        ),
      );
    } else {
      return Scaffold(
        backgroundColor: Colors.grey.shade50,
        body: Column(
          children: [
            CustomAppBar(
              title: 'Notifications',
              subtitle: 'Stay updated with important alerts',
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios_rounded),
                onPressed: () => Navigator.maybePop(context),
              ),
            ),
            Expanded(child: content),
          ],
        ),
      );
    }
  }
}
