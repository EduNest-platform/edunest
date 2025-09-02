import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/custom_app_bar.dart';
import '../../../models/subject.dart';
import '../../../models/user_profile.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FeedbackFormScreen extends StatefulWidget {
  final Subject subject;
  final UserProfile userProfile;

  const FeedbackFormScreen({
    super.key,
    required this.subject,
    required this.userProfile,
  });

  @override
  State<FeedbackFormScreen> createState() => _FeedbackFormScreenState();
}

class _FeedbackFormScreenState extends State<FeedbackFormScreen> {
  bool _isLoading = false;
  bool _isSubmitting = false;
  bool _hasAlreadySubmitted = false;
  List<Map<String, dynamic>> _activeCampaigns = [];
  Map<String, dynamic>? _selectedCampaign;
  Map<String, int> _ratings = {};

  @override
  void initState() {
    super.initState();
    _loadActiveCampaigns();
  }

  Future<void> _loadActiveCampaigns() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      // Load active feedback campaigns for this semester - OPTIMIZED
      final response = await Supabase.instance.client
          .from('feedback_data')
          .select('id, campaign_info, semester, created_at')  // Only select needed columns
          .eq('type', 'campaign')
          .eq('semester', widget.userProfile.semester ?? '')
          .order('created_at', ascending: false)
          .limit(20);  // Limit results

      final data = response as List<dynamic>;
      final campaigns = data.where((campaign) {
        final info = campaign['campaign_info'] as Map<String, dynamic>?;
        if (info == null) return false;

        // Check if campaign is active
        if (info['status'] != 'active') return false;

        // Check if campaign is within date range - EFFICIENT DATE FILTERING
        final now = DateTime.now();
        final dates = info['dates'] as Map<String, dynamic>?;
        if (dates != null) {
          final startDate = DateTime.tryParse(dates['start'] ?? '');
          final endDate = DateTime.tryParse(dates['end'] ?? '');
          
          // Hide campaigns that haven't started yet
          if (startDate != null && now.isBefore(startDate)) return false;
          
          // Hide campaigns that have ended
          if (endDate != null && now.isAfter(endDate)) return false;
        }

        // Check if campaign matches user's hierarchy
        final hierarchy = info['hierarchy'] as Map<String, dynamic>?;
        if (hierarchy == null) return false;

        return hierarchy['collegeName'] == widget.userProfile.college &&
               hierarchy['branchName'] == widget.userProfile.branch &&
               hierarchy['semesterName'] == widget.userProfile.semester;
      }).toList();

