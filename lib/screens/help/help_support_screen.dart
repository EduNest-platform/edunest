import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../theme/app_theme.dart';
import 'package:flutter/foundation.dart';
import '../../widgets/desktop_sidebar.dart';

class HelpSupportScreen extends StatefulWidget {
  const HelpSupportScreen({super.key});

  @override
  State<HelpSupportScreen> createState() => _HelpSupportScreenState();
}

class _HelpSupportScreenState extends State<HelpSupportScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _launchURL(String url) async {
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDesktop =
        kIsWeb ||
        (Theme.of(context).platform == TargetPlatform.windows ||
            Theme.of(context).platform == TargetPlatform.linux ||
            Theme.of(context).platform == TargetPlatform.macOS);
    if (isDesktop) {
      return Scaffold(
        backgroundColor: Colors.grey.shade50,
        body: Row(
          children: [
            DesktopSidebar(
              selected: 'help-support',
              onNavigate: (route) => Navigator.pushNamed(context, route),
            ),
            Expanded(
              child: CustomScrollView(
                slivers: [
                  // Modern App Bar
                  SliverAppBar(
                    expandedHeight: 200,
                    floating: false,
                    pinned: true,
                    backgroundColor: AppTheme.primaryBlue,
                    elevation: 0,
                    leading: Container(
                      margin: const EdgeInsets.all(8),
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
                    flexibleSpace: FlexibleSpaceBar(
                      background: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              AppTheme.primaryBlue,
                              AppTheme.primaryLight,
                              Colors.purple.shade400,
                            ],
                          ),
                        ),
                        child: Stack(
                          children: [
                            Positioned(
                              top: -30,
                              right: -30,
                              child: Container(
                                width: 120,
                                height: 120,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                            Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    width: 80,
                                    height: 80,
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(
                                        alpha: 0.2,
                                      ),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: Colors.white.withValues(
                                          alpha: 0.3,
                                        ),
                                        width: 2,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(
                                            alpha: 0.1,
                                          ),
                                          blurRadius: 20,
                                          offset: const Offset(0, 10),
                                        ),
                                      ],
                                    ),
                                    child: const Icon(
                                      Icons.help_rounded,
                                      size: 40,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'Help & Support',
                                    style: GoogleFonts.poppins(
                                      fontSize: 28,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                      letterSpacing: -0.5,
                                    ),
                                  ),
                                  Text(
                                    'We\'re here to help you',
                                    style: GoogleFonts.poppins(
                                      fontSize: 16,
                                      color: Colors.white.withValues(
                                        alpha: 0.9,
                                      ),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Content
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Quick Actions (improved for desktop)
                          Text(
                            'Quick Actions',
                            style: GoogleFonts.poppins(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Card(
                            elevation: 6,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            color: Colors.white,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: 32,
                                horizontal: 32,
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: _buildQuickActionCard(
                                      icon: Icons.bug_report_rounded,
                                      title: 'Report Bug',
                                      subtitle: 'Found an issue?',
                                      color: Colors.red,
                                      gradientStart: Colors.red,
                                      gradientEnd: Colors.red.shade600,
                                      onTap:
                                          () => _launchURL(
                                            'mailto:ranojitdas362@gmail.com?subject=Bug Report',
                                          ),
                                      isDesktop: true,
                                    ),
                                  ),
                                  const SizedBox(width: 32),
                                  Expanded(
                                    child: _buildQuickActionCard(
                                      icon: Icons.lightbulb_rounded,
                                      title: 'Feature Request',
                                      subtitle: 'Suggest improvements',
                                      color: Colors.orange,
                                      gradientStart: Colors.orange,
                                      gradientEnd: Colors.orange.shade600,
                                      onTap:
                                          () => _launchURL(
                                            'mailto:ranojitdas362@gmail.com?subject=Feature Request',
                                          ),
                                      isDesktop: true,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 30),

                          // Tab Bar
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.05),
                                  blurRadius: 20,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                TabBar(
                                  controller: _tabController,
                                  labelColor: AppTheme.primaryBlue,
                                  unselectedLabelColor: Colors.grey.shade600,
                                  indicatorColor: AppTheme.primaryBlue,
                                  indicatorWeight: 3,
                                  labelStyle: GoogleFonts.poppins(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                  tabs: const [
                                    Tab(text: 'FAQ'),
                                    Tab(text: 'Contact'),
                                    Tab(text: 'Troubleshoot'),
                                  ],
                                ),
                                SizedBox(
                                  height: 400,
                                  child: TabBarView(
                                    controller: _tabController,
                                    children: [
                                      _buildFAQTab(),
                                      _buildContactTab(),
                                      _buildTroubleshootTab(),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 40),

                          // Footer
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Colors.grey.shade100,
                                  Colors.grey.shade50,
                                ],
                              ),
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: Colors.grey.shade200,
                                width: 1,
                              ),
                            ),
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.support_agent_rounded,
                                      color: AppTheme.primaryBlue,
                                      size: 24,
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      '24/7 Support Available',
                                      style: GoogleFonts.poppins(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.grey.shade700,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'Our support team is always ready to help you with any questions or issues.',
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    color: Colors.grey.shade600,
                                    height: 1.5,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }
    // Mobile/tablet layout
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: CustomScrollView(
        slivers: [
          // Modern App Bar
          SliverAppBar(
            expandedHeight: 200,
            floating: false,
            pinned: true,
            backgroundColor: AppTheme.primaryBlue,
            elevation: 0,
            leading: Container(
              margin: const EdgeInsets.all(8),
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
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppTheme.primaryBlue,
                      AppTheme.primaryLight,
                      Colors.purple.shade400,
                    ],
                  ),
                ),
                child: Stack(
                  children: [
                    Positioned(
                      top: -30,
                      right: -30,
                      child: Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.3),
                                width: 2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.1),
                                  blurRadius: 20,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.help_rounded,
                              size: 40,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Help & Support',
                            style: GoogleFonts.poppins(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: -0.5,
                            ),
                          ),
                          Text(
                            'We\'re here to help you',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              color: Colors.white.withValues(alpha: 0.9),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Content
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Quick Actions
                  Text(
                    'Quick Actions',
                    style: GoogleFonts.poppins(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 1.3,
                    children: [
                      _buildQuickActionCard(
                        icon: Icons.bug_report_rounded,
                        title: 'Report Bug',
                        subtitle: 'Found an issue?',
                        color: Colors.red,
                        gradientStart: Colors.red,
                        gradientEnd: Colors.red.shade600,
                        onTap:
                            () => _launchURL(
                              'mailto:ranojitdas362@gmail.com?subject=Bug Report',
                            ),
                      ),
                      _buildQuickActionCard(
                        icon: Icons.lightbulb_rounded,
                        title: 'Feature Request',
                        subtitle: 'Suggest improvements',
                        color: Colors.orange,
                        gradientStart: Colors.orange,
                        gradientEnd: Colors.orange.shade600,
                        onTap:
                            () => _launchURL(
                              'mailto:ranojitdas362@gmail.com?subject=Feature Request',
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 30),

                  // Tab Bar
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        TabBar(
                          controller: _tabController,
                          labelColor: AppTheme.primaryBlue,
                          unselectedLabelColor: Colors.grey.shade600,
                          indicatorColor: AppTheme.primaryBlue,
                          indicatorWeight: 3,
                          labelStyle: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                          tabs: const [
                            Tab(text: 'FAQ'),
                            Tab(text: 'Contact'),
                            Tab(text: 'Troubleshoot'),
                          ],
                        ),
                        SizedBox(
                          height: 400,
                          child: TabBarView(
                            controller: _tabController,
                            children: [
                              _buildFAQTab(),
                              _buildContactTab(),
                              _buildTroubleshootTab(),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),

                  // Footer
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Colors.grey.shade100, Colors.grey.shade50],
                      ),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.grey.shade200, width: 1),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.support_agent_rounded,
                              color: AppTheme.primaryBlue,
                              size: 24,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              '24/7 Support Available',
                              style: GoogleFonts.poppins(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Our support team is always ready to help you with any questions or issues.',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                            height: 1.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required Color gradientStart,
    required Color gradientEnd,
    required VoidCallback onTap,
    bool isDesktop = false,
  }) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: StatefulBuilder(
        builder: (context, setState) {
          bool isHovered = false;
          return GestureDetector(
            onTap: onTap,
            onTapDown: (_) => setState(() => isHovered = true),
            onTapUp: (_) => setState(() => isHovered = false),
            onTapCancel: () => setState(() => isHovered = false),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors:
                      isDesktop
                          ? [Colors.white, Colors.grey.shade50]
                          : [Colors.white, Colors.grey.shade50],
                ),
                borderRadius: BorderRadius.circular(isDesktop ? 24 : 16),
                border: Border.all(
                  color:
                      isHovered ? color.withOpacity(0.3) : Colors.grey.shade200,
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: color.withOpacity(isHovered ? 0.15 : 0.08),
                    blurRadius: isHovered ? 24 : 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              padding: EdgeInsets.all(isDesktop ? 32 : 16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    padding: EdgeInsets.all(isDesktop ? 16 : 8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [gradientStart, gradientEnd],
                      ),
                      borderRadius: BorderRadius.circular(isDesktop ? 18 : 12),
                      boxShadow: [
                        BoxShadow(
                          color: gradientStart.withOpacity(0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(
                      icon,
                      color: Colors.white,
                      size: isDesktop ? 38 : 22,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    title,
                    style: GoogleFonts.poppins(
                      fontSize: isDesktop ? 18 : 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (isDesktop) ...[
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        color: Colors.grey.shade600,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFAQTab() {
    final faqItems = [
      FAQItem(
        question: 'How do I upload study materials?',
        answer:
            'Go to Upload Files section, select your file, choose subject and category, add description, and tap Upload.',
      ),
      FAQItem(
        question: 'How can I track my attendance?',
        answer:
            'Navigate to Attendance section, select your subject and mark attendance for each class.',
      ),
      FAQItem(
        question: 'How do I search for resources?',
        answer:
            'Use Search Resources feature from main menu. Search by subject name, file type, or keywords.',
      ),
      FAQItem(
        question: 'Can I share resources?',
        answer:
            'Yes! Uploaded files become available to all students in your college and branch.',
      ),
      FAQItem(
        question: 'How do I update my profile?',
        answer:
            'Go to My Profile, tap edit icon to modify personal information and academic details.',
      ),
    ];

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: faqItems.length,
      itemBuilder: (context, index) {
        final item = faqItems[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200, width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ExpansionTile(
            tilePadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 8,
            ),
            childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.help_rounded,
                color: AppTheme.primaryBlue,
                size: 20,
              ),
            ),
            title: Text(
              item.question,
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            children: [
              Text(
                item.answer,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.grey.shade700,
                  height: 1.5,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildContactTab() {
    final contactOptions = [
      ContactOption(
        icon: Icons.email_rounded,
        title: 'Email Support',
        subtitle: 'Get detailed assistance via email',
        description:
            'Send us a detailed email and we\'ll respond within 24 hours',
        action: 'Send Email',
        color: Colors.blue,
        gradientStart: Colors.blue,
        gradientEnd: Colors.blue.shade600,
        url: 'mailto:ranojitdas362@gmail.com',
      ),
      ContactOption(
        icon: Icons.chat_rounded,
        title: 'Live Chat',
        subtitle: 'Chat with our support team',
        description: 'Get instant help from our support representatives',
        action: 'Start Chat',
        color: Colors.green,
        gradientStart: Colors.green,
        gradientEnd: Colors.green.shade600,
        url: 'https://t.me/your_support_channel',
      ),
      ContactOption(
        icon: Icons.phone_rounded,
        title: 'Phone Support',
        subtitle: 'Call us directly',
        description: 'Speak with our support team during business hours',
        action: 'Call Now',
        color: Colors.orange,
        gradientStart: Colors.orange,
        gradientEnd: Colors.orange.shade600,
        url: 'tel:+1234567890',
      ),
    ];

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: contactOptions.length,
      itemBuilder: (context, index) {
        final option = contactOptions[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.white, Colors.grey.shade50],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.grey.shade200, width: 1),
            boxShadow: [
              BoxShadow(
                color: option.color.withValues(alpha: 0.08),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _launchURL(option.url),
              borderRadius: BorderRadius.circular(20),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                option.gradientStart,
                                option.gradientEnd,
                              ],
                            ),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: option.gradientStart.withValues(
                                  alpha: 0.3,
                                ),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Icon(
                            option.icon,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                option.title,
                                style: GoogleFonts.poppins(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                ),
                              ),
                              Text(
                                option.subtitle,
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  color: option.color,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      option.description,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: option.color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: option.color.withValues(alpha: 0.3),
                          width: 1,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          option.action,
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: option.color,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTroubleshootTab() {
    final troubleshootItems = [
      TroubleshootItem(
        icon: Icons.wifi_off_rounded,
        title: 'Connection Issues',
        description:
            'Check your internet connection and try refreshing the app.',
        color: Colors.red,
      ),
      TroubleshootItem(
        icon: Icons.file_download_rounded,
        title: 'Download Problems',
        description:
            'Ensure you have sufficient storage space and try downloading again.',
        color: Colors.orange,
      ),
      TroubleshootItem(
        icon: Icons.login_rounded,
        title: 'Login Issues',
        description:
            'Verify your credentials and check if your account is active.',
        color: Colors.blue,
      ),
      TroubleshootItem(
        icon: Icons.upload_rounded,
        title: 'Upload Failures',
        description:
            'Check file size limits and ensure the file format is supported.',
        color: Colors.purple,
      ),
    ];

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: troubleshootItems.length,
      itemBuilder: (context, index) {
        final item = troubleshootItems[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200, width: 1),
            boxShadow: [
              BoxShadow(
                color: item.color.withValues(alpha: 0.08),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: item.color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(item.icon, color: item.color, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.description,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class FAQItem {
  final String question;
  final String answer;

  FAQItem({required this.question, required this.answer});
}

class ContactOption {
  final IconData icon;
  final String title;
  final String subtitle;
  final String description;
  final String action;
  final Color color;
  final Color gradientStart;
  final Color gradientEnd;
  final String url;

  ContactOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.description,
    required this.action,
    required this.color,
    required this.gradientStart,
    required this.gradientEnd,
    required this.url,
  });
}

class TroubleshootItem {
  final IconData icon;
  final String title;
  final String description;
  final Color color;

  TroubleshootItem({
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
  });
}
