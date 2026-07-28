class ScanDocument {
  const ScanDocument({
    required this.id,
    required this.name,
    required this.pageCount,
    required this.filePath,
    required this.createdAt,
    this.isSynced = false,
    this.driveId,
  });

  final String id;
  final String name;
  final int pageCount;
  final String filePath;
  final DateTime createdAt;
  final bool isSynced;
  final String? driveId;

  factory ScanDocument.fromMap(Map<String, dynamic> map) {
    return ScanDocument(
      id: map['id'] as String,
      name: map['name'] as String,
      pageCount: map['pageCount'] as int,
      filePath: map['filePath'] as String,
      createdAt: DateTime.parse(map['createdAt'] as String),
      isSynced: (map['isSynced'] as int?) == 1,
      driveId: map['driveId'] as String?,
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
    };
  }
}
