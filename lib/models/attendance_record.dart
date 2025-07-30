class AttendanceRecord {
  final String id;
  final String studentId;
  final String subjectId;
  final DateTime date;
  final String status; // 'present' or 'absent'
  final String? college;
  final String? branch;
  final int? semester;
  final int? classNumber;
  final DateTime? createdAt;

  AttendanceRecord({
    required this.id,
    required this.studentId,
    required this.subjectId,
    required this.date,
    required this.status,
    this.college,
    this.branch,
    this.semester,
    this.classNumber,
    this.createdAt,
  });

  factory AttendanceRecord.fromJson(Map<String, dynamic> json) {
    return AttendanceRecord(
      id: json['id'] as String,
      studentId: json['student_id'] as String,
      subjectId: json['subject_id'] as String,
      date: DateTime.parse(json['date'] as String),
      status: json['status'] as String,
      college: json['college'] as String?,
      branch: json['branch'] as String?,
      semester: json['semester'] as int?,
      classNumber: json['class_number'] as int?,
      createdAt:
          json['created_at'] != null
              ? DateTime.parse(json['created_at'] as String)
              : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'student_id': studentId,
      'subject_id': subjectId,
      'date': date.toIso8601String(),
      'status': status,
      'college': college,
      'branch': branch,
      'semester': semester,
      'class_number': classNumber,
      'created_at': createdAt?.toIso8601String(),
    };
  }
}
