import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  var prompt = TextEditingController();
  var response = "";
  void showResponse(String resp) {
    setState(() {
      response = resp;
    });
  }

  static const platform = MethodChannel("gemma");

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Cachy")),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextFormField(
              controller: prompt,
              maxLines: null,
              decoration: InputDecoration(
                border: OutlineInputBorder(),
                label: Text("Prompt"),
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                final result = await platform.invokeMethod("generate", {
                  "prompt": prompt.text,
                });

                showResponse(result);
              } catch (e) {
                showResponse(e.toString());
              }
            },
            child: Text("Send"),
          ),
          Padding(padding: const EdgeInsets.all(8.0), child: Text(response)),
        ],
      ),
    );
  }
}
