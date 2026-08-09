class ScanDocument {
  const ScanDocument({
    required this.id,
    required this.name,
    required this.pageCount,
    required this.filePath,
    required this.createdAt,
    this.isSynced = false,
    this.driveId,
    this.category,
    this.subfolder,
    this.extractedText,
  });

  final String id;
  final String name;
  final int pageCount;
  final String filePath;
  final DateTime createdAt;
  final bool isSynced;
  final String? driveId;
  final String? category;
  final String? subfolder;
  final String? extractedText;

  factory ScanDocument.fromMap(Map<String, dynamic> map) {
    return ScanDocument(
      id: map['id'] as String,
      name: map['name'] as String,
      pageCount: map['pageCount'] as int,
      filePath: map['filePath'] as String,
      createdAt: DateTime.parse(map['createdAt'] as String),
      isSynced: (map['isSynced'] as int?) == 1,
      driveId: map['driveId'] as String?,
      category: map['category'] as String?,
      subfolder: map['subfolder'] as String?,
      extractedText: map['extractedText'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'pageCount': pageCount,
      'filePath': filePath,
      'createdAt': createdAt.toIso8601String(),
      'isSynced': isSynced ? 1 : 0,
      'driveId': driveId,
      'category': category,
      'subfolder': subfolder,
      'extractedText': extractedText,
    };
  }

  ScanDocument copyWith({
    String? id,
    String? name,
    int? pageCount,
    String? filePath,
    DateTime? createdAt,
    bool? isSynced,
    String? driveId,
    String? category,
    String? subfolder,
    String? extractedText,
  }) {
    return ScanDocument(
      id: id ?? this.id,
      name: name ?? this.name,
      pageCount: pageCount ?? this.pageCount,
      filePath: filePath ?? this.filePath,
      createdAt: createdAt ?? this.createdAt,
      isSynced: isSynced ?? this.isSynced,
      driveId: driveId ?? this.driveId,
      category: category ?? this.category,
      subfolder: subfolder ?? this.subfolder,
      extractedText: extractedText ?? this.extractedText,
    );
  }
}

