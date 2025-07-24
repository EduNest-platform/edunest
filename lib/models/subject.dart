class Subject {
  final String id;
  final String name;
  final String? code;
  final String? description;
  final String semesterId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final Semester? semester;
  final int resourceCount;

  Subject({
    required this.id,
    required this.name,
    this.code,
    this.description,
    required this.semesterId,
    required this.createdAt,
    required this.updatedAt,
    this.semester,
    this.resourceCount = 0,
  });

  factory Subject.fromJson(Map<String, dynamic> json) {
    return Subject(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      code: json['code'],
      description: json['description'],
      semesterId: json['semester_id'] ?? '',
      createdAt: DateTime.parse(
        json['created_at'] ?? DateTime.now().toIso8601String(),
      ),
      updatedAt: DateTime.parse(
        json['updated_at'] ?? DateTime.now().toIso8601String(),
      ),
      semester:
          json['semesters'] != null
              ? Semester.fromJson(json['semesters'])
              : null,
      resourceCount: json['resource_count'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'code': code,
      'description': description,
      'semester_id': semesterId,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'semesters': semester?.toJson(),
      'resource_count': resourceCount,
    };
  }

  // Helper method to get semester name
  String get semesterName => semester?.name ?? 'Unknown Semester';

  // Helper method to get branch name
  String get branchName => semester?.branch?.name ?? 'Unknown Branch';

  // Helper method to get college name
  String get collegeName =>
      semester?.branch?.college?.name ?? 'Unknown College';

  // Helper method to get full hierarchy path
  String get hierarchyPath => '$collegeName > $branchName > $semesterName';
}

class Semester {
  final String id;
  final String name;
  final Branch? branch;

  Semester({required this.id, required this.name, this.branch});

  factory Semester.fromJson(Map<String, dynamic> json) {
    return Semester(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      branch:
          json['branches'] != null ? Branch.fromJson(json['branches']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {'id': id, 'name': name, 'branches': branch?.toJson()};
  }
}

class Branch {
  final String id;
  final String name;
  final College? college;

  Branch({required this.id, required this.name, this.college});

  factory Branch.fromJson(Map<String, dynamic> json) {
    return Branch(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      college:
          json['colleges'] != null ? College.fromJson(json['colleges']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {'id': id, 'name': name, 'colleges': college?.toJson()};
  }
}

class College {
  final String id;
  final String name;

  College({required this.id, required this.name});

  factory College.fromJson(Map<String, dynamic> json) {
    return College(id: json['id'] ?? '', name: json['name'] ?? '');
  }

  Map<String, dynamic> toJson() {
    return {'id': id, 'name': name};
  }
}
