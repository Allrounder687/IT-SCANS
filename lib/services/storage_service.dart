
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/scan_document.dart';

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
      version: 4,
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
            extractedText TEXT
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
}
