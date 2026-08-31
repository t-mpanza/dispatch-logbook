import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../models/entry.dart';
import '../models/reminder.dart';

class DatabaseService {
  static Database? _db;

  static Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDb();
    return _db!;
  }

  static Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'dispatch_diary.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE entries (
            id TEXT PRIMARY KEY,
            title TEXT NOT NULL,
            tags TEXT,
            expected_total INTEGER,
            notes TEXT,
            attachments TEXT,
            trips TEXT,
            loading_sheet_trips TEXT,
            despatcher_name TEXT,
            created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL,
            day_key TEXT NOT NULL,
            month_key TEXT NOT NULL,
            year_key TEXT NOT NULL
          )
        ''');

        await db.execute('''
          CREATE TABLE reminders (
            id TEXT PRIMARY KEY,
            entryId TEXT NOT NULL,
            at INTEGER NOT NULL,
            text TEXT NOT NULL,
            done INTEGER NOT NULL
          )
        ''');

        await db.execute('''
          CREATE TABLE settings (
            key TEXT PRIMARY KEY,
            value TEXT NOT NULL
          )
        ''');

        await db.execute(
            'CREATE INDEX idx_entries_day_key ON entries(day_key)');
        await db.execute(
            'CREATE INDEX idx_entries_updated_at ON entries(updated_at)');
      },
    );
  }

  // ── Entry Operations ────────────────────────────────────────────────────────

  static Future<List<Entry>> getAllEntries() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'entries',
      orderBy: 'created_at DESC',
    );
    return maps.map((m) => Entry.fromMap(m)).toList();
  }

  static Future<List<Entry>> getEntriesByDay(String dayKey) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'entries',
      where: 'day_key = ?',
      whereArgs: [dayKey],
      orderBy: 'created_at DESC',
    );
    return maps.map((m) => Entry.fromMap(m)).toList();
  }

  static Future<Entry?> getEntryById(String id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'entries',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return Entry.fromMap(maps.first);
  }

  static Future<void> insertOrUpdateEntry(Entry entry) async {
    final db = await database;
    await db.insert(
      'entries',
      entry.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<void> insertOrUpdateBatch(List<Entry> entries) async {
    if (entries.isEmpty) return;
    final db = await database;
    final batch = db.batch();
    for (final entry in entries) {
      batch.insert(
        'entries',
        entry.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  static Future<void> deleteEntry(String id) async {
    final db = await database;
    await db.delete('entries', where: 'id = ?', whereArgs: [id]);
  }

  static Future<List<Entry>> searchEntries(String query) async {
    final db = await database;
    final q = '%${query.trim().toLowerCase()}%';
    final List<Map<String, dynamic>> maps = await db.query(
      'entries',
      where:
          'LOWER(title) LIKE ? OR LOWER(tags) LIKE ? OR LOWER(notes) LIKE ? OR LOWER(loading_sheet_trips) LIKE ?',
      whereArgs: [q, q, q, q],
      orderBy: 'created_at DESC',
    );
    return maps.map((m) => Entry.fromMap(m)).toList();
  }

  static Future<List<String>> getAllTags() async {
    final entries = await getAllEntries();
    final Set<String> tagSet = {};
    for (final e in entries) {
      tagSet.addAll(e.tags);
    }
    final list = tagSet.toList()..sort();
    return list;
  }

  // ── Settings Operations ─────────────────────────────────────────────────────

  static Future<String?> getSetting(String key) async {
    final db = await database;
    final maps = await db.query(
      'settings',
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return maps.first['value'] as String?;
  }

  static Future<void> saveSetting(String key, String value) async {
    final db = await database;
    await db.insert(
      'settings',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // ── Reminders Operations ────────────────────────────────────────────────────

  static Future<List<Reminder>> getAllReminders() async {
    final db = await database;
    final maps = await db.query('reminders', orderBy: 'at ASC');
    return maps.map((m) => Reminder.fromMap(m)).toList();
  }

  static Future<void> saveReminder(Reminder reminder) async {
    final db = await database;
    await db.insert(
      'reminders',
      reminder.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}
