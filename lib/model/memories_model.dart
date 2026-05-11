class Memory {
  int? id;
  String data;
  int time;

  Memory({this.id, required this.data, required this.time});

  Map<String, dynamic> toMap() {
    return {'id': id, 'data': data, 'time': time};
  }

  factory Memory.fromMap(Map<String, dynamic> map) {
    return Memory(id: map['id'], data: map['data'], time: map['time']);
  }
}
