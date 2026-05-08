import 'dart:convert';
import 'dart:io';
import 'package:cachy/database/database_helper.dart';
import 'package:cachy/model/memories_model.dart';
import 'package:cachy/widget/snackbar_message.dart';
import 'package:flutter/material.dart';
import 'package:flutter_litert_lm/flutter_litert_lm.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class AIPage extends StatefulWidget {
  const AIPage({super.key});

  @override
  State<AIPage> createState() => _AIPageState();
}

class _AIPageState extends State<AIPage> {
  final classificationPrompt =
      '''You are a memory classifier. Determine whether the user wants to READ from memory/database or WRITE to memory/database.

Rules:
- If the user is asking for information, classify as "read" and return concise search keywords.
- If the user is providing information to save, classify as "write" and return a clean, formalized memory sentence.
- Respond ONLY in valid JSON.

Format:
{"type":"read|write","data":"keywords or formatted memory"}

USER:''';

  final memoryFindingPrompt =
      '''You are a memory retrieval agent. Your task is to find the most relevant memories for the user's request from the provided memory list and combine them into a natural response.

Rules:
- Use only the provided memories.
- Return a concise, human-readable sentence.
- If multiple memories are relevant, combine them naturally.
- If no relevant memory exists, respond with: "I could not find any relevant memory."
- Do not invent or assume information.
- Respond ONLY in valid JSON.

Format:
{"response":"natural language answer"}

USER REQUEST:
{{user_request}}

MEMORIES:
{{memory_list}}''';
  LiteLmEngine? engine;
  LiteLmConversation? conversation;
  bool isGenerating = false;
  bool isLoading = true;
  var prompt = TextEditingController();
  var response = "";
  void showResponse(String resp) {
    setState(() {
      response = resp;
      isGenerating = false;
    });
  }

  bool isDeeperSearch = false;
  bool isPermissionGranted = true;
  Future<void> requestPermission() async {
    var status = await Permission.manageExternalStorage.request();

    if (status.isGranted) {
      print("Permission Granted");
    }

    if (status.isDenied) {
      print("Permission Denied");
      setState(() {
        isPermissionGranted = false;
      });
    }

    if (status.isPermanentlyDenied) {
      openAppSettings();
    }
  }

  dynamic jsonifyResponse(String response) {
    final cleanedResponse = response
        .replaceFirst(RegExp(r'^```json\s*'), '')
        .replaceFirst(RegExp(r'```$'), '')
        .trim();

    return jsonDecode(cleanedResponse);
  }

  getKeywordMatchingMemories(keywords) async {
    final filteredMemories = db.searchMemories(keywords);
    return filteredMemories;
  }

