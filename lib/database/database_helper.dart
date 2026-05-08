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

  Future<int> createMemory(Memories memory) async {
    final db = await instance.database;

    return await db.insert('memories', memory.toMap());
  }

  Future<List<Memories>> getMemories() async {
    final db = await instance.database;

    final result = await db.query('memories');

    return result.map((json) => Memories.fromMap(json)).toList();
  }

  Future<int> updateMemory(Memories memory) async {
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

  Future close() async {
    final db = await instance.database;

    db.close();
  }
}
