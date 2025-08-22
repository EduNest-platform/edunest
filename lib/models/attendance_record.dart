class AttendanceRecord {
  final String id;
  final String classId;
  final String studentRollNumber;
  final String studentName;
  final DateTime date;
  final String status; // 'present' or 'absent'
  final String professorEmail;
  final String subjectName;
  final String? collegeName;
  final String? branchName;
  final String? semesterName;
  final int? classNumber;
  final DateTime? createdAt;

  AttendanceRecord({
    required this.id,
    required this.classId,
    required this.studentRollNumber,
    required this.studentName,
    required this.date,
    required this.status,
    required this.professorEmail,
    required this.subjectName,
    this.collegeName,
    this.branchName,
    this.semesterName,
    this.classNumber,
    this.createdAt,
  });

  factory AttendanceRecord.fromJson(Map<String, dynamic> json) {
    return AttendanceRecord(
      id: json['id'] as String,
      classId: json['class_id'] as String,
      studentRollNumber: json['student_roll_number'] as String,
      studentName: json['student_name'] as String,
      date: DateTime.parse(json['date'] as String),
      status: json['status'] as String,
      professorEmail: json['professor_email'] as String? ?? 'professor@system.com', // Handle missing professor_email from professor_attendance table
      subjectName: json['subject_name'] as String,
      collegeName: json['college_name'] as String?,
      branchName: json['branch_name'] as String?,
      semesterName: json['semester_name'] as String?,
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
      'class_id': classId,
      'student_roll_number': studentRollNumber,
      'student_name': studentName,
      'date': date.toIso8601String(),
      'status': status,
      'professor_email': professorEmail,
      'subject_name': subjectName,
      'college_name': collegeName,
      'branch_name': branchName,
      'semester_name': semesterName,
      'class_number': classNumber,
      'created_at': createdAt?.toIso8601String(),
    };
  }
}
