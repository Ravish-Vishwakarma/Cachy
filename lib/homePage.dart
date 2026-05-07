import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_litert_lm/flutter_litert_lm.dart';
import 'package:path_provider/path_provider.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  LiteLmEngine? engine;
  LiteLmConversation? conversation;

  bool isLoading = true;
  var prompt = TextEditingController();
  var response = "";
  void showResponse(String resp) {
    setState(() {
      response = resp;
    });
  }

  Future<void> loadModel() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();

      final localModelPath = "${appDir.path}/gemma-4-E2B-it.litertlm";

      final localModelFile = File(localModelPath);

      if (!await localModelFile.exists()) {
        final sourceFile = File(
          "/storage/emulated/0/Download/gemma-4-E2B-it.litertlm",
        );

        await sourceFile.copy(localModelPath);
      }

      engine = await LiteLmEngine.create(
        LiteLmEngineConfig(
          modelPath: localModelPath,
          backend: LiteLmBackend.cpu,
        ),
      );

      conversation = await engine!.createConversation(
        LiteLmConversationConfig(
          systemInstruction: "You are a helpful assistant.",
        ),
      );

      setState(() {
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
      });

      showResponse(e.toString());
    }
  }

  @override
  void initState() {
    super.initState();
    loadModel();
  }

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
              if (isLoading || conversation == null) {
                showResponse("Model still loading...");
                return;
              }

              try {
                final reply = await conversation!.sendMessage(prompt.text);

                showResponse(reply.text);
              } catch (e) {
                showResponse(e.toString());
              }
            },
            child: Text(isLoading ? "Loading model..." : "Send"),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(isLoading ? "Loading model..." : response),
          ),
        ],
      ),
    );
  }
}
