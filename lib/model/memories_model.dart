/// Represents a single memory record stored in the local database.
class Memory {
  /// Auto-incremented primary key. Null for new unsaved memories.
  int? id;

  /// The textual content of the memory.
  String data;

  /// Unix timestamp in milliseconds of when this memory was created.
  int time;

  Memory({this.id, required this.data, required this.time});

  /// Converts this memory to a map for SQLite insertion/update.
  Map<String, dynamic> toMap() {
    return {'id': id, 'data': data, 'time': time};
  }

  /// Creates a [Memory] from a database row map.
  factory Memory.fromMap(Map<String, dynamic> map) {
    return Memory(id: map['id'], data: map['data'], time: map['time']);
  }
}
