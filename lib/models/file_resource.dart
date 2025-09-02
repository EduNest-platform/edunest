class FileResource {
  final String id;
  final String name;
  final String type;
  final String? url;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? subjectId;
  final String? description;

  FileResource({
    required this.id,
    required this.name,
    required this.type,
    this.url,
    required this.createdAt,
    required this.updatedAt,
    this.subjectId,
    this.description,
  });

  factory FileResource.fromJson(Map<String, dynamic> json) {
    return FileResource(
      id: json['id'] as String,
      name: json['name'] as String,
      type: json['type'] as String,
      url: json['url'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      subjectId: json['subject_id'] as String?,
      description: json['description'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'url': url,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'subject_id': subjectId,
      'description': description,
    };
  }
}
