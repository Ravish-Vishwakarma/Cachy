class Memories {
  int? id;
  String data;
  int time;

  Memories({this.id, required this.data, required this.time});

  Map<String, dynamic> toMap() {
    return {'id': id, 'data': data, 'time': time};
  }

  factory Memories.fromMap(Map<String, dynamic> map) {
    return Memories(id: map['id'], data: map['data'], time: map['time']);
  }
}
