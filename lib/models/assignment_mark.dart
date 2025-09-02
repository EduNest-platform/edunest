class AssignmentMark {
  final String id;
  final String classId;
  String assignmentName;
  final String studentId;
  final double? marks;
  final double? maxMarks;
  final DateTime? gradedAt;
  final String gradedBy;
  final String? studentName;
  final String? studentEmail;
  final String? subjectName; // Add subject name field

  AssignmentMark({
    required this.id,
    required this.classId,
    required this.assignmentName,
    required this.studentId,
    this.marks,
    this.maxMarks,
    this.gradedAt,
    required this.gradedBy,
    this.studentName,
    this.studentEmail,
    this.subjectName, // Add to constructor
  });

  factory AssignmentMark.fromJson(Map<String, dynamic> json) {
    return AssignmentMark(
      id: json['id']?.toString() ?? '',
      classId: json['class_id'] ?? '',
      assignmentName: json['assignment_name'] ?? '',
      studentId: json['student_id'] ?? '',
      marks: json['marks']?.toDouble(),
      maxMarks: json['max_marks']?.toDouble(),
      gradedAt: json['graded_at'] != null ? DateTime.parse(json['graded_at']) : null,
      gradedBy: json['graded_by'] ?? '',
      studentName: json['student_name'],
      studentEmail: json['student_email'],
      subjectName: json['subject_name'], // Add subject name parsing
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'class_id': classId,
      'assignment_name': assignmentName,
      'student_id': studentId,
      'marks': marks,
      'max_marks': maxMarks,
      'graded_at': gradedAt?.toIso8601String(),
      'graded_by': gradedBy,
      'student_name': studentName,
      'student_email': studentEmail,
      'subject_name': subjectName, // Add subject name to JSON
    };
  }

  // Helper method to get percentage
  double get percentage => (maxMarks != null && marks != null && maxMarks! > 0) ? (marks! / maxMarks!) * 100 : 0;

  // Helper method to get grade
  String get grade {
    final percent = percentage;
    if (percent >= 90) return 'A+';
    if (percent >= 80) return 'A';
    if (percent >= 70) return 'B+';
    if (percent >= 60) return 'B';
    if (percent >= 50) return 'C+';
    if (percent >= 40) return 'C';
    if (percent >= 35) return 'D';
    return 'F';
  }

  // Helper method to get grade color
  String get gradeColor {
    final percent = percentage;
    if (percent >= 80) return '#4CAF50'; // Green
    if (percent >= 60) return '#FF9800'; // Orange
    if (percent >= 40) return '#FFC107'; // Amber
    return '#F44336'; // Red
  }
}

class Assignment {
  final String name;
  final double maxMarks;
  final List<AssignmentMark> marks;

  Assignment({
    required this.name,
    required this.maxMarks,
    required this.marks,
  });

  // Helper method to get student's mark
  AssignmentMark? getMarkForStudent(String studentId) {
    try {
      return marks.firstWhere((mark) => mark.studentId == studentId);
    } catch (e) {
      return null;
    }
  }
}