  Future<String> getMemoriesString(memories) async {
    return memories
        .asMap()
        .entries
        .map((entry) {
          int index = entry.key + 1;
          Memories memory = entry.value;

          return "$index. ${memory.data}";
        })
        .join("\n");
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

  List<String> splitIntoChunks(String text, {int maxLength = 2000}) {
    List<String> chunks = [];

    while (text.isNotEmpty) {
      if (text.length <= maxLength) {
        chunks.add(text.trim());
        break;
      }

      int splitIndex = text.lastIndexOf('\n', maxLength);

      if (splitIndex == -1) {
        splitIndex = maxLength;
      }

      chunks.add(text.substring(0, splitIndex).trim());

      text = text.substring(splitIndex).trim();
    }

    return chunks;
  }

  deeperSearch() async {
    final memories = await db.getMemories();

    final allmemo = await getMemoriesString(memories);

    List<String> listOfMemories = splitIntoChunks(allmemo);

    for (int i = 0; i < listOfMemories.length; i++) {
      final filterPrompt = memoryFindingPrompt
          .replaceFirst("{{memory_list}}", "${listOfMemories[i]}")
          .replaceAll("{{user_request}}", "${prompt.text}");
      final reply = await conversation!.sendMessage(filterPrompt);
      final filteredMemory = jsonifyResponse(reply.text);
      if (!filteredMemory["response"].contains(
        "could not find any relevant memory",
      )) {
        showResponse(filteredMemory["response"]);
        break;
      }
    }
  }

  int memoriesCount = 0;

  void getMemoriesCount() async {
    int count = await db.getMemoriesCount();
    setState(() {
      memoriesCount = count;
    });
  }

  @override
  void initState() {
    super.initState();
    requestPermission();
    loadModel();
    getMemoriesCount();
  }

  final db = DatabaseHelper.instance;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("CACHY", style: TextStyle(color: Colors.white)),
        actions: [
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 0, 10, 0),
            child: Text(
              "TOTAL MEMORIES: ${memoriesCount}",
              style: TextStyle(color: Colors.white),
            ),
          ),
          isPermissionGranted
              ? SizedBox.shrink()
              : IconButton(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (context) {
                        return AlertDialog(
                          title: Text("File Permission not Allowed"),
                          // content: RichText(
                          //   // "Please Allow File Permission to 'Allow management of all files' in Settings",
                          // ),
                          content: RichText(
                            text: TextSpan(
                              style: TextStyle(color: Colors.black),
                              children: [
                                TextSpan(
                                  text:
                                      "Please Allow File Permission and set it to: ",
                                ),
                                TextSpan(
                                  text: "'Allow management of all files' ",
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                TextSpan(text: "in Settings."),
                              ],
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
                                openAppSettings();
                              },
                              child: Text("Setting"),
                            ),
                          ],
                        );
                      },
                    );
                  },
                  icon: Icon(Icons.error_outline, color: Colors.red),
                ),
        ],
        backgroundColor: const Color(0xFF093176),
      ),
      body: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: TextFormField(
                controller: prompt,
                decoration: InputDecoration(
                  border: OutlineInputBorder(),
                  label: Text("Prompt"),
                ),
              ),
            ),
            ElevatedButton(
              onPressed: isLoading | isGenerating
                  ? null
                  : () async {
                      setState(() {
                        isGenerating = true;
                      });
                      if (prompt.text != "") {
                        if (isLoading || conversation == null) {
                          showResponse("Model still loading...");
                          return;
                        }
                        final structuredPrompt =
                            "${classificationPrompt}${prompt.text}";
                        try {
                          final reply = await conversation!.sendMessage(
                            structuredPrompt,
                          );
                          final requestType = jsonifyResponse(reply.text);

                          if (requestType["type"].toLowerCase() == "write") {
                            print("Its type Write");
                            final data = Memories(
                              data: requestType["data"],
                              time: DateTime.now().millisecondsSinceEpoch,
                            );
                            db.createMemory(data);
                            showResponse("Added: ${requestType["data"]}");
                          }

                          if (requestType["type"].toLowerCase() == "read") {
                            final memories = await db.getMemories();
                            final allmemo = await getMemoriesString(memories);
                            if (allmemo.length < 3000) {
                              print("length is okay");
                              final filterPrompt = memoryFindingPrompt
                                  .replaceFirst("{{memory_list}}", "${allmemo}")
                                  .replaceAll(
                                    "{{user_request}}",
                                    "${prompt.text}",
                                  );
                              final reply = await conversation!.sendMessage(
                                filterPrompt,
                              );
                              final filteredMemory = jsonifyResponse(
                                reply.text,
                              );

                              showResponse(filteredMemory["response"]);
                            } else {
                              print("using above 3000 technique");
                              final searchKeywords = requestType["data"].split(
                                " ",
                              );
                              final filteredMemories =
                                  await getKeywordMatchingMemories(
                                    searchKeywords,
                                  );
                              final allmemostring = await getMemoriesString(
                                filteredMemories,
                              );
                              final filterPrompt = memoryFindingPrompt
                                  .replaceFirst(
                                    "{{memory_list}}",
                                    "${allmemostring}",
                                  )
                                  .replaceAll(
                                    "{{user_request}}",
                                    "${prompt.text}",
                                  );
                              final reply = await conversation!.sendMessage(
                                filterPrompt,
                              );
                              final filteredMemory = jsonifyResponse(
                                reply.text,
                              );
                              if (filteredMemory["response"].contains(
                                "could not find any relevant memory",
                              )) {
                                setState(() {
                                  isDeeperSearch = true;
                                });
                              }
                              showResponse(filteredMemory["response"]);
                            }
                          }

                          // showResponse(reply.text);
                        } catch (e) {
                          showResponse(e.toString());
                        }
                      } else {
                        SnackbarMessage.show(context, "Enter A Prompt");
                      }
                    },
              child: Text(isLoading ? "Loading model..." : "Send"),
            ),
            isGenerating
                ? Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      "Generating...",
                      style: TextStyle(fontSize: 20),
                    ),
                  )
                : response == ""
                ? SizedBox.shrink()
                : Padding(
                    padding: const EdgeInsets.all(2.0),
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: SelectableText(
                          response,
                          style: TextStyle(fontSize: 20),
                        ),
                      ),
                    ),
                  ),
            isDeeperSearch
                ? Column(
                    children: [
                      SizedBox(height: 40),
                      Text("Want Deeper Search?"),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          TextButton(
                            onPressed: () {
                              setState(() {
                                isDeeperSearch = false;
                              });
                            },
                            child: Text("No"),
                          ),
                          TextButton(
                            onPressed: () {
                              setState(() {
                                isDeeperSearch = false;
                              });
                              deeperSearch();
                            },
                            child: Text("Yes!"),
                          ),
                        ],
                      ),
                    ],
                  )
                : Container(),
          ],
        ),
      ),
    );
  }
}
