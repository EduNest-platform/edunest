import 'package:flutter/material.dart';
import '../services/user_profile_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProfileSetupController extends ChangeNotifier {
  // College/Branch/Semester selection
  List<Map<String, dynamic>> colleges = [];
  List<Map<String, dynamic>> branches = [];
  List<Map<String, dynamic>> semesters = [];
  String? selectedCollegeId;
  String? selectedBranchId;
  String? selectedSemesterId;

  bool _isLoading = false;
  String? _errorMessage;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  void setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void setError(String? message) {
    _errorMessage = message;
    notifyListeners();
  }

  // Fetch colleges from Supabase
  Future<void> fetchColleges() async {
    setLoading(true);
    try {
      final data = await Supabase.instance.client.from('colleges').select();
      colleges = List<Map<String, dynamic>>.from(data);
      notifyListeners();
    } catch (e) {
      setError('Failed to load colleges');
    }
    setLoading(false);
  }

  // Fetch branches for selected college
  Future<void> fetchBranches(String collegeId) async {
    setLoading(true);
    try {
      final data = await Supabase.instance.client
          .from('branches')
          .select()
          .eq('college_id', collegeId);
      branches = List<Map<String, dynamic>>.from(data);
      notifyListeners();
    } catch (e) {
      setError('Failed to load branches');
    }
    setLoading(false);
  }

  // Fetch semesters for selected branch
  Future<void> fetchSemesters(String branchId) async {
    setLoading(true);
    try {
      final data = await Supabase.instance.client
          .from('semesters')
          .select()
          .eq('branch_id', branchId);
      semesters = List<Map<String, dynamic>>.from(data);
      notifyListeners();
    } catch (e) {
      setError('Failed to load semesters');
    }
    setLoading(false);
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
        'college': getSelectedCollegeName(),
        'branch': getSelectedBranchName(),
        'semester': getSelectedSemesterName(), // Save semester name as text
        'updated_at': DateTime.now().toIso8601String(),
      };

      final success = await UserProfileService.updateProfile(profileData);
      setLoading(false);
      return success;
    } catch (e) {
      setError('Failed to save academic path');
      setLoading(false);
      return false;
    }
  }

  void disposeControllers() {
    // No controllers to dispose since we removed personal info fields
  }

  Future<void> loadExistingAcademicPath() async {
    try {
      final profile = await UserProfileService.getCurrentUserProfile();
      if (profile != null) {
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
                        semester['id'].toString() ==
                        profile.semester.toString(),
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
