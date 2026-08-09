class AppSection {
  final String id;
  final String name;
  final int orderIndex;

  const AppSection({
    required this.id,
    required this.name,
    this.orderIndex = 0,
  });

  factory AppSection.fromMap(Map<String, dynamic> map) {
    return AppSection(
      id: map['id'] as String,
      name: map['name'] as String,
      orderIndex: map['orderIndex'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'orderIndex': orderIndex,
    };
  }
}

class AppSubfolder {
  final String id;
  final String sectionId;
  final String name;

  const AppSubfolder({
    required this.id,
    required this.sectionId,
    required this.name,
  });

  factory AppSubfolder.fromMap(Map<String, dynamic> map) {
    return AppSubfolder(
      id: map['id'] as String,
      sectionId: map['sectionId'] as String,
      name: map['name'] as String,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'sectionId': sectionId,
      'name': name,
    };
  }
}
