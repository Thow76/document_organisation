import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/document.dart';
import '../models/reminder.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  static Database? _database;

  factory DatabaseService() => _instance;

  DatabaseService._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;

    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'docsafe.db');

    return await openDatabase(
      path,
      version: 2,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE documents (
            id TEXT PRIMARY KEY,
            title TEXT,
            category TEXT,
            captureDate TEXT,
            letterDate TEXT,
            priority TEXT,
            notes TEXT,
            imagePath TEXT,
            aiSummary TEXT,
            aiTags TEXT,
            actionableDate TEXT,
            actionableDateContext TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE reminders (
            id TEXT PRIMARY KEY,
            documentId TEXT,
            actionableDate TEXT,
            contextReason TEXT,
            notifyDaysBefore INTEGER,
            isCompleted INTEGER,
            createdAt TEXT,
            FOREIGN KEY (documentId) REFERENCES documents(id)
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('ALTER TABLE documents ADD COLUMN actionableDate TEXT');
          await db.execute('ALTER TABLE documents ADD COLUMN actionableDateContext TEXT');
        }
      },
    );
  }

  Future<void> insertDocument(Document doc) async {
    final db = await database;
    await db.insert('documents', doc.toMap());
  }

  Future<void> updateDocument(Document doc) async {
    final db = await database;
    await db.update(
      'documents',
      doc.toMap(),
      where: 'id = ?',
      whereArgs: [doc.id],
    );
  }

  Future<void> deleteDocument(String id) async {
    final db = await database;
    await db.delete('reminders', where: 'documentId = ?', whereArgs: [id]);
    await db.delete('documents', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Document>> getAllDocuments() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('documents');

    return maps.map((map) => Document.fromMap(map)).toList();
  }

  Future<List<Document>> getDocumentsByCategory(String category) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'documents',
      where: 'category = ?',
      whereArgs: [category],
    );

    return maps.map((map) => Document.fromMap(map)).toList();
  }

  Future<List<Document>> searchDocuments(String query) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'documents',
      where:
          'title LIKE ? OR notes LIKE ? OR aiSummary LIKE ? OR aiTags LIKE ?',
      whereArgs: ['%$query%', '%$query%', '%$query%', '%$query%'],
    );

    return maps.map((map) => Document.fromMap(map)).toList();
  }

  // ── Reminder methods ──────────────────────────────────────────────────────

  Future<void> insertReminder(Reminder reminder) async {
    final db = await database;
    await db.insert('reminders', reminder.toMap());
  }

  Future<void> updateReminder(Reminder reminder) async {
    final db = await database;
    await db.update(
      'reminders',
      reminder.toMap(),
      where: 'id = ?',
      whereArgs: [reminder.id],
    );
  }

  Future<void> deleteReminder(String id) async {
    final db = await database;
    await db.delete('reminders', where: 'id = ?', whereArgs: [id]);
  }

  Future<Reminder?> getReminderForDocument(String documentId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'reminders',
      where: 'documentId = ?',
      whereArgs: [documentId],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return Reminder.fromMap(maps.first);
  }

  Future<List<Reminder>> getAllActiveReminders() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'reminders',
      where: 'isCompleted = 0',
      orderBy: 'actionableDate ASC',
    );
    return maps.map((map) => Reminder.fromMap(map)).toList();
  }

  Future<List<Reminder>> getUpcomingReminders(int days) async {
    final db = await database;
    final now = DateTime.now();
    final cutoff = now.add(Duration(days: days));
    final List<Map<String, dynamic>> maps = await db.query(
      'reminders',
      where: 'isCompleted = 0 AND actionableDate >= ? AND actionableDate <= ?',
      whereArgs: [now.toIso8601String(), cutoff.toIso8601String()],
      orderBy: 'actionableDate ASC',
    );
    return maps.map((map) => Reminder.fromMap(map)).toList();
  }
}
