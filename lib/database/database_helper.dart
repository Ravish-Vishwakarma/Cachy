import 'package:cachy/model/memories_model.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('memories.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(path, version: 1, onCreate: _createDB);
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE memories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        data TEXT,
        time INTEGER
      )
    ''');
  }

  Future<int> createMemory(Memory memory) async {
    final db = await instance.database;

    return await db.insert('memories', memory.toMap());
  }

  Future<List<Memory>> getMemories() async {
    final db = await instance.database;

    final result = await db.query('memories');

    return result.map((json) => Memory.fromMap(json)).toList();
  }

  Future<int> updateMemory(Memory memory) async {
    final db = await instance.database;

    return await db.update(
      'memories',
      memory.toMap(),
      where: 'id = ?',
      whereArgs: [memory.id],
    );
  }

  Future<int> deleteMemory(int id) async {
    final db = await instance.database;

    return await db.delete('memories', where: 'id = ?', whereArgs: [id]);
  }

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

  Future<int> getMemoriesCount() async {
    final db = await instance.database;

    final result = await db.rawQuery('SELECT COUNT(*) as count FROM memories');

    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future close() async {
    final db = await instance.database;
    await db.close();
    _database = null;
  }
}
