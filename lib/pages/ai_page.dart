import 'dart:convert';
import 'dart:io';
import 'package:cachy/database/database_helper.dart';
import 'package:cachy/model/memories_model.dart';
import 'package:cachy/widget/snackbar_message.dart';
import 'package:dio/dio.dart';
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
  // ======================= VARIABLES ======================= //
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

  var prompt = TextEditingController();
  var response = "";

  bool isDeeperSearch = false;
  bool isPermissionGranted = true;
  bool isModelDownloaded = true;
  bool isDownloading = false;
  bool isGenerating = false;
  bool isLoading = true;
  int memoriesCount = 0;

  // ======================= FUNCTIONS ======================= //

  // Used for showing any string in the response area of the app
  void showResponse(String resp) {
    setState(() {
      response = resp;
      isGenerating = false;
    });
    prompt.clear();
  }

  // Used for granting permission to read the downloaded model file
  Future<void> requestPermission() async {
    var status = await Permission.manageExternalStorage.request();
    if (status.isDenied) {
      setState(() {
        isPermissionGranted = false;
      });
    }

    if (status.isPermanentlyDenied) {
      openAppSettings();
    }
  }

  // Used to convert json string from model to json type
  dynamic jsonifyResponse(String response) {
    final cleanedResponse = response
        .replaceFirst(RegExp(r'^```json\s*'), '')
        .replaceFirst(RegExp(r'```$'), '')
        .trim();

    return jsonDecode(cleanedResponse);
  }

  // Used to search for memories with maching keywords
  getKeywordMatchingMemories(keywords) async {
    final filteredMemories = db.searchMemories(keywords);
    return filteredMemories;
  }

  // Used to convert Memories into formatted string to feed in AI models
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

  // Used for loading the model from the app directory or copy it from the downloads folder
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

      // Checks if the model is downloaded or not?
      if (e.toString().contains("PathNotFoundException: Cannot copy file to")) {
        showResponse("Model Not Downloaded");
        setState(() {
          isModelDownloaded = false;
        });
      }
    }
  }

  // Downloads the model from hugging face into your app directory
  Future<void> downloadModel() async {
    setState(() {
      isDownloading = true;
    });
    final appDir = await getApplicationDocumentsDirectory();

    final localModelPath = "${appDir.path}/gemma-4-E2B-it.litertlm";

    const modelUrl =
        "https://huggingface.co/litert-community/gemma-4-E2B-it-litert-lm/resolve/main/gemma-4-E2B-it.litertlm";

    final dio = Dio();

    try {
      await dio.download(
        modelUrl,
        localModelPath,

        onReceiveProgress: (received, total) {
          if (total != -1) {
            final progress = (received / total * 100).toStringAsFixed(0);

            // print("Progress: $progress%");
            showResponse("Downloading Model: $progress%");
          }
        },

        options: Options(
          responseType: ResponseType.bytes,
          followRedirects: true,
          receiveTimeout: const Duration(hours: 2),
        ),
      );
    } catch (e) {
      showResponse(e.toString());
    }
  }

  // Used for searching bigger chunks of memories for a deeper search
  List<String> splitIntoChunks(String text, {int maxLength = 10000}) {
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

  // Search every memory to find the answer
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

  // Used for getting the total numbers of memories present in the app
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
            isModelDownloaded
                ? Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: TextFormField(
                      controller: prompt,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(),
                        label: Text("Prompt"),
                      ),
                    ),
                  )
                : SizedBox.shrink(),
            isModelDownloaded
                ? ElevatedButton(
                    onPressed: isLoading | isGenerating
                        ? null
                        : () async {
                            if (prompt.text != "") {
                              setState(() {
                                isGenerating = true;
                              });
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

                                if (requestType["type"].toLowerCase() ==
                                    "write") {
                                  print("Its type Write");
                                  final data = Memories(
                                    data: requestType["data"],
                                    time: DateTime.now().millisecondsSinceEpoch,
                                  );
                                  db.createMemory(data);
                                  showResponse("Added: ${requestType["data"]}");
                                }

                                if (requestType["type"].toLowerCase() ==
                                    "read") {
                                  final memories = await db.getMemories();
                                  final allmemo = await getMemoriesString(
                                    memories,
                                  );

                                  if (allmemo.length < 15000) {
                                    print("length is okay");
                                    final filterPrompt = memoryFindingPrompt
                                        .replaceFirst(
                                          "{{memory_list}}",
                                          "${allmemo}",
                                        )
                                        .replaceAll(
                                          "{{user_request}}",
                                          "${prompt.text}",
                                        );
                                    final reply = await conversation!
                                        .sendMessage(filterPrompt);
                                    final filteredMemory = jsonifyResponse(
                                      reply.text,
                                    );

                                    showResponse(filteredMemory["response"]);
                                  } else {
                                    print("using above 15,000 technique");
                                    final searchKeywords = requestType["data"]
                                        .split(" ");
                                    final filteredMemories =
                                        await getKeywordMatchingMemories(
                                          searchKeywords,
                                        );
                                    final allmemostring =
                                        await getMemoriesString(
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
                                    final reply = await conversation!
                                        .sendMessage(filterPrompt);
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
                  )
                : SizedBox.shrink(),
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
            isModelDownloaded
                ? SizedBox.shrink()
                : !isDownloading
                ? ElevatedButton(
                    onPressed: () {
                      downloadModel();
                    },
                    child: Text("Download Model"),
                  )
                : SizedBox.shrink(),
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