      setState(() {
        _activeCampaigns = campaigns.cast<Map<String, dynamic>>();
        if (_activeCampaigns.isNotEmpty) {
          _selectedCampaign = _activeCampaigns.first;
          _initializeRatings();
        }
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading campaigns: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _initializeRatings() {
    if (_selectedCampaign == null) return;
    
    final campaignInfo = _selectedCampaign!['campaign_info'] as Map<String, dynamic>;
    final questions = campaignInfo['questions'] as List<dynamic>? ?? [];
    
    _ratings.clear();
    
    for (final question in questions) {
      final questionId = question['id'] as String;
      _ratings[questionId] = 3; // Default rating
    }
    
    // Check if user has already submitted for this campaign
    _checkExistingSubmission();
  }

  Future<void> _checkExistingSubmission() async {
    if (_selectedCampaign == null) return;

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      // More efficient query - filter by user ID and campaign
      final response = await Supabase.instance.client
          .from('feedback_data')
          .select('id, response_info')
          .eq('type', 'response')
          .eq('semester', widget.userProfile.semester ?? '')
          .limit(100); // Reasonable limit for checking

      final data = response as List<dynamic>;
      
      // Check if any response matches this user, campaign, and subject
      for (final item in data) {
        final responseInfo = item['response_info'] as Map<String, dynamic>?;
        if (responseInfo == null) continue;

        final userId = responseInfo['user_id'];
        final campaignId = responseInfo['campaign_id'];
        final subjectInfo = responseInfo['subject_info'] as Map<String, dynamic>?;
        
        // Check if this response is from the same user, campaign, and subject
        if (userId == user.id && 
            campaignId == _selectedCampaign!['id'] && 
            subjectInfo != null && 
            subjectInfo['subject_id'] == widget.subject.id) {
          setState(() {
            _hasAlreadySubmitted = true;
          });
          return;
        }
      }

      setState(() {
        _hasAlreadySubmitted = false;
      });
    } catch (e) {
      // If error checking, allow submission to proceed
      setState(() {
        _hasAlreadySubmitted = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 900;
    
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: Column(
        children: [
          CustomAppBar(
            title: 'Feedback for ${widget.subject.name}',
            subtitle: widget.subject.code != null ? 'Code: ${widget.subject.code}' : '',
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(),
                  )
                : _activeCampaigns.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.feedback_outlined,
                              size: isDesktop ? 80 : 64,
                              color: Colors.grey.shade400,
                            ),
                            SizedBox(height: isDesktop ? 24 : 16),
                            Text(
                              'No Active Feedback Campaigns',
                              style: GoogleFonts.poppins(
                                fontSize: isDesktop ? 22 : 18,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade700,
                              ),
                            ),
                            SizedBox(height: isDesktop ? 12 : 8),
                            Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: isDesktop ? 40 : 24,
                              ),
                              child: Text(
                                'There are no active feedback campaigns for your class at the moment.',
                                style: GoogleFonts.poppins(
                                  fontSize: isDesktop ? 16 : 14,
                                  color: Colors.grey.shade600,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                        ),
                      )
                    : Center(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: isDesktop ? 800 : double.infinity,
                          ),
                          child: SingleChildScrollView(
                            padding: EdgeInsets.all(isDesktop ? 32 : 16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildCampaignSelector(),
                                SizedBox(height: isDesktop ? 32 : 24),
                                if (_hasAlreadySubmitted) 
                                  _buildAlreadySubmittedMessage()
                                else ...[
                                  _buildFeedbackForm(),
                                  SizedBox(height: isDesktop ? 40 : 32),
                                  _buildSubmitButton(),
                                ],
                                SizedBox(height: isDesktop ? 24 : 16),
                              ],
                            ),
                          ),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlreadySubmittedMessage() {
    final isDesktop = MediaQuery.of(context).size.width > 900;
    
    return Container(
      padding: EdgeInsets.all(isDesktop ? 32 : 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.green.shade50,
            Colors.green.shade100.withValues(alpha: 0.5),
          ],
        ),
        borderRadius: BorderRadius.circular(isDesktop ? 24 : 16),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withValues(alpha: 0.1),
            blurRadius: isDesktop ? 24 : 16,
            offset: const Offset(0, 8),
            spreadRadius: 0,
          ),
        ],
        border: Border.all(
          color: Colors.green.shade200,
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(isDesktop ? 20 : 16),
            decoration: BoxDecoration(
              color: Colors.green.shade100,
              borderRadius: BorderRadius.circular(isDesktop ? 20 : 16),
            ),
            child: Icon(
              Icons.check_circle_rounded,
              color: Colors.green.shade700,
              size: isDesktop ? 48 : 40,
            ),
          ),
          SizedBox(height: isDesktop ? 24 : 20),
          Text(
            'Feedback Already Submitted',
            style: GoogleFonts.poppins(
              fontSize: isDesktop ? 24 : 20,
              fontWeight: FontWeight.w700,
              color: Colors.green.shade800,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: isDesktop ? 16 : 12),
          Text(
            'You have already submitted feedback for this subject in the current campaign. Thank you for your participation!',
            style: GoogleFonts.poppins(
              fontSize: isDesktop ? 16 : 14,
              color: Colors.green.shade700,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: isDesktop ? 24 : 20),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade600,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(
                vertical: isDesktop ? 16 : 12,
                horizontal: isDesktop ? 32 : 24,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(isDesktop ? 12 : 10),
              ),
              elevation: 0,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.arrow_back_rounded,
                  size: isDesktop ? 20 : 18,
                ),
                SizedBox(width: isDesktop ? 8 : 6),
                Text(
                  'Back to Subjects',
                  style: GoogleFonts.poppins(
                    fontSize: isDesktop ? 16 : 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCampaignSelector() {
    if (_activeCampaigns.length <= 1) return const SizedBox.shrink();
    final isDesktop = MediaQuery.of(context).size.width > 900;

    return Container(
      padding: EdgeInsets.all(isDesktop ? 28 : 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white,
            Colors.grey.shade50,
          ],
        ),
        borderRadius: BorderRadius.circular(isDesktop ? 20 : 16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: isDesktop ? 20 : 16,
            offset: const Offset(0, 6),
            spreadRadius: 0,
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
            spreadRadius: 0,
          ),
        ],
        border: Border.all(
          color: Colors.grey.shade200,
          width: 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Select Feedback Campaign',
            style: GoogleFonts.poppins(
              fontSize: isDesktop ? 18 : 16,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade800,
            ),
          ),
          SizedBox(height: isDesktop ? 16 : 12),
          DropdownButtonFormField<Map<String, dynamic>>(
            value: _selectedCampaign,
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(isDesktop ? 16 : 12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(isDesktop ? 16 : 12),
                borderSide: BorderSide(color: AppTheme.primaryBlue, width: 2),
              ),
              contentPadding: EdgeInsets.symmetric(
                horizontal: isDesktop ? 20 : 16, 
                vertical: isDesktop ? 16 : 12,
              ),
            ),
            items: _activeCampaigns.map((campaign) {
              final info = campaign['campaign_info'] as Map<String, dynamic>;
              return DropdownMenuItem(
                value: campaign,
                child: Text(
                  info['title'] ?? 'Untitled Campaign',
                  style: GoogleFonts.poppins(
                    fontSize: isDesktop ? 16 : 14,
                    color: Colors.grey.shade800,
                  ),
                ),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                _selectedCampaign = value;
                _initializeRatings();
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFeedbackForm() {
    if (_selectedCampaign == null) return const SizedBox.shrink();
    final isDesktop = MediaQuery.of(context).size.width > 900;

    final campaignInfo = _selectedCampaign!['campaign_info'] as Map<String, dynamic>;
    final questions = campaignInfo['questions'] as List<dynamic>? ?? [];

    return Container(
      padding: EdgeInsets.all(isDesktop ? 32 : 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white,
            Colors.grey.shade50,
          ],
        ),
        borderRadius: BorderRadius.circular(isDesktop ? 24 : 16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: isDesktop ? 24 : 16,
            offset: const Offset(0, 8),
            spreadRadius: 0,
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
            spreadRadius: 0,
          ),
        ],
        border: Border.all(
          color: Colors.grey.shade200,
          width: 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(isDesktop ? 16 : 12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppTheme.primaryBlue.withValues(alpha: 0.15),
                      AppTheme.primaryBlue.withValues(alpha: 0.08),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(isDesktop ? 16 : 12),
                  border: Border.all(
                    color: AppTheme.primaryBlue.withValues(alpha: 0.2),
                    width: 1,
                  ),
                ),
                child: Icon(
                  Icons.rate_review_rounded,
                  color: AppTheme.primaryBlue,
                  size: isDesktop ? 28 : 24,
                ),
              ),
              SizedBox(width: isDesktop ? 20 : 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      campaignInfo['title'] ?? 'Feedback Form',
                      style: GoogleFonts.poppins(
                        fontSize: isDesktop ? 22 : 18,
                        fontWeight: FontWeight.w700,
                        color: Colors.grey.shade800,
                        height: 1.2,
                      ),
                    ),
                    if (campaignInfo['description'] != null) ...[
                      SizedBox(height: isDesktop ? 8 : 6),
                      Text(
                        campaignInfo['description'],
                        style: GoogleFonts.poppins(
                          fontSize: isDesktop ? 16 : 14,
                          color: Colors.grey.shade600,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: isDesktop ? 32 : 24),
          ...questions.map<Widget>((question) => _buildQuestionCard(question)).toList(),
        ],
      ),
    );
  }

  Widget _buildQuestionCard(dynamic question) {
    final questionId = question['id'] as String;
    final questionText = question['text'] as String;
    final scale = question['scale'] as int? ?? 5;
    final isDesktop = MediaQuery.of(context).size.width > 900;

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: EdgeInsets.all(isDesktop ? 24 : 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white,
            Colors.grey.shade50,
          ],
        ),
        borderRadius: BorderRadius.circular(isDesktop ? 16 : 12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: isDesktop ? 20 : 16,
            offset: const Offset(0, 4),
            spreadRadius: 0,
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
            spreadRadius: 0,
          ),
        ],
        border: Border.all(
          color: Colors.grey.shade200,
          width: 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            questionText,
            style: GoogleFonts.poppins(
              fontSize: isDesktop ? 18 : 16,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade800,
              height: 1.4,
            ),
          ),
          SizedBox(height: isDesktop ? 24 : 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Poor',
                style: GoogleFonts.poppins(
                  fontSize: isDesktop ? 14 : 12,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey.shade600,
                ),
              ),
              Text(
                'Excellent',
                style: GoogleFonts.poppins(
                  fontSize: isDesktop ? 14 : 12,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
          SizedBox(height: isDesktop ? 16 : 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(scale, (index) {
              final rating = index + 1;
              final isSelected = _ratings[questionId] == rating;
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _ratings[questionId] = rating;
                  });
                },
                child: Container(
                  width: isDesktop ? 50 : 40,
                  height: isDesktop ? 50 : 40,
                  decoration: BoxDecoration(
                    gradient: isSelected
                        ? LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              AppTheme.primaryBlue,
                              AppTheme.primaryBlue.withValues(alpha: 0.8),
                            ],
                          )
                        : LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Colors.white,
                              Colors.grey.shade50,
                            ],
                          ),
                    borderRadius: BorderRadius.circular(isDesktop ? 25 : 20),
                    boxShadow: [
                      BoxShadow(
                        color: isSelected
                            ? AppTheme.primaryBlue.withValues(alpha: 0.3)
                            : Colors.black.withValues(alpha: 0.1),
                        blurRadius: isSelected ? 12 : 8,
                        offset: const Offset(0, 4),
                        spreadRadius: 0,
                      ),
                    ],
                    border: Border.all(
                      color: isSelected 
                          ? AppTheme.primaryBlue 
                          : Colors.grey.shade300,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      rating.toString(),
                      style: GoogleFonts.poppins(
                        fontSize: isDesktop ? 18 : 16,
                        fontWeight: FontWeight.w700,
                        color: isSelected ? Colors.white : Colors.grey.shade700,
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton() {
    final isDesktop = MediaQuery.of(context).size.width > 900;
    
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isSubmitting ? null : _submitFeedback,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.primaryBlue,
          foregroundColor: Colors.white,
          padding: EdgeInsets.symmetric(
            vertical: isDesktop ? 20 : 16,
            horizontal: isDesktop ? 32 : 24,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(isDesktop ? 16 : 12),
          ),
          elevation: 0,
          shadowColor: Colors.transparent,
        ).copyWith(
          backgroundColor: WidgetStateProperty.resolveWith<Color>(
            (Set<WidgetState> states) {
              if (states.contains(WidgetState.pressed)) {
                return AppTheme.primaryBlue.withValues(alpha: 0.8);
              }
              if (states.contains(WidgetState.disabled)) {
                return Colors.grey.shade300;
              }
              return AppTheme.primaryBlue;
            },
          ),
        ),
        child: _isSubmitting
            ? SizedBox(
                width: isDesktop ? 24 : 20,
                height: isDesktop ? 24 : 20,
                child: const CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.send_rounded,
                    size: isDesktop ? 24 : 20,
                  ),
                  SizedBox(width: isDesktop ? 12 : 8),
                  Text(
                    'Submit Feedback',
                    style: GoogleFonts.poppins(
                      fontSize: isDesktop ? 18 : 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Future<void> _submitFeedback() async {
    if (_selectedCampaign == null) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      final campaignInfo = _selectedCampaign!['campaign_info'] as Map<String, dynamic>;
      final questions = campaignInfo['questions'] as List<dynamic>? ?? [];

      // Prepare responses
      final responses = questions.map((question) {
        final questionId = question['id'] as String;
        return {
          'question_id': questionId,
          'question_text': question['text'],
          'rating': _ratings[questionId] ?? 3,
        };
      }).toList();

      // Create response data
      final responseData = {
        'response_info': {
          'campaign_id': _selectedCampaign!['id'],
          'user_id': user.id, // Add user ID for unique identification
          'subject_info': {
            'subject_id': widget.subject.id,
            'subject_name': widget.subject.name,
            'subject_code': widget.subject.code,
          },
          'student_info': {
            'semester': widget.userProfile.semester,
            'branch': widget.userProfile.branch,
            'college': widget.userProfile.college,
          },
          'responses': responses,
          'submitted_at': DateTime.now().toIso8601String(),
          'is_anonymous': true,
        },
        'type': 'response',
        'semester': widget.userProfile.semester,
      };

      // Save to database
      await Supabase.instance.client
          .from('feedback_data')
          .insert(responseData);

      setState(() {
        _isSubmitting = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Feedback submitted successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      setState(() {
        _isSubmitting = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error submitting feedback: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
