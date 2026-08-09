import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/scan_document.dart';
import '../models/category_model.dart';

class StorageService {
  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDB();
    return _db!;
  }

  Future<Database> _initDB() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'scans.db');

    return await openDatabase(
      path,
      version: 5,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE scans(
            id TEXT PRIMARY KEY,
            name TEXT,
            pageCount INTEGER,
            filePath TEXT,
            createdAt TEXT,
            isSynced INTEGER DEFAULT 0,
            driveId TEXT,
            category TEXT,
            subfolder TEXT,
            extractedText TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE sections(
            id TEXT PRIMARY KEY,
            name TEXT,
            orderIndex INTEGER DEFAULT 0
          )
        ''');
        await db.execute('''
          CREATE TABLE subfolders(
            id TEXT PRIMARY KEY,
            sectionId TEXT,
            name TEXT
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('ALTER TABLE scans ADD COLUMN isSynced INTEGER DEFAULT 0');
        }
        if (oldVersion < 3) {
          await db.execute('ALTER TABLE scans ADD COLUMN driveId TEXT');
        }
        if (oldVersion < 4) {
          await db.execute('ALTER TABLE scans ADD COLUMN category TEXT');
          await db.execute('ALTER TABLE scans ADD COLUMN extractedText TEXT');
        }
        if (oldVersion < 5) {
          await db.execute('ALTER TABLE scans ADD COLUMN subfolder TEXT');
          await db.execute('''
            CREATE TABLE sections(
              id TEXT PRIMARY KEY,
              name TEXT,
              orderIndex INTEGER DEFAULT 0
            )
          ''');
          await db.execute('''
            CREATE TABLE subfolders(
              id TEXT PRIMARY KEY,
              sectionId TEXT,
              name TEXT
            )
          ''');
        }
      },
    );
  }

  Future<void> saveScanDocument(ScanDocument doc) async {
    final db = await database;
    await db.insert(
      'scans',
      doc.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // --- Category Models ---

  Future<List<AppSection>> getSections() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('sections', orderBy: 'orderIndex ASC');
    return List.generate(maps.length, (i) => AppSection.fromMap(maps[i]));
  }

  Future<void> saveSection(AppSection section) async {
    final db = await database;
    await db.insert('sections', section.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> deleteSection(String id) async {
    final db = await database;
    await db.delete('sections', where: 'id = ?', whereArgs: [id]);
    await db.delete('subfolders', where: 'sectionId = ?', whereArgs: [id]);
  }

  Future<List<AppSubfolder>> getSubfolders(String sectionId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('subfolders', where: 'sectionId = ?', whereArgs: [sectionId]);
    return List.generate(maps.length, (i) => AppSubfolder.fromMap(maps[i]));
  }

  Future<List<AppSubfolder>> getAllSubfolders() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('subfolders');
    return List.generate(maps.length, (i) => AppSubfolder.fromMap(maps[i]));
  }

  Future<void> saveSubfolder(AppSubfolder subfolder) async {
    final db = await database;
    await db.insert('subfolders', subfolder.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> deleteSubfolder(String id) async {
    final db = await database;
    await db.delete('subfolders', where: 'id = ?', whereArgs: [id]);
  }


  Future<List<ScanDocument>> getScanDocuments() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'scans',
      orderBy: 'createdAt DESC',
    );
    return List.generate(maps.length, (i) {
      return ScanDocument.fromMap(maps[i]);
    });
  }

  Future<void> deleteDocument(String id) async {
    final db = await database;
    await db.delete(
      'scans',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> updateDocumentName(String id, String newName) async {
    final db = await database;
    await db.update(
      'scans',
      {'name': newName},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> updateDocumentCategory(String id, String category) async {
    final db = await database;
    await db.update(
      'scans',
      {'category': category},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> moveDocument(String id, String category, String? subfolder) async {
    final db = await database;
    await db.update(
      'scans',
      {
        'category': category,
        'subfolder': subfolder,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> updateSyncStatus(String id, bool isSynced, {String? driveId}) async {
    final db = await database;
    
    final Map<String, dynamic> data = {'isSynced': isSynced ? 1 : 0};
    if (driveId != null) {
      data['driveId'] = driveId;
    }
    
    await db.update(
      'scans',
      data,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<String> exportStructureToJson() async {
    final sections = await getSections();
    final subfolders = await getAllSubfolders();
    
    final map = {
      'sections': sections.map((s) => s.toMap()).toList(),
      'subfolders': subfolders.map((s) => s.toMap()).toList(),
    };
    
    return jsonEncode(map);
  }

  Future<void> importStructureFromJson(String jsonString) async {
    try {
      final map = jsonDecode(jsonString) as Map<String, dynamic>;
      final sectionsList = map['sections'] as List<dynamic>? ?? [];
      final subfoldersList = map['subfolders'] as List<dynamic>? ?? [];
      
      final db = await database;
      
      await db.transaction((txn) async {
        for (final secMap in sectionsList) {
          await txn.insert(
            'sections',
            secMap as Map<String, dynamic>,
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
        for (final subMap in subfoldersList) {
          await txn.insert(
            'subfolders',
            subMap as Map<String, dynamic>,
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      });
    } catch (e) {
      // Ignore parse errors safely
    }
  }
}
