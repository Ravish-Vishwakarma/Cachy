import 'package:cachy/model/memories_model.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

/// Singleton helper for SQLite database operations on the `memories` table.
class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  /// Lazily-initialized database instance.
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('memories.db');
    return _database!;
  }

  /// Opens or creates the SQLite database at the platform's default path.
  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(path, version: 1, onCreate: _createDB);
  }

  /// Creates the `memories` table with id, data, and time columns.
  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE memories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        data TEXT,
        time INTEGER
      )
    ''');
  }

  /// Inserts a new [memory] into the database and returns its row id.
  Future<int> createMemory(Memory memory) async {
    final db = await instance.database;

    return await db.insert('memories', memory.toMap());
  }

  /// Retrieves all memories ordered by rowid (insertion order).
  Future<List<Memory>> getMemories() async {
    final db = await instance.database;

    final result = await db.query('memories');

    return result.map((json) => Memory.fromMap(json)).toList();
  }

  /// Updates an existing [memory] identified by its id.
  Future<int> updateMemory(Memory memory) async {
    final db = await instance.database;

    return await db.update(
      'memories',
      memory.toMap(),
      where: 'id = ?',
      whereArgs: [memory.id],
    );
  }

  /// Deletes a memory by its [id].
  Future<int> deleteMemory(int id) async {
    final db = await instance.database;

    return await db.delete('memories', where: 'id = ?', whereArgs: [id]);
  }

  /// Searches memories whose `data` column contains any of the [keywords]
  /// using SQL `LIKE` with `%` wildcards. Keywords are OR-ed together.
  Future<List<Memory>> searchMemories(List<String> keywords) async {
    final db = await instance.database;

    if (keywords.isEmpty) {
      return [];
    }

    final whereClause = keywords.map((_) => 'data LIKE ?').join(' OR ');

    final whereArgs = keywords.map((keyword) => '%$keyword%').toList();

    final result = await db.query(
      'memories',
      where: whereClause,
      whereArgs: whereArgs,
    );

    return result.map((json) => Memory.fromMap(json)).toList();
  }

  /// Returns the total number of memories stored in the database.
  Future<int> getMemoriesCount() async {
    final db = await instance.database;

    final result = await db.rawQuery('SELECT COUNT(*) as count FROM memories');

    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// Closes the database connection and resets the cached instance.
  Future close() async {
    final db = await instance.database;
    await db.close();
    _database = null;
  }
}
