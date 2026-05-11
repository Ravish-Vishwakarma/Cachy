import 'package:cachy/model/memories_model.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class MemoryDetailDialog extends StatelessWidget {
  final Memory memory;
  const MemoryDetailDialog({super.key, required this.memory});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(memory.data, style: TextStyle(fontSize: 18)),
          Text(
            "Time: ${DateFormat('hh:mm aa -- dd-MMM-yyyy').format(DateTime.fromMillisecondsSinceEpoch(memory.time))}",
            style: TextStyle(color: Colors.grey[700]),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(context);
          },
          child: const Text('Close'),
        ),
      ],
    );
  }
}
