import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../theme/app_theme.dart';
import 'package:flutter/foundation.dart';
import '../../widgets/desktop_sidebar.dart';
import '../../services/supabase_service.dart';

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

  void _showFeedbackDialog() {
    showDialog(context: context, builder: (context) => FeedbackDialog());
  }

  void _showFeedbackDialogWithType(String type) {
    showDialog(
      context: context,
      builder: (context) => FeedbackDialog(initialType: type),
    );
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
                                          () => _showFeedbackDialogWithType(
                                            'Bug',
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
                                          () => _showFeedbackDialogWithType(
                                            'Feature',
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
                        onTap: () => _showFeedbackDialogWithType('Bug'),
                      ),
                      _buildQuickActionCard(
                        icon: Icons.lightbulb_rounded,
                        title: 'Feature Request',
                        subtitle: 'Suggest improvements',
                        color: Colors.orange,
                        gradientStart: Colors.orange,
                        gradientEnd: Colors.orange.shade600,
                        onTap: () => _showFeedbackDialogWithType('Feature'),
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
                      isHovered
                          ? color.withValues(alpha: 0.3)
                          : Colors.grey.shade200,
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: isHovered ? 0.15 : 0.08),
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
                          color: gradientStart.withValues(alpha: 0.3),
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

class FeedbackDialog extends StatefulWidget {
  final String initialType;
  const FeedbackDialog({super.key, this.initialType = 'Bug'});
  @override
  State<FeedbackDialog> createState() => _FeedbackDialogState();
}

class _FeedbackDialogState extends State<FeedbackDialog> {
  final _formKey = GlobalKey<FormState>();
  String _type = '';
  String _title = '';
  String _description = '';
  String _email = '';
  bool _loading = false;
  String? _error;
  String? _success;

  @override
  void initState() {
    super.initState();
    _type = widget.initialType;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
      _success = null;
    });
    try {
      final response = await SupabaseService.client.from('feedback').insert({
        'type': _type,
        'title': _title,
        'description': _description,
        'user_email': _email.isNotEmpty ? _email : null,
        'created_at': DateTime.now().toIso8601String(),
      });
      setState(() {
        _success = 'Thank you for your feedback!';
      });
      await Future.delayed(Duration(seconds: 1));
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() {
        _error = 'Failed to submit feedback. Please try again.';
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isDesktop =
        kIsWeb ||
        (Theme.of(context).platform == TargetPlatform.windows ||
            Theme.of(context).platform == TargetPlatform.linux ||
            Theme.of(context).platform == TargetPlatform.macOS);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      elevation: 16,
      backgroundColor: isDark ? Colors.grey[900] : Colors.white,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: isDesktop ? 500 : double.infinity,
          maxHeight: isDesktop ? 700 : MediaQuery.of(context).size.height * 0.8,
        ),
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: isDesktop ? 32 : 28,
              vertical: isDesktop ? 28 : 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header with icon and title
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [AppTheme.primaryBlue, AppTheme.primaryLight],
                    ),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(18),
                      topRight: Radius.circular(18),
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(
                    vertical: 28,
                    horizontal: 0,
                  ),
                  child: Column(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.06),
                              blurRadius: 8,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.all(12),
                        child: Icon(
                          _type == 'Bug'
                              ? Icons.bug_report_rounded
                              : Icons.lightbulb_rounded,
                          color: AppTheme.primaryBlue,
                          size: 32,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        _type == 'Bug' ? 'Report a Bug' : 'Feature Request',
                        style: GoogleFonts.poppins(
                          fontSize: 22,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _type == 'Bug'
                            ? 'Help us improve by reporting issues.'
                            : 'Suggest a new feature or improvement.',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: Colors.white.withValues(alpha: 0.92),
                          fontWeight: FontWeight.w400,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                // Form card
                Container(
                  margin: const EdgeInsets.only(top: 18),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey[900] : Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 12,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        DropdownButtonFormField<String>(
                          value: _type,
                          items: [
                            DropdownMenuItem(
                              value: 'Bug',
                              child: Text('Bug Report'),
                            ),
                            DropdownMenuItem(
                              value: 'Feature',
                              child: Text('Feature Request'),
                            ),
                          ],
                          onChanged: (v) => setState(() => _type = v ?? 'Bug'),
                          decoration: InputDecoration(
                            labelText: 'Type',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            filled: true,
                            fillColor:
                                isDark ? Colors.grey[850] : Colors.grey[100],
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: isDesktop ? 12 : 16,
                            ),
                          ),
                        ),
                        SizedBox(height: isDesktop ? 12 : 16),
                        TextFormField(
                          decoration: InputDecoration(
                            labelText: 'Title',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            filled: true,
                            fillColor:
                                isDark ? Colors.grey[850] : Colors.grey[100],
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: isDesktop ? 12 : 16,
                            ),
                          ),
                          onChanged: (v) => _title = v,
                          validator:
                              (v) =>
                                  v == null || v.trim().isEmpty
                                      ? 'Title required'
                                      : null,
                          style: GoogleFonts.poppins(),
                        ),
                        SizedBox(height: isDesktop ? 12 : 16),
                        TextFormField(
                          decoration: InputDecoration(
                            labelText: 'Description',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            filled: true,
                            fillColor:
                                isDark ? Colors.grey[850] : Colors.grey[100],
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: isDesktop ? 12 : 16,
                            ),
                          ),
                          onChanged: (v) => _description = v,
                          minLines: isDesktop ? 2 : 3,
                          maxLines: isDesktop ? 4 : 5,
                          validator:
                              (v) =>
                                  v == null || v.trim().isEmpty
                                      ? 'Description required'
                                      : null,
                          style: GoogleFonts.poppins(),
                        ),
                        SizedBox(height: isDesktop ? 12 : 16),
                        TextFormField(
                          decoration: InputDecoration(
                            labelText: 'Your Email (optional)',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            filled: true,
                            fillColor:
                                isDark ? Colors.grey[850] : Colors.grey[100],
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: isDesktop ? 12 : 16,
                            ),
                          ),
                          onChanged: (v) => _email = v,
                          keyboardType: TextInputType.emailAddress,
                          style: GoogleFonts.poppins(),
                        ),
                      ],
                    ),
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline, color: Colors.red[700]),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _error!,
                            style: GoogleFonts.poppins(
                              color: Colors.red[700],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (_success != null) ...[
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.check_circle_outline,
                          color: Colors.green[700],
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _success!,
                            style: GoogleFonts.poppins(
                              color: Colors.green[700],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed:
                          _loading ? null : () => Navigator.of(context).pop(),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.grey[600],
                        textStyle: GoogleFonts.poppins(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: _loading ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryBlue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 28,
                          vertical: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        textStyle: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      child:
                          _loading
                              ? SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                              : const Text('Submit'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
