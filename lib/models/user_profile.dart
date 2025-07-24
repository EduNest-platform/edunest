class UserProfile {
  final String id;
  final String? fullName;
  final String? email;
  final String? studentId;
  final String? phone;
  final String? college;
  final String? branch;
  final String? semester;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? profileImageUrl;

  UserProfile({
    required this.id,
    this.fullName,
    this.email,
    this.studentId,
    this.phone,
    this.college,
    this.branch,
    this.semester,
    this.createdAt,
    this.updatedAt,
    this.profileImageUrl,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'],
      fullName: json['full_name'],
      email: json['email'],
      studentId: json['student_id'],
      phone: json['phone'],
      college: json['college'],
      branch: json['branch'],
      semester: json['semester']?.toString(),
      createdAt:
          json['created_at'] != null
              ? DateTime.parse(json['created_at'])
              : null,
      updatedAt:
          json['updated_at'] != null
              ? DateTime.parse(json['updated_at'])
              : null,
      profileImageUrl: json['profile_image_url'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'full_name': fullName,
      'email': email,
      'student_id': studentId,
      'phone': phone,
      'college': college,
      'branch': branch,
      'semester': semester,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'profile_image_url': profileImageUrl,
    };
  }

  bool isComplete() {
    return (fullName != null && fullName!.trim().isNotEmpty) &&
        (college != null && college!.trim().isNotEmpty) &&
        (branch != null && branch!.trim().isNotEmpty) &&
        (semester != null && semester!.trim().isNotEmpty);
  }
}
