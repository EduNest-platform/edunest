import 'package:flutter/material.dart';
import '../services/user_profile_service.dart';
import '../services/network_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProfileSetupController extends ChangeNotifier {
  // College/Branch/Semester selection
  List<Map<String, dynamic>> colleges = [];
  List<Map<String, dynamic>> branches = [];
  List<Map<String, dynamic>> semesters = [];
  String? selectedCollegeId;
  String? selectedBranchId;
  String? selectedSemesterId;
  
  // Roll number controller
  final rollNumberController = TextEditingController();

  bool _isLoading = false;
  String? _errorMessage;
  bool _hasNetworkError = false;
  final NetworkService _networkService = NetworkService();

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get hasNetworkError => _hasNetworkError;

  void setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void setError(String? message) {
    _errorMessage = message;
    notifyListeners();
  }

  void setNetworkError(bool value) {
    _hasNetworkError = value;
    notifyListeners();
  }

  // Fetch colleges from Supabase
  Future<void> fetchColleges() async {
    setLoading(true);
    setNetworkError(false);
    
    // Check both general connectivity and Supabase-specific connectivity
    final generalConnectivity = await _networkService.isConnected();
    final supabaseConnectivity = await _networkService.isSupabaseReachable();
    
    if (!generalConnectivity || !supabaseConnectivity) {
      setNetworkError(true);
      setError('Unable to connect to EduNest servers. Please check your internet connection and try again.');
      setLoading(false);
      return;
    }
    
    try {
      final data = await Supabase.instance.client.from('colleges').select();
      colleges = List<Map<String, dynamic>>.from(data);
      setNetworkError(false);
      setError(null); // Clear any previous errors
      notifyListeners();
    } catch (e) {
      // Check if it's a network-related error
      if (e.toString().contains('Failed host lookup') || 
          e.toString().contains('SocketException') ||
          e.toString().contains('No address associated with hostname')) {
        setNetworkError(true);
        setError('Unable to connect to EduNest servers. Please check your internet connection and try again.');
      } else {
        setError('Failed to load colleges. Please try again.');
      }
    }
    setLoading(false);
  }

  // Fetch branches for selected college
  Future<void> fetchBranches(String collegeId) async {
    setLoading(true);
    setNetworkError(false);
    
    // Check both general connectivity and Supabase-specific connectivity
    final generalConnectivity = await _networkService.isConnected();
    final supabaseConnectivity = await _networkService.isSupabaseReachable();
    
    if (!generalConnectivity || !supabaseConnectivity) {
      setNetworkError(true);
      setError('Unable to connect to EduNest servers. Please check your internet connection and try again.');
      setLoading(false);
      return;
    }
    
    try {
      final data = await Supabase.instance.client
          .from('branches')
          .select()
          .eq('college_id', collegeId);
      branches = List<Map<String, dynamic>>.from(data);
      setNetworkError(false);
      setError(null); // Clear any previous errors
      notifyListeners();
    } catch (e) {
      // Check if it's a network-related error
      if (e.toString().contains('Failed host lookup') || 
          e.toString().contains('SocketException') ||
          e.toString().contains('No address associated with hostname')) {
        setNetworkError(true);
        setError('Unable to connect to EduNest servers. Please check your internet connection and try again.');
      } else {
        setError('Failed to load branches. Please try again.');
      }
    }
    setLoading(false);
  }

  // Fetch semesters for selected branch
  Future<void> fetchSemesters(String branchId) async {
    setLoading(true);
    setNetworkError(false);
    
    // Check both general connectivity and Supabase-specific connectivity
    final generalConnectivity = await _networkService.isConnected();
    final supabaseConnectivity = await _networkService.isSupabaseReachable();
    
    if (!generalConnectivity || !supabaseConnectivity) {
      setNetworkError(true);
      setError('Unable to connect to EduNest servers. Please check your internet connection and try again.');
      setLoading(false);
      return;
    }
    
    try {
      final data = await Supabase.instance.client
          .from('semesters')
          .select()
          .eq('branch_id', branchId);
      semesters = List<Map<String, dynamic>>.from(data);
      setNetworkError(false);
      setError(null); // Clear any previous errors
      notifyListeners();
    } catch (e) {
      // Check if it's a network-related error
      if (e.toString().contains('Failed host lookup') || 
          e.toString().contains('SocketException') ||
          e.toString().contains('No address associated with hostname')) {
        setNetworkError(true);
        setError('Unable to connect to EduNest servers. Please check your internet connection and try again.');
      } else {
        setError('Failed to load semesters. Please try again.');
      }
    }
    setLoading(false);
  }

  // Retry network operations
  Future<void> retryNetworkOperation() async {
    await fetchColleges();
  }

  void setSelectedCollege(String? collegeId) {
    selectedCollegeId = collegeId;
    selectedBranchId = null;
    selectedSemesterId = null;
    branches = [];
    semesters = [];
    if (collegeId != null) {
      fetchBranches(collegeId);
    }
    notifyListeners();
  }

  void setSelectedBranch(String? branchId) {
    selectedBranchId = branchId;
    selectedSemesterId = null;
    semesters = [];
    if (branchId != null) {
      fetchSemesters(branchId);
    }
    notifyListeners();
  }

  void setSelectedSemester(String? semesterId) {
    selectedSemesterId = semesterId;
    notifyListeners();
  }

  // Get selected college name
  String getSelectedCollegeName() {
    if (selectedCollegeId == null) return '';
    final college = colleges.firstWhere(
      (college) => college['id'].toString() == selectedCollegeId,
      orElse: () => {'name': ''},
    );
    return college['name'] ?? '';
  }

  // Get selected branch name
  String getSelectedBranchName() {
    if (selectedBranchId == null) return '';
    final branch = branches.firstWhere(
      (branch) => branch['id'].toString() == selectedBranchId,
      orElse: () => {'name': ''},
    );
    return branch['name'] ?? '';
  }

  // Get selected semester name
  String getSelectedSemesterName() {
    if (selectedSemesterId == null) return '';
    final semester = semesters.firstWhere(
      (semester) => semester['id'].toString() == selectedSemesterId,
      orElse: () => {'name': ''},
    );
    return semester['name'] ?? '';
  }

  Future<bool> saveProfile() async {
    setLoading(true);
    setError(null);

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        setError('User not authenticated');
        setLoading(false);
        return false;
      }

      // Validate roll number uniqueness within same academic context
      final rollNumber = rollNumberController.text.trim();
      if (rollNumber.isNotEmpty) {
        final isDuplicate = await UserProfileService.checkStudentIdExistsInSameContext(
          studentId: rollNumber,
          college: getSelectedCollegeName(),
          branch: getSelectedBranchName(),
          semester: getSelectedSemesterName(),
          excludeUserId: user.id, // Exclude current user
        );
        
        if (isDuplicate) {
          setError('Roll number "$rollNumber" is already taken by another student in the same college, branch, and semester');
          setLoading(false);
          return false;
        }
      }

      // First, get the current profile to preserve existing data
      final currentProfile = await UserProfileService.getCurrentUserProfile();

      // Get name from profile or auth metadata
      String? userName = currentProfile?.fullName;
      if (userName == null || userName.isEmpty) {
        userName = user.userMetadata?['name'] as String?;
      }

      final profileData = {
        'id': user.id,
        'full_name': userName, // Preserve existing name or get from auth
        'email':
            currentProfile?.email ??
            user.email, // Preserve existing email or get from auth
        'student_id': rollNumber, // Save roll number as student_id
        'college': getSelectedCollegeName(),
        'branch': getSelectedBranchName(),
        'semester': getSelectedSemesterName(), // Save semester name as text
        'updated_at': DateTime.now().toIso8601String(),
      };

      final success = await UserProfileService.updateProfile(profileData);
      
      // Auto-link to existing class roster entries if they exist
      if (success && rollNumber.isNotEmpty) {
        await _autoLinkToExistingRosterEntries(
          userId: user.id,
          rollNumber: rollNumber,
          fullName: userName ?? '',
          email: currentProfile?.email ?? user.email ?? '',
        );
      }
      
      setLoading(false);
      return success;
    } catch (e) {
      setError('Failed to save academic path');
      setLoading(false);
      return false;
    }
  }

  void disposeControllers() {
    rollNumberController.dispose();
  }

  /// Auto-link student to existing class roster entries when they complete profile setup
  Future<void> _autoLinkToExistingRosterEntries({
    required String userId,
    required String rollNumber,
    required String fullName,
    required String email,
  }) async {
    try {
      // Find existing class roster entries with this roll number but no profile ID
      final response = await Supabase.instance.client
          .from('class_rosters')
          .select('id, class_id, student_name, student_email')
          .eq('roll_number', rollNumber)
          .isFilter('student_profile_id', null);

      final existingEntries = response as List;
      
      if (existingEntries.isEmpty) {
        print('No existing roster entries found for roll number: $rollNumber');
        return;
      }

      // Update all matching entries to link them to the user's profile
      await Supabase.instance.client
          .from('class_rosters')
          .update({
            'student_profile_id': userId,
            'is_verified': true,
            'student_name': fullName.isNotEmpty ? fullName : null,
            'student_email': email.isNotEmpty ? email : null,
          })
          .eq('roll_number', rollNumber)
          .isFilter('student_profile_id', null);

      print('Auto-linked ${existingEntries.length} roster entries for roll number: $rollNumber');
    } catch (e) {
      print('Error auto-linking to existing roster entries: $e');
      // Don't throw error - this is a background operation
    }
  }

  Future<void> loadExistingAcademicPath() async {
    try {
      final profile = await UserProfileService.getCurrentUserProfile();
      if (profile != null) {
        // Load existing roll number
        if (profile.studentId != null) {
          rollNumberController.text = profile.studentId!;
        }
        
        // Load colleges first
        await fetchColleges();

        // Find and set the college
        if (profile.college != null) {
          final college = colleges.firstWhere(
            (college) => college['name'] == profile.college,
            orElse: () => {},
          );
          if (college.isNotEmpty) {
            setSelectedCollege(college['id'].toString());

            // Find and set the branch
            if (profile.branch != null) {
              final branch = branches.firstWhere(
                (branch) => branch['name'] == profile.branch,
                orElse: () => {},
              );
              if (branch.isNotEmpty) {
                setSelectedBranch(branch['id'].toString());

                // Find and set the semester
                if (profile.semester != null) {
                  final semester = semesters.firstWhere(
                    (semester) =>
                        semester['name'] == profile.semester,
                    orElse: () => {},
                  );
                  if (semester.isNotEmpty) {
                    setSelectedSemester(semester['id'].toString());
                  }
                }
              }
            }
          }
        }
      }
    } catch (e) {
      // ... existing code ...
    }
  }
}
