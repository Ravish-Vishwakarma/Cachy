import 'package:cachy/widget/snackbar_message.dart';
import 'package:flutter/material.dart';

class CreateMemoryDialog extends StatelessWidget {
  final Function(String memory) onSave;
  const CreateMemoryDialog({super.key, required this.onSave});

  @override
  Widget build(BuildContext context) {
    var memoryController = TextEditingController();
    return AlertDialog(
      title: const Text('New Memory'),
      content: TextFormField(
        autofocus: true,
        controller: memoryController,
        decoration: InputDecoration(
          labelText: "memory",
          border: OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(context);
          },
          child: const Text('Close'),
        ),
        TextButton(
          onPressed: () {
            if (memoryController.text != "") {
              onSave(memoryController.text);
              SnackbarMessage.show(context, "Added");
            }
            Navigator.pop(context);
          },
          child: Text("Save"),
        ),
      ],
    );
  }
}
